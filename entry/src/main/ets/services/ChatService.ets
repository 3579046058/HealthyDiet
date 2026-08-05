import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { ChatHistoryItem } from '../model/ChatModels';
import { GlobalData } from '../common/GlobalData';
import { AiDefaults } from '../common/Constants';

export interface ChatCallbacks {
  onChunk: (chunk: string) => void;
  onDone: () => void;
  onError: (message: string) => void;
}

interface GlmRequestMessage {
  role: string;
  content: string;
}

interface GlmRequestBody {
  model: string;
  messages: Array<GlmRequestMessage>;
  stream: boolean;
  temperature: number;
}

interface GlmDelta {
  content?: string;
}

interface GlmChoice {
  delta?: GlmDelta;
}

interface GlmSseChunk {
  choices?: Array<GlmChoice>;
}

interface GlmChatMessageResult {
  content?: string;
}

interface GlmChatChoiceResult {
  message?: GlmChatMessageResult;
}

interface GlmChatResult {
  choices?: Array<GlmChatChoiceResult>;
}

export class ChatService {
  private static instance: ChatService;
  private apiUrl: string = AiDefaults.API_URL;
  private model: string = AiDefaults.CHAT_MODEL;
  private glmApiKey: string = '';
  private request: http.HttpRequest | null = null;
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
  private initError: string = '';

  static getInstance(): ChatService {
    if (!ChatService.instance) {
      ChatService.instance = new ChatService();
    }
    return ChatService.instance;
  }

  async init(context: Context): Promise<void> {
    await this.loadConfig(context);
  }

  async reloadConfig(context: Context): Promise<void> {
    this.glmApiKey = '';
    this.apiUrl = AiDefaults.API_URL;
    this.model = AiDefaults.CHAT_MODEL;
    this.initError = '';
    await this.loadConfig(context);
  }

  private async loadConfig(context: Context): Promise<void> {
    try {
      if (GlobalData.initialized) {
        const cfg = await GlobalData.prefs.getAiConfig();
        if (cfg.apiUrl.length > 0) {
          this.apiUrl = cfg.apiUrl;
        }
        if (cfg.chatModel.length > 0) {
          this.model = cfg.chatModel;
        }
        if (cfg.apiKey.length > 0) {
          this.glmApiKey = cfg.apiKey;
          this.initError = '';
          console.info('ChatService key loaded from user settings, keyLen=' + String(cfg.apiKey.length));
          return;
        }
      }
    } catch (err) {
      console.error('ChatService prefs config error:', JSON.stringify(err));
    }
    let rawText: string = '';
    try {
      const resourceMgr = context.resourceManager;
      const data: Uint8Array = await resourceMgr.getRawFileContent('ai_config.json');
      rawText = this.decoder.decodeToString(data);
    } catch (err) {
      this.initError = 'rawfile 读取失败: ' + JSON.stringify(err);
      console.error('ChatService init error:', this.initError);
      return;
    }
    let parsed: Record<string, Object>;
    try {
      parsed = JSON.parse(rawText) as Record<string, Object>;
    } catch (err) {
      this.initError = 'ai_config.json 解析失败: ' + JSON.stringify(err);
      console.error('ChatService init error:', this.initError);
      return;
    }
    const key = parsed['glm_api_key'];
    if (typeof key === 'string' && key.length > 0) {
      this.glmApiKey = key;
      this.initError = '';
      console.info('ChatService key loaded from ai_config.json, keyLen=' + String(this.glmApiKey.length));
    } else {
      this.initError = 'ai_config.json 中缺少 glm_api_key 字段';
      console.error('ChatService config missing key');
    }
  }

  isConfigured(): boolean {
    return this.glmApiKey.length > 0;
  }

  getInitError(): string {
    return this.initError;
  }

  private normalizeUrl(url: string): string {
    let result: string = url.trim();
    if (result.length === 0) {
      return AiDefaults.API_URL;
    }
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    if (!result.endsWith('/chat/completions')) {
      result = result + '/chat/completions';
    }
    return result;
  }

