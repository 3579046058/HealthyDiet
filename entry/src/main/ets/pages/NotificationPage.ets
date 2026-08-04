import { router } from '@kit.ArkUI';
import { ThemeColors } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { ReminderScheduler } from '../services/ReminderScheduler';

@Entry
@Component
struct NotificationPage {
  @StorageLink('currentTheme') theme: string = 'dark';
  @State waterReminderEnabled: boolean = false;
  @State sedentaryReminderEnabled: boolean = false;
  @State waterReminderTime: string = '10:00';
  @State sedentaryReminderTime: string = '14:00';
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
      this.waterReminderTime = String(waterTimeRaw);
      const sedentaryTimeRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_time', '14:00');
      this.sedentaryReminderTime = String(sedentaryTimeRaw);
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

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt()).onClick(() => { router.back(); })
        Text('通知设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding(16)

      Scroll() {
        Column() {
          this.notifCard('💧 喝水提醒', '每天 ' + this.waterReminderTime + ' 提醒喝水', this.waterReminderEnabled, (on: boolean) => {
            this.waterReminderEnabled = on;
            ReminderScheduler.getInstance().toggleWaterReminder(on);
          })
          Row() {
            Text('⏰ 设置时间').fontSize(14).fontColor(this.sub()).layoutWeight(1)
            Text(this.waterReminderTime)
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .onClick(() => { this.showWaterTimePicker = !this.showWaterTimePicker; })
            Text('✏️').fontSize(16).margin({ left: 8 })
              .onClick(() => { this.showWaterTimePicker = !this.showWaterTimePicker; })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 4 })

          if (this.showWaterTimePicker) {
            TimePicker({ selected: this.parseReminderTime(this.waterReminderTime) })
              .useMilitaryTime(true)
              .width(200).height(120)
              .onChange((value: TimePickerResult) => {
                this.waterReminderTime = this.formatReminderTime(value);
                ReminderScheduler.getInstance().setWaterTime(this.waterReminderTime);
              })
              .margin({ left: 16, bottom: 8 })
          }

          this.notifCard('🪑 久坐提醒', '每天 ' + this.sedentaryReminderTime + ' 提醒起身活动', this.sedentaryReminderEnabled, (on: boolean) => {
            this.sedentaryReminderEnabled = on;
            ReminderScheduler.getInstance().toggleSedentaryReminder(on);
          })
          Row() {
            Text('⏰ 设置时间').fontSize(14).fontColor(this.sub()).layoutWeight(1)
            Text(this.sedentaryReminderTime)
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .onClick(() => { this.showSedentaryTimePicker = !this.showSedentaryTimePicker; })
            Text('✏️').fontSize(16).margin({ left: 8 })
              .onClick(() => { this.showSedentaryTimePicker = !this.showSedentaryTimePicker; })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 4 })

          if (this.showSedentaryTimePicker) {
            TimePicker({ selected: this.parseReminderTime(this.sedentaryReminderTime) })
              .useMilitaryTime(true)
              .width(200).height(120)
              .onChange((value: TimePickerResult) => {
                this.sedentaryReminderTime = this.formatReminderTime(value);
                ReminderScheduler.getInstance().setSedentaryTime(this.sedentaryReminderTime);
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
