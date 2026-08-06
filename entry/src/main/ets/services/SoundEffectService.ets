import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { GlobalData } from '../common/GlobalData';

/**
 * 音效服务（SoundPool 封装）
 * 提供短音效播放，用于喝水/运动/成就/提醒等场景
 * 音效资源在 rawfile 下，已处理为短 MP3（<1MB，1-3秒）
 */
export class SoundEffectService {
  private static instance: SoundEffectService;
  private soundPool: media.SoundPool | null = null;
  private soundIds: Map<string, number> = new Map<string, number>();
  private context: common.UIAbilityContext | null = null;
  private initPromise: Promise<void> | null = null;

  static getInstance(): SoundEffectService {
    if (!SoundEffectService.instance) {
      SoundEffectService.instance = new SoundEffectService();
    }
    return SoundEffectService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 初始化 SoundPool 并加载所有音效（幂等，只初始化一次）
   */
  async init(): Promise<void> {
    if (this.initPromise) {
      return this.initPromise;
    }
    this.initPromise = this.doInit();
    return this.initPromise;
  }

  private async doInit(): Promise<void> {
    try {
      const audioRendererInfo: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 1
      };
      this.soundPool = await media.createSoundPool(5, audioRendererInfo);

      // 加载所有音效资源
      const files: string[] = [
        'sfx_water.mp3',
        'sfx_sport_start.mp3',
        'sfx_success.mp3',
        'sfx_notify.mp3'
      ];
      if (!this.context) {
        console.error('SoundEffectService: context not set');
        return;
      }
      const resourceManager = this.context.resourceManager;
      for (const file of files) {
        try {
          const fd = await resourceManager.getRawFd(file);
          const soundId: number = await this.soundPool.load(fd.fd, fd.offset, fd.length);
          // 文件名去前缀和后缀作为 key
          const key: string = file.replace('sfx_', '').replace('.mp3', '');
          this.soundIds.set(key, soundId);
          console.info('SoundEffectService: loaded ' + file + ' -> ' + key);
        } catch (err) {
          console.error('SoundEffectService: load ' + file + ' error: ' + JSON.stringify(err));
        }
      }
    } catch (err) {
      const e = err as BusinessError;
      console.error('SoundEffectService init error: ' + e.code + ' ' + e.message);
    }
  }

  /**
   * 播放音效（受总开关 + 单项开关控制）
   * @param name 音效名：water / sport_start / success / notify
   */
  async play(name: string): Promise<void> {
    try {
      // 1. 总开关（默认开）
      const masterRaw: string | number | boolean = await GlobalData.prefs.get('sound_effect_enabled', 'true');
      if (String(masterRaw) !== 'true') {
        return;
      }
      // 2. 单项开关（默认开）
      const itemKey: string = 'sfx_' + name + '_enabled';
      const itemRaw: string | number | boolean = await GlobalData.prefs.get(itemKey, 'true');
      if (String(itemRaw) !== 'true') {
        return;
      }
      await this.init();
      if (!this.soundPool) {
        return;
      }
      const soundId: number | undefined = this.soundIds.get(name);
      if (soundId === undefined) {
        console.warn('SoundEffectService: unknown sound ' + name);
        return;
      }
      const params: media.PlayParameters = {
        loop: 0,
        rate: audio.AudioRendererRate.RENDER_RATE_NORMAL,
        leftVolume: 0.8,
        rightVolume: 0.8,
        priority: 0
      };
      this.soundPool.play(soundId, params, (err: BusinessError | null, streamId: number) => {
        if (err) {
          console.warn('SoundEffectService: play ' + name + ' error ' + err.code);
        } else {
          console.info('SoundEffectService: played ' + name + ' stream=' + String(streamId));
        }
      });
    } catch (err) {
      console.error('SoundEffectService play error: ' + JSON.stringify(err));
    }
  }

  /**
   * 释放资源（应用退出时调用）
   */
  release(): void {
    try {
      if (this.soundPool) {
        this.soundPool.release();
        this.soundPool = null;
      }
      this.soundIds.clear();
      this.initPromise = null;
    } catch (err) {
      console.error('SoundEffectService release error: ' + JSON.stringify(err));
    }
  }
}
