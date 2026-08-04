import { router, promptAction } from '@kit.ArkUI';
import { ThemeColors } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';

@Entry
@Component
struct ProfilePage {
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State heightCm: string = '';
  @State weightKg: string = '';
  @State gender: string = '男';
  @State saved: boolean = false;

  private genders: string[] = ['男', '女', '其他'];

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  aboutToAppear(): void {
    this.loadProfile();
  }

  async loadProfile(): Promise<void> {
    try {
      const config = await GlobalData.prefs.getGoalConfig();
      this.heightCm = String(config.heightCm);
      this.weightKg = String(config.weightKg);
      const g = await GlobalData.prefs.getGender();
      if (g.length > 0) {
        this.gender = g;
      }
    } catch (err) {
      console.error('ProfilePage load error:', JSON.stringify(err));
    }
  }

  async saveProfile(): Promise<void> {
    const h = parseInt(this.heightCm);
    const w = parseFloat(this.weightKg);
    if (isNaN(h) || h <= 0 || isNaN(w) || w <= 0) {
      promptAction.showToast({ message: '请填写有效的身高和体重' });
      return;
    }
    const config = await GlobalData.prefs.getGoalConfig();
    config.heightCm = h;
    config.weightKg = w;
    await GlobalData.prefs.saveGoalConfig(config);
    await GlobalData.prefs.setWeight(w);
    await GlobalData.prefs.markWeightConfigured();
    await GlobalData.prefs.setGender(this.gender);
    this.saved = true;
    promptAction.showToast({ message: '个人信息已保存' });
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt()).onClick(() => { router.back(); })
        Text('个人信息').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Scroll() {
        Column() {
          Column() {
            Text('👤').fontSize(64)
            Text('完善你的基本信息').fontSize(13).fontColor(this.sub()).margin({ top: 8 })
          }
          .width('100%').alignItems(HorizontalAlign.Center).padding(20)

          Column() {
            Text('性别').fontSize(14).fontColor(this.sub()).width('100%')
            Row() {
              ForEach(this.genders, (item: string) => {
                Text(item)
                  .fontSize(14)
                  .fontColor(this.gender === item ? '#FFFFFF' : this.txt())
                  .backgroundColor(this.gender === item ? '#FF6B35' : this.card())
                  .borderRadius(18).padding({ left: 18, right: 18, top: 10, bottom: 10 })
                  .margin({ right: 10 })
                  .onClick(() => { this.gender = item; })
              })
            }
            .width('100%').margin({ top: 8, bottom: 16 })

            Row() {
              Text('身高').fontSize(14).fontColor(this.sub()).width(60)
              TextInput({ placeholder: '170', text: this.heightCm })
                .type(InputType.Number).layoutWeight(1).height(44)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt()).placeholderColor(this.sub())
                .onChange((v: string) => { this.heightCm = v; })
              Text('cm').fontSize(14).fontColor(this.sub()).margin({ left: 8 })
            }
            .width('100%').margin({ bottom: 12 })

            Row() {
              Text('体重').fontSize(14).fontColor(this.sub()).width(60)
              TextInput({ placeholder: '70', text: this.weightKg })
                .type(InputType.Number).layoutWeight(1).height(44)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt()).placeholderColor(this.sub())
                .onChange((v: string) => { this.weightKg = v; })
              Text('kg').fontSize(14).fontColor(this.sub()).margin({ left: 8 })
            }
            .width('100%')

            Button('保存个人信息').width('100%').height(48)
              .backgroundColor('#FF6B35').borderRadius(24)
              .fontColor(Color.White).fontSize(16)
              .margin({ top: 24 })
              .onClick(() => { this.saveProfile(); })

            if (this.saved) {
              Text('✅ 已保存').fontSize(13).fontColor('#4CAF50').width('100%').textAlign(TextAlign.Center).margin({ top: 10 })
            }

            Text('提示：身高体重用于BMI计算和运动热量估算').fontSize(11).fontColor(this.sub())
              .width('100%').textAlign(TextAlign.Center).margin({ top: 12 })
          }
          .width('100%').padding(16)
          .backgroundColor(this.card()).borderRadius(14)
          .margin({ left: 16, right: 16 })

          Divider().opacity(0).height(30)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
