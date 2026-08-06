import { common } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { bundleManager, wantAgent } from '@kit.AbilityKit';
import { uri as uriModule } from '@kit.ArkTS';
import { GlobalData } from '../common/GlobalData';
import { DbRow } from '../common/Constants';

// 内置默认歌单的原始文件名列表（rawfile/music/ 下的文件）
const BUILTIN_MUSIC_FILES: string[] = ['NewMorning.m4a'];

// 音乐库服务：导入本地音频到沙箱、管理播放
export class MusicService {
  private static instance: MusicService;
  private context: common.UIAbilityContext | null = null;
  private avPlayer: media.AVPlayer | null = null;
  private session: avSession.AVSession | null = null;
  private playlist: DbRow[] = [];
  private currentIndex: number = -1;
  private durationMs: number = 0;
  private currentTimeMs: number = 0;
  private isPlayingFlag: boolean = false;
  private activeFile: fs.File | null = null; // 当前播放的文件句柄（fd:// 方式需保持打开）
  private volumeValue: number = 1.0; // 音量 0.0 - 1.0
  private playMode: number = 0; // 0=顺序循环 1=单曲循环 2=随机播放

  static getInstance(): MusicService {
    if (!MusicService.instance) {
      MusicService.instance = new MusicService();
    }
    return MusicService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  getContext(): common.UIAbilityContext | null {
    return this.context;
  }

  // 创建并激活 AVSession（媒体会话），支持播控中心与后台播放
  async initSession(): Promise<void> {
    if (!this.context || this.session) {
      return;
    }
    try {
      this.session = await avSession.createAVSession(this.context, 'HealthMusicPlayer', 'audio');
      await this.session.activate();
      this.setupSessionCallbacks();
    } catch (err) {
      console.error('init AVSession error:', JSON.stringify(err));
    }
  }

  // 监听播控中心指令
  private setupSessionCallbacks(): void {
    if (!this.session) {
      return;
    }
    this.session.on('play', () => {
      this.resume();
    });
    this.session.on('pause', () => {
      this.pause();
    });
    this.session.on('playNext', () => {
      this.next();
    });
    this.session.on('playPrevious', () => {
      this.prev();
    });
    this.session.on('seek', (time: number) => {
      this.seek(time);
    });
  }

  // 上报播放状态到播控中心
  private async updateSessionState(): Promise<void> {
    if (!this.session) {
      return;
    }
    const state = this.isPlayingFlag ? avSession.PlaybackState.PLAYBACK_STATE_PLAY :
      avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    try {
      this.session.setAVPlaybackState({
        state: state,
        position: {
          elapsedTime: this.currentTimeMs,
          updateTime: Date.now()
        }
      });
    } catch (err) {
      console.error('updateSessionState error:', JSON.stringify(err));
    }
  }

  // 上报歌曲元数据
  private async updateSessionMetadata(): Promise<void> {
    if (!this.session) {
      return;
    }
    const track = this.getCurrentTrack();
    if (!track) {
      return;
    }
    try {
      this.session.setAVMetadata({
        assetId: String(track.id),
        title: String(track.title),
        artist: String(track.artist),
        duration: this.durationMs
      });
    } catch (err) {
      console.error('updateSessionMetadata error:', JSON.stringify(err));
    }
  }

  // 申请音频播放长时任务（后台播放）
  async startBackgroundPlayback(): Promise<void> {
    if (!this.context) {
      return;
    }
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: bundleInfo.name,
            abilityName: 'EntryAbility'
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITIES,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const wantAgentObj = await wantAgent.getWantAgent(wantAgentInfo);
      await backgroundTaskManager.startBackgroundRunning(this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj);
    } catch (err) {
      console.error('startBackgroundPlayback error:', JSON.stringify(err));
    }
  }

