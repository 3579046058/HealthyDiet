import { router, promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { DbRow, ThemeColors } from '../common/Constants';

@Entry
@Component
struct WomenHealthPage {
  @State startDate: string = '';
  @State endDate: string = '';
  @State cycleLength: string = '';
  @State periodLength: string = '';
  @State showInput: boolean = false;
  @State records: DbRow[] = [];
  @State predictedNext: string = '';
  @State predictedOvulation: string = '';
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      this.records = await GlobalData.db.getPeriodRecords();
      this.calculatePredictions();
    } catch (err) {
      console.error('WomenHealthPage loadData error:', JSON.stringify(err));
    }
  }

  calculatePredictions(): void {
    if (this.records.length > 0 && this.cycleLength.length > 0) {
      const lastRecord: DbRow = this.records[this.records.length - 1];
      const startDateStr: string = String(lastRecord.start_date);
      const cycleDays: number = parseInt(this.cycleLength);
      if (!isNaN(cycleDays) && cycleDays > 0) {
        const startDateObj: Date = new Date(startDateStr);
        const nextDate: Date = new Date(startDateObj.getTime() + cycleDays * 24 * 60 * 60 * 1000);
        this.predictedNext = this.formatDate(nextDate);
        const ovulationDate: Date = new Date(nextDate.getTime() - 14 * 24 * 60 * 60 * 1000);
        this.predictedOvulation = this.formatDate(ovulationDate);
      }
    }
  }

  formatDate(date: Date): string {
    const year: number = date.getFullYear();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const monthStr: string = month < 10 ? '0' + month : '' + month;
    const dayStr: string = day < 10 ? '0' + day : '' + day;
    return year + '-' + monthStr + '-' + dayStr;
  }

  parseDate(dateStr: string): Date {
    if (dateStr.length === 0) {
      return new Date();
    }
    const parts: string[] = dateStr.split('-');
    const y: number = parseInt(parts[0]) || 2026;
    const m: number = parseInt(parts[1]) || 1;
    const d: number = parseInt(parts[2]) || 1;
    return new Date(y, m - 1, d);
  }

  async saveRecord(): Promise<void> {
    if (this.startDate.length === 0 || this.endDate.length === 0) {
      promptAction.showToast({ message: '请填写开始和结束日期' });
      return;
    }
    try {
      const cycleLen: number = parseInt(this.cycleLength) || 28;
      const periodLen: number = parseInt(this.periodLength) || 5;
      const record: DbRow = {
        start_date: this.startDate,
        end_date: this.endDate,
        cycle_length: cycleLen,
        period_length: periodLen,
      };
      await GlobalData.db.addPeriodRecord(record);
      this.startDate = '';
      this.endDate = '';
      this.cycleLength = '';
      this.periodLength = '';
      this.showInput = false;
      promptAction.showToast({ message: '保存成功' });
      await this.loadData();
    } catch (err) {
      console.error('WomenHealthPage saveRecord error:', JSON.stringify(err));
    }
  }

  async deleteRecord(id: number): Promise<void> {
    await GlobalData.db.deletePeriodRecord(id);
    await this.loadData();
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt())
          .onClick(() => { router.back(); })
        Text('女性健康')
          .fontSize(20).fontColor(this.txt()).fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Scroll() {
        Column() {
          Column() {
            Text('预计下次经期').fontSize(14).fontColor(this.sub())
            Text(this.predictedNext.length > 0 ? this.predictedNext : '--')
              .fontSize(24).fontColor('#E91E63').fontWeight(FontWeight.Bold).margin({ top: 4 })
            Divider().height(1).color('#333333').margin({ top: 12, bottom: 12 })
            Text('排卵窗口').fontSize(14).fontColor(this.sub())
            Text(this.predictedOvulation.length > 0 ? this.predictedOvulation : '--')
              .fontSize(20).fontColor(this.txt()).fontWeight(FontWeight.Medium).margin({ top: 4 })
          }
          .width('100%').padding(16)
          .backgroundColor(this.card()).borderRadius(12)
          .margin({ bottom: 16 })

          if (!this.showInput) {
            Button('添加经期记录')
              .width('100%').height(48)
              .backgroundColor('#E91E63').fontColor(this.txt()).borderRadius(24)
              .onClick(() => { this.showInput = true; })
          } else {
            Column() {
              Text('记录经期').fontSize(16).fontColor(this.txt()).fontWeight(FontWeight.Bold).margin({ bottom: 16 })

              Text('开始日期').fontSize(12).fontColor(this.sub())
              DatePicker({ selected: this.parseDate(this.startDate) })
                .onDateChange((value: Date) => { this.startDate = this.formatDate(value); })
                .margin({ bottom: 12 })

              Text('结束日期').fontSize(12).fontColor(this.sub())
              DatePicker({ selected: this.parseDate(this.endDate) })
                .onDateChange((value: Date) => { this.endDate = this.formatDate(value); })
                .margin({ bottom: 12 })

              Text('周期长度 (天)').fontSize(12).fontColor(this.sub())
              TextInput({ placeholder: '28', text: this.cycleLength })
                .type(InputType.Number)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((value: string) => { this.cycleLength = value; })
                .margin({ bottom: 12 })

              Text('经期长度 (天)').fontSize(12).fontColor(this.sub())
              TextInput({ placeholder: '5', text: this.periodLength })
                .type(InputType.Number)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((value: string) => { this.periodLength = value; })
                .margin({ bottom: 16 })

              Row() {
                Button('取消').height(40).backgroundColor('#333333').fontColor(this.txt()).borderRadius(20)
                  .layoutWeight(1).onClick(() => { this.showInput = false; })
                Button('保存').height(40).backgroundColor('#E91E63').fontColor(this.txt()).borderRadius(20)
                  .layoutWeight(1).margin({ left: 12 })
                  .onClick(() => { this.saveRecord(); })
              }
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(12).margin({ bottom: 16 })
          }

          Text('经期历史').fontSize(16).fontColor(this.txt()).fontWeight(FontWeight.Bold).margin({ bottom: 12 })

          ForEach(this.records, (record: DbRow) => {
            Row() {
              Column() {
                Text(String(record.start_date)).fontSize(14).fontColor(this.txt())
                Text(String(record.end_date)).fontSize(12).fontColor(this.sub()).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)

              Column() {
                Text(String(record.cycle_length) + ' 天周期').fontSize(12).fontColor('#E91E63')
                Text(String(record.period_length) + ' 天').fontSize(12).fontColor(this.sub()).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.End)
              Text('🗑').fontSize(16).margin({ left: 10 })
                .onClick(() => { this.deleteRecord(Number(record.id)); })
            }
            .width('100%').padding(12)
            .backgroundColor(this.card()).borderRadius(8)
            .margin({ bottom: 8 })
          }, (record: DbRow): string => String(record.start_date))
        }
        .width('100%').padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%')    .backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
