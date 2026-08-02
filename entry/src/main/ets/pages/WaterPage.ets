import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { DbRow, ThemeColors } from '../common/Constants';

@Entry
@Component
struct WaterPage {
  @State currentMl: number = 0;
  @State goalMl: number = 2000;
  @State cupMl: number = 250;
  @State showGoalInput: boolean = false;
  @State goalInput: string = '';
  @State timeline: DbRow[] = [];
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const config = await GlobalData.prefs.getGoalConfig();
      this.goalMl = config.dailyWaterMl;
      this.timeline = await GlobalData.db.getWaterTimeline(today);
      let total: number = 0;
      for (const r of this.timeline) {
        total += Number(r.ml);
      }
      this.currentMl = total;
      await GlobalData.db.updateDailySummaryField(today, 'water_ml', total);
    } catch (err) {
      console.error('WaterPage loadData error:', JSON.stringify(err));
    }
  }

  async deleteTimelineItem(id: number): Promise<void> {
    await GlobalData.db.deleteWaterTimelineItem(id);
    const today = await GlobalData.getTodayDate();
    this.timeline = await GlobalData.db.getWaterTimeline(today);
    await this.syncWaterSummary(today);
  }

  async addCup(): Promise<void> {
    const today = await GlobalData.getTodayDate();
    const now = GlobalData.getTimeStr();
    await GlobalData.db.addWaterCup(today, this.cupMl);
    await GlobalData.db.addWaterTimeline(today, now, this.cupMl);
    this.currentMl += this.cupMl;
    this.timeline = await GlobalData.db.getWaterTimeline(today);
    await this.syncWaterSummary(today);
  }

  async syncWaterSummary(date: string): Promise<void> {
    try {
      const rows = await GlobalData.db.getWaterTimeline(date);
      let total: number = 0;
      for (const r of rows) {
        total += Number(r.ml);
      }
      this.currentMl = total;
      await GlobalData.db.updateDailySummaryField(date, 'water_ml', total);
    } catch (err) {
      console.error('WaterPage syncWaterSummary error:', JSON.stringify(err));
    }
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

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).onClick(() => { router.back(); })
        Text('喝水提醒').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
        Blank()
        Text('设置目标').fontSize(14).fontColor('#03A9F4')
          .onClick(() => { this.showGoalInput = !this.showGoalInput; })
      }
      .width('100%').padding(16)

      Scroll() {
        Column() {
          if (this.showGoalInput) {
            Row() {
              TextInput({ placeholder: '每日目标 (ml)', text: this.goalInput })
                .width(180).type(InputType.Number)
                .onChange((v: string) => { this.goalInput = v; })
              Button('保存').backgroundColor('#03A9F4').borderRadius(20).margin({ left: 8 })
                .onClick(() => { this.updateGoal(); })
            }
            .padding(16)
          }

          Column() {
            Text('💧').fontSize(60)
            Text(String(this.currentMl) + ' / ' + String(this.goalMl) + ' ml')
              .fontSize(24).fontWeight(FontWeight.Bold).margin({ top: 8 })
            Stack() {
              Row().width('100%').height(14).backgroundColor(ThemeColors.divider(this.theme)).borderRadius(7)
              Row()
                .width(Math.min(100, (this.currentMl / this.goalMl) * 100) + '%')
                .height(14).backgroundColor('#03A9F4').borderRadius(7)
            }
            .width('80%').margin({ top: 16 })
            Text('已喝 ' + String(Math.floor(this.currentMl / this.cupMl)) + ' 杯')
              .fontSize(14).fontColor(this.sub()).margin({ top: 8 })
          }
          .width('100%').padding(32)

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach([100, 150, 200, 250, 300, 500], (ml: number) => {
              Button(String(ml) + 'ml')
                .width(90).height(46)
                .backgroundColor(this.cupMl === ml ? '#03A9F4' : this.card())
                .borderRadius(23)
                .fontColor(this.cupMl === ml ? '#FFFFFF' : this.sub())
                .margin(6)
                .onClick(() => { this.cupMl = ml; })
            })
          }
          .margin({ top: 16 })

          Button() {
            Text('+ ' + String(this.cupMl) + 'ml 记录喝水').fontSize(18).fontColor(this.txt())
          }
          .width(240).height(54).backgroundColor('#03A9F4').borderRadius(27)
          .margin({ top: 24 })
          .onClick(() => { this.addCup(); })

          if (this.timeline.length > 0) {
            Text('喝水时间线').fontSize(16).fontWeight(FontWeight.Bold)
              .width('100%').padding({ left: 16, top: 24, bottom: 8 })
            Column() {
              ForEach(this.timeline, (item: DbRow) => {
                Row() {
                  Text(String(item.time)).fontSize(14).fontColor(this.sub()).width(60)
                  Row()
                    .width(Math.min(200, Number(item.ml) / 5) + 30)
                    .height(24).backgroundColor('#03A9F4').borderRadius(12)
                    .margin({ left: 8 })
                  Text(String(item.ml) + 'ml').fontSize(13).fontColor(this.sub()).margin({ left: 8 })
                  Blank()
                  Text('🗑').fontSize(14).margin({ left: 4 })
                    .onClick(() => { this.deleteTimelineItem(Number(item.id)); })
                }
                .width('100%').padding({ left: 16, right: 16, bottom: 6 })
              })
            }
          }

          Text('💧 每天喝水，健康又美丽')
            .fontSize(14).fontColor(this.sub())
            .margin({ top: 16, bottom: 24 })
        }
        .width('100%')
      }
    }
    .width('100%').height('100%')    .backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
