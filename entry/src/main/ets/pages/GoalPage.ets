import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { GoalConfig, ThemeColors } from '../common/Constants';

@Entry
@Component
struct GoalPage {
  @State stepsGoal: string = '8000';
  @State waterGoal: string = '2000';
  @State sportDays: string = '3';
  @State sleepHours: string = '8';
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  aboutToAppear(): void {
    this.loadGoals();
  }

  async loadGoals(): Promise<void> {
    try {
      const config: GoalConfig = await GlobalData.prefs.getGoalConfig();
      this.stepsGoal = String(config.dailySteps);
      this.waterGoal = String(config.dailyWaterMl);
      this.sportDays = String(config.weeklySportDays);
      this.sleepHours = String(config.sleepHours);
    } catch (err) {
      console.error('GoalPage load error:', JSON.stringify(err));
    }
  }

  async saveGoals(): Promise<void> {
    const current = await GlobalData.prefs.getGoalConfig();
    await GlobalData.prefs.saveGoalConfig({
      dailySteps: parseInt(this.stepsGoal) || 8000,
      dailyWaterMl: parseInt(this.waterGoal) || 2000,
      weeklySportDays: parseInt(this.sportDays) || 3,
      sleepHours: parseFloat(this.sleepHours) || 8,
      weightKg: current.weightKg,
      heightCm: current.heightCm,
      dailyCalorie: current.dailyCalorie, // 保留由体重页计算的热量值，不从本页修改
    });
    router.back();
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt()).onClick(() => { router.back(); })
        Text('目标设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 + this.statusBarHeight, bottom: 12 })

      Scroll() {
        Column() {
          this.goalCard('每日步数目标', '步数', this.stepsGoal, '步', (v: string) => { this.stepsGoal = v; })
          this.goalCard('每日喝水目标', '喝水', this.waterGoal, 'ml', (v: string) => { this.waterGoal = v; })
          this.goalCard('每周运动天数', '运动', this.sportDays, '天/周', (v: string) => { this.sportDays = v; })
          this.goalCard('每日睡眠目标', '睡眠', this.sleepHours, '小时', (v: string) => { this.sleepHours = v; })

          Button() {
            Text('保存目标').fontSize(18).fontColor(this.txt())
          }
          .width('90%').height(52).backgroundColor('#FF6B35').borderRadius(26)
          .margin({ top: 20, bottom: 40 })
          .onClick(() => { this.saveGoals(); })
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder goalCard(title: string, label: string, value: string, unit: string, onChange: (v: string) => void) {
    Column() {
      Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
        .width('100%').padding({ left: 12, top: 12 })
      Row() {
        Text(label).fontSize(15).fontColor(this.txt()).width(90)
        TextInput({ placeholder: value, text: value })
          .type(InputType.Number).width(140).height(44)
          .backgroundColor(ThemeColors.inputBg(this.theme))
          .fontColor(this.txt())
          .placeholderColor(ThemeColors.textSecondary(this.theme))
          .onChange((v: string) => { onChange(v); })
        Text(unit).fontSize(14).fontColor(this.sub()).margin({ left: 8 })
        Blank()
      }
      .width('100%').padding(12)
    }
    .width('100%').padding(8).backgroundColor(this.card()).borderRadius(14)
    .margin({ left: 16, right: 16, bottom: 12 })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn })
      .slide(SlideEffect.Left)
  }
}