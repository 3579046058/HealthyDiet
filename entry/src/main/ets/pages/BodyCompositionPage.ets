import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, ThemeColors } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';

interface MetricDef {
  label: string;
  value: string;
  unit: string;
  color: string;
  field: string;
}

@Entry
@Component
struct BodyCompositionPage {
  @State showInput: boolean = false;
  @State bodyFat: string = '--';
  @State muscleMass: string = '--';
  @State bodyWater: string = '--';
  @State boneMass: string = '--';
  @State visceralFat: string = '--';
  @State latest: DbRow | null = null;
  @State records: DbRow[] = [];
  @State historyDates: string[] = [];
  @State historyBodyFat: number[] = [];
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const latestRow = await GlobalData.db.getLatestBodyComposition();
      if (latestRow) {
        this.latest = latestRow;
        this.bodyFat = Number(latestRow.body_fat).toFixed(1);
        this.muscleMass = Number(latestRow.muscle_mass).toFixed(1);
        this.bodyWater = Number(latestRow.body_water).toFixed(1);
        this.boneMass = Number(latestRow.bone_mass).toFixed(1);
        this.visceralFat = Number(latestRow.visceral_fat).toFixed(1);
      }

      const end = new Date();
      const start = new Date(end.getTime() - 90 * 24 * 60 * 60 * 1000);
      const rows = await GlobalData.db.getBodyCompositionRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.records = rows;
      this.historyDates = rows.map((item: DbRow): string => String(item.date).slice(5));
      this.historyBodyFat = rows.map((item: DbRow): number => Number(item.body_fat));
    } catch (err) {
      console.error('BodyCompositionPage loadData error:', JSON.stringify(err));
    }
  }

  async saveRecord(): Promise<void> {
    const bf = parseFloat(this.bodyFat);
    const mm = parseFloat(this.muscleMass);
    const bw = parseFloat(this.bodyWater);
    const bm = parseFloat(this.boneMass);
    const vf = parseFloat(this.visceralFat);
    if (isNaN(bf) || isNaN(mm) || isNaN(bw) || isNaN(bm) || isNaN(vf)) {
      return;
    }
    const today = await GlobalData.getTodayDate();
    const values: DbRow = {
      date: today,
      body_fat: bf,
      muscle_mass: mm,
      body_water: bw,
      bone_mass: bm,
      visceral_fat: vf
    };
    await GlobalData.db.addBodyCompositionRecord(values);
    this.showInput = false;
    await this.loadData();
  }

  async deleteRecord(id: number): Promise<void> {
    await GlobalData.db.deleteBodyCompositionRecord(id);
    await this.loadData();
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => { router.back(); })
        Text('🏋️ 体成分')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
        Blank()
        Button('记录')
          .backgroundColor(Constants.COLOR_BODY)
          .borderRadius(20)
          .fontSize(14)
          .onClick(() => { this.showInput = !this.showInput; })
      }
      .width('100%')
      .padding(16)

      Scroll() {
        Column() {
          if (this.latest !== null) {
            Text('当前测量')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .padding({ left: 16, bottom: 8 })

            Column() {
              ForEach(this.getMetrics(), (metric: MetricDef) => {
                Row() {
                  Text(metric.label)
                    .fontSize(14)
                    .fontColor(this.sub())
                  Blank()
                  Text(metric.value)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(metric.color)
                  Text(' ' + metric.unit)
                    .fontSize(13)
                    .fontColor(this.sub())
                }
                .width('100%')
                .padding({ top: 6, bottom: 6 })

                Row() {
                      Row()
                        .height(6)
                        .width(this.getBarWidth(metric.field) + '%')
                        .borderRadius(3)
                        .backgroundColor(metric.color)
                    }
                    .width('100%')
                    .height(6)
                    .backgroundColor('#2A2A3E')
                    .borderRadius(3)
              })
            }
            .padding(16)
            .backgroundColor(this.card())
            .borderRadius(12)
            .margin({ left: 16, right: 16 })
          }

          if (this.showInput) {
            Column() {
              Text('添加体成分记录')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 12 })

              this.inputField('体脂率 %', this.bodyFat, (v: string) => { this.bodyFat = v; })
              this.inputField('肌肉量 kg', this.muscleMass, (v: string) => { this.muscleMass = v; })
              this.inputField('水分率 %', this.bodyWater, (v: string) => { this.bodyWater = v; })
              this.inputField('骨量 kg', this.boneMass, (v: string) => { this.boneMass = v; })
              this.inputField('内脏脂肪', this.visceralFat, (v: string) => { this.visceralFat = v; })

              Button('保存')
                .backgroundColor(Constants.COLOR_BODY)
                .borderRadius(20)
                .width('100%')
                .margin({ top: 12 })
                .onClick(() => { this.saveRecord(); })
            }
            .padding(16)
            .backgroundColor(this.card())
            .borderRadius(12)
            .margin({ left: 16, right: 16, top: 16 })
          }

          if (this.historyBodyFat.length > 1) {
              Text('体脂趋势（90天）')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .padding({ left: 16, top: 20, bottom: 8 })
              TrendChart({
                dataPoints: this.historyBodyFat,
                lineColor: '#FF9800',
                fillColor: '#FF980022',
                labels: this.historyDates
              })
              .height(180)
              .padding({ left: 16, right: 16 })
          }

          Text('历史记录')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .padding({ left: 16, top: 20, bottom: 8 })

          if (this.records.length === 0) {
            Text('暂无体成分数据')
              .fontSize(14)
              .fontColor(this.sub())
              .padding(20)
          }

          List() {
            ForEach(this.records, (record: DbRow) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(String(record.date))
                      .fontSize(13)
                      .fontColor(this.sub())
                    Text('体脂 ' + Number(record.body_fat).toFixed(1) + '%  |  肌肉 ' + Number(record.muscle_mass).toFixed(1) + 'kg')
                      .fontSize(12)
                      .fontColor(this.sub())
                      .margin({ top: 4 })
                  }
                  Blank()
                  Text('水分 ' + Number(record.body_water).toFixed(1) + '%')
                    .fontSize(13)
                    .fontColor('#2196F3')
                  Text('🗑').fontSize(16).margin({ left: 10 })
                    .onClick(() => { this.deleteRecord(Number(record.id)); })
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

  getMetrics(): MetricDef[] {
    return [
      { label: '体脂率', value: this.bodyFat, unit: '%', color: '#FF9800', field: 'body_fat' },
      { label: '肌肉量', value: this.muscleMass, unit: 'kg', color: '#4CAF50', field: 'muscle_mass' },
      { label: '水分率', value: this.bodyWater, unit: '%', color: '#2196F3', field: 'body_water' },
      { label: '骨量', value: this.boneMass, unit: 'kg', color: '#FFC107', field: 'bone_mass' },
      { label: '内脏脂肪', value: this.visceralFat, unit: '级', color: '#F44336', field: 'visceral_fat' },
    ];
  }

  getBarWidth(field: string): number {
    const row = this.latest;
    if (row === null) return 0;
    const val = Number(row[field]);
    if (field === 'body_fat') return Math.min(val / 50 * 100, 100);
    if (field === 'muscle_mass') return Math.min(val / 60 * 100, 100);
    if (field === 'body_water') return Math.min(val / 70 * 100, 100);
    if (field === 'bone_mass') return Math.min(val / 5 * 100, 100);
    if (field === 'visceral_fat') return Math.min(val / 20 * 100, 100);
    return 0;
  }

  @Builder
  inputField(label: string, value: string, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.sub())
        .width(80)
      TextInput({ placeholder: '请输入', text: value })
        .type(InputType.Number)
        .backgroundColor(ThemeColors.inputBg(this.theme))
        .fontColor(this.txt())
        .placeholderColor(ThemeColors.textSecondary(this.theme))
        .layoutWeight(1)
        .onChange((v: string) => { onChange(v); })
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
