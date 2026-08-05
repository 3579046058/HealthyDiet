import { router, promptAction } from '@kit.ArkUI';
import { ThemeColors } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { ReminderScheduler } from '../services/ReminderScheduler';

@Entry
@Component
struct NotificationPage {
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State waterReminderEnabled: boolean = false;
  @State sedentaryReminderEnabled: boolean = false;
  @State waterTimes: string[] = ['10:00'];
  @State sedentaryTimes: string[] = ['14:00'];
  @State waterEditTime: string = '10:00';
  @State sedentaryEditTime: string = '14:00';
  @State showWaterTimePicker: boolean = false;
  @State showSedentaryTimePicker: boolean = false;

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }
  accent(): string { return '#FF6B35'; }

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    try {
      const waterRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_enabled', 'false');
      this.waterReminderEnabled = String(waterRaw) === 'true';
      const sedentaryRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_enabled', 'false');
      this.sedentaryReminderEnabled = String(sedentaryRaw) === 'true';
      const waterTimeRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_time', '10:00');
      this.waterTimes = String(waterTimeRaw).split(',').filter((t: string) => t.length > 0);
      if (this.waterTimes.length === 0) {
        this.waterTimes = ['10:00'];
      }
      this.waterEditTime = this.waterTimes[0];
      const sedentaryTimeRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_time', '14:00');
      this.sedentaryTimes = String(sedentaryTimeRaw).split(',').filter((t: string) => t.length > 0);
      if (this.sedentaryTimes.length === 0) {
        this.sedentaryTimes = ['14:00'];
      }
      this.sedentaryEditTime = this.sedentaryTimes[0];
    } catch (err) {
      console.error('NotificationPage load error:', JSON.stringify(err));
    }
  }

  parseReminderTime(timeStr: string): Date {
    const parts: string[] = timeStr.split(':');
    const h: number = parseInt(parts[0]) || 10;
    const m: number = parseInt(parts[1]) || 0;
    const d: Date = new Date();
    d.setHours(h, m, 0, 0);
    return d;
  }

  formatReminderTime(value: TimePickerResult): string {
    const h: number = value.hour;
    const m: number = value.minute;
    const hStr: string = h < 10 ? '0' + h : '' + h;
    const mStr: string = m < 10 ? '0' + m : '' + m;
    return hStr + ':' + mStr;
  }

  // ===== 喝水提醒多时间点操作 =====
  addWaterTime(): void {
    const t: string = this.waterEditTime;
    if (t.length === 0) {
      promptAction.showToast({ message: '请先选择时间' });
      return;
    }
    if (this.waterTimes.indexOf(t) >= 0) {
      promptAction.showToast({ message: '该时间点已存在' });
      return;
    }
    const list: string[] = this.waterTimes.slice();
    list.push(t);
    list.sort();
    this.waterTimes = list;
    ReminderScheduler.getInstance().setWaterTimes(this.waterTimes);
  }

  removeWaterTime(t: string): void {
    const list: string[] = [];
    for (const x of this.waterTimes) {
      if (x !== t) {
        list.push(x);
      }
    }
    this.waterTimes = list.length > 0 ? list : ['10:00'];
    ReminderScheduler.getInstance().setWaterTimes(this.waterTimes);
  }

  // ===== 久坐提醒多时间点操作 =====
  addSedentaryTime(): void {
    const t: string = this.sedentaryEditTime;
    if (t.length === 0) {
      promptAction.showToast({ message: '请先选择时间' });
      return;
    }
    if (this.sedentaryTimes.indexOf(t) >= 0) {
      promptAction.showToast({ message: '该时间点已存在' });
      return;
    }
    const list: string[] = this.sedentaryTimes.slice();
    list.push(t);
    list.sort();
    this.sedentaryTimes = list;
    ReminderScheduler.getInstance().setSedentaryTimes(this.sedentaryTimes);
  }

  removeSedentaryTime(t: string): void {
    const list: string[] = [];
    for (const x of this.sedentaryTimes) {
      if (x !== t) {
        list.push(x);
      }
    }
    this.sedentaryTimes = list.length > 0 ? list : ['14:00'];
    ReminderScheduler.getInstance().setSedentaryTimes(this.sedentaryTimes);
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt()).onClick(() => { router.back(); })
        Text('通知设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Scroll() {
        Column() {
          this.notifCard('💧 喝水提醒', '每天 ' + this.waterTimes.join(' / ') + ' 提醒喝水', this.waterReminderEnabled, (on: boolean) => {
            this.waterReminderEnabled = on;
            ReminderScheduler.getInstance().toggleWaterReminder(on);
          })

          // 喝水多时间点列表
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.waterTimes, (t: string) => {
              Row() {
                Text(t).fontSize(14).fontColor(this.txt())
                Text('✕').fontSize(14).fontColor('#F44336').margin({ left: 6 })
                  .onClick(() => { this.removeWaterTime(t); })
              }
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor('#1E3A5F').borderRadius(12)
              .margin({ right: 6, bottom: 6 })
            }, (t: string): string => t)
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 4 })

          Row() {
            Text(this.waterEditTime).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .onClick(() => { this.showWaterTimePicker = !this.showWaterTimePicker; })
            Button('＋ 添加时间点').fontSize(13).backgroundColor('#03A9F4').borderRadius(16)
              .height(32).margin({ left: 12 })
              .onClick(() => { this.addWaterTime(); })
            Blank()
            Text('✏️').fontSize(16).margin({ left: 8 })
              .onClick(() => { this.showWaterTimePicker = !this.showWaterTimePicker; })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 4 })

          if (this.showWaterTimePicker) {
            TimePicker({ selected: this.parseReminderTime(this.waterEditTime) })
              .useMilitaryTime(true)
              .width(200).height(120)
              .onChange((value: TimePickerResult) => {
                this.waterEditTime = this.formatReminderTime(value);
              })
              .margin({ left: 16, bottom: 8 })
          }

          this.notifCard('🪑 久坐提醒', '每天 ' + this.sedentaryTimes.join(' / ') + ' 提醒起身活动', this.sedentaryReminderEnabled, (on: boolean) => {
            this.sedentaryReminderEnabled = on;
            ReminderScheduler.getInstance().toggleSedentaryReminder(on);
          })

          // 久坐多时间点列表
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.sedentaryTimes, (t: string) => {
              Row() {
                Text(t).fontSize(14).fontColor(this.txt())
                Text('✕').fontSize(14).fontColor('#F44336').margin({ left: 6 })
                  .onClick(() => { this.removeSedentaryTime(t); })
              }
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor('#1E3A5F').borderRadius(12)
              .margin({ right: 6, bottom: 6 })
            }, (t: string): string => t)
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 4 })

          Row() {
            Text(this.sedentaryEditTime).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .onClick(() => { this.showSedentaryTimePicker = !this.showSedentaryTimePicker; })
            Button('＋ 添加时间点').fontSize(13).backgroundColor('#03A9F4').borderRadius(16)
              .height(32).margin({ left: 12 })
              .onClick(() => { this.addSedentaryTime(); })
            Blank()
            Text('✏️').fontSize(16).margin({ left: 8 })
              .onClick(() => { this.showSedentaryTimePicker = !this.showSedentaryTimePicker; })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 4 })

          if (this.showSedentaryTimePicker) {
            TimePicker({ selected: this.parseReminderTime(this.sedentaryEditTime) })
              .useMilitaryTime(true)
              .width(200).height(120)
              .onChange((value: TimePickerResult) => {
                this.sedentaryEditTime = this.formatReminderTime(value);
              })
              .margin({ left: 16, bottom: 8 })
          }

          this.notifCard('💊 用药提醒', '根据设定的时间提醒你服药', false, (on: boolean) => {
            console.info('Medication reminder toggle: ' + String(on));
          })

          Text('闹钟功能需在用药页面添加用药计划后生效')
            .fontSize(12).fontColor(this.sub()).padding({ left: 16, right: 16, top: 8 })

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
  }

  @Builder notifCard(title: string, desc: string, enabled: boolean, onChange: (on: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.txt())
        Text(desc).fontSize(12).fontColor(this.sub()).margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(this.accent())
        .onChange((isOn: boolean) => { onChange(isOn); })
    }
    .width('100%').padding(16).backgroundColor(this.card()).borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
