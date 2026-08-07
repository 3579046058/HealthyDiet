import { GlobalData } from '../common/GlobalData';
import { ChatMessage, ChatHistoryItem, ChatRole, ChatSession } from '../model/ChatModels';
import { ChatPersist } from '../model/ChatPersist';
import { ChatService, ChatCallbacks } from '../services/ChatService';
import { KbService, KbChunk } from '../services/KbService';
import { DietAgentDraft, DietIntentResult, DietRecordInput, DietRecordResult } from '../model/HealthAgentModels';
import { HealthDataService } from '../services/HealthDataService';

@ObservedV2
export class ChatViewModel {
  @Trace inputContent: string = '';
  @Trace messages: Array<ChatMessage> = [];
  @Trace isLoading: boolean = false;
  @Trace sessions: Array<ChatSession> = [];
  @Trace currentSessionId: string = '';
  @Trace currentSessionTitle: string = '';
  @Trace isWide: boolean = false;
  @Trace isExpanded: boolean = false;
  @Trace drawerOpen: boolean = false;
  @Trace isRecording: boolean = false;
  @Trace pendingDiet: DietAgentDraft | null = null;
  @Trace pendingDietAmount: string = '';
  @Trace pendingDietError: string = '';
  @Trace isSavingDiet: boolean = false;

  @Computed
  get sessionList(): Array<ChatSession> {
    const result: Array<ChatSession> = [];
    for (let i = this.sessions.length - 1; i >= 0; i--) {
      result.push(this.sessions[i]);
    }
    return result;
  }
}

