import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, GoalConfig, ThemeColors } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';

@Entry
@Component
struct WeightPage {
  @State weightInput: string = '';
  @State heightInput: string = '';
  @State currentWeight: string = '--';
  @State currentHeight: string = '--';
  @State bmi: string = '--';
  @State bmiStatus: string = '';
  @State gender: string = '男';
  @State heightCm: number = 170;
  @State historyDates: string[] = [];
  @State historyWeights: number[] = [];
  @State historyHeights: number[] = [];
  @State historyBmis: number[] = [];
  @State records: DbRow[] = [];
  @State heightRecords: DbRow[] = [];
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

      // 获取最新的体重记录
      const latestWeight = await GlobalData.db.getLatestWeight();
      if (latestWeight) {
        this.currentWeight = Number(latestWeight.weight_kg).toFixed(1);
      }

      // 获取最新的身高记录
      const latestHeight = await GlobalData.db.getLatestHeight();
      if (latestHeight) {
        this.currentHeight = Number(latestHeight.height_cm).toFixed(0);
        this.heightCm = Number(latestHeight.height_cm);
      } else {
        this.currentHeight = String(this.heightCm);
      }

      // 计算BMI
      if (latestWeight && this.heightCm > 0) {
        const bmiVal = this.calcBMI(Number(latestWeight.weight_kg));
        this.bmi = bmiVal.toFixed(1);
        this.bmiStatus = this.getBmiStatus(Number(bmiVal));
      }