  async sendMessage(messages: Array<ChatHistoryItem>, callbacks: ChatCallbacks): Promise<void> {
    if (this.glmApiKey.length === 0) {
      const reason: string = this.initError.length > 0 ? this.initError : '未配置 AI 服务密钥，请检查 rawfile/ai_config.json';
      callbacks.onError(reason);
      return;
    }
    const reqMessages: Array<GlmRequestMessage> = [];
    for (let i = 0; i < messages.length; i++) {
      const item: ChatHistoryItem = messages[i];
      const msg: GlmRequestMessage = { role: item.role, content: item.content };
      reqMessages.push(msg);
    }
    const body: GlmRequestBody = {
      model: this.model,
      messages: reqMessages,
      stream: true,
      temperature: 0.7
    };

    const httpRequest: http.HttpRequest = http.createHttp();
    this.request = httpRequest;
    let buffer: string = '';
    let finished: boolean = false;

    const cleanup = (): void => {
      if (this.request === httpRequest) {
        this.request = null;
      }
      httpRequest.off('dataReceive');
      httpRequest.off('dataEnd');
      httpRequest.destroy();
    };

    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      if (finished) {
        return;
      }
      buffer += this.decoder.decodeToString(new Uint8Array(data));
      let idx: number = buffer.indexOf('\n');
      while (idx >= 0) {
        const line: string = buffer.slice(0, idx).trim();
        buffer = buffer.slice(idx + 1);
        if (line.startsWith('data:')) {
          const payload: string = line.substring(5).trim();
          if (payload === '[DONE]') {
            finished = true;
            callbacks.onDone();
            cleanup();
            return;
          }
          try {
            const chunk = JSON.parse(payload) as GlmSseChunk;
            if (chunk.choices !== undefined && chunk.choices.length > 0) {
              const choice: GlmChoice = chunk.choices[0];
              const delta: GlmDelta | undefined = choice.delta;
              if (delta !== undefined) {
                const text: string | undefined = delta.content;
                if (text !== undefined && text !== null) {
                  callbacks.onChunk(text);
                }
              }
            }
          } catch (err) {
            console.warn('ChatService parse chunk error:', JSON.stringify(err));
          }
        }
        idx = buffer.indexOf('\n');
      }
    });

    httpRequest.on('dataEnd', () => {
      if (!finished) {
        finished = true;
        callbacks.onDone();
        cleanup();
      }
    });

    try {
      const code: number = await httpRequest.requestInStream(this.normalizeUrl(this.apiUrl), {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.glmApiKey
        },
        extraData: JSON.stringify(body),
        connectTimeout: 15000,
        readTimeout: 60000
      });
      if (!finished) {
        finished = true;
        if (code !== 200) {
          callbacks.onError('AI 服务返回错误，HTTP ' + String(code));
        } else {
          callbacks.onDone();
        }
        cleanup();
      }
    } catch (err) {
      if (!finished) {
        finished = true;
        callbacks.onError('AI 请求失败，请检查网络后重试');
        cleanup();
      }
    }
  }

  cancel(): void {
    if (this.request) {
      this.request.destroy();
      this.request = null;
    }
  }

  async generateTitle(firstMessage: string): Promise<string> {
    if (this.glmApiKey.length === 0 || firstMessage.length === 0) {
      return '';
    }
    const titleMessages: Array<GlmRequestMessage> = [
      { role: 'system', content: '你是标题生成器。用不超过12个中文字符概括这段对话的主题，只输出标题本身，不要引号、标点或任何解释。' },
      { role: 'user', content: firstMessage }
    ];
    const titleBody: GlmRequestBody = {
      model: this.model,
      messages: titleMessages,
      stream: false,
      temperature: 0.3
    };
    const titleRequest: http.HttpRequest = http.createHttp();
    try {
      const response = await titleRequest.request(this.normalizeUrl(this.apiUrl), {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.glmApiKey
        },
        extraData: JSON.stringify(titleBody),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (response.responseCode !== 200) {
        return '';
      }
      const raw: Object = response.result;
      if (typeof raw !== 'string') {
        return '';
      }
      const result = JSON.parse(raw) as GlmChatResult;
      if (result.choices !== undefined && result.choices.length > 0) {
        const choice: GlmChatChoiceResult = result.choices[0];
        const message: GlmChatMessageResult | undefined = choice.message;
        if (message !== undefined) {
          const content: string | undefined = message.content;
          if (content !== undefined && content !== null) {
            const title: string = content.trim();
            return title.length > 12 ? title.slice(0, 12) : title;
          }
        }
      }
      return '';
    } catch (err) {
      console.error('ChatService generateTitle error:', JSON.stringify(err));
      return '';
    } finally {
      titleRequest.destroy();
    }
  }
}
