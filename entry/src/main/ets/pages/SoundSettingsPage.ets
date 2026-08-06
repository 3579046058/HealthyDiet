import { router } from '@kit.ArkUI';
import { ThemeColors } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { SoundEffectService } from '../services/SoundEffectService';

@Entry
@Component
struct SoundSettingsPage {
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  // 各音效场景开关
  @State masterEnabled: boolean = true;
  @State waterEnabled: boolean = true;
  @State sportStartEnabled: boolean = true;
  @State successEnabled: boolean = true;
  @State notifyEnabled: boolean = true;

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    try {
      const masterRaw: string | number | boolean = await GlobalData.prefs.get('sound_effect_enabled', 'true');
      this.masterEnabled = String(masterRaw) === 'true';
      const waterRaw: string | number | boolean = await GlobalData.prefs.get('sfx_water_enabled', 'true');
      this.waterEnabled = String(waterRaw) === 'true';
      const sportRaw: string | number | boolean = await GlobalData.prefs.get('sfx_sport_start_enabled', 'true');
      this.sportStartEnabled = String(sportRaw) === 'true';
      const successRaw: string | number | boolean = await GlobalData.prefs.get('sfx_success_enabled', 'true');
      this.successEnabled = String(successRaw) === 'true';
      const notifyRaw: string | number | boolean = await GlobalData.prefs.get('sfx_notify_enabled', 'true');
      this.notifyEnabled = String(notifyRaw) === 'true';
    } catch (err) {
      console.error('SoundSettingsPage load error:', JSON.stringify(err));
    }
  }

  async saveToggle(key: string, value: boolean): Promise<void> {
    await GlobalData.prefs.put(key, String(value));
    await GlobalData.prefs.flush();
  }

  // 测试播放对应音效
  testPlay(name: string): void {
    SoundEffectService.getInstance().play(name);
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }
  accent(): string { return '#FF6B35'; }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('←').fontSize(22).fontColor(this.txt()).onClick(() => { router.back(); })
        Text('音效设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 + this.statusBarHeight, bottom: 12 })

      Scroll() {
        Column() {
          // 总开关
          this.soundItem('🔊', '音效总开关', '所有场景音效的开关', this.masterEnabled, 'sound_effect_enabled',
            (on: boolean) => { this.masterEnabled = on; }, () => {})

          Divider().margin({ left: 16, right: 16, top: 4, bottom: 8 })

          // 各场景开关
          this.soundItem('💧', '喝水记录', '记录喝水时的滴水声', this.waterEnabled, 'sfx_water_enabled',
            (on: boolean) => { this.waterEnabled = on; }, () => { this.testPlay('water'); })
          this.soundItem('🏃', '运动开始', '开始运动时的哨声', this.sportStartEnabled, 'sfx_sport_start_enabled',
            (on: boolean) => { this.sportStartEnabled = on; }, () => { this.testPlay('sport_start'); })
          this.soundItem('🎉', '目标达成', '达成目标/解锁成就的庆祝声', this.successEnabled, 'sfx_success_enabled',
            (on: boolean) => { this.successEnabled = on; }, () => { this.testPlay('success'); })
          this.soundItem('🔔', '运动结束/情绪', '运动结束铃声和情绪记录提示', this.notifyEnabled, 'sfx_notify_enabled',
            (on: boolean) => { this.notifyEnabled = on; }, () => { this.testPlay('notify'); })

          Text('点击右侧图标可试听对应音效')
            .fontSize(12).fontColor(this.sub()).padding({ left: 16, right: 16, top: 12 })

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor(this.bg())
  }

  @Builder
  soundItem(icon: string, title: string, desc: string, enabled: boolean, key: string,
    onChange: (on: boolean) => void, onTest: () => void) {
    Row() {
      Text(icon).fontSize(22)
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.txt())
        Text(desc).fontSize(11).fontColor(this.sub()).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
      Text('▶').fontSize(14).fontColor(this.accent()).margin({ right: 12 })
        .onClick(() => { onTest(); })
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(this.accent())
        .onChange((isOn: boolean) => {
          onChange(isOn);
          this.saveToggle(key, isOn);
        })
    }
    .width('100%').padding(14).backgroundColor(this.card()).borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 8 })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