  // 停止音频播放长时任务
  async stopBackgroundPlayback(): Promise<void> {
    if (!this.context) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
    } catch (err) {
      console.error('stopBackgroundPlayback error:', JSON.stringify(err));
    }
  }

  isPlaying(): boolean {
    return this.isPlayingFlag;
  }

  // 是否启动过播放（用于判断是否应恢复而非重新自动播放）
  hasStartedPlayback(): boolean {
    return this.playlist.length > 0;
  }

  getDuration(): number {
    return this.durationMs;
  }

  // 当前播放位置（ms）
  getCurrentTime(): number {
    return this.currentTimeMs;
  }

  getCurrentIndex(): number {
    return this.currentIndex;
  }

  getPlaylist(): DbRow[] {
    return this.playlist;
  }

  setPlaylist(list: DbRow[], index: number): void {
    this.playlist = list;
    this.currentIndex = index;
  }

  getCurrentTrack(): DbRow | null {
    if (this.currentIndex >= 0 && this.currentIndex < this.playlist.length) {
      return this.playlist[this.currentIndex];
    }
    return null;
  }

  // 通过系统音频选择器导入 mp3 到应用沙箱，并写入数据库
  async importAudio(): Promise<DbRow | null> {
    if (!this.context) {
      return null;
    }
    try {
      const audioPicker = new picker.AudioViewPicker(this.context);
      const uris: string[] = await audioPicker.select();
      if (uris.length === 0) {
        return null;
      }
      const uri: string = uris[0];
      // 提取原扩展名（mp3/m4a/wav 等）
      let ext: string = 'mp3';
      const dotIdx = uri.lastIndexOf('.');
      if (dotIdx >= 0) {
        const e = uri.substring(dotIdx + 1).toLowerCase();
        if (e.length >= 2 && e.length <= 4) {
          ext = e;
        }
      }
      // 使用时间戳安全文件名，避免中文/空格/# 等特殊字符导致的路径问题
      const fileName = 'music_' + String(Date.now()) + '.' + ext;
      // 直接写入 filesDir（不建子目录，规避可能的目录权限问题）
      const destPath = this.context.filesDir + '/' + fileName;
      console.info('[MusicImport] filesDir=' + this.context.filesDir + ' dest=' + destPath);
      // 官方推荐：从 uri 打开源 fd，用 copyFileSync 复制到沙箱目标路径
      try {
        const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const srcFd = srcFile.fd;
        console.info('[MusicImport] open ok fd=' + srcFd);
        fs.copyFileSync(srcFd, destPath);
        fs.closeSync(srcFile);
        console.info('[MusicImport] copy ok');
      } catch (copyErr) {
        console.error('[MusicImport] copy failed: ' + JSON.stringify(copyErr));
        return null;
      }

      // 读取时长（通过 AVPlayer 探测）
      let duration: number = 0;
      const probe: media.AVPlayer = await media.createAVPlayer();
      try {
        await new Promise<void>((resolve) => {
          let resolved: boolean = false;
          const done = (): void => {
            if (!resolved) {
              resolved = true;
              resolve();
            }
          };
          probe.on('durationUpdate', (d: number) => {
            duration = d;
            done();
          });
          probe.on('error', (err: BusinessError) => {
            console.error('probe error:', JSON.stringify(err));
            done();
          });
          probe.on('stateChange', async (state: string) => {
            if (state === 'prepared') {
              await probe.pause();
              done();
            }
          });
          probe.url = 'file://' + destPath;
          probe.prepare();
          // 超时兜底：5 秒未拿到时长也继续
          setTimeout(() => { done(); }, 5000);
        });
      } catch (err) {
        console.error('probe duration error:', JSON.stringify(err));
      }
      probe.release();

      // 原始显示名（解码百分号编码：%20→空格 等），用于标题
      let displayName: string = '本地音乐';
      let decodedName: string = '';
      try {
        const uriObj = new uriModule.URI(uri);
        const decodedPath = uriObj.path;
        decodedName = decodedPath.substring(decodedPath.lastIndexOf('/') + 1);
      } catch (uriErr) {
        console.error('decode uri error:', JSON.stringify(uriErr));
        decodedName = uri.substring(uri.lastIndexOf('/') + 1);
      }
      if (decodedName.length > 0) {
        displayName = this.stripExtension(decodedName);
      }

      const record: DbRow = {
        title: displayName,
        artist: '本地音乐',
        duration_ms: duration,
        file_name: fileName,
        file_uri: 'file://' + destPath,
        created_at: Date.now()
      };
      await GlobalData.db.addMusicRecord(record);
      return record;
    } catch (err) {
      const e = err as BusinessError;
      console.error('importAudio error: ' + e.code + ' ' + e.message);
      return null;
    }
  }

  // 从数据库加载音乐库
  async loadLibrary(): Promise<DbRow[]> {
    const list = await GlobalData.db.getMusicRecords();
    this.playlist = list;
    return list;
  }

  // 播放指定曲目
  async playTrack(index: number): Promise<void> {
    if (index < 0 || index >= this.playlist.length) {
      return;
    }
    this.currentIndex = index;
    const track = this.playlist[index];
    if (!track || !track.file_uri) {
      return;
    }
    try {
      // 重置旧播放器（若存在），并关闭旧文件句柄
      if (this.avPlayer) {
        await this.avPlayer.reset();
        this.avPlayer.off('durationUpdate');
        this.avPlayer.off('timeUpdate');
        this.avPlayer.off('stateChange');
        this.avPlayer.off('error');
      } else {
        this.avPlayer = await media.createAVPlayer();
      }
      if (this.activeFile) {
        try {
          fs.closeSync(this.activeFile);
        } catch (closeErr) {
          console.error('close old file error:', JSON.stringify(closeErr));
        }
        this.activeFile = null;
      }

      // 用 fd:// 方式播放本地文件：打开文件保持 fd 打开，传给 AVPlayer
      const filePath = String(track.file_uri).replace('file://', '');
      const musicFile = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const fdUrl = 'fd://' + musicFile.fd;
      this.activeFile = musicFile; // 保持文件打开，播放期间不能 close
      console.info('[MusicPlay] url=' + fdUrl + ' path=' + filePath);

      this.avPlayer.on('error', (err: BusinessError) => {
        console.error('[MusicPlay] error: code=' + err.code + ' msg=' + err.message);
      });
      this.avPlayer.on('durationUpdate', (duration: number) => {
        this.durationMs = duration;
      });
      this.avPlayer.on('timeUpdate', (time: number) => {
        this.currentTimeMs = time;
        if (this.isPlayingFlag) {
          this.updateSessionState();
        }
      });
      this.avPlayer.on('stateChange', async (state: string) => {
        if (state === 'initialized') {
          // 进入 initialized 后才能 prepare
          await this.avPlayer?.prepare();
        }
        if (state === 'prepared') {
          // 播放前 2s 淡入：音量从 0 非线性渐增（二次曲线，速度越来越快）
          this.startFadeIn();
        }
        if (state === 'playing') {
          this.isPlayingFlag = true;
          await this.initSession();
          await this.updateSessionMetadata();
          await this.updateSessionState();
          // 按后台播放设置决定是否申请长时任务
          const bgEnabled = await this.isBackgroundPlayEnabled();
          if (bgEnabled) {
            await this.startBackgroundPlayback();
          }
        }
        if (state === 'paused') {
          this.isPlayingFlag = false;
          await this.updateSessionState();
          await this.stopBackgroundPlayback();
        }
        if (state === 'completed') {
          this.isPlayingFlag = false;
          await this.updateSessionState();
          await this.stopBackgroundPlayback();
          // 自动播放下一首（按播放模式）
          if (this.playlist.length > 1) {
            await this.playNextAuto();
          }
        }
      });
      // 设置 url 触发状态机到 initialized
      this.avPlayer.url = fdUrl;
    } catch (err) {
      console.error('playTrack error:', JSON.stringify(err));
      // 失败时关闭文件句柄
      if (this.activeFile) {
        try {
          fs.closeSync(this.activeFile);
        } catch (closeErr) {
          console.error('close file error:', JSON.stringify(closeErr));
        }
        this.activeFile = null;
      }
    }
  }

  // 探测音频时长（毫秒）
  private async probeDuration(path: string): Promise<number> {
    let duration: number = 0;
    const probe: media.AVPlayer = await media.createAVPlayer();
    try {
      await new Promise<void>((resolve) => {
        let resolved: boolean = false;
        const done = (): void => {
          if (!resolved) {
            resolved = true;
            resolve();
          }
        };
        probe.on('durationUpdate', (d: number) => {
          duration = d;
          done();
        });
        probe.on('error', (err: BusinessError) => {
          console.error('probe error:', JSON.stringify(err));
          done();
        });
        probe.on('stateChange', async (state: string) => {
          if (state === 'prepared') {
            await probe.pause();
            done();
          }
        });
        probe.url = 'file://' + path;
        probe.prepare();
        setTimeout(() => { done(); }, 5000);
      });
    } catch (err) {
      console.error('probe duration error:', JSON.stringify(err));
    }
    probe.release();
    return duration;
  }

  // 暂停
  async pause(): Promise<void> {
    if (this.avPlayer) {
      await this.avPlayer.pause();
    }
  }

  // 播放淡入：2 秒内音量从 0 非线性（二次曲线，先慢后快）增至目标音量
  private fadeTimer: number = -1;

  private startFadeIn(): void {
    if (this.fadeTimer >= 0) {
      clearInterval(this.fadeTimer);
      this.fadeTimer = -1;
    }
    const durationMs: number = 2000;
    const steps: number = 40;
    const intervalMs: number = durationMs / steps;
    let step: number = 0;
    // 立即播放（音量 0 起步）
    this.avPlayer?.play();
    this.fadeTimer = setInterval(() => {
      step++;
      if (step > steps) {
        clearInterval(this.fadeTimer);
        this.fadeTimer = -1;
        // 确保达到目标音量
        this.avPlayer?.setVolume(this.volumeValue);
        return;
      }
      // 二次曲线：t = (step/steps)^2，先慢后快
      const t: number = step / steps;
      const vol: number = this.volumeValue * t * t;
      this.avPlayer?.setVolume(vol);
    }, intervalMs);
  }

  // 继续播放
  async resume(): Promise<void> {
    if (this.avPlayer) {
      await this.avPlayer.play();
    }
  }

  // 播放/暂停切换
  async toggle(): Promise<void> {
    if (this.isPlayingFlag) {
      await this.pause();
    } else {
      await this.resume();
    }
  }

  // 设置音量（0.0 - 1.0）
  async setVolume(vol: number): Promise<void> {
    this.volumeValue = vol;
    if (this.avPlayer) {
      try {
        await this.avPlayer.setVolume(vol);
      } catch (err) {
        console.error('setVolume error:', JSON.stringify(err));
      }
    }
  }

  getVolume(): number {
    return this.volumeValue;
  }

  // 加载音量设置（从偏好存储），默认 30%
  async loadVolumeSetting(): Promise<void> {
    try {
      const v = await GlobalData.prefs.get('music_volume', 0.3) as number;
      this.volumeValue = v >= 0 && v <= 1 ? v : 0.3;
    } catch (err) {
      console.error('loadVolumeSetting error:', JSON.stringify(err));
    }
  }

  // 加载默认歌单设置
  async getDefaultPlaylistId(): Promise<number> {
    try {
      const v = await GlobalData.prefs.get('music_default_playlist', 0) as number;
      return v;
    } catch (err) {
      console.error('getDefaultPlaylistId error:', JSON.stringify(err));
      return 0;
    }
  }

  // 是否开启后台播放
  async isBackgroundPlayEnabled(): Promise<boolean> {
    try {
      const v = await GlobalData.prefs.get('music_background_play', false);
      return v === true || v === 'true';
    } catch (err) {
      console.error('isBackgroundPlayEnabled error:', JSON.stringify(err));
      return true;
    }
  }

  // 是否开启进入应用自动播放
  async isAutoPlayEnabled(): Promise<boolean> {
    try {
      const v = await GlobalData.prefs.get('music_auto_play_enter', true);
      return v === true || v === 'true';
    } catch (err) {
      console.error('isAutoPlayEnabled error:', JSON.stringify(err));
      return true;
    }
  }

  // 确保内置"默认歌单"存在：按固定名称查找，不存在才创建（避免重复）
  async ensureDefaultPlaylist(): Promise<number> {
    try {
      // 先按名称查找现有默认歌单
      const playlists = await GlobalData.db.getPlaylists();
      for (const p of playlists) {
        if (String(p.name) === '默认歌单') {
          const id = Number(p.id);
          await GlobalData.prefs.put('music_default_playlist', id);
          return id;
        }
      }
      // 不存在则创建
      const newId = await GlobalData.db.addPlaylist('默认歌单');
      if (newId > 0) {
        await GlobalData.prefs.put('music_default_playlist', newId);
      }
      return newId;
    } catch (err) {
      console.error('ensureDefaultPlaylist error:', JSON.stringify(err));
      return 0;
    }
  }

  // 初始化内置音乐：将 rawfile/music/ 下的内置曲目复制到沙箱并加入默认歌单
  async initBuiltinMusic(): Promise<void> {
    console.info('[MusicInit] initBuiltinMusic called, files=' + BUILTIN_MUSIC_FILES.length);
    if (!this.context || BUILTIN_MUSIC_FILES.length === 0) {
      console.error('[MusicInit] early return: context=' + String(this.context !== null) +
        ' files=' + String(BUILTIN_MUSIC_FILES.length));
      return;
    }
    try {
      const defaultId = await this.ensureDefaultPlaylist();
      console.info('[MusicInit] defaultId=' + String(defaultId));
      if (defaultId <= 0) {
        return;
      }
      // 检查沙箱中是否已有内置音乐（用标记文件判断是否已初始化）
      const markerPath = this.context.filesDir + '/builtin_music_initialized';
      // 若标记存在，仍需确认内置歌曲真的在库中；缺失则重新初始化（避免"标记在了但歌没进去"）
      const lib = await GlobalData.db.getMusicRecords();
      let hasAllBuiltin: boolean = true;
      for (let i = 0; i < BUILTIN_MUSIC_FILES.length; i++) {
        let found = false;
        for (const r of lib) {
          if (String(r.file_name) === BUILTIN_MUSIC_FILES[i]) {
            found = true;
            break;
          }
        }
        if (!found) {
          hasAllBuiltin = false;
          break;
        }
      }
      if (this.exists(markerPath) && hasAllBuiltin) {
        console.info('[MusicInit] already initialized, all builtin songs present');
        return;
      }
      console.info('[MusicInit] marker exists but songs missing, re-init');
      // 逐个复制内置音乐到沙箱
      for (let i = 0; i < BUILTIN_MUSIC_FILES.length; i++) {
        const rawName = BUILTIN_MUSIC_FILES[i];
        const destPath = this.context.filesDir + '/' + rawName;
        await this.copyRawfileToSandbox(rawName, destPath);
        // 检查是否已入库（避免重复）
        const existing = await GlobalData.db.getMusicRecords();
        let alreadyExists = false;
        for (const r of existing) {
          if (String(r.file_name) === rawName) {
            alreadyExists = true;
            break;
          }
        }
        if (!alreadyExists) {
          // 探测时长（毫秒）
          let durationMs = 0;
          try {
            durationMs = await this.probeDuration(destPath);
          } catch (probeErr) {
            console.error('[MusicInit] probe duration error:', JSON.stringify(probeErr));
          }
          const record: DbRow = {
            title: this.stripExtension(rawName),
            artist: '内置音乐',
            duration_ms: durationMs,
            file_name: rawName,
            file_uri: 'file://' + destPath,
            created_at: Date.now()
          };
          await GlobalData.db.addMusicRecord(record);
          const musicRows = await GlobalData.db.getMusicRecords();
          let songId = -1;
          for (const r of musicRows) {
            if (String(r.file_name) === rawName) {
              songId = Number(r.id);
              break;
            }
          }
          if (songId > 0) {
            await GlobalData.db.addSongToPlaylist(defaultId, songId);
          }
        }
      }
      // 写标记文件
      const marker = fs.openSync(markerPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(marker.fd, '1');
      fs.closeSync(marker);
      console.info('[MusicInit] builtin music initialized');
    } catch (err) {
      console.error('initBuiltinMusic error:', JSON.stringify(err));
    }
  }

  // 将 rawfile 文件复制到沙箱（官方推荐：readSync 用 data.offset+off，writeSync 从头写）
  private async copyRawfileToSandbox(rawName: string, destPath: string): Promise<void> {
    try {
      const rawFile = this.context?.resourceManager.getRawFdSync('music/' + rawName);
      if (!rawFile) {
        console.error('[MusicInit] getRawFdSync failed: ' + rawName);
        return;
      }
      const dest = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const bufSize = 4096;
      const buf = new ArrayBuffer(bufSize);
      let off = 0;
      let len = 0;
      let readedLen = 0;
      let remain = rawFile.length;
      while (true) {
        const toRead = remain < bufSize ? remain : bufSize;
        if (toRead <= 0) {
          break;
        }
        // 关键：readSync 的 offset 必须是 rawFile.offset + 已读偏移（rawfile 在 HAP 内的绝对位置）
        len = fs.readSync(rawFile.fd, buf, { offset: rawFile.offset + off, length: toRead });
        if (len <= 0) {
          break;
        }
        // writeSync 从 dest 文件头开始顺序写
        fs.writeSync(dest.fd, buf, { offset: off, length: len });
        off += len;
        readedLen += len;
        remain = rawFile.length - readedLen;
      }
      fs.closeSync(dest);
      this.context?.resourceManager.closeRawFd('music/' + rawName);
      console.info('[MusicInit] copied rawfile: ' + rawName + ' size=' + String(readedLen) + ' total=' + String(rawFile.length));
    } catch (err) {
      console.error('copyRawfileToSandbox error:', JSON.stringify(err));
    }
  }

  // 按指定歌曲列表播放（用于歌单播放）
  async playList(tracks: DbRow[], index: number): Promise<void> {
    if (tracks.length === 0) {
      return;
    }
    this.playlist = tracks;
    const safeIdx = index >= 0 && index < tracks.length ? index : 0;
    await this.playTrack(safeIdx);
  }

  // 下一首
  async next(): Promise<void> {
    if (this.playlist.length === 0) return;
    const idx = this.computeNextIndex();
    await this.playTrack(idx);
  }

  // 上一首
  async prev(): Promise<void> {
    if (this.playlist.length === 0) return;
    const idx = this.computePrevIndex();
    await this.playTrack(idx);
  }

  // 计算下一首索引（按播放模式）
  private computeNextIndex(): number {
    if (this.playlist.length === 0) return 0;
    if (this.playMode === 1) {
      // 单曲循环：回到当前曲
      return this.currentIndex >= 0 ? this.currentIndex : 0;
    }
    if (this.playMode === 2) {
      // 随机播放
      return Math.floor(Math.random() * this.playlist.length);
    }
    // 顺序循环
    return (this.currentIndex + 1) % this.playlist.length;
  }

  private computePrevIndex(): number {
    if (this.playlist.length === 0) return 0;
    if (this.playMode === 1) {
      return this.currentIndex >= 0 ? this.currentIndex : 0;
    }
    if (this.playMode === 2) {
      return Math.floor(Math.random() * this.playlist.length);
    }
    return (this.currentIndex - 1 + this.playlist.length) % this.playlist.length;
  }

  // 播放完成后自动下一首
  async playNextAuto(): Promise<void> {
    const idx = this.computeNextIndex();
    await this.playTrack(idx);
  }

  // 切换播放模式：0=顺序 1=单曲 2=随机
  cyclePlayMode(): number {
    this.playMode = (this.playMode + 1) % 3;
    return this.playMode;
  }

  getPlayMode(): number {
    return this.playMode;
  }

  // 跳转到指定位置
  async seek(ms: number): Promise<void> {
    if (this.avPlayer) {
      await this.avPlayer.seek(ms, media.SeekMode.SEEK_PREV_SYNC);
    }
  }

  // 注册进度回调（供页面 UI 刷新）
  onTimeUpdate(callback: (time: number) => void): void {
    if (this.avPlayer) {
      this.avPlayer.on('timeUpdate', (time: number) => {
        callback(time);
      });
    }
  }

  // 删除曲目（数据库 + 文件）
  async deleteTrack(index: number): Promise<void> {
    if (index < 0 || index >= this.playlist.length) {
      return;
    }
    const track = this.playlist[index];
    const id = Number(track.id);
    await GlobalData.db.deleteMusicRecord(id);
    // 删除沙箱文件
    if (track.file_uri) {
      try {
        const path = String(track.file_uri).replace('file://', '');
        if (this.exists(path)) {
          fs.unlinkSync(path);
        }
      } catch (err) {
        console.error('delete music file error:', JSON.stringify(err));
      }
    }
    // 若正在播放该曲，停止
    if (index === this.currentIndex && this.avPlayer) {
      await this.avPlayer.reset();
      this.isPlayingFlag = false;
    }
    this.playlist.splice(index, 1);
  }

  // 释放播放器
  release(): void {
    if (this.avPlayer) {
      this.avPlayer.release();
      this.avPlayer = null;
    }
    if (this.activeFile) {
      try {
        fs.closeSync(this.activeFile);
      } catch (err) {
        console.error('close active file error:', JSON.stringify(err));
      }
      this.activeFile = null;
    }
    if (this.session) {
      // AVSession 随应用生命周期自动销毁，无需手动 release
      this.session = null;
    }
    this.isPlayingFlag = false;
  }

  private stripExtension(name: string): string {
    const idx = name.lastIndexOf('.');
    return idx > 0 ? name.substring(0, idx) : name;
  }

  // 判断文件/目录是否存在（accessSync 不存在时抛异常，需捕获）
  private exists(path: string): boolean {
    try {
      fs.accessSync(path);
      return true;
    } catch (err) {
      return false;
    }
  }
}