      // 获取最近30天记录
      const end = new Date();
      const start = new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);

      // 获取体重记录
      const weightRows = await GlobalData.db.getWeightRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.records = weightRows;

      // 获取身高记录
      const heightRows = await GlobalData.db.getHeightRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.heightRecords = heightRows;

      // 合并日期
      const allDates = new Set<string>();
      weightRows.forEach((item: DbRow) => allDates.add(String(item.date)));
      heightRows.forEach((item: DbRow) => allDates.add(String(item.date)));

      const sortedDates = Array.from(allDates).sort();
      this.historyDates = sortedDates.map((date: string) => date.slice(5));

      // 构建体重历史数据（按 timestamp 排序，保留最新的记录）
      const sortedWeightRows = weightRows.slice().sort((a: DbRow, b: DbRow) =>
        Number(a.timestamp) - Number(b.timestamp)
      );
      const weightMap = new Map<string, number>();
      sortedWeightRows.forEach((item: DbRow) => {
        weightMap.set(String(item.date), Number(item.weight_kg));
      });

      // 构建身高历史数据（按 timestamp 排序，保留最新的记录）
      const sortedHeightRows = heightRows.slice().sort((a: DbRow, b: DbRow) =>
        Number(a.timestamp) - Number(b.timestamp)
      );
      const heightMap = new Map<string, number>();
      sortedHeightRows.forEach((item: DbRow) => {
        heightMap.set(String(item.date), Number(item.height_cm));
      });

      // 填充历史数据
      this.historyWeights = [];
      this.historyHeights = [];
      this.historyBmis = [];

      let lastWeight: number | null = null;
      let lastHeight: number | null = null;

      sortedDates.forEach((date: string) => {
        const weight = weightMap.get(date) || lastWeight;
        const height = heightMap.get(date) || lastHeight;

        if (weight) lastWeight = weight;
        if (height) lastHeight = height;

        this.historyWeights.push(weight || 0);
        this.historyHeights.push(height || 0);

        if (weight && height && height > 0) {
          const bmiVal = weight / Math.pow(height / 100, 2);
          this.historyBmis.push(Number(bmiVal.toFixed(1)));
        } else {
          this.historyBmis.push(0);
        }
      });
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

  async saveRecord(): Promise<void> {
    const today = await GlobalData.getTodayDate();

    // 保存体重
    const weightVal = parseFloat(this.weightInput);
    if (!isNaN(weightVal) && weightVal > 0) {
      // 先删除今天的旧体重记录
      const existingWeight = await GlobalData.db.getWeightRecords(today, today);
      for (const record of existingWeight) {
        await GlobalData.db.deleteWeightRecord(Number(record.id));
      }
      // 添加新记录
      await GlobalData.db.addWeightRecord(today, weightVal);
      this.weightInput = '';
    }

    // 保存身高
    const heightVal = parseFloat(this.heightInput);
    if (!isNaN(heightVal) && heightVal > 0) {
      // 先删除今天的旧身高记录
      const existingHeight = await GlobalData.db.getHeightRecords(today, today);
      for (const record of existingHeight) {
        await GlobalData.db.deleteHeightRecord(Number(record.id));
      }
      // 添加新记录
      await GlobalData.db.addHeightRecord(today, heightVal);
      // 同时更新配置中的身高
      const cfg = await GlobalData.prefs.getGoalConfig();
      cfg.heightCm = heightVal;
      await GlobalData.prefs.saveGoalConfig(cfg);
      this.heightInput = '';
    }

    await this.loadData();
  }

  async deleteWeight(id: number): Promise<void> {
    await GlobalData.db.deleteWeightRecord(id);
    await this.loadData();
  }

  async deleteHeight(id: number): Promise<void> {
    await GlobalData.db.deleteHeightRecord(id);
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
          // 当前数据展示
          Row() {
            Column() {
              Text(this.currentHeight)
                .fontSize(36)
                .fontWeight(FontWeight.Bold)
              Text('身高')
                .fontSize(14)
                .fontColor(this.sub())
                .margin({ top: 4 })
            }
            .layoutWeight(1)

            Divider()
              .vertical(true)
              .height(60)
              .margin({ left: 10, right: 10 })

            Column() {
              Text(this.currentWeight)
                .fontSize(36)
                .fontWeight(FontWeight.Bold)
              Text('体重')
                .fontSize(14)
                .fontColor(this.sub())
                .margin({ top: 4 })
            }
            .layoutWeight(1)

            Divider()
              .vertical(true)
              .height(60)
              .margin({ left: 10, right: 10 })

            Column() {
              Text(this.bmi)
                .fontSize(36)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getBmiColor())
              Text('BMI')
                .fontSize(14)
                .fontColor(this.sub())
                .margin({ top: 4 })
              if (this.bmiStatus.length > 0) {
                Text(this.bmiStatus)
                  .fontSize(12)
                  .fontColor(this.getBmiColor())
                  .margin({ top: 2 })
              }
            }
            .layoutWeight(1)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(20)
          .backgroundColor(this.card())
          .borderRadius(16)
          .margin({ left: 16, right: 16 })

          // 输入区域
          Column() {
            Text('记录数据')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .margin({ bottom: 12 })

            Row() {
              TextInput({ placeholder: '身高', text: this.heightInput })
                .layoutWeight(1)
                .type(InputType.Number)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((value: string) => { this.heightInput = value; })

              TextInput({ placeholder: '体重', text: this.weightInput })
                .layoutWeight(1)
                .type(InputType.Number)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((value: string) => { this.weightInput = value; })
                .margin({ left: 12 })

              Button('提交')
                .backgroundColor(Constants.COLOR_WEIGHT)
                .fontColor('#fff')
                .borderRadius(20)
                .margin({ left: 12 })
                .onClick(() => { this.saveRecord(); })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.card())
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 8 })

          // 趋势图
          if (this.historyHeights.length > 1) {
            Column() {
              Text('身高趋势 (30天)')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .padding({ left: 16, bottom: 8 })
              TrendChart({
                dataPoints: this.historyHeights,
                lineColor: '#2196F3',
                fillColor: '#2196F322',
                labels: this.historyDates
              })
                .height(150)
                .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .margin({ top: 16 })
          }

          if (this.historyWeights.length > 1) {
            Column() {
              Text('体重趋势 (30天)')
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
                .height(150)
                .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .margin({ top: 16 })
          }

          if (this.historyBmis.length > 1) {
            Column() {
              Text('BMI趋势 (30天)')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .padding({ left: 16, bottom: 8 })
              TrendChart({
                dataPoints: this.historyBmis,
                lineColor: '#FF9800',
                fillColor: '#FF980022',
                labels: this.historyDates
              })
                .height(150)
                .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .margin({ top: 16 })
          }

          // 历史记录
          Text('历史记录')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .padding({ left: 16, top: 20, bottom: 8 })

          List() {
            ForEach(this.historyDates, (date: string, index: number) => {
              ListItem() {
                Row() {
                  Text(date)
                    .fontSize(14)
                    .layoutWeight(1)

                  Text(this.historyHeights[index] > 0 ? this.historyHeights[index].toFixed(0) + ' cm' : '--')
                    .fontSize(14)
                    .width(70)
                    .textAlign(TextAlign.Center)

                  Text(this.historyWeights[index] > 0 ? this.historyWeights[index].toFixed(1) + ' kg' : '--')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .width(70)
                    .textAlign(TextAlign.Center)

                  Text(this.historyBmis[index] > 0 ? this.historyBmis[index].toFixed(1) : '--')
                    .fontSize(14)
                    .fontColor('#4CAF50')
                    .width(50)
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
                .padding(14)
                .backgroundColor(this.card())
                .borderRadius(10)
                .margin({ bottom: 8 })
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
