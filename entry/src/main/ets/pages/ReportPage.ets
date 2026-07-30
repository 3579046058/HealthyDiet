import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';

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

  aboutToAppear(): void {
    this.loadWeekData();
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
      this.weekAvgSteps = Math.round(this.weekSteps.reduce((a: number, b: number) => a + b, 0) / 7);
      this.weekTotalHours = days.reduce((s: number, d: DbRow) => s + (Number(d.exercise_minutes) || 0), 0) / 60;
      this.weekAvgWater = Math.round(days.reduce((s: number, d: DbRow) => s + (Number(d.water_ml) || 0), 0) / 7);
      this.weekAvgSleep = parseFloat((days.reduce((s: number, d: DbRow) => s + (Number(d.sleep_hours) || 0), 0) / 7).toFixed(1));
      this.weekTotalCalories = days.reduce((s: number, d: DbRow) => s + (Number(d.calories_burned) || 0), 0);

      // 生成总结文本
      if (this.weekAvgSteps > 0) {
        this.summaryText = '本周平均每日步数 ' + String(this.weekAvgSteps) + ' 步';
        if (this.weekAvgSteps >= 8000) {
          this.summaryText += '，保持得不错！💪';
        } else {
          this.summaryText += '，继续加油！👉';
        }
      }

      // 月数据
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

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).onClick(() => { router.back(); })
        Text('数据报告').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding(16)

      Scroll() {
        Column() {
          // 周期切换
          Row() {
            Button(this.reportType === 'week' ? '📊 周报' : '周报')
              .width(100).height(40)
              .backgroundColor(this.reportType === 'week' ? '#FF6B35' : '#1A1A2E')
              .borderRadius(20).fontColor('#FFFFFF').fontSize(14)
              .onClick(() => { this.reportType = 'week'; })
            Button(this.reportType === 'month' ? '📅 月报' : '月报')
              .width(100).height(40)
              .backgroundColor(this.reportType === 'month' ? '#FF6B35' : '#1A1A2E')
              .borderRadius(20).fontColor('#FFFFFF').fontSize(14).margin({ left: 12 })
              .onClick(() => { this.reportType = 'month'; })
          }
          .width('100%').justifyContent(FlexAlign.Center).padding(16)

          if (this.reportType === 'week') {
            // 周报卡片
            Text('本周概况').fontSize(18).fontWeight(FontWeight.Bold)
              .width('100%').padding({ left: 16, bottom: 8 })

            Row() {
              Column() {
                Text(String(this.weekAvgSteps)).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF9800')
                Text('日均步数').fontSize(12).fontColor('#888888')
              }
              .width('45%').padding(16).backgroundColor('#1A1A2E').borderRadius(12)

              Column() {
                Text(String(this.weekAvgWater)).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#03A9F4')
                Text('日均喝水').fontSize(12).fontColor('#888888')
              }
              .width('45%').padding(16).backgroundColor('#1A1A2E').borderRadius(12)
            }
            .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16, bottom: 12 })

            Row() {
              Column() {
                Text(String(this.weekTotalHours.toFixed(1))).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
                Text('运动(小时)').fontSize(12).fontColor('#888888')
              }
              .width('45%').padding(16).backgroundColor('#1A1A2E').borderRadius(12)

              Column() {
                Text(String(this.weekTotalCalories)).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#F44336')
                Text('消耗(千卡)').fontSize(12).fontColor('#888888')
              }
              .width('45%').padding(16).backgroundColor('#1A1A2E').borderRadius(12)
            }
            .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16, bottom: 12 })

            // 步数趋势
            if (this.weekSteps.length > 1) {
              Text('步数趋势').fontSize(16).fontWeight(FontWeight.Bold)
                .width('100%').padding({ left: 16, bottom: 8 })
              TrendChart({
                dataPoints: this.weekSteps,
                lineColor: Constants.COLOR_STEP,
                fillColor: '#FF980022',
                labels: this.weekLabels
              }).height(180).padding({ left: 16, right: 16 })
            }
          } else {
            // 月报内容
            Text('本月概况').fontSize(18).fontWeight(FontWeight.Bold)
              .width('100%').padding({ left: 16, bottom: 8 })

            Row() {
              Column() {
                Text(String(this.monthAvgSteps)).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF9800')
                Text('日均步数').fontSize(12).fontColor('#888888')
              }
              .width('90%').padding(20).backgroundColor('#1A1A2E').borderRadius(12)
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

          Text(this.summaryText)
            .fontSize(15).fontColor('#AAAAAA')
            .width('100%').padding(16).margin({ top: 8 })

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor('#0D0D1A')
  }
}
