import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { MusicService } from '../services/MusicService';
import { DbRow, ThemeColors } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';

interface PlaylistInfo {
  id: number;
  name: string;
  songCount: number;
}

@Entry
@Component
struct MusicPlayerPage {
  @State playlist: DbRow[] = [];
  @State currentIndex: number = -1;
  @State isPlaying: boolean = false;
  @State progress: number = 0;
  @State duration: number = 0;
  @State currentTime: number = 0;
  @State isImporting: boolean = false;
  @State viewTab: number = 0; // 0=全部音乐 1=歌单
  @State playlists: PlaylistInfo[] = [];
  @State currentPlaylistId: number = -1; // -1=全部音乐
  @State playlistSongs: DbRow[] = [];
  @State showAddPlaylist: boolean = false;
  @State newPlaylistName: string = '';
  @State volume: number = 0.3;
  @State showVolumeBar: boolean = false;
  @State pickSong: DbRow | null = null;
  @State playMode: number = 0;
  @State currentTitle: string = '未选择';
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  private timer: number = -1;
  private musicService: MusicService = MusicService.getInstance();

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  aboutToAppear(): void {
    this.musicService.initSession();
    this.musicService.loadVolumeSetting();
    this.volume = this.musicService.getVolume();
    this.playMode = this.musicService.getPlayMode();
    this.loadLibrary();
    this.loadPlaylists();
    this.checkAutoPlay();
  }

  // 进入播放器时自动播放：仅在开启"进入应用自动播放"且首次冷启动时生效；已有播放则保持进度
  async checkAutoPlay(): Promise<void> {
    try {
      const autoPlay = await this.musicService.isAutoPlayEnabled();
      if (!autoPlay) {
        return; // 用户关闭了自动播放
      }
      // 已有播放列表：若暂停则恢复（保持进度），不重新开始
      if (this.musicService.getPlaylist().length > 0) {
        if (!this.musicService.isPlaying()) {
          await this.musicService.resume();
        }
        return;
      }
      // 首次自动播放标记：仅冷启动第一次触发
      const firstRaw: string | number | boolean = await GlobalData.prefs.get('music_first_autoplay_done', 'false');
      if (String(firstRaw) === 'true') {
        return;
      }
      // 确保内置默认歌单存在
      const defaultId = await this.musicService.ensureDefaultPlaylist();
      let songs: DbRow[] = [];
      if (defaultId > 0) {
        songs = await GlobalData.db.getPlaylistSongs(defaultId);
      }
      if (songs.length > 0) {
        // 自动播放默认歌单
        this.currentPlaylistId = defaultId;
        this.playlistSongs = songs;
        this.viewTab = 1;
        await this.musicService.playList(songs, 0);
        await GlobalData.prefs.put('music_first_autoplay_done', 'true');
        this.currentIndex = 0;
        this.isPlaying = true;
        this.startTimer();
      } else {
        // 默认歌单为空，自动播放全部音乐
        const allSongs = await this.musicService.loadLibrary();
        if (allSongs.length > 0) {
          this.currentPlaylistId = -1;
          await this.musicService.playList(allSongs, 0);
          await GlobalData.prefs.put('music_first_autoplay_done', 'true');
          this.currentIndex = 0;
          this.isPlaying = true;
          this.startTimer();
        }
      }
    } catch (err) {
      console.error('checkAutoPlay error:', JSON.stringify(err));
    }
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  async loadLibrary(): Promise<void> {
    this.playlist = await this.musicService.loadLibrary();
    const idx = this.musicService.getCurrentIndex();
    this.currentIndex = idx;
    this.isPlaying = this.musicService.isPlaying();
    this.duration = this.musicService.getDuration();
    if (idx >= 0 && this.playlist.length > 0) {
      this.startTimer();
    }
  }

  async loadPlaylists(): Promise<void> {
    const rows = await GlobalData.db.getPlaylists();
    const list: PlaylistInfo[] = [];
    for (const r of rows) {
      const songs = await GlobalData.db.getPlaylistSongs(Number(r.id));
      const info: PlaylistInfo = {
        id: Number(r.id),
        name: String(r.name),
        songCount: songs.length
      };
      list.push(info);
    }
    this.playlists = list;
  }

  async loadPlaylistSongs(playlistId: number): Promise<void> {
    this.playlistSongs = await GlobalData.db.getPlaylistSongs(playlistId);
  }

  startTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    this.timer = setInterval(() => {
      this.currentTime = this.musicService.getCurrentTime();
      this.duration = this.musicService.getDuration();
      this.isPlaying = this.musicService.isPlaying();
      // 同步当前歌曲标题（service 内部变化不会自动刷新 @State）
      const track = this.musicService.getCurrentTrack();
      this.currentTitle = track ? String(track.title) : '未选择';
      if (this.duration > 0) {
        this.progress = Math.min(100, this.currentTime / this.duration * 100);
      }
    }, 500);
  }

