import { GlobalData } from '../common/GlobalData';
import { ChatMessage, ChatHistoryItem, ChatRole } from '../model/ChatModels';
import { ChatPersist } from '../model/ChatPersist';
import { ChatService, ChatCallbacks } from '../services/ChatService';

@ObservedV2
export class ChatViewModel {
  @Trace inputContent: string = '';
  @Trace messages: Array<ChatMessage> = [];
  @Trace isLoading: boolean = false;
}

export class ChatController {
  private vm: ChatViewModel;
  private service: ChatService;
  private persist: ChatPersist;
  private context: Context | null = null;
  private seq: number = 0;
  private activeAiMessage: ChatMessage | null = null;

  constructor(vm: ChatViewModel) {
    this.vm = vm;
    this.service = ChatService.getInstance();
    this.persist = new ChatPersist();
  }

  getViewModel(): ChatViewModel {
    return this.vm;
  }

  isConfigured(): boolean {
    return this.service.isConfigured();
  }

  async init(context: Context | undefined): Promise<void> {
    const fallback: Context | undefined = GlobalData.appContext !== null ? GlobalData.appContext : undefined;
    const ctx: Context | undefined = context !== undefined ? context : fallback;
    if (ctx === undefined) {
      console.error('ChatController init failed: no context available');
      return;
    }
    this.context = ctx;
    await this.persist.init(ctx);
    await this.service.init(ctx);
    await this.restoreHistory();
  }

  async send(): Promise<void> {
    const text: string = this.vm.inputContent.trim();
    if (text.length === 0 || this.vm.isLoading) {
      return;
    }
    if (!this.service.isConfigured() && this.context !== null) {
      await this.service.init(this.context);
    }
    const userMsg: ChatMessage = new ChatMessage();
    userMsg.id = this.nextId();
    userMsg.role = ChatRole.USER;
    userMsg.content = text;

    const aiMsg: ChatMessage = new ChatMessage();
    aiMsg.id = this.nextId();
    aiMsg.role = ChatRole.ASSISTANT;
    aiMsg.content = '';
    aiMsg.isThinking = true;

    this.vm.messages.push(userMsg);
    this.vm.messages.push(aiMsg);
    this.vm.inputContent = '';
    this.vm.isLoading = true;
    this.activeAiMessage = aiMsg;

    const history: Array<ChatHistoryItem> = await this.buildHistory();
    const callbacks: ChatCallbacks = {
      onChunk: (chunk: string) => {
        if (this.activeAiMessage) {
          this.activeAiMessage.content += chunk;
        }
      },
      onDone: () => {
        this.finishTurn(false, '');
      },
      onError: (message: string) => {
        this.finishTurn(true, message);
      }
    };
    await this.service.sendMessage(history, callbacks);
  }

  stop(): void {
    this.service.cancel();
    this.finishTurn(false, '');
  }

  async newSession(): Promise<void> {
    if (this.vm.isLoading) {
      return;
    }
    await this.persistSession();
    this.vm.messages = [];
    this.vm.inputContent = '';
    this.activeAiMessage = null;
  }

  private nextId(): number {
    this.seq += 1;
    return this.seq;
  }

  private finishTurn(isError: boolean, message: string): void {
    this.vm.isLoading = false;
    if (this.activeAiMessage) {
      this.activeAiMessage.isThinking = false;
      if (isError) {
        this.activeAiMessage.isError = true;
        if (this.activeAiMessage.content.length === 0) {
          this.activeAiMessage.content = message;
        }
      }
      this.activeAiMessage = null;
    }
    if (!isError) {
      this.persistSession();
    }
  }

  private async persistSession(): Promise<void> {
    const history: Array<ChatHistoryItem> = this.toHistoryItems();
    await this.persist.saveSession(history);
  }

  private async restoreHistory(): Promise<void> {
    const history: Array<ChatHistoryItem> = await this.persist.loadSession();
    this.vm.messages = [];
    for (let i = 0; i < history.length; i++) {
      const item: ChatHistoryItem = history[i];
      const msg: ChatMessage = new ChatMessage();
      msg.id = this.nextId();
      msg.role = item.role;
      msg.content = item.content;
      this.vm.messages.push(msg);
    }
  }

  private toHistoryItems(): Array<ChatHistoryItem> {
    const result: Array<ChatHistoryItem> = [];
    for (let i = 0; i < this.vm.messages.length; i++) {
      const msg: ChatMessage = this.vm.messages[i];
      if (msg.content.length === 0) {
        continue;
      }
      const item: ChatHistoryItem = new ChatHistoryItem();
      item.role = msg.role;
      item.content = msg.content;
      result.push(item);
    }
    return result;
  }

  private async buildHistory(): Promise<Array<ChatHistoryItem>> {
    const result: Array<ChatHistoryItem> = [];
    const system: ChatHistoryItem = new ChatHistoryItem();
    system.role = ChatRole.SYSTEM;
    system.content = await this.buildSystemPrompt();
    result.push(system);
    const past: Array<ChatHistoryItem> = this.toHistoryItems();
    for (let i = 0; i < past.length; i++) {
      result.push(past[i]);
    }
    return result;
  }

  private async buildSystemPrompt(): Promise<string> {
    let context: string = '用户今天还没有记录任何健康数据。';
    try {
      if (GlobalData.initialized) {
        const today: string = await GlobalData.getTodayDate();
        const summary = await GlobalData.db.getDailySummary(today);
        if (summary !== null) {
          const steps: number = Number(summary.steps) || 0;
          const waterMl: number = Number(summary.water_ml) || 0;
          const sleepHours: number = Number(summary.sleep_hours) || 0;
          const sleepScore: number = Number(summary.sleep_score) || 0;
          const exerciseMin: number = Number(summary.exercise_minutes) || 0;
          context = '用户今日健康数据（来自应用真实记录）：步数 ' + String(steps) +
            ' 步，喝水 ' + String(waterMl) + ' ml，睡眠 ' + String(sleepHours) +
            ' 小时（评分 ' + String(sleepScore) + '），运动 ' + String(exerciseMin) + ' 分钟。';
        }
      }
    } catch (err) {
      console.error('ChatController buildSystemPrompt error:', JSON.stringify(err));
    }
    return '你是「健康1st」应用内置的健康助手，请用中文回答用户关于饮食、运动、睡眠、喝水、体重等健康问题，给出实用、科学的建议。' +
      context +
      ' 如果某项数据缺失或为 0，说明用户今天还没有该记录，不要编造数据。回答保持简洁、友好、具体。';
  }
}
