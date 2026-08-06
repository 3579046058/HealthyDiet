import { router, promptAction } from '@kit.ArkUI';
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
  @State timeList: string[] = [];
  @State frequency: string = '';
  // 提醒星期（1=周一 ... 7=周日），默认全周
  @State selectedDays: number[] = [1, 2, 3, 4, 5, 6, 7];
  @State startDate: string = '';
  @State endDate: string = '';
  @State records: DbRow[] = [];
  @State todayMeds: DbRow[] = [];
  @State checkedIds: number[] = [];
  @State isRefreshing: boolean = false; // 下拉刷新状态
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const allRecords: DbRow[] = await GlobalData.db.getMedicationRecords();
      // animateTo 包裹数据更新，触发列表项 transition 进入动画
      animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
        this.records = allRecords;
        this.todayMeds = this.getTodaysMeds(allRecords);
      });
    } catch (err) {
      console.error('MedicationPage loadData error:', JSON.stringify(err));
    }
  }

  async saveRecord(): Promise<void> {
    if (this.name === '' || this.dosage === '' || this.timeList.length === 0 || this.startDate === '' || this.endDate === '') {
      return;
    }
    // 校验日期区间：结束日期不能早于开始日期
    if (this.endDate < this.startDate) {
      promptAction.showToast({ message: '结束日期不能早于开始日期' });
      return;
    }
    try {
      const record: DbRow = {
        name: this.name,
        dosage: this.dosage,
        time: this.timeList.join(','),
        frequency: this.frequency,
        start_date: this.startDate,
        end_date: this.endDate,
        reminder_ids: ''
      };
      const newId = await GlobalData.db.addMedicationRecord(record);
      // 发布多时间点闹铃（按选定星期重复）
      const newIds: number[] = await ReminderScheduler.getInstance()
        .scheduleMedicationReminder(this.timeList, this.name, [], this.selectedDays);
      if (newId > 0 && newIds.length > 0) {
        await GlobalData.db.updateMedicationReminderIds(newId, newIds.join(','));
      }
      this.name = '';
      this.dosage = '';
      this.time = '';
      this.timeList = [];
      this.frequency = '';
      this.selectedDays = [1, 2, 3, 4, 5, 6, 7];
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
      // 先取消该药品的所有闹铃
      for (const r of this.records) {
        if (Number(r.id) === id) {
          const idsStr: string = r.reminder_ids ? String(r.reminder_ids) : '';
          if (idsStr.length > 0) {
            const ids: number[] = [];
            for (const part of idsStr.split(',')) {
              const n = parseInt(part);
              if (!isNaN(n)) {
                ids.push(n);
              }
            }
            await ReminderScheduler.getInstance().cancelMedicationReminders(ids);
          }
          break;
        }
      }
      await GlobalData.db.deleteMedicationRecord(id);
      await this.loadData();
    } catch (err) {
      console.error('MedicationPage deleteRecord error:', JSON.stringify(err));
    }
  }

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

  // ===== 提醒星期选择 =====
  isDaySelected(day: number): boolean {
    return this.selectedDays.indexOf(day) >= 0;
  }

  toggleDay(day: number): void {
    const list: number[] = [];
    let found: boolean = false;
    for (const d of this.selectedDays) {
      if (d === day) {
        found = true;
      } else {
        list.push(d);
      }
    }
    if (!found) {
      list.push(day);
      list.sort();
    }
    this.selectedDays = list.length > 0 ? list : [day];
  }

  selectAllDays(): void {
    this.selectedDays = [1, 2, 3, 4, 5, 6, 7];
  }

  selectWorkdays(): void {
    this.selectedDays = [1, 2, 3, 4, 5];
  }

  selectWeekend(): void {
    this.selectedDays = [6, 7];
  }

  dayLabel(day: number): string {
    const labels: string[] = ['', '一', '二', '三', '四', '五', '六', '日'];
    return labels[day];
  }

  selectedDaysText(): string {
    if (this.selectedDays.length === 7) {
      return '每天';
    }
    if (this.selectedDays.length === 5 &&
      this.selectedDays.indexOf(1) >= 0 && this.selectedDays.indexOf(5) >= 0) {
      return '工作日';
    }
    if (this.selectedDays.length === 2 &&
      this.selectedDays.indexOf(6) >= 0 && this.selectedDays.indexOf(7) >= 0) {
      return '周末';
    }
    let s: string = '';
    for (const d of this.selectedDays) {
      s += (s.length > 0 ? '、' : '') + '周' + this.dayLabel(d);
    }
    return s;
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
        Text('用药提醒')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt())
          .margin({ left: 12 })
      }
      .width('100%').padding({ top: 12 + this.statusBarHeight, bottom: 12, left: 16, right: 16 })

      Refresh({ refreshing: $$this.isRefreshing }) {
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
                  if (this.isChecked(Number(item.id))) {
                    Image($r('app.media.ic_checkbox_on')).width(24).height(24).fillColor('#00897B')
                      .onClick(() => { this.toggleCheck(Number(item.id)); })
                  } else {
                    Image($r('app.media.ic_checkbox_off')).width(24).height(24).fillColor(this.sub())
                      .onClick(() => { this.toggleCheck(Number(item.id)); })
                  }
                  Column() {
                    Text(String(item.name)).fontSize(16).fontColor(this.txt())
                    Text(String(item.dosage) + ' - ' + String(item.time).split(',').join(' / '))
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

              Text('服用时间（可添加多个）').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              TimePicker({ selected: this.parseTimeToDate(this.time) })
                .useMilitaryTime(true)
                .width(180).height(80)
                .onChange((value: TimePickerResult) => { this.time = this.formatPickerTime(value); })
                .margin({ bottom: 4 })
              Button() { Text('＋ 添加此时间点').fontSize(14).fontColor(this.txt()) }
              .width('100%').height(36).backgroundColor('#00897B').borderRadius(8)
              .margin({ bottom: 8 })
              .onClick(() => {
                if (this.time.length === 0) {
                  promptAction.showToast({ message: '请先选择时间' });
                  return;
                }
                if (this.timeList.indexOf(this.time) >= 0) {
                  promptAction.showToast({ message: '该时间点已存在' });
                  return;
                }
                const newList: string[] = this.timeList.slice();
                newList.push(this.time);
                this.timeList = newList;
              })

              // 已选时间点列表
              if (this.timeList.length > 0) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.timeList, (t: string) => {
                    Row() {
                      Text(t).fontSize(14).fontColor(this.txt())
                      Text('✕').fontSize(14).fontColor('#F44336').margin({ left: 6 })
                        .onClick(() => {
                          const newList: string[] = [];
                          for (const x of this.timeList) {
                            if (x !== t) {
                              newList.push(x);
                            }
                          }
                          this.timeList = newList;
                        })
                    }
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor('#1E3A5F').borderRadius(12)
                    .margin({ right: 6, bottom: 6 })
                  }, (t: string): string => t)
                }
                .width('100%').margin({ bottom: 8 })
              }

              // 提醒星期选择（频率）
              Text('提醒星期：' + this.selectedDaysText()).fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              Row() {
                Button('每天').fontSize(12).backgroundColor('#00897B').borderRadius(14).height(28)
                  .onClick(() => { this.selectAllDays(); })
                Button('工作日').fontSize(12).backgroundColor('#00897B').borderRadius(14).height(28).margin({ left: 8 })
                  .onClick(() => { this.selectWorkdays(); })
                Button('周末').fontSize(12).backgroundColor('#00897B').borderRadius(14).height(28).margin({ left: 8 })
                  .onClick(() => { this.selectWeekend(); })
              }
              .width('100%').margin({ bottom: 6 })

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach([1, 2, 3, 4, 5, 6, 7], (day: number) => {
                  Text('周' + this.dayLabel(day))
                    .fontSize(13)
                    .fontColor(this.isDaySelected(day) ? '#FFFFFF' : this.sub())
                    .backgroundColor(this.isDaySelected(day) ? '#00897B' : '#1E3A5F')
                    .borderRadius(16)
                    .width(42).height(32).textAlign(TextAlign.Center)
                    .margin({ right: 6, bottom: 6 })
                    .onClick(() => { this.toggleDay(day); })
                }, (day: number): string => String(day))
              }
              .width('100%').margin({ bottom: 8 })

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
              Text('暂无用药记录').fontSize(16).fontColor(this.sub())
            }
            .width('100%').alignItems(HorizontalAlign.Center)
            .padding({ top: 32, bottom: 32 })
          } else {
            Column() {
              ForEach(this.records, (item: DbRow) => {
                Row() {
                  Column() {
                    Text(String(item.name)).fontSize(16).fontColor(this.txt())
                    Text(String(item.dosage) + ' | ' + String(item.time).split(',').join(' / ') + ' | ' + String(item.frequency))
                      .fontSize(13).fontColor(this.sub())
                    Text(String(item.start_date) + ' ~ ' + String(item.end_date))
                      .fontSize(12).fontColor(this.sub())
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)

                  Button() { Image($r('app.media.ic_delete')).width(20).height(20).fillColor('#F44336') }
                  .width(40).height(40).backgroundColor('transparent')
                  .onClick(() => { this.deleteRecord(Number(item.id)); })
                }
                .width('100%').padding(12)
                .backgroundColor(this.card()).borderRadius(10)
                .margin({ bottom: 8 })
                .transition(
                  TransitionEffect.OPACITY
                    .combine(TransitionEffect.translate({ y: 30 }))
                    .animation({
                      duration: 350,
                      curve: Curve.EaseOut
                    })
                )
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
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .onRefreshing(() => {
        // 下拉刷新：重新加载用药记录
        this.loadData().then(() => {
          setTimeout(() => { this.isRefreshing = false; }, 600);
        }).catch(() => { this.isRefreshing = false; });
      })
    }
    .width('100%').height('100%')
    .backgroundColor(this.bg())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
