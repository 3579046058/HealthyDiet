import { speechRecognizer } from '@kit.CoreSpeechKit';

export interface VoiceInputCallbacks {
  onPartial: (text: string) => void;
  onFinal: (text: string) => void;
  onError: (message: string) => void;
  onStateChange: (recording: boolean) => void;
}

export class VoiceInputService {
  private static instance: VoiceInputService;
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private sessionId: string = '';
  private callbacks: VoiceInputCallbacks | null = null;
  private isRecording: boolean = false;
  private isStarting: boolean = false;
  private isStopping: boolean = false;
  private started: boolean = false;
  private cancelled: boolean = false;
  private committedText: string = '';
  private lastDisplayedText: string = '';
  private startupTimer: number = -1;
  private stopTimer: number = -1;

  static getInstance(): VoiceInputService {
    if (!VoiceInputService.instance) {
      VoiceInputService.instance = new VoiceInputService();
    }
    return VoiceInputService.instance;
  }

  setCallbacks(callbacks: VoiceInputCallbacks): void {
    this.callbacks = callbacks;
  }

  clearCallbacks(): void {
    this.callbacks = null;
  }

  isActive(): boolean {
    return this.isRecording || this.isStarting || this.isStopping;
  }

  async start(): Promise<void> {
    if (this.isActive() || this.callbacks === null) {
      return;
    }
    this.clearTimers();
    this.committedText = '';
    this.lastDisplayedText = '';
    this.started = false;
    this.cancelled = false;
    this.isStopping = false;
    this.isStarting = true;
    this.sessionId = String(Date.now());
    const sessionToken: string = this.sessionId;
    try {
      await this.initEngine();
      if (this.engine === null || this.cancelled || this.sessionId !== sessionToken) {
        this.resetSession();
        return;
      }
      const listener: speechRecognizer.RecognitionListener = {
        onStart: (sid: string, eventMessage: string): void => {
          if (!this.isCurrentSession(sid)) {
            return;
          }
          console.info('VoiceInput onStart sessionId=' + sid + ' message=' + eventMessage);
          this.clearStartupTimer();
          this.started = true;
          this.isStarting = false;
          this.isRecording = true;
          this.notifyState(true);
        },
        onEvent: (sid: string, eventCode: number, eventMessage: string): void => {
          if (this.isCurrentSession(sid)) {
            console.info('VoiceInput onEvent code=' + String(eventCode) + ' msg=' + eventMessage);
          }
        },
        onResult: (sid: string, result: speechRecognizer.SpeechRecognitionResult): void => {
          if (this.isCurrentSession(sid)) {
            this.handleResult(result);
          }
        },
        onComplete: (sid: string, eventMessage: string): void => {
          if (!this.isCurrentSession(sid)) {
            return;
          }
          console.info('VoiceInput onComplete sessionId=' + sid + ' message=' + eventMessage);
          this.handleComplete();
        },
        onError: (sid: string, errorCode: number, errorMessage: string): void => {
          if (!this.isCurrentSession(sid)) {
            return;
          }
          console.error('VoiceInput onError code=' + String(errorCode) + ' message=' + errorMessage);
          if (errorCode === 1002200006) {
            this.notifyError('语音引擎正忙，请稍后再试');
          } else if (!this.started) {
            this.notifyError('语音引擎启动失败，请重试（' + String(errorCode) + '）');
          } else {
            this.notifyError('语音识别出错（' + String(errorCode) + '）');
          }
          this.resetSession();
        }
      };
      this.engine.setListener(listener);
      const audioInfo: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      };
      const extraParams: Record<string, Object> = {
        'recognitionMode': 0,
        'vadBegin': 2000,
        'vadEnd': 3000,
        'maxAudioDuration': 600000
      };
      const startParams: speechRecognizer.StartParams = {
        sessionId: sessionToken,
        audioInfo: audioInfo,
        extraParams: extraParams
      };
      this.engine.startListening(startParams);
      this.startupTimer = setTimeout(() => {
        if (this.sessionId === sessionToken && this.isStarting && !this.cancelled) {
          this.notifyError('语音引擎启动超时，请重试');
          this.cancel();
        }
      }, 12000);
    } catch (err) {
      console.error('VoiceInput start error:', JSON.stringify(err));
      this.notifyError('语音输入启动失败，请重试');
      this.resetSession();
    }
  }

  async stop(): Promise<void> {
    if (!this.isRecording && !this.isStarting) {
      return;
    }
    const activeSessionId: string = this.sessionId;
    this.clearStartupTimer();
    this.isRecording = false;
    this.isStarting = false;
    this.isStopping = true;
    this.notifyState(false);
    try {
      if (this.engine !== null) {
        this.engine.finish(activeSessionId);
      }
    } catch (err) {
      console.error('VoiceInput finish error:', JSON.stringify(err));
      this.deliverFinalText();
      this.resetSession();
      return;
    }
    this.stopTimer = setTimeout(() => {
      if (this.sessionId === activeSessionId && this.isStopping) {
        this.deliverFinalText();
        this.resetSession();
      }
    }, 3000);
  }

  cancel(): void {
    if (!this.isActive()) {
      return;
    }
    const activeSessionId: string = this.sessionId;
    this.cancelled = true;
    try {
      if (this.engine !== null) {
        this.engine.cancel(activeSessionId);
      }
    } catch (err) {
      console.error('VoiceInput cancel error:', JSON.stringify(err));
    }
    this.resetSession();
  }

  private async initEngine(): Promise<void> {
    if (this.engine !== null) {
      return;
    }
    const extraParams: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'long' };
    const params: speechRecognizer.CreateEngineParams = {
      language: 'zh-CN',
      online: 1,
      extraParams: extraParams
    };
    this.engine = await speechRecognizer.createEngine(params);
  }

  private isCurrentSession(sid: string): boolean {
    return sid === this.sessionId && !this.cancelled && this.isActive();
  }

  private handleResult(result: speechRecognizer.SpeechRecognitionResult): void {
    const text: string = result.result.trim();
    if (text.length === 0) {
      return;
    }
    if (result.isFinal) {
      this.committedText += text;
      this.lastDisplayedText = this.committedText;
    } else {
      this.lastDisplayedText = this.committedText + text;
    }
    if (this.callbacks !== null) {
      this.callbacks.onPartial(this.lastDisplayedText);
    }
  }

  private handleComplete(): void {
    this.deliverFinalText();
    this.resetSession();
  }

  private deliverFinalText(): void {
    if (this.callbacks !== null && this.lastDisplayedText.length > 0) {
      this.callbacks.onFinal(this.lastDisplayedText);
    }
  }

  private resetSession(): void {
    this.clearTimers();
    this.isRecording = false;
    this.isStarting = false;
    this.isStopping = false;
    this.started = false;
    this.notifyState(false);
  }

  private clearStartupTimer(): void {
    if (this.startupTimer !== -1) {
      clearTimeout(this.startupTimer);
      this.startupTimer = -1;
    }
  }

  private clearTimers(): void {
    this.clearStartupTimer();
    if (this.stopTimer !== -1) {
      clearTimeout(this.stopTimer);
      this.stopTimer = -1;
    }
  }

  private notifyState(recording: boolean): void {
    if (this.callbacks !== null) {
      this.callbacks.onStateChange(recording);
    }
  }

  private notifyError(message: string): void {
    console.error('VoiceInput error:', message);
    if (this.callbacks !== null) {
      this.callbacks.onError(message);
    }
  }
}