export class ChatController {
  private vm: ChatViewModel;
  private service: ChatService;
  private persist: ChatPersist;
  private context: Context | null = null;
  private seq: number = 0;
  private turnToken: number = 0;
  private activeAiMessage: ChatMessage | null = null;
  private currentSession: ChatSession = new ChatSession();

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
    await KbService.getInstance().init(ctx);
    await this.restoreState();
  }

  async send(): Promise<void> {
    const text: string = this.vm.inputContent.trim();
    if (text.length === 0 || this.vm.isLoading) {
      return;
    }
    if (!this.service.isConfigured() && this.context !== null) {
      await this.service.init(this.context);
    }
    if (this.currentSession.id.length === 0) {
      this.currentSession = this.createSession();
    }
    const isFirstMessage: boolean = this.currentSession.title.length === 0;
    if (isFirstMessage) {
      const provisional: string = text.length > 12 ? text.slice(0, 12) : text;
      this.currentSession.title = provisional;
    }
    this.vm.currentSessionId = this.currentSession.id;
    this.vm.currentSessionTitle = this.currentSession.title;

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
    this.turnToken += 1;
    const activeTurn: number = this.turnToken;

    if (isFirstMessage) {
      const targetId: string = this.currentSession.id;
      this.generateTitleAsync(targetId, text);
    }

    const dietIntent: DietIntentResult = await this.service.extractDietIntent(text);
    if (activeTurn !== this.turnToken || !this.vm.isLoading) {
      return;
    }
    if (dietIntent.isDietAction) {
      if (dietIntent.draft.mealType.length === 0) {
        dietIntent.draft.mealType = HealthDataService.inferMealType(new Date().getHours());
      }
      this.vm.pendingDiet = dietIntent.draft;
      this.vm.pendingDietAmount = dietIntent.draft.amountG > 0 ? String(dietIntent.draft.amountG) : '';
      this.vm.pendingDietError = '';
      aiMsg.isThinking = false;
      aiMsg.content = this.buildDietConfirmationText(dietIntent.draft);
      this.finishTurn(false, '');
      return;
    }

    const hits: Array<KbChunk> = [];
    try {
      const found: Array<KbChunk> = KbService.getInstance().search(text, 3);
      for (let i = 0; i < found.length; i++) {
        hits.push(found[i]);
      }
    } catch (err) {
      console.error('ChatController kb pre-search error:', JSON.stringify(err));
    }
    aiMsg.isSearching = hits.length > 0;
    const history: Array<ChatHistoryItem> = await this.buildHistory(text, hits);
    const callbacks: ChatCallbacks = {
      onChunk: (chunk: string) => {
        if (activeTurn === this.turnToken && this.activeAiMessage) {
          this.activeAiMessage.isSearching = false;
          this.activeAiMessage.content += chunk;
        }
      },
      onDone: () => {
        if (activeTurn === this.turnToken) {
          this.finishTurn(false, '');
        }
      },
      onError: (message: string) => {
        if (activeTurn === this.turnToken) {
          this.finishTurn(true, message);
        }
      }
    };
    await this.service.sendMessage(history, callbacks);
  }

  stop(): void {
    this.turnToken += 1;
    this.service.cancel();
    this.finishTurn(false, '');
  }

  async confirmDietDraft(): Promise<void> {
    const draft: DietAgentDraft | null = this.vm.pendingDiet;
    if (draft === null || this.vm.isSavingDiet) {
      return;
    }
    const amountG: number = Number(this.vm.pendingDietAmount.trim());
    if (!Number.isFinite(amountG) || amountG <= 0 || amountG > 10000) {
      this.vm.pendingDietError = '请输入 0 到 10000 克之间的有效重量';
      return;
    }
    this.vm.isSavingDiet = true;
    this.vm.pendingDietError = '';
    try {
      const input: DietRecordInput = new DietRecordInput();
      input.date = await GlobalData.getTodayDate();
      input.mealType = draft.mealType;
      input.foodName = draft.foodName;
      input.amountG = amountG;
      const saveResult: DietRecordResult = await HealthDataService.getInstance().addDietRecord(input);
      if (!saveResult.success) {
        this.vm.pendingDietError = saveResult.message;
        return;
      }
      this.vm.pendingDiet = null;
      this.vm.pendingDietAmount = '';
      this.vm.pendingDietError = '';
      this.appendAssistantMessage(saveResult.message);
      await this.saveCurrentSession();
    } finally {
      this.vm.isSavingDiet = false;
    }
  }

  cancelDietDraft(): void {
    if (this.vm.pendingDiet === null || this.vm.isSavingDiet) {
      return;
    }
    this.vm.pendingDiet = null;
    this.vm.pendingDietAmount = '';
    this.vm.pendingDietError = '';
    this.appendAssistantMessage('已取消这条饮食记录。');
    this.saveCurrentSession();
  }

  setPendingDietMealType(mealType: string): void {
    if (this.vm.pendingDiet !== null) {
      const updated: DietAgentDraft = new DietAgentDraft();
      updated.foodName = this.vm.pendingDiet.foodName;
      updated.amountG = this.vm.pendingDiet.amountG;
      updated.count = this.vm.pendingDiet.count;
      updated.unit = this.vm.pendingDiet.unit;
      updated.requiresAmount = this.vm.pendingDiet.requiresAmount;
      updated.mealType = mealType;
      this.vm.pendingDiet = updated;
    }
  }

  async newSession(): Promise<void> {
    if (this.vm.isLoading) {
      return;
    }
    await this.saveCurrentSession();
    this.vm.messages = [];
    this.vm.inputContent = '';
    this.vm.currentSessionId = '';
    this.vm.currentSessionTitle = '';
    this.activeAiMessage = null;
    this.vm.pendingDiet = null;
    this.vm.pendingDietAmount = '';
    this.vm.pendingDietError = '';
    this.currentSession = this.createSession();
  }

  async openSession(id: string): Promise<void> {
    if (this.vm.isLoading) {
      return;
    }
    if (id === this.currentSession.id) {
      return;
    }
    this.clearPendingDiet();
    await this.saveCurrentSession();
    await this.loadSession(id);
  }

  async deleteSession(id: string): Promise<void> {
    if (this.vm.isLoading) {
      return;
    }
    const updated: Array<ChatSession> = [];
    for (let i = 0; i < this.vm.sessions.length; i++) {
      if (this.vm.sessions[i].id !== id) {
        updated.push(this.vm.sessions[i]);
      }
    }
    this.vm.sessions = updated;
    await this.persist.saveSessions(updated);
    if (id === this.currentSession.id) {
      this.vm.messages = [];
      this.vm.currentSessionId = '';
      this.vm.currentSessionTitle = '';
      this.activeAiMessage = null;
      this.currentSession = this.createSession();
      if (updated.length > 0) {
        const last: ChatSession = updated[updated.length - 1];
        await this.loadSession(last.id);
      }
    }
  }

  private async generateTitleAsync(targetId: string, firstMessage: string): Promise<void> {
    const title: string = await this.service.generateTitle(firstMessage);
    if (title.length === 0) {
      return;
    }
    const updated: Array<ChatSession> = [];
    for (let i = 0; i < this.vm.sessions.length; i++) {
      const s: ChatSession = this.vm.sessions[i];
      if (s.id === targetId) {
        s.title = title;
      }
      updated.push(s);
    }
    this.vm.sessions = updated;
    await this.persist.saveSessions(updated);
    if (targetId === this.currentSession.id) {
      this.currentSession.title = title;
      this.vm.currentSessionTitle = title;
    }
  }

  private async loadSession(id: string): Promise<void> {
    let target: ChatSession | undefined = undefined;
    for (let i = 0; i < this.vm.sessions.length; i++) {
      if (this.vm.sessions[i].id === id) {
        target = this.vm.sessions[i];
        break;
      }
    }
    if (target === undefined) {
      return;
    }
    this.currentSession = target;
    this.vm.messages = [];
    for (let i = 0; i < target.messages.length; i++) {
      const item: ChatHistoryItem = target.messages[i];
      const msg: ChatMessage = new ChatMessage();
      msg.id = this.nextId();
      msg.role = item.role;
      msg.content = item.content;
      this.vm.messages.push(msg);
    }
    this.vm.currentSessionId = target.id;
    this.vm.currentSessionTitle = target.title;
    await this.persist.setCurrentSessionId(target.id);
  }

  private async restoreState(): Promise<void> {
    const sessions: Array<ChatSession> = await this.persist.loadSessions();
    if (sessions.length === 0) {
      const legacy: Array<ChatHistoryItem> = await this.persist.loadLegacyHistory();
      if (legacy.length > 0) {
        const migrated: ChatSession = new ChatSession();
        migrated.id = String(Date.now());
        migrated.title = legacy[0].content.length > 18 ? legacy[0].content.slice(0, 18) : legacy[0].content;
        migrated.messages = legacy;
        migrated.updatedAt = Date.now();
        sessions.push(migrated);
        await this.persist.saveSessions(sessions);
        await this.persist.clearLegacyHistory();
      }
    }
    this.vm.sessions = sessions;
    const currentId: string = await this.persist.getCurrentSessionId();
    let target: ChatSession | undefined = undefined;
    for (let i = 0; i < sessions.length; i++) {
      if (sessions[i].id === currentId) {
        target = sessions[i];
        break;
      }
    }
    if (target === undefined && sessions.length > 0) {
      target = sessions[sessions.length - 1];
    }
    if (target !== undefined) {
      this.currentSession = target;
      this.vm.currentSessionId = target.id;
      this.vm.currentSessionTitle = target.title;
      for (let i = 0; i < target.messages.length; i++) {
        const item: ChatHistoryItem = target.messages[i];
        const msg: ChatMessage = new ChatMessage();
        msg.id = this.nextId();
        msg.role = item.role;
        msg.content = item.content;
        this.vm.messages.push(msg);
      }
    } else {
      this.currentSession = this.createSession();
    }
  }

  private createSession(): ChatSession {
    const session: ChatSession = new ChatSession();
    session.id = String(Date.now());
    session.title = '';
    session.updatedAt = Date.now();
    return session;
  }

  private nextId(): number {
    this.seq += 1;
    return this.seq;
  }

  private clearPendingDiet(): void {
    this.vm.pendingDiet = null;
    this.vm.pendingDietAmount = '';
    this.vm.pendingDietError = '';
    this.vm.isSavingDiet = false;
  }

  private buildDietConfirmationText(draft: DietAgentDraft): string {
    let quantity: string = '';
    if (draft.count > 0) {
      quantity = ' × ' + String(draft.count) + draft.unit;
    }
    if (draft.requiresAmount) {
      return '识别到饮食记录：' + draft.foodName + quantity + '。请确认总重量和餐次后保存。';
    }
    return '识别到饮食记录：' + draft.foodName + '，共 ' + String(draft.amountG) + ' 克。请确认餐次后保存。';
  }

  private appendAssistantMessage(content: string): void {
    const message: ChatMessage = new ChatMessage();
    message.id = this.nextId();
    message.role = ChatRole.ASSISTANT;
    message.content = content;
    this.vm.messages.push(message);
  }

  private finishTurn(isError: boolean, message: string): void {
    this.vm.isLoading = false;
    if (this.activeAiMessage) {
      this.activeAiMessage.isThinking = false;
      this.activeAiMessage.isSearching = false;
      if (isError) {
        this.activeAiMessage.isError = true;
        if (this.activeAiMessage.content.length === 0) {
          this.activeAiMessage.content = message;
        }
      }
      this.activeAiMessage = null;
    }
    this.saveCurrentSession();
  }

  private async saveCurrentSession(): Promise<void> {
    if (this.currentSession.id.length === 0) {
      return;
    }
    this.currentSession.messages = this.toHistoryItems();
    if (this.currentSession.messages.length === 0) {
      return;
    }
    this.currentSession.updatedAt = Date.now();
    let replaced: boolean = false;
    const updated: Array<ChatSession> = [];
    for (let i = 0; i < this.vm.sessions.length; i++) {
      if (this.vm.sessions[i].id === this.currentSession.id) {
        updated.push(this.currentSession);
        replaced = true;
      } else {
        updated.push(this.vm.sessions[i]);
      }
    }
    if (!replaced) {
      updated.push(this.currentSession);
    }
    this.vm.sessions = updated;
    await this.persist.saveSessions(updated);
    await this.persist.setCurrentSessionId(this.currentSession.id);
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

  private async buildHistory(userText: string, hits: Array<KbChunk>): Promise<Array<ChatHistoryItem>> {
    const result: Array<ChatHistoryItem> = [];
    const system: ChatHistoryItem = new ChatHistoryItem();
    system.role = ChatRole.SYSTEM;
    system.content = await this.buildSystemPrompt(userText, hits);
    result.push(system);
    const past: Array<ChatHistoryItem> = this.toHistoryItems();
    for (let i = 0; i < past.length; i++) {
      result.push(past[i]);
    }
    return result;
  }

  private async buildSystemPrompt(userText: string, hits: Array<KbChunk>): Promise<string> {
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
    let kbContext: string = '';
    if (hits.length > 0) {
      let kbText: string = '';
      for (let i = 0; i < hits.length; i++) {
        kbText += '【' + hits[i].title + '】\n' + hits[i].content + '\n';
      }
      kbContext = '以下是相关知识库内容，回答问题时应优先参考：\n' + kbText;
    }
    return '你是「健康1st」应用内置的健康助手，请用中文回答用户关于饮食、运动、睡眠、喝水、体重等健康问题，给出实用、科学的建议。' +
      context +
      kbContext +
      ' 如果某项数据缺失或为 0，说明用户今天还没有该记录，不要编造数据。知识库内容仅在问题相关时使用，与问题无关时不要强行引用。回答保持简洁、友好、具体。';
  }
}
