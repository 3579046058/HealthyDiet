import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';

@Entry
@Component
struct WeightPage {
  @State weightInput: string = '';
  @State currentWeight: string = '--';
  @State bmi: string = '--';
  @State historyDates: string[] = [];
  @State historyWeights: number[] = [];
  @State records: DbRow[] = [];

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const latest = await GlobalData.db.getLatestWeight();
      if (latest) {
        this.currentWeight = Number(latest.weight_kg).toFixed(1);
        this.bmi = this.calcBMI(Number(latest.weight_kg));
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

  calcBMI(weightKg: number): string {
    const h = 170; // 默认身高170cm，后续可配置
    const bmiVal = weightKg / ((h / 100) * (h / 100));
    return bmiVal.toFixed(1);
  }

  async saveWeight(): Promise<void> {
    const val = parseFloat(this.weightInput);
    if (isNaN(val) || val <= 0) return;
    const today = await GlobalData.getTodayDate();
    await GlobalData.db.addWeightRecord(today, val);
    this.weightInput = '';
    await this.loadData();
  }

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
                .fontColor('#888888')
            }
            Divider()
              .vertical(true)
              .height(60)
              .margin({ left: 30, right: 30 })
            Column() {
              Text(this.bmi)
                .fontSize(48)
                .fontWeight(FontWeight.Bold)
                .fontColor('#4CAF50')
              Text('BMI')
                .fontSize(16)
                .fontColor('#888888')
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
                }
                .width('100%')
                .padding(14)
                .backgroundColor('#1A1A2E')
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
    .backgroundColor('#0D0D1A')
  }
}