  async importMusic(): Promise<void> {
    this.isImporting = true;
    const track = await this.musicService.importAudio();
    this.isImporting = false;
    if (track) {
      promptAction.showToast({ message: '导入成功: ' + String(track.title) });
      await this.loadLibrary();
    } else {
      promptAction.showToast({ message: '未选择音频或导入失败' });
    }
  }

  async playTrack(index: number): Promise<void> {
    await this.musicService.playTrack(index);
    this.currentIndex = index;
    this.isPlaying = true;
    this.duration = this.musicService.getDuration();
    this.startTimer();
  }

  // 播放歌单内歌曲
  async playPlaylistSong(index: number): Promise<void> {
    await this.musicService.playList(this.playlistSongs, index);
    this.currentIndex = index;
    this.isPlaying = true;
    this.duration = this.musicService.getDuration();
    this.startTimer();
  }

  async togglePlay(): Promise<void> {
    if (this.currentIndex < 0) {
      return;
    }
    await this.musicService.toggle();
    this.isPlaying = this.musicService.isPlaying();
  }

  async nextTrack(): Promise<void> {
    if (this.musicService.getPlaylist().length === 0) return;
    await this.musicService.next();
    this.currentIndex = this.musicService.getCurrentIndex();
    this.startTimer();
  }

  async prevTrack(): Promise<void> {
    if (this.musicService.getPlaylist().length === 0) return;
    await this.musicService.prev();
    this.currentIndex = this.musicService.getCurrentIndex();
    this.startTimer();
  }

  async onSeek(value: number): Promise<void> {
    if (this.duration <= 0) return;
    const ms = Math.round(value / 100 * this.duration);
    await this.musicService.seek(ms);
  }

  async deleteTrack(index: number): Promise<void> {
    const track = this.playlist[index];
    if (!track) return;
    await this.musicService.deleteTrack(index);
    await this.loadLibrary();
    promptAction.showToast({ message: '已删除' });
  }

