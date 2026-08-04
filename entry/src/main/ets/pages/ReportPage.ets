import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, ThemeColors } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';
import { BarChart } from '../components/BarChart';

@Entry
@Component
struct ReportPage {
  @State reportType: string = 'week';
  @State weekSteps: number[] = [];
  @State weekLabels: string[] = [];
  @State weekAvgSteps: number = 0;
  @State weekTotalHours: number = 0;
  @State weekAvgWater: number = 0;
  @State weekAvgSleep: number = 0;
  @State weekTotalCalories: number = 0;
  @State monthSteps: number[] = [];
  @State monthLabels: string[] = [];
  @State monthAvgSteps: number = 0;
  @State summaryText: string = '';
  @State insightText: string = '';
  @State weekWaterData: number[] = [];
  @State weekSleepData: number[] = [];
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  aboutToAppear(): void {
    this.loadWeekData();
    this.startAutoRefresh();
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
  }

  private refreshTimer: number = -1;

  startAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
    }
    this.refreshTimer = setInterval(() => {
      this.loadWeekData();
    }, 15000);
  }

  stopAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  async loadWeekData(): Promise<void> {
    try {
      const end = new Date();
      const start = new Date(end.getTime() - 6 * 24 * 60 * 60 * 1000);
      const startStr = GlobalData.formatDate(start);
      const endStr = GlobalData.formatDate(end);
      const rows = await GlobalData.db.getDailySummaries(startStr, endStr);

      const days: DbRow[] = [];
      for (let i = 6; i >= 0; i--) {
        const d = new Date(end.getTime() - i * 24 * 60 * 60 * 1000);
        const ds = GlobalData.formatDate(d);
        const row = rows.find((r: DbRow) => String(r.date) === ds);
        days.push(row || {
          date: ds, steps: 0, water_ml: 0, sleep_hours: 0,
          calories_burned: 0, exercise_minutes: 0
        });
      }

      this.weekLabels = days.map((item: DbRow) => String(item.date).slice(5));
      this.weekSteps = days.map((item: DbRow) => Number(item.steps) || 0);
      this.weekWaterData = days.map((item: DbRow) => Number(item.water_ml) || 0);
      this.weekSleepData = days.map((item: DbRow) => Number(item.sleep_hours) || 0);
      this.weekAvgSteps = Math.round(this.weekSteps.reduce((a: number, b: number) => a + b, 0) / 7);
      this.weekTotalHours = days.reduce((s: number, d: DbRow) => s + (Number(d.exercise_minutes) || 0), 0) / 60;
      this.weekAvgWater = Math.round(days.reduce((s: number, d: DbRow) => s + (Number(d.water_ml) || 0), 0) / 7);
      this.weekAvgSleep = parseFloat((days.reduce((s: number, d: DbRow) => s + (Number(d.sleep_hours) || 0), 0) / 7).toFixed(1));
      this.weekTotalCalories = days.reduce((s: number, d: DbRow) => s + (Number(d.calories_burned) || 0), 0);

      if (this.weekAvgSteps > 0) {
        this.summaryText = '本周平均每日步数 ' + String(this.weekAvgSteps) + ' 步';
        if (this.weekAvgSteps >= 8000) {
          this.summaryText += '，保持得不错！💪';
        } else {
          this.summaryText += '，继续加油！👉';
        }
      }

      // Generate insight text
      const insights: string[] = [];
      if (this.weekAvgSteps > 0) {
        insights.push('日均步数 ' + String(this.weekAvgSteps) + ' 步');
      }
      if (this.weekAvgWater > 0) {
        insights.push('日均饮水 ' + String(this.weekAvgWater) + 'ml');
      }
      if (this.weekAvgSleep > 0) {
        insights.push('平均睡眠 ' + String(this.weekAvgSleep) + ' 小时');
      }
      if (this.weekTotalHours > 0) {
        insights.push('总运动 ' + String(this.weekTotalHours.toFixed(1)) + ' 小时');
      }
      const bestDay = Math.max(...this.weekSteps);
      const bestIdx = this.weekSteps.indexOf(bestDay);
      if (bestDay > 0) {
        insights.push('最佳日: ' + (bestIdx >= 0 && bestIdx < this.weekLabels.length ? this.weekLabels[bestIdx] : '') + ' (' + String(bestDay) + ' 步)');
      }
      this.insightText = insights.length > 0 ? '📊 ' + insights.join(' · ') : '';

      const monthStart = new Date(end.getFullYear(), end.getMonth(), 1);
      const monthRows = await GlobalData.db.getDailySummaries(
        GlobalData.formatDate(monthStart), endStr
      );
      this.monthLabels = monthRows.map((r: DbRow) => String(new Date(String(r.date)).getDate()));
      this.monthSteps = monthRows.map((item: DbRow) => Number(item.steps) || 0);
      this.monthAvgSteps = this.monthSteps.length > 0
        ? Math.round(this.monthSteps.reduce((a: number, b: number) => a + b, 0) / this.monthSteps.length)
        : 0;
    } catch (err) {
      console.error('ReportPage loadData error:', JSON.stringify(err));
    }
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).onClick(() => { router.back(); })
        Text('数据报告').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Scroll() {
        Column() {
          Row() {
            Button(this.reportType === 'week' ? '📊 周报' : '周报')
              .width(100).height(40)
              .backgroundColor(this.reportType === 'week' ? '#FF6B35' : this.card())
              .borderRadius(20).fontColor(this.txt()).fontSize(14)
              .onClick(() => { this.reportType = 'week'; })
            Button(this.reportType === 'month' ? '📅 月报' : '月报')
              .width(100).height(40)
              .backgroundColor(this.reportType === 'month' ? '#FF6B35' : this.card())
              .borderRadius(20).fontColor(this.txt()).fontSize(14).margin({ left: 12 })
              .onClick(() => { this.reportType = 'month'; })
          }
          .width('100%').justifyContent(FlexAlign.Center).padding(16)

          if (this.reportType === 'week') {
            Text('本周概况').fontSize(18).fontWeight(FontWeight.Bold)
              .width('100%').padding({ left: 16, bottom: 8 })

            Row() {
              Column() {
                Text(String(this.weekAvgSteps)).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF9800')
                Text('日均步数').fontSize(12).fontColor(this.sub())
              }
              .width('45%').padding(16).backgroundColor(this.card()).borderRadius(12)
              Column() {
                Text(String(this.weekAvgWater)).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#03A9F4')
                Text('日均喝水').fontSize(12).fontColor(this.sub())
              }
              .width('45%').padding(16).backgroundColor(this.card()).borderRadius(12)
            }
            .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16, bottom: 12 })

            Row() {
              Column() {
                Text(String(this.weekTotalHours.toFixed(1))).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
                Text('运动(小时)').fontSize(12).fontColor(this.sub())
              }
              .width('45%').padding(16).backgroundColor(this.card()).borderRadius(12)
              Column() {
                Text(String(this.weekTotalCalories)).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#F44336')
                Text('消耗(千卡)').fontSize(12).fontColor(this.sub())
              }
              .width('45%').padding(16).backgroundColor(this.card()).borderRadius(12)
            }
            .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16, bottom: 12 })

            if (this.weekSteps.length > 1) {
              Text('步数趋势').fontSize(16).fontWeight(FontWeight.Bold)
                .width('100%').padding({ left: 16, bottom: 8 })
              TrendChart({
                dataPoints: this.weekSteps,
                lineColor: Constants.COLOR_STEP,
                fillColor: '#FF980022',
                labels: this.weekLabels
              }).height(160).padding({ left: 16, right: 16 })
            }

            if (this.weekWaterData.length > 1) {
              Text('喝水情况').fontSize(16).fontWeight(FontWeight.Bold)
                .width('100%').padding({ left: 16, top: 16, bottom: 8 })
              BarChart({
                dataPoints: this.weekWaterData,
                barColor: Constants.COLOR_WATER,
                labels: this.weekLabels,
                unit: 'ml'
              }).height(140).padding({ left: 16, right: 16 })
            }

            if (this.weekSleepData.length > 1) {
              Text('睡眠时长').fontSize(16).fontWeight(FontWeight.Bold)
                .width('100%').padding({ left: 16, top: 16, bottom: 8 })
              BarChart({
                dataPoints: this.weekSleepData,
                barColor: Constants.COLOR_SLEEP,
                labels: this.weekLabels,
                unit: 'h'
              }).height(140).padding({ left: 16, right: 16 })
            }
          } else {
            Text('本月概况').fontSize(18).fontWeight(FontWeight.Bold)
              .width('100%').padding({ left: 16, bottom: 8 })

            Row() {
              Column() {
                Text(String(this.monthAvgSteps)).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF9800')
                Text('日均步数').fontSize(12).fontColor(this.sub())
              }
              .width('90%').padding(20).backgroundColor(this.card()).borderRadius(12)
            }
            .width('100%').justifyContent(FlexAlign.Center).padding({ left: 16, right: 16, bottom: 12 })

            if (this.monthSteps.length > 1) {
              Text('本月步数趋势').fontSize(16).fontWeight(FontWeight.Bold)
                .width('100%').padding({ left: 16, bottom: 8 })
              TrendChart({
                dataPoints: this.monthSteps,
                lineColor: Constants.COLOR_STEP,
                fillColor: '#FF980022',
                labels: this.monthLabels
              }).height(200).padding({ left: 16, right: 16 })
            }
          }

          if (this.insightText) {
            Text(this.insightText)
              .fontSize(14).fontColor(this.sub())
              .width('100%').padding(16).margin({ top: 4 })
              .backgroundColor(this.card()).borderRadius(12)
              .margin({ left: 16, right: 16 })
          }

          if (this.summaryText) {
            Text(this.summaryText)
              .fontSize(15).fontColor(this.sub())
              .width('100%').padding(16).margin({ top: 8 })
          }

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn })
      .slide(SlideEffect.Left)
  }
}
