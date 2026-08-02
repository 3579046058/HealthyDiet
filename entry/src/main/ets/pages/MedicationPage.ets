import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { DbRow, ThemeColors } from '../common/Constants';
import { ReminderScheduler } from '../services/ReminderScheduler';

@Entry
@Component
struct MedicationPage {
  @State showInput: boolean = false;
  @State name: string = '';
  @State dosage: string = '';
  @State time: string = '';
  @State frequency: string = '';
  @State startDate: string = '';
  @State endDate: string = '';
  @State records: DbRow[] = [];
  @State todayMeds: DbRow[] = [];
  @State checkedIds: number[] = [];
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const allRecords: DbRow[] = await GlobalData.db.getMedicationRecords();
      this.records = allRecords;
      this.todayMeds = this.getTodaysMeds(allRecords);
    } catch (err) {
      console.error('MedicationPage loadData error:', JSON.stringify(err));
    }
  }

  async saveRecord(): Promise<void> {
    if (this.name === '' || this.dosage === '' || this.time === '' || this.frequency === '' || this.startDate === '' || this.endDate === '') {
      return;
    }
    try {
      const record: DbRow = {
        name: this.name,
        dosage: this.dosage,
        time: this.time,
        frequency: this.frequency,
        start_date: this.startDate,
        end_date: this.endDate
      };
      await GlobalData.db.addMedicationRecord(record);
      ReminderScheduler.getInstance().scheduleMedicationReminder(this.time, this.name);
      this.name = '';
      this.dosage = '';
      this.time = '';
      this.frequency = '';
      this.startDate = '';
      this.endDate = '';
      this.showInput = false;
      await this.loadData();
    } catch (err) {
      console.error('MedicationPage saveRecord error:', JSON.stringify(err));
    }
  }

  parseTimeToDate(timeStr: string): Date {
    const parts: string[] = timeStr.split(':');
    const h: number = parseInt(parts[0]) || 8;
    const m: number = parseInt(parts[1]) || 0;
    const d: Date = new Date();
    d.setHours(h, m, 0, 0);
    return d;
  }

  formatPickerTime(value: TimePickerResult): string {
    const h: number = value.hour;
    const m: number = value.minute;
    const hStr: string = h < 10 ? '0' + h : '' + h;
    const mStr: string = m < 10 ? '0' + m : '' + m;
    return hStr + ':' + mStr;
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

  formatDate(date: Date): string {
    const year: number = date.getFullYear();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const monthStr: string = month < 10 ? '0' + month : '' + month;
    const dayStr: string = day < 10 ? '0' + day : '' + day;
    return year + '-' + monthStr + '-' + dayStr;
  }

  async deleteRecord(id: number): Promise<void> {
    try {
      await GlobalData.db.deleteMedicationRecord(id);
      await this.loadData();
    } catch (err) {
      console.error('MedicationPage deleteRecord error:', JSON.stringify(err));
    }  }

  getTodaysMeds(records: DbRow[]): DbRow[] {
    const today: string = new Date().toISOString().split('T')[0];
    const result: DbRow[] = [];
    for (const record of records) {
      const sd: string = String(record.start_date);
      const ed: string = String(record.end_date);
      if (sd <= today && ed >= today) {
        result.push(record);
      }
    }
    return result;
  }

  isChecked(id: number): boolean {
    for (const cid of this.checkedIds) {
      if (cid === id) {
        return true;
      }
    }
    return false;
  }

  toggleCheck(id: number): void {
    const newArr: number[] = [];
    let found: boolean = false;
    for (const cid of this.checkedIds) {
      if (cid === id) {
        found = true;
      } else {
        newArr.push(cid);
      }
    }
    if (!found) {
      newArr.push(id);
    }
    this.checkedIds = newArr;
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
        Text('💊 用药提醒')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt())
          .margin({ left: 12 })
      }
      .width('100%').padding({ top: 12, bottom: 12, left: 16, right: 16 })

      Scroll() {
        Column() {
          Text('今日用药')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt())
            .width('100%').margin({ top: 16, bottom: 8, left: 16 })

          if (this.todayMeds.length === 0) {
            Text('今日无用药安排')
              .fontSize(14).fontColor(this.sub())
              .width('100%').padding({ left: 16, top: 8, bottom: 8 })
          } else {
            Column() {
              ForEach(this.todayMeds, (item: DbRow) => {
                Row() {
                  Text(this.isChecked(Number(item.id)) ? '☑' : '☐')
                    .fontSize(24)
                    .onClick(() => { this.toggleCheck(Number(item.id)); })
                  Column() {
                    Text('💊 ' + String(item.name)).fontSize(16).fontColor(this.txt())
                    Text(String(item.dosage) + ' - ' + String(item.time))
                      .fontSize(13).fontColor(this.sub())
                  }
                  .margin({ left: 10 }).alignItems(HorizontalAlign.Start)
                }
                .width('100%').padding(12)
                .backgroundColor(this.card()).borderRadius(10)
                .margin({ bottom: 8 })
              }, (item: DbRow): string => String(item.id))
            }
            .width('100%').padding({ left: 16, right: 16 })
          }

          Button() {
            Text(this.showInput ? '− 取消' : '+ 添加用药')
              .fontSize(16).fontColor(this.txt())
          }
          .width('90%').height(48)
          .backgroundColor('#00BCD4').borderRadius(24)
          .margin({ top: 16, bottom: 8 })
          .onClick(() => { this.showInput = !this.showInput; })

          if (this.showInput) {
            Column() {
              TextInput({ placeholder: '药品名称', text: this.name })
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((value: string) => { this.name = value; })
                .width('100%').height(44).margin({ bottom: 8 })

              TextInput({ placeholder: '剂量 (如 500mg)', text: this.dosage })
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((value: string) => { this.dosage = value; })
                .width('100%').height(44).margin({ bottom: 8 })

              Text('服用时间').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              TimePicker({ selected: this.parseTimeToDate(this.time) })
                .useMilitaryTime(true)
                .width(180).height(80)
                .onChange((value: TimePickerResult) => { this.time = this.formatPickerTime(value); })
                .margin({ bottom: 8 })

              TextInput({ placeholder: '频率 (如 每天)', text: this.frequency })
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((value: string) => { this.frequency = value; })
                .width('100%').height(44).margin({ bottom: 8 })

              Text('开始日期').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              DatePicker({ selected: this.parseDate(this.startDate) })
                .onDateChange((value: Date) => { this.startDate = this.formatDate(value); })
                .margin({ bottom: 8 })

              Text('结束日期').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              DatePicker({ selected: this.parseDate(this.endDate) })
                .onDateChange((value: Date) => { this.endDate = this.formatDate(value); })
                .margin({ bottom: 8 })

              Button() { Text('保存').fontSize(16).fontColor(this.txt()) }
              .width('100%').height(44).backgroundColor('#00BCD4').borderRadius(8)
              .margin({ top: 8 }).onClick(() => { this.saveRecord(); })
            }
            .width('90%').padding(16)
            .backgroundColor(this.card()).borderRadius(12).margin({ top: 8 })
          }

          Text('全部用药')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt())
            .width('100%').margin({ top: 24, bottom: 8, left: 16 })

          if (this.records.length === 0) {
            Column() {
              Text('💊').fontSize(48)
              Text('暂无用药记录').fontSize(16).fontColor(this.sub()).margin({ top: 8 })
            }
            .width('100%').alignItems(HorizontalAlign.Center)
            .padding({ top: 32, bottom: 32 })
          } else {
            Column() {
              ForEach(this.records, (item: DbRow) => {
                Row() {
                  Column() {
                    Text('💊 ' + String(item.name)).fontSize(16).fontColor(this.txt())
                    Text(String(item.dosage) + ' | ' + String(item.time) + ' | ' + String(item.frequency))
                      .fontSize(13).fontColor(this.sub())
                    Text(String(item.start_date) + ' ~ ' + String(item.end_date))
                      .fontSize(12).fontColor(this.sub())
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)

                  Button() { Text('🗑').fontSize(18) }
                  .width(40).height(40).backgroundColor('transparent')
                  .onClick(() => { this.deleteRecord(Number(item.id)); })
                }
                .width('100%').padding(12)
                .backgroundColor(this.card()).borderRadius(10)
                .margin({ bottom: 8 })
              }, (item: DbRow): string => String(item.id))
            }
            .width('100%').padding({ left: 16, right: 16 })
          }
        }
        .width('100%')
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
