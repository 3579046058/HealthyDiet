import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ThemeColors } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { MusicService } from '../services/MusicService';

interface PlaylistInfo {
  id: number;
  name: string;
  songCount: number;
}

@Entry
@Component
struct MusicSettingsPage {
  @State playlists: PlaylistInfo[] = [];
  @State defaultPlaylistId: number = 0;
  @State volume: number = 0.1;
  @State autoPlayOnEnter: boolean = true;
  @State backgroundPlay: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  private musicService: MusicService = MusicService.getInstance();

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    await this.musicService.loadVolumeSetting();
    this.volume = this.musicService.getVolume();
    this.defaultPlaylistId = await this.musicService.getDefaultPlaylistId();
    try {
      const ap = await GlobalData.prefs.get('music_auto_play_enter', true);
      this.autoPlayOnEnter = ap === true || ap === 'true';
    } catch (err) {
      this.autoPlayOnEnter = true;
    }
    try {
      const bp = await GlobalData.prefs.get('music_background_play', false);
      this.backgroundPlay = bp === true || bp === 'true';
    } catch (err) {
      this.backgroundPlay = true;
    }
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

  async setDefaultPlaylist(id: number): Promise<void> {
    this.defaultPlaylistId = id;
    try {
      await GlobalData.prefs.put('music_default_playlist', id);
      promptAction.showToast({ message: '默认歌单已设置' });
    } catch (err) {
      console.error('save default playlist error:', JSON.stringify(err));
    }
  }

  async onVolumeChange(value: number): Promise<void> {
    this.volume = value;
    await this.musicService.setVolume(value);
    try {
      await GlobalData.prefs.put('music_volume', value);
    } catch (err) {
      console.error('save volume error:', JSON.stringify(err));
    }
  }

  async onAutoPlayChange(on: boolean): Promise<void> {
    this.autoPlayOnEnter = on;
    try {
      await GlobalData.prefs.put('music_auto_play_enter', on);
    } catch (err) {
      console.error('save auto play error:', JSON.stringify(err));
    }
  }

  async onBackgroundPlayChange(on: boolean): Promise<void> {
    this.backgroundPlay = on;
    try {
      await GlobalData.prefs.put('music_background_play', on);
    } catch (err) {
      console.error('save background play error:', JSON.stringify(err));
    }
    if (!on) {
      if (this.musicService.isPlaying()) {
        await this.musicService.pause();
      }
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_back')).width(22).height(22).fillColor(this.txt())
          .onClick(() => { router.back(); })
        Text('音乐播放设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 + this.statusBarHeight, bottom: 12 })

      Scroll() {
        Column() {
          // 播放设置
          Text('播放设置').fontSize(14).fontColor(this.sub()).width('100%')
            .padding({ left: 20, bottom: 8 })

          Row() {
            Image($r('app.media.ic_music')).width(20).height(20).fillColor('#E91E63')
            Column() {
              Text('进入应用自动播放').fontSize(15).fontColor(this.txt())
              Text('启动后自动播放默认歌单').fontSize(11).fontColor(this.sub()).margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
            Toggle({ type: ToggleType.Switch, isOn: this.autoPlayOnEnter })
              .selectedColor('#E91E63')
              .onChange((isOn: boolean) => { this.onAutoPlayChange(isOn); })
          }
          .width('100%').padding(14).backgroundColor(this.card()).borderRadius(12)
          .margin({ left: 16, right: 16, bottom: 8 })

          Row() {
            Image($r('app.media.ic_music')).width(20).height(20).fillColor('#E91E63')
            Column() {
              Text('后台播放').fontSize(15).fontColor(this.txt())
              Text('切到后台继续播放音乐').fontSize(11).fontColor(this.sub()).margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
            Toggle({ type: ToggleType.Switch, isOn: this.backgroundPlay })
              .selectedColor('#E91E63')
              .onChange((isOn: boolean) => { this.onBackgroundPlayChange(isOn); })
          }
          .width('100%').padding(14).backgroundColor(this.card()).borderRadius(12)
          .margin({ left: 16, right: 16, bottom: 16 })

          // 默认音量
          Text('默认音量').fontSize(14).fontColor(this.sub()).width('100%')
            .padding({ left: 20, bottom: 8 })
          Text('进入应用时的初始音量（默认 10%）').fontSize(12).fontColor(this.sub()).width('100%')
            .padding({ left: 20, bottom: 8 })

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
            Text(Math.round(this.volume * 100) + '%').fontSize(13).fontColor(this.txt()).width(48)
              .textAlign(TextAlign.End).margin({ left: 8 })
          }
          .width('100%').padding(16)
          .backgroundColor(this.card()).borderRadius(12)
          .margin({ left: 16, right: 16, bottom: 16 })

          // 默认歌单
          Text('默认播放歌单').fontSize(14).fontColor(this.sub()).width('100%')
            .padding({ left: 20, bottom: 8 })
          Text('打开播放器后自动播放该歌单').fontSize(12).fontColor(this.sub()).width('100%')
            .padding({ left: 20, bottom: 8 })

          if (this.playlists.length === 0) {
            Column() {
              Text('暂无歌单').fontSize(15).fontColor(this.sub()).margin({ top: 8 })
              Text('请先在音乐播放器中创建歌单').fontSize(12).fontColor(this.sub()).margin({ top: 4 })
            }
            .width('100%').padding(20).alignItems(HorizontalAlign.Center)
            .backgroundColor(this.card()).borderRadius(12)
            .margin({ left: 16, right: 16, bottom: 8 })
          } else {
            ForEach(this.playlists, (p: PlaylistInfo) => {
              Row() {
                Image($r('app.media.ic_music')).width(20).height(20).fillColor('#E91E63')
                Column() {
                  Text(p.name).fontSize(15).fontColor(this.txt())
                  Text(p.songCount + ' 首歌曲').fontSize(12).fontColor(this.sub()).margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })

                if (this.defaultPlaylistId === p.id) {
                  Row() {
                    Image($r('app.media.ic_check')).width(14).height(14).fillColor('#4CAF50')
                    Text('默认').fontSize(12).fontColor('#4CAF50').margin({ left: 4 })
                  }
                } else {
                  Button('设为默认').fontSize(12).height(28)
                    .backgroundColor('#E91E63').fontColor(Color.White).borderRadius(14)
                    .onClick(() => { this.setDefaultPlaylist(p.id); })
                }
              }
              .width('100%').padding(14)
              .backgroundColor(this.card()).borderRadius(12)
              .margin({ left: 16, right: 16, bottom: 8 })
            }, (p: PlaylistInfo): string => String(p.id))
          }

          // 说明
          Text('提示：进入应用时将自动播放默认歌单；后台播放可在上方开关控制。')
            .fontSize(11).fontColor(this.sub()).width('100%')
            .padding({ left: 20, right: 20, top: 12 })

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor(this.bg())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
