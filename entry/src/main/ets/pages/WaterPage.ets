import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants } from '../common/Constants';

@Entry
@Component
struct WaterPage {
  @State currentMl: number = 0;
  @State goalMl: number = 2000;
  @State cupMl: number = 250;
  @State showGoalInput: boolean = false;
  @State goalInput: string = '';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const config = await GlobalData.prefs.getGoalConfig();
      this.goalMl = config.dailyWaterMl;

      const summary = await GlobalData.db.getDailySummary(today);
      if (summary) {
        this.currentMl = Number(summary.water_ml) || 0;
      }
    } catch (err) {
      console.error('WaterPage loadData error:', JSON.stringify(err));
    }
  }

  async addCup(): Promise<void> {
    const today = await GlobalData.getTodayDate();
    await GlobalData.db.addWaterCup(today, this.cupMl);
    this.currentMl += this.cupMl;
  }

  async updateGoal(): Promise<void> {
    const val = parseInt(this.goalInput);
    if (isNaN(val) || val <= 0) return;
    const config = await GlobalData.prefs.getGoalConfig();
    config.dailyWaterMl = val;
    await GlobalData.prefs.saveGoalConfig(config);
    this.goalMl = val;
    this.showGoalInput = false;
    this.goalInput = '';
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => { router.back(); })
        Text('喝水提醒')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
        Blank()
        Text('设置目标')
          .fontSize(14)
          .fontColor('#03A9F4')
          .onClick(() => { this.showGoalInput = !this.showGoalInput; })
      }
      .width('100%')
      .padding(16)

      Scroll() {
        Column() {
          // 目标设置
          if (this.showGoalInput) {
            Row() {
              TextInput({ placeholder: '每日目标 (ml)', text: this.goalInput })
                .width(180)
                .type(InputType.Number)
                .onChange((v: string) => { this.goalInput = v; })
              Button('保存')
                .backgroundColor('#03A9F4')
                .borderRadius(20)
                .margin({ left: 8 })
                .onClick(() => { this.updateGoal(); })
            }
            .padding(16)
          }

          // 喝水进度
          Column() {
            // 水滴图标
            Text('💧')
              .fontSize(60)

            Text(String(this.currentMl) + ' / ' + String(this.goalMl) + ' ml')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 8 })

            // 进度条
            Stack() {
              Row()
                .width('100%')
                .height(14)
                .backgroundColor('#333333')
                .borderRadius(7)
              Row()
                .width(Math.min(100, (this.currentMl / this.goalMl) * 100) + '%')
                .height(14)
                .backgroundColor('#03A9F4')
                .borderRadius(7)
            }
            .width('80%')
            .margin({ top: 16 })

            Text('已喝 ' + String(Math.floor(this.currentMl / this.cupMl)) + ' 杯')
              .fontSize(14)
              .fontColor('#888888')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(32)

          // 快速加水按钮
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach([100, 150, 200, 250, 300, 500], (ml: number) => {
              Button(String(ml) + 'ml')
                .width(90)
                .height(46)
                .backgroundColor(this.cupMl === ml ? '#03A9F4' : '#1A1A2E')
                .borderRadius(23)
                .fontColor(this.cupMl === ml ? '#FFFFFF' : '#AAAAAA')
                .margin(6)
                .onClick(() => { this.cupMl = ml; })
            })
          }
          .margin({ top: 16 })

          // 添加按钮
          Button() {
            Text('+ ' + String(this.cupMl) + 'ml 记录喝水')
              .fontSize(18)
              .fontColor('#FFFFFF')
          }
          .width(240)
          .height(54)
          .backgroundColor('#03A9F4')
          .borderRadius(27)
          .margin({ top: 24 })
          .onClick(() => { this.addCup(); })

          // 历史概况
          Text('近七天喝水情况')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .padding({ left: 16, top: 32, bottom: 8 })

          // 简单提示
          Text('💧 每天喝水，健康又美丽')
            .fontSize(14)
            .fontColor('#888888')
            .margin({ top: 12, bottom: 24 })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D1A')
  }
}