  // 新建歌单
  async createPlaylist(): Promise<void> {
    const name = this.newPlaylistName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入歌单名称' });
      return;
    }
    await GlobalData.db.addPlaylist(name);
    this.showAddPlaylist = false;
    this.newPlaylistName = '';
    await this.loadPlaylists();
    promptAction.showToast({ message: '歌单创建成功' });
  }

  // 删除歌单
  async removePlaylist(id: number): Promise<void> {
    await GlobalData.db.deletePlaylist(id);
    if (this.currentPlaylistId === id) {
      this.currentPlaylistId = -1;
      this.playlistSongs = [];
    }
    await this.loadPlaylists();
    promptAction.showToast({ message: '歌单已删除' });
  }

  // 将歌曲加入歌单
  async addToPlaylist(song: DbRow, playlistId: number): Promise<void> {
    const songId = Number(song.id);
    const inList = await GlobalData.db.isSongInPlaylist(playlistId, songId);
    if (inList) {
      promptAction.showToast({ message: '该歌曲已在歌单中' });
      return;
    }
    await GlobalData.db.addSongToPlaylist(playlistId, songId);
    await this.loadPlaylists();
    promptAction.showToast({ message: '已加入歌单' });
  }

  // 从歌单移除歌曲
  async removeFromPlaylist(song: DbRow): Promise<void> {
    if (this.currentPlaylistId < 0) return;
    await GlobalData.db.removeSongFromPlaylist(this.currentPlaylistId, Number(song.id));
    await this.loadPlaylistSongs(this.currentPlaylistId);
    await this.loadPlaylists();
    promptAction.showToast({ message: '已从歌单移除' });
  }

  // 音量调节
  async onVolumeChange(value: number): Promise<void> {
    this.volume = value;
    await this.musicService.setVolume(value);
    try {
      await GlobalData.prefs.put('music_volume', value);
    } catch (err) {
      console.error('save volume error:', JSON.stringify(err));
    }
  }

  formatTime(ms: number): string {
    const totalSec = Math.floor(ms / 1000);
    const min = Math.floor(totalSec / 60);
    const sec = totalSec % 60;
    return (min < 10 ? '0' + min : String(min)) + ':' + (sec < 10 ? '0' + sec : String(sec));
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_back')).width(22).height(22).fillColor(this.txt())
          .onClick(() => { router.back(); })
        Text('音乐播放器').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
        if (this.viewTab === 0) {
          Button() {
            Row() {
              Image($r('app.media.ic_music_add')).width(16).height(16).fillColor(Color.White)
              Text('导入').fontSize(13).fontColor(Color.White).margin({ left: 4 })
            }
          }
            .backgroundColor('#E91E63').borderRadius(18).height(36)
            .enabled(!this.isImporting)
            .onClick(() => { this.importMusic(); })
        } else {
          Button() {
            Row() {
              Image($r('app.media.ic_playlist_add')).width(16).height(16).fillColor(Color.White)
              Text('新建歌单').fontSize(13).fontColor(Color.White).margin({ left: 4 })
            }
          }
            .backgroundColor('#E91E63').borderRadius(18).height(36)
            .onClick(() => { this.showAddPlaylist = true; })
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 + this.statusBarHeight, bottom: 12 })

      // Tab 切换
      Row() {
        this.tabButton('全部音乐', 0)
        this.tabButton('歌单', 1)
      }
      .width('100%').padding({ left: 16, right: 16, bottom: 8 })

      // 内容区
      if (this.viewTab === 0) {
        // 全部音乐列表
        Scroll() {
          Column() {
            if (this.playlist.length === 0) {
              Column() {
                Image($r('app.media.ic_music')).width(64).height(64).fillColor(this.txt()).opacity(0.3)
                Text('音乐库为空').fontSize(16).fontColor(this.sub()).margin({ top: 16 })
                Text('点击右上角"导入"添加本地音频').fontSize(13).fontColor(this.sub()).margin({ top: 6 })
              }
              .width('100%').alignItems(HorizontalAlign.Center).margin({ top: 60 })
            } else {
              ForEach(this.playlist, (item: DbRow, index: number) => {
                Row() {
                  Image($r('app.media.ic_music_mono')).width(18).height(18)
                    .fillColor(index === this.currentIndex ? '#E91E63' : this.sub())
                  Column() {
                    Text(String(item.title)).fontSize(15).fontColor(index === this.currentIndex ? '#E91E63' : this.txt())
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(String(item.artist)).fontSize(12).fontColor(this.sub()).margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })

                  if (index === this.currentIndex && this.isPlaying) {
                    Image($r('app.media.ic_volume')).width(16).height(16).fillColor('#E91E63')
                  }

                  // 加入歌单按钮
                  Image($r('app.media.ic_playlist_add')).width(16).height(16).fillColor(this.sub())
                    .margin({ left: 10 })
                    .onClick(() => { this.showSongPlaylistPicker(item); })

                  Image($r('app.media.ic_delete')).width(16).height(16).fillColor(this.sub())
                    .margin({ left: 10 })
                    .onClick(() => { this.deleteTrack(index); })
                }
                .width('100%').padding(14)
                .backgroundColor(this.card()).borderRadius(12)
                .margin({ left: 16, right: 16, bottom: 8 })
                .onClick(() => {
                  if (index === this.currentIndex && this.isPlaying) {
                    this.togglePlay();
                  } else {
                    this.playTrack(index);
                  }
                })
              }, (item: DbRow): string => String(item.id))
            }
          }
          .width('100%').padding({ top: 4, bottom: 140 })
        }
        .layoutWeight(1)
      } else {
        // 歌单视图
        Scroll() {
          Column() {
            if (this.currentPlaylistId < 0) {
              // 歌单列表
              if (this.playlists.length === 0) {
                Column() {
                  Image($r('app.media.ic_playlist_add')).width(64).height(64).fillColor(this.txt()).opacity(0.3)
                  Text('暂无歌单').fontSize(16).fontColor(this.sub()).margin({ top: 16 })
                  Text('点击右上角"新建歌单"创建').fontSize(13).fontColor(this.sub()).margin({ top: 6 })
                }
                .width('100%').alignItems(HorizontalAlign.Center).margin({ top: 60 })
              } else {
                ForEach(this.playlists, (p: PlaylistInfo) => {
                  Row() {
                    Image($r('app.media.ic_music')).width(20).height(20).fillColor('#E91E63')
                    Column() {
                      Text(p.name).fontSize(15).fontColor(this.txt())
                      Text(p.songCount + ' 首歌曲').fontSize(12).fontColor(this.sub()).margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })

                    Image($r('app.media.ic_delete')).width(16).height(16).fillColor(this.sub())
                      .onClick(() => { this.removePlaylist(p.id); })
                  }
                  .width('100%').padding(14)
                  .backgroundColor(this.card()).borderRadius(12)
                  .margin({ left: 16, right: 16, bottom: 8 })
                  .onClick(() => {
                    this.currentPlaylistId = p.id;
                    this.loadPlaylistSongs(p.id);
                  })
                }, (p: PlaylistInfo): string => String(p.id))
              }
            } else {
              // 歌单详情
              Row() {
                Image($r('app.media.ic_back')).width(20).height(20).fillColor(this.txt())
                  .onClick(() => { this.currentPlaylistId = -1; this.playlistSongs = []; })
                Text(this.currentPlaylistName()).fontSize(16).fontWeight(FontWeight.Bold)
                  .fontColor(this.txt()).margin({ left: 8 })
                Blank()
              }
              .width('100%').padding({ left: 16, right: 16, bottom: 8 })

              if (this.playlistSongs.length === 0) {
                Text('歌单为空，去"全部音乐"添加歌曲吧').fontSize(13).fontColor(this.sub())
                  .width('100%').textAlign(TextAlign.Center).margin({ top: 40 })
              } else {
                ForEach(this.playlistSongs, (item: DbRow, index: number) => {
                  Row() {
                    Image($r('app.media.ic_music_mono')).width(18).height(18)
                      .fillColor(index === this.currentIndex ? '#E91E63' : this.sub())
                    Column() {
                      Text(String(item.title)).fontSize(15).fontColor(index === this.currentIndex ? '#E91E63' : this.txt())
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(String(item.artist)).fontSize(12).fontColor(this.sub()).margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })

                    if (index === this.currentIndex && this.isPlaying) {
                      Image($r('app.media.ic_volume')).width(16).height(16).fillColor('#E91E63')
                    }

                    Image($r('app.media.ic_close')).width(16).height(16).fillColor(this.sub())
                      .margin({ left: 10 })
                      .onClick(() => { this.removeFromPlaylist(item); })
                  }
                  .width('100%').padding(14)
                  .backgroundColor(this.card()).borderRadius(12)
                  .margin({ left: 16, right: 16, bottom: 8 })
                  .onClick(() => {
                    if (index === this.currentIndex && this.isPlaying) {
                      this.togglePlay();
                    } else {
                      this.playPlaylistSong(index);
                    }
                  })
                }, (item: DbRow): string => String(item.id))
              }
            }
          }
          .width('100%').padding({ top: 4, bottom: 140 })
        }
        .layoutWeight(1)
      }

      // 新建歌单弹窗
      if (this.showAddPlaylist) {
        Column() {
          Column() {
            Text('新建歌单').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ bottom: 16 })
            TextInput({ placeholder: '歌单名称', text: this.newPlaylistName })
              .width('100%').height(42)
              .fontColor(this.txt()).placeholderColor(this.sub())
              .backgroundColor(this.card())
              .borderRadius(10)
              .onChange((value: string) => { this.newPlaylistName = value; })
            Row() {
              Button('取消').layoutWeight(1).height(40).backgroundColor(this.card())
                .fontColor(this.txt()).borderRadius(20)
                .onClick(() => { this.showAddPlaylist = false; this.newPlaylistName = ''; })
              Button('创建').layoutWeight(1).height(40).backgroundColor('#E91E63')
                .fontColor(Color.White).borderRadius(20).margin({ left: 12 })
                .onClick(() => { this.createPlaylist(); })
            }
            .width('100%').margin({ top: 16 })
          }
          .width('85%').padding(20).backgroundColor(this.bg()).borderRadius(16)
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.6)')
        .onClick(() => { this.showAddPlaylist = false; })
      }

      // 加入歌单选择弹窗
      if (this.pickSong) {
        Column() {
          Column() {
            Text('添加到歌单').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ bottom: 16 })
            Text(String(this.pickSong.title)).fontSize(13).fontColor(this.sub()).margin({ bottom: 12 })
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Scroll() {
              Column() {
                ForEach(this.playlists, (p: PlaylistInfo) => {
                  Row() {
                    Image($r('app.media.ic_music')).width(18).height(18).fillColor('#E91E63')
                    Text(p.name).fontSize(15).fontColor(this.txt()).margin({ left: 10 }).layoutWeight(1)
                    Text(p.songCount + '首').fontSize(12).fontColor(this.sub())
                  }
                  .width('100%').padding(12)
                  .backgroundColor(this.card()).borderRadius(10)
                  .margin({ bottom: 8 })
                  .onClick(() => {
                    if (this.pickSong) {
                      this.addToPlaylist(this.pickSong, p.id);
                      this.pickSong = null;
                    }
                  })
                }, (p: PlaylistInfo): string => String(p.id))
              }
              .width('100%')
            }
            .constraintSize({ maxHeight: 300 })
            Button('取消').width('100%').height(38).backgroundColor(this.card())
              .fontColor(this.txt()).borderRadius(19).margin({ top: 8 })
              .onClick(() => { this.pickSong = null; })
          }
          .width('85%').padding(20).backgroundColor(this.bg()).borderRadius(16)
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.6)')
        .onClick(() => { this.pickSong = null; })
      }

      // 底部播放控制条
      if (this.musicService.getPlaylist().length > 0) {
        Column() {
          Row() {
            Image($r('app.media.ic_music')).width(40).height(40).fillColor('#E91E63')
            Column() {
              Text(this.currentTitle)
                .fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.txt())
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.formatTime(this.currentTime) + ' / ' + this.formatTime(this.duration))
                .fontSize(11).fontColor(this.sub()).margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })

            Image($r('app.media.ic_volume')).width(20).height(20).fillColor('#E91E63')
              .onClick(() => { this.showVolumeBar = !this.showVolumeBar; })
          }
          .width('100%')

          // 音量滑块（横向）
          if (this.showVolumeBar) {
            Row() {
              Image($r('app.media.ic_music_mono')).width(14).height(14).fillColor(this.sub())
              Slider({ value: this.volume, min: 0, max: 1, step: 0.05 })
                .layoutWeight(1).margin({ left: 8, right: 8 })
                .selectedColor('#E91E63')
                .onChange((value: number, mode: SliderChangeMode) => {
                  if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) {
                    this.onVolumeChange(value);
                  }
                })
              Image($r('app.media.ic_volume')).width(18).height(18).fillColor('#E91E63')
              Text(Math.round(this.volume * 100) + '%').fontSize(11).fontColor(this.sub()).width(40)
                .textAlign(TextAlign.End)
            }
            .width('100%').margin({ top: 8 })
          }

          Slider({ value: this.progress, min: 0, max: 100, step: 1 })
            .selectedColor('#E91E63').width('100%')
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) {
                this.progress = value;
                this.onSeek(value);
              }
            })

          Row() {
            Image($r('app.media.ic_prev')).width(28).height(28).fillColor(this.txt())
              .onClick(() => { this.prevTrack(); })
            Text(this.playModeLabel()).fontSize(11).fontColor(this.playMode === 0 ? '#E91E63' : this.sub())
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(this.playMode === 0 ? '#E91E6322' : 'transparent')
              .borderRadius(10)
              .onClick(() => { this.cyclePlayMode(); })
            Blank()
            Button() {
              if (this.isPlaying) {
                Image($r('app.media.ic_pause')).width(30).height(30).fillColor(Color.White)
              } else {
                Image($r('app.media.ic_play')).width(30).height(30).fillColor(Color.White)
              }
            }
              .width(64).height(64).borderRadius(32).backgroundColor('#E91E63')
              .onClick(() => { this.togglePlay(); })
            Blank()
            Image($r('app.media.ic_next')).width(28).height(28).fillColor(this.txt())
              .onClick(() => { this.nextTrack(); })
          }
          .width('100%').alignItems(VerticalAlign.Center).margin({ top: 8 })
        }
        .width('100%').padding(16)
        .backgroundColor(this.card()).borderRadius(20)
        .margin({ left: 12, right: 12, bottom: 16 })
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.bg())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  tabButton(label: string, tabIndex: number) {
    Text(label)
      .fontSize(15)
      .fontWeight(tabIndex === this.viewTab ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(tabIndex === this.viewTab ? '#E91E63' : this.sub())
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .backgroundColor(tabIndex === this.viewTab ? '#E91E6322' : 'transparent')
      .borderRadius(16)
      .onClick(() => { this.viewTab = tabIndex; })
  }

  // 弹窗选择歌单（从全部音乐添加歌曲到歌单）
  showSongPlaylistPicker(song: DbRow): void {
    if (this.playlists.length === 0) {
      promptAction.showToast({ message: '请先在"歌单"页新建歌单' });
      return;
    }
    this.pickSong = song;
  }

  currentPlaylistName(): string {
    for (const p of this.playlists) {
      if (p.id === this.currentPlaylistId) {
        return p.name;
      }
    }
    return '歌单';
  }

  currentTrackTitle(): string {
    const track = this.musicService.getCurrentTrack();
    return track ? String(track.title) : '未选择';
  }

  playModeLabel(): string {
    if (this.playMode === 0) return '顺序';
    if (this.playMode === 1) return '单曲';
    return '随机';
  }

  cyclePlayMode(): void {
    this.playMode = this.musicService.cyclePlayMode();
  }
}
