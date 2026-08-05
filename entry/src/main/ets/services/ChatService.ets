import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { ChatHistoryItem } from '../model/ChatModels';

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

export class ChatService {
  private static instance: ChatService;
  private static readonly GLM_URL: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  private static readonly GLM_MODEL: string = 'glm-4-flash';
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
    if (this.glmApiKey.length > 0) {
      return;
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
      console.info('ChatService key loaded, keyLen=' + String(this.glmApiKey.length));
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
      model: ChatService.GLM_MODEL,
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
                if (text !== undefined) {
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
      const code: number = await httpRequest.requestInStream(ChatService.GLM_URL, {
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
}
