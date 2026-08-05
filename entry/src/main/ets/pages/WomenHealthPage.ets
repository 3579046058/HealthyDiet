import { router, promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { DbRow, ThemeColors } from '../common/Constants';

interface DbRowExt extends DbRow {
  cycle_length: number;
  period_length: number;
}

@Entry
@Component
struct WomenHealthPage {
  @State startDate: string = '';
  @State endDate: string = '';
  @State tempStart: Date = new Date();
  @State tempEnd: Date = new Date();
  @State cycleLength: string = '';
  @State periodLength: string = '';
  @State showInput: boolean = false;
  @State records: DbRowExt[] = [];
  @State predictedNext: string = '';
  @State predictedOvulation: string = '';
  @State avgCycle: number = 28;
  @State avgPeriod: number = 5;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }
  divider(): string { return ThemeColors.divider(this.theme); }
  inputBg(): string { return ThemeColors.inputBg(this.theme); }

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const raw = await GlobalData.db.getPeriodRecords();
      this.records = raw as DbRowExt[];

      // ====关键修复：强制按照经期开始日期升序排序，最新记录放在数组末尾====
      this.records.sort((itemA:DbRowExt,itemB:DbRowExt)=>{
        const timeA = this.parseDate(String(itemA.start_date)).getTime()
        const timeB = this.parseDate(String(itemB.start_date)).getTime()
        return timeA - timeB
      })

      this.calcAverageData();
      this.calculatePredictions();
    } catch (err) {
      console.error('WomenHealthPage loadData error:', JSON.stringify(err));
    }
  }

  // 自动计算历史平均周期、平均经期
  calcAverageData(): void {
    if (this.records.length === 0) {
      this.avgCycle = 28;
      this.avgPeriod = 5;
      return;
    }
    let sumCycle = 0;
    let sumPeriod = 0;
    this.records.forEach((item: DbRowExt) => {
      sumCycle += item.cycle_length;
      sumPeriod += item.period_length;
    })
    this.avgCycle = Math.round(sumCycle / this.records.length);
    this.avgPeriod = Math.round(sumPeriod / this.records.length);
    this.cycleLength = String(this.avgCycle);
    this.periodLength = String(this.avgPeriod);
  }

  calculatePredictions(): void {
    if (this.records.length === 0) {
      this.predictedNext = "--";
      this.predictedOvulation = "--";
      return;
    }
    // 排序之后数组最后一项一定为最新的经期记录
    const lastRecord: DbRowExt = this.records[this.records.length - 1];
    const dateStr = String(lastRecord.start_date);
    const lastStartDate = this.parseDate(dateStr);

    let targetCycle = parseInt(this.cycleLength);
    if (isNaN(targetCycle) || targetCycle <= 0) {
      targetCycle = this.avgCycle;
    }
    const nextPeriodDate = new Date(lastStartDate.getTime() + targetCycle * 24 * 60 * 60 * 1000);
    this.predictedNext = this.formatDate(nextPeriodDate);
    const ovulationDate = new Date(nextPeriodDate.getTime() - 14 * 24 * 60 * 60 * 1000);
    this.predictedOvulation = this.formatDate(ovulationDate);
  }

  formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  parseDate(dateStr: string): Date {
    if (!dateStr) return new Date();
    const arr = dateStr.split('-');
    const year = parseInt(arr[0]);
    const month = parseInt(arr[1]) - 1;
    const day = parseInt(arr[2]);
    return new Date(year, month, day);
  }

  async saveRecord(): Promise<void> {
    if (this.startDate.length === 0 || this.endDate.length === 0) {
      promptAction.showToast({ message: '请填写开始和结束日期' });
      return;
    }

    // 校验开始日期 ≤ 结束日期
    const startDay = this.parseDate(this.startDate).getTime();
    const endDay = this.parseDate(this.endDate).getTime();
    if (startDay > endDay) {
      promptAction.showToast({ message: '经期开始日期不能晚于结束日期' });
      return;
    }

    try {
      // 自动计算本次经期天数
      const periodLen = Math.round((endDay - startDay) / (24 * 60 * 60 * 1000)) + 1;

      // 自动计算周期天数
      let cycleLen = this.avgCycle;
      if (this.records.length > 0) {
        const idx = this.records.length - 1;
        const lastRecord = this.records[idx];
        const lastStartStr = String(lastRecord.start_date);
        const lastStartDay = this.parseDate(lastStartStr).getTime();
        cycleLen = Math.round((startDay - lastStartDay) / (24 * 60 * 60 * 1000));
      }

      let baseRecord: DbRow = {} as DbRow;
      baseRecord.start_date = this.startDate;
      baseRecord.end_date = this.endDate;

      const record = baseRecord as DbRowExt;
      record.cycle_length = cycleLen;
      record.period_length = periodLen;

      await GlobalData.db.addPeriodRecord(record as DbRow);
      this.startDate = '';
      this.endDate = '';
      this.showInput = false;
      promptAction.showToast({ message: '保存成功，已更新预测日期' });
      await this.loadData();
    } catch (err) {
      console.error('saveRecord error:', JSON.stringify(err));
    }
  }

  deleteRecord(id: number): void {
    GlobalData.db.deletePeriodRecord(id);
    this.loadData();
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt())
          .accessibilityText('返回上一页')
          .accessibilityLevel('important')
          .onClick(() => {
            router.back();
          })
        Text('女性健康')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.txt())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Scroll() {
        Column() {
          Column() {
            Text('预计下次经期').fontSize(14).fontColor(this.sub())
            Text(this.predictedNext)
              .fontSize(24)
              .fontColor('#E91E63')
              .fontWeight(FontWeight.Bold)
              .margin({ top: 4 })
            Divider().width('100%').height(1).backgroundColor(this.divider()).margin({ top: 12, bottom: 12 })
            Text('预计排卵日（下次经期前14天）').fontSize(14).fontColor(this.sub())
            Text(this.predictedOvulation)
              .fontSize(20)
              .fontColor(this.txt())
              .fontWeight(FontWeight.Medium)
              .margin({ top: 4 })
            Divider().width('100%').height(1).backgroundColor(this.divider()).margin({ top: 12, bottom: 12 })
            Text(`历史平均周期：${this.avgCycle}天 | 平均经期：${this.avgPeriod}天`)
              .fontSize(13)
              .fontColor(this.sub())
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.card())
          .borderRadius(12)
          .margin({ bottom: 16 })

          if (!this.showInput) {
            Button('添加经期记录')
              .width('100%')
              .height(48)
              .backgroundColor('#E91E63')
              .fontSize(16)
              .fontColor('#ffffff')
              .borderRadius(24)
              .onClick(() => {
                this.showInput = true;
              })
          } else {
            Column() {
              Text('记录本次经期')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.txt())
                .margin({ bottom: 16 })

              Text('月经开始日期').fontSize(14).fontColor(this.sub())
              DatePicker({ selected: this.tempStart })
                .onDateChange((d: Date) => {
                  this.tempStart = d;
                })
                .margin({ bottom: 12 })

              Text('月经结束日期').fontSize(14).fontColor(this.sub())
              DatePicker({ selected: this.tempEnd })
                .onDateChange((d: Date) => {
                  this.tempEnd = d;
                })
                .margin({ bottom: 16 })

              Row() {
                Button('取消')
                  .layoutWeight(1)
                  .height(40)
                  .backgroundColor('#555555')
                  .fontColor('#fff')
                  .borderRadius(20)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.showInput = false;
                    this.startDate = '';
                    this.endDate = '';
                  })
                Button('保存记录')
                  .layoutWeight(1)
                  .height(40)
                  .backgroundColor('#E91E63')
                  .fontColor('#fff')
                  .borderRadius(20)
                  .onClick(() => {
                    this.startDate = this.formatDate(this.tempStart);
                    this.endDate = this.formatDate(this.tempEnd);
                    this.saveRecord();
                  })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.card())
            .borderRadius(12)
            .margin({ bottom: 16 })
          }

          Text('历史经期记录').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ bottom: 12 })
          ForEach(this.records, (record: DbRowExt) => {
            Row() {
              Column() {
                Text(`${record.start_date} ~ ${record.end_date}`).fontSize(14).fontColor(this.txt())
                Text(`本次经期${record.period_length}天`).fontSize(12).fontColor(this.sub()).margin({ top: 2 })
              }
              .alignItems(0)
              .layoutWeight(1)

              Row() {
                Text(`${record.cycle_length}天周期`).fontSize(12).fontColor('#E91E63').margin({ right: 8 })
                Text('🗑').fontSize(16)
                  .onClick(() => {
                    if (record.id) {
                      const idNum = Number(record.id);
                      this.deleteRecord(idNum);
                    }
                  })
              }
              .alignItems(2)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.card())
            .borderRadius(8)
            .margin({ bottom: 8 })
          }, (record: DbRowExt): string => String(record.start_date))
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg())
  }
}