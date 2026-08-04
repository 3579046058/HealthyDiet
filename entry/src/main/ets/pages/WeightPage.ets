import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, GoalConfig, ThemeColors } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';

@Entry
@Component
struct WeightPage {
  @State weightInput: string = '';
  @State currentWeight: string = '--';
  @State bmi: string = '--';
  @State bmiStatus: string = '';
  @State gender: string = '男';
  @State heightCm: number = 170;
  @State historyDates: string[] = [];
  @State historyWeights: number[] = [];
  @State records: DbRow[] = [];
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.loadData();
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
      this.loadData();
    }, 15000);
  }

  stopAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  async loadData(): Promise<void> {
    try {
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      this.heightCm = goalConfig.heightCm;
      const g = await GlobalData.prefs.getGender();
      if (g.length > 0) {
        this.gender = g;
      }
      const latest = await GlobalData.db.getLatestWeight();
      if (latest) {
        this.currentWeight = Number(latest.weight_kg).toFixed(1);
        const bmiVal = this.calcBMI(Number(latest.weight_kg));
        this.bmi = bmiVal.toFixed(1);
        this.bmiStatus = this.getBmiStatus(Number(bmiVal));
      }

      // 获取最近30天记录
      const end = new Date();
      const start = new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
      const rows = await GlobalData.db.getWeightRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.records = rows;
      this.historyDates = rows.map((item: DbRow) => String(item.date).slice(5));
      this.historyWeights = rows.map((item: DbRow) => Number(item.weight_kg));
    } catch (err) {
      console.error('WeightPage loadData error:', JSON.stringify(err));
    }
  }

  calcBMI(weightKg: number): number {
    const h = this.heightCm;
    if (h <= 0) {
      return 0;
    }
    return weightKg / ((h / 100) * (h / 100));
  }

  getBmiStatus(bmiVal: number): string {
    if (bmiVal <= 0) {
      return '';
    }
    let low = 18.5;
    let high = 24;
    if (this.gender === '男') {
      low = 18.5;
      high = 24;
    } else if (this.gender === '女') {
      low = 18;
      high = 23;
    }
    if (bmiVal < low) {
      return '偏瘦';
    }
    if (bmiVal <= high) {
      return '正常';
    }
    if (bmiVal < 28) {
      return '偏胖';
    }
    return '肥胖';
  }

  getBmiColor(): string {
    if (this.bmiStatus === '正常') {
      return '#4CAF50';
    }
    if (this.bmiStatus === '偏瘦' || this.bmiStatus === '偏胖') {
      return '#FF9800';
    }
    return '#F44336';
  }

  async saveWeight(): Promise<void> {
    const val = parseFloat(this.weightInput);
    if (isNaN(val) || val <= 0) return;
    const today = await GlobalData.getTodayDate();
    await GlobalData.db.addWeightRecord(today, val);
    this.weightInput = '';
    await this.loadData();
  }

  async deleteWeight(id: number): Promise<void> {
    await GlobalData.db.deleteWeightRecord(id);
    await this.loadData();
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => { router.back(); })
        Text('体重记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
        Blank()
      }
      .width('100%')
      .padding(16)

      Scroll() {
        Column() {
          // 当前体重
          Row() {
            Column() {
              Text(this.currentWeight)
                .fontSize(48)
                .fontWeight(FontWeight.Bold)
              Text('kg')
                .fontSize(16)
                .fontColor(this.sub())
            }
            Divider()
              .vertical(true)
              .height(60)
              .margin({ left: 30, right: 30 })
            Column() {
              Text(this.bmi)
                .fontSize(48)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getBmiColor())
              Text('BMI')
                .fontSize(16)
                .fontColor(this.sub())
              if (this.bmiStatus.length > 0) {
                Text(this.bmiStatus)
                  .fontSize(13)
                  .fontColor(this.getBmiColor())
                  .margin({ top: 4 })
              }
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(20)

          // 输入区
          Row() {
            TextInput({ placeholder: '输入体重 (kg)', text: this.weightInput })
              .width(180)
              .type(InputType.Number)
              .backgroundColor(ThemeColors.inputBg(this.theme))
              .fontColor(this.txt())
              .placeholderColor(ThemeColors.textSecondary(this.theme))
              .onChange((v: string) => { this.weightInput = v; })
            Button('记录')
              .backgroundColor('#4CAF50')
              .borderRadius(20)
              .margin({ left: 12 })
              .onClick(() => { this.saveWeight(); })
          }
          .padding(16)

          // 趋势图
          if (this.historyWeights.length > 1) {
            Text('30天趋势')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .padding({ left: 16, bottom: 8 })
            TrendChart({
              dataPoints: this.historyWeights,
              lineColor: Constants.COLOR_WEIGHT,
              fillColor: '#4CAF5022',
              labels: this.historyDates
            })
            .height(180)
            .padding({ left: 16, right: 16 })
          }

          // 历史记录
          Text('历史记录')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .padding({ left: 16, top: 20, bottom: 8 })

          List() {
            ForEach(this.records, (record: DbRow) => {
              ListItem() {
                Row() {
                  Text(String(record.date))
                    .fontSize(14)
                  Blank()
                  Text(Number(record.weight_kg).toFixed(1) + ' kg')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                  Text('🗑').fontSize(16).margin({ left: 12 })
                    .onClick(() => { this.deleteWeight(Number(record.id)); })
                }
                .width('100%')
                .padding(14)
                .backgroundColor(this.card())
                .borderRadius(10)
              }
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .height(300)
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
