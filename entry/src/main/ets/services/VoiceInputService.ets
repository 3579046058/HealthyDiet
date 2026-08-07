import { speechRecognizer } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';

export interface VoiceInputCallbacks {
  onPartial: (text: string) => void;
  onFinal: (text: string) => void;
  onError: (message: string) => void;
  onStateChange: (recording: boolean) => void;
}

export class VoiceInputService {
  private static instance: VoiceInputService;
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private capturer: audio.AudioCapturer | null = null;
  private sessionId: string = '';
  private callbacks: VoiceInputCallbacks | null = null;
  private pending: Uint8Array = new Uint8Array(0);
  private isRecording: boolean = false;
  private isStarting: boolean = false;
  private started: boolean = false;
  private cancelled: boolean = false;
  private isFinishing: boolean = false;
  private finalText: string = '';
  private lastPartial: string = '';
  private startupTimer: number = -1;

  static getInstance(): VoiceInputService {
    if (!VoiceInputService.instance) {
      VoiceInputService.instance = new VoiceInputService();
    }
    return VoiceInputService.instance;
  }

  setCallbacks(callbacks: VoiceInputCallbacks): void {
    this.callbacks = callbacks;
  }

  isActive(): boolean {
    return this.isRecording || this.isStarting;
  }

  async start(): Promise<void> {
    if (this.isRecording || this.isStarting) {
      return;
    }
    if (!this.callbacks) {
      return;
    }
    this.finalText = '';
    this.lastPartial = '';
    this.started = false;
    this.cancelled = false;
    this.isFinishing = false;
    this.isStarting = true;
    this.sessionId = String(Date.now());
    const sessionToken: string = this.sessionId;
    try {
      await this.initEngine();
      if (!this.engine || this.cancelled) {
        this.finishRecording();
        return;
      }
      const listener: speechRecognizer.RecognitionListener = {
        onStart: (sid: string, eventMessage: string): void => {
          if (sid !== sessionToken || this.cancelled) {
            return;
          }
          console.info('VoiceInput onStart sessionId=' + sid);
          this.started = true;
          this.isStarting = false;
          this.isRecording = true;
          this.notifyState(true);
        },
        onEvent: (sid: string, eventCode: number, eventMessage: string): void => {
          console.info('VoiceInput onEvent code=' + String(eventCode) + ' msg=' + eventMessage);
        },
        onResult: (sid: string, result: speechRecognizer.SpeechRecognitionResult): void => {
          if (sid !== sessionToken || this.cancelled) {
            return;
          }
          this.handleResult(result);
        },
        onComplete: (sid: string, eventMessage: string): void => {
          if (sid !== sessionToken || this.cancelled) {
            return;
          }
          this.handleComplete();
        },
        onError: (sid: string, errorCode: number, errorMessage: string): void => {
          if (sid !== sessionToken) {
            return;
          }
          if (errorCode === 1002200006) {
            this.notifyError('语音引擎正忙，请稍后再试');
          } else if (!this.started) {
            this.notifyError('语音引擎启动失败，请重试（' + String(errorCode) + '）');
          } else {
            this.notifyError('语音识别出错（' + String(errorCode) + '）');
          }
          this.finishRecording();
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
        'vadBegin': 1000,
        'vadEnd': 2000,
        'maxAudioDuration': 20000
      };
      const startParams: speechRecognizer.StartParams = {
        sessionId: sessionToken,
        audioInfo: audioInfo,
        extraParams: extraParams
      };
      this.engine.startListening(startParams);

      await this.startCapturer();

      this.startupTimer = setTimeout(() => {
        if (!this.started && !this.cancelled) {
          this.notifyError('语音引擎启动超时，请重试');
          this.finishRecording();
        }
      }, 12000);
    } catch (err) {
      console.error('VoiceInput start error:', JSON.stringify(err));
      this.notifyError('语音输入启动失败，请重试');
      this.finishRecording();
    }
  }

  async stop(): Promise<void> {
    if (!this.isRecording && !this.isStarting) {
      return;
    }
    if (this.isStarting && !this.started) {
      this.finishRecording();
      return;
    }
    // 先结束识别，UI 立即恢复
    try {
      if (this.engine) {
        this.engine.finish(this.sessionId);
      }
    } catch (err) {
      console.error('VoiceInput finish error:', JSON.stringify(err));
    }
    this.isRecording = false;
    this.notifyState(false);
    // 停止录音不阻塞主流程
    if (this.capturer) {
      this.stopCapturerAsync(this.capturer);
    }
    setTimeout(() => {
      if (this.engine !== null) {
        if (this.callbacks && this.finalText.length === 0 && this.lastPartial.length > 0) {
          this.callbacks.onFinal(this.lastPartial);
        }
        this.finishRecording();
      }
    }, 3000);
  }

  private async stopCapturerAsync(capturer: audio.AudioCapturer): Promise<void> {
    try {
      await capturer.stop();
    } catch (err) {
      console.error('VoiceInput capturer stop error:', JSON.stringify(err));
    }
  }

  cancel(): void {
    this.finishRecording();
  }

  private async initEngine(): Promise<void> {
    if (this.engine) {
      return;
    }
    const extraParams: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
    const params: speechRecognizer.CreateEngineParams = {
      language: 'zh-CN',
      online: 1,
      extraParams: extraParams
    };
    this.engine = await speechRecognizer.createEngine(params);
  }

  private async startCapturer(): Promise<void> {
    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };
    const capturerInfo: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    };
    const options: audio.AudioCapturerOptions = {
      streamInfo: streamInfo,
      capturerInfo: capturerInfo
    };
    const capturer: audio.AudioCapturer = await audio.createAudioCapturer(options);
    this.capturer = capturer;
    capturer.on('readData', (data: ArrayBuffer) => {
      this.feedAudio(data);
    });
    await capturer.start();
  }

  private feedAudio(data: ArrayBuffer): void {
    if (!this.engine || !this.started || !this.isRecording) {
      return;
    }
    const incoming: Uint8Array = new Uint8Array(data);
    const combined: Uint8Array = new Uint8Array(this.pending.length + incoming.length);
    combined.set(this.pending, 0);
    combined.set(incoming, this.pending.length);
    this.pending = combined;
    let offset: number = 0;
    while (this.pending.length - offset >= 640) {
      const buf: ArrayBuffer = this.pending.buffer.slice(this.pending.byteOffset + offset, this.pending.byteOffset + offset + 640);
      this.engine.writeAudio(this.sessionId, new Uint8Array(buf));
      offset += 640;
    }
    if (offset > 0) {
      const rest: ArrayBuffer = this.pending.buffer.slice(this.pending.byteOffset + offset);
      this.pending = new Uint8Array(rest);
    }
  }

  private handleResult(result: speechRecognizer.SpeechRecognitionResult): void {
    const text: string = result.result;
    if (text.length > 0) {
      this.lastPartial = text;
    }
    if (result.isFinal) {
      this.finalText = text;
    }
    if (this.callbacks) {
      this.callbacks.onPartial(text);
    }
  }

  private handleComplete(): void {
    if (this.callbacks && this.finalText.length > 0) {
      this.callbacks.onFinal(this.finalText);
    } else if (this.callbacks && this.lastPartial.length > 0) {
      this.callbacks.onFinal(this.lastPartial);
    }
    this.finishRecording();
  }

  private finishRecording(): void {
    if (this.isFinishing) {
      return;
    }
    this.isFinishing = true;
    this.cancelled = true;
    this.isRecording = false;
    this.isStarting = false;
    this.started = false;
    if (this.startupTimer !== -1) {
      clearTimeout(this.startupTimer);
      this.startupTimer = -1;
    }
    this.pending = new Uint8Array(0);
    this.notifyState(false);
    this.cleanup();
    this.isFinishing = false;
  }

  private cleanup(): void {
    try {
      if (this.capturer) {
        this.capturer.release();
      }
    } catch (err) {
      console.error('VoiceInput capturer release error:', JSON.stringify(err));
    }
    this.capturer = null;
    try {
      if (this.engine) {
        this.engine.shutdown();
      }
    } catch (err) {
      console.error('VoiceInput engine shutdown error:', JSON.stringify(err));
    }
    this.engine = null;
  }

  private notifyState(recording: boolean): void {
    if (this.callbacks) {
      this.callbacks.onStateChange(recording);
    }
  }

  private notifyError(message: string): void {
    console.error('VoiceInput error:', message);
    if (this.callbacks) {
      this.callbacks.onError(message);
    }
  }
}
