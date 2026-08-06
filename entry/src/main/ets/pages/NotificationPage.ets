import { router, promptAction } from '@kit.ArkUI';
import { ThemeColors, DbRow } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { ReminderScheduler } from '../services/ReminderScheduler';

// 通知卡片组件（支持响应式描述）
@Component
struct NotifCard {
  @Prop title: string = '';
  @Prop icon: ResourceStr = '';
  @Prop isEnabled: boolean = false;
  @Prop cardColor: string = '#1A1A2E';
  @Prop txtColor: string = '#FFFFFF';
  @Prop subColor: string = '#888888';
  @Prop accentColor: string = '#FF6B35';
  @BuilderParam descContent: () => void = this.defaultDesc;
  onChange: (on: boolean) => void = () => {};

  @Builder defaultDesc() {
    Text('').fontSize(12).fontColor(this.subColor)
  }

  build() {
    Row() {
      if (typeof this.icon === 'string') {
        if (this.icon.length > 0) {
          Text(this.icon).fontSize(20).margin({ right: 10 })
        }
      } else {
        Image(this.icon).width(20).height(20).fillColor(this.accentColor).margin({ right: 10 })
      }
      Column() {
        Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.txtColor)
        this.descContent();
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
        .selectedColor(this.accentColor)
        .onChange((isOn: boolean) => { this.onChange(isOn); })
    }
    .width('100%').padding(16).backgroundColor(this.cardColor).borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 10 })
  }
}

@Entry
@Component
struct NotificationPage {
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  
  // 喝水提醒
  @State waterReminderEnabled: boolean = false;
  @State waterTimes: string[] = ['10:00'];
  @State waterEditTime: string = '10:00';
  @State showWaterTimePicker: boolean = false;
  
  // 睡眠提醒
  @State sleepReminderEnabled: boolean = false;
  @State sleepReminderTime: string = '22:30';
  @State showSleepTimePicker: boolean = false;

  // 用药提醒（有用药计划且有闹铃时视为已启用）
  @State medicationEnabled: boolean = false;
  @State medicationCount: number = 0;
  
  // 目标达成通知
  @State goalStepsNotify: boolean = true;
  @State goalSportNotify: boolean = true;
  @State goalSleepNotify: boolean = true;
  
  // 成就通知
  @State achievementNotify: boolean = true;
  
  // 运动追踪通知
  @State sportTrackingNotify: boolean = true;
  
  // 睡眠追踪通知
  @State sleepTrackingNotify: boolean = true;

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }
  accent(): string { return ThemeColors.accent(this.theme); }
  danger(): string { return '#EF4444'; }  // 红色（删除按钮）
  info(): string { return ThemeColors.accent(this.theme); }  // 使用主题强调色

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    try {
      // 喝水提醒
      const waterRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_enabled', 'false');
      this.waterReminderEnabled = String(waterRaw) === 'true';
      const waterTimeRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_time', '10:00');
      this.waterTimes = String(waterTimeRaw).split(',').filter((t: string) => t.length > 0);
      if (this.waterTimes.length === 0) {
        this.waterTimes = ['10:00'];
      }
      this.waterEditTime = this.waterTimes[0];
      
      // 睡眠提醒
      const sleepRaw: string | number | boolean = await GlobalData.prefs.get('sleep_reminder_enabled', 'false');
      this.sleepReminderEnabled = String(sleepRaw) === 'true';
      const sleepTimeRaw: string | number | boolean = await GlobalData.prefs.get('sleep_reminder_time', '22:30');
      this.sleepReminderTime = String(sleepTimeRaw);
      
      // 目标达成通知
      const stepsRaw: string | number | boolean = await GlobalData.prefs.get('goal_steps_notify', 'true');
      this.goalStepsNotify = String(stepsRaw) === 'true';
      const sportRaw: string | number | boolean = await GlobalData.prefs.get('goal_sport_notify', 'true');
      this.goalSportNotify = String(sportRaw) === 'true';
      const sleepGoalRaw: string | number | boolean = await GlobalData.prefs.get('goal_sleep_notify', 'true');
      this.goalSleepNotify = String(sleepGoalRaw) === 'true';
      
      // 成就通知
      const achieveRaw: string | number | boolean = await GlobalData.prefs.get('achievement_notify', 'true');
      this.achievementNotify = String(achieveRaw) === 'true';
      
      // 运动追踪通知
      const sportTrackRaw: string | number | boolean = await GlobalData.prefs.get('sport_tracking_notify', 'true');
      this.sportTrackingNotify = String(sportTrackRaw) === 'true';
      
      // 睡眠追踪通知
      const sleepTrackRaw: string | number | boolean = await GlobalData.prefs.get('sleep_tracking_notify', 'true');
      this.sleepTrackingNotify = String(sleepTrackRaw) === 'true';

      // 用药提醒：有用药记录且有闹铃时显示已启用
      const medRows: DbRow[] = await GlobalData.db.getMedicationRecords();
      this.medicationCount = medRows.length;
      let hasReminder: boolean = false;
      for (const r of medRows) {
        const idsStr: string = r.reminder_ids ? String(r.reminder_ids) : '';
        if (idsStr.length > 0) {
          hasReminder = true;
          break;
        }
      }
      this.medicationEnabled = medRows.length > 0 && hasReminder;
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

  // ===== 睡眠提醒操作 =====
  async toggleSleepReminder(isEnabled: boolean): Promise<void> {
    this.sleepReminderEnabled = isEnabled;
    await GlobalData.prefs.put('sleep_reminder_enabled', String(isEnabled));
    if (isEnabled) {
      const id: number = await ReminderScheduler.getInstance().scheduleSleepReminder(this.sleepReminderTime);
      await GlobalData.prefs.put('sleep_reminder_id', id);
      promptAction.showToast({ message: '睡眠提醒已开启：' + this.sleepReminderTime });
    } else {
      await ReminderScheduler.getInstance().cancelSleepReminder();
      promptAction.showToast({ message: '睡眠提醒已关闭' });
    }
  }

  async updateSleepReminderTime(): Promise<void> {
    await GlobalData.prefs.put('sleep_reminder_time', this.sleepReminderTime);
    if (this.sleepReminderEnabled) {
      const id: number = await ReminderScheduler.getInstance().scheduleSleepReminder(this.sleepReminderTime);
      await GlobalData.prefs.put('sleep_reminder_id', id);
    }
  }

  // ===== 通用开关保存 =====
  async saveToggle(key: string, value: boolean): Promise<void> {
    await GlobalData.prefs.put(key, String(value));
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('←').fontSize(22).fontColor(this.txt()).onClick(() => { router.back(); })
        Text('通知设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Scroll() {
        Column() {
          // ===== 健康提醒 =====
          Row() {
            Image($r('app.media.ic_notify')).width(20).height(20).fillColor(this.txt())
            Text('健康提醒').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 8 })
          }
            .width('100%').padding({ left: 16, bottom: 12 })

          // 喝水提醒
          NotifCard({
            title: '喝水提醒',
            icon: $r('app.media.ic_water'),
            isEnabled: this.waterReminderEnabled,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              this.waterReminderEnabled = on;
              ReminderScheduler.getInstance().toggleWaterReminder(on);
            }
          }) {
            Text('每天 ' + this.waterTimes.join(' / ') + ' 提醒喝水')
              .fontSize(12).fontColor(this.sub()).margin({ top: 4 })
          }

          // 喝水多时间点列表
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.waterTimes, (t: string) => {
              Row() {
                Text(t).fontSize(14).fontColor(this.txt())
                Text('✕').fontSize(14).fontColor(this.danger()).margin({ left: 6 })
                  .onClick(() => { this.removeWaterTime(t); })
              }
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.card()).borderRadius(12)
              .margin({ right: 6, bottom: 6 })
            }, (t: string): string => t)
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 4 })

          Row() {
            Text(this.waterEditTime).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .onClick(() => { this.showWaterTimePicker = !this.showWaterTimePicker; })
            Button('＋ 添加时间点').fontSize(13).backgroundColor(this.info()).borderRadius(16)
              .height(32).margin({ left: 12 })
              .onClick(() => { this.addWaterTime(); })
            Blank()
            Image($r('app.media.ic_edit')).width(16).height(16).fillColor(this.txt()).margin({ left: 8 })
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

          // 睡眠提醒
          NotifCard({
            title: '睡眠提醒',
            icon: $r('app.media.ic_moon'),
            isEnabled: this.sleepReminderEnabled,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              this.toggleSleepReminder(on);
            }
          }) {
            Text('每天 ' + this.sleepReminderTime + ' 提醒睡觉')
              .fontSize(12).fontColor(this.sub()).margin({ top: 4 })
          }

          Row() {
            Text('提醒时间：').fontSize(14).fontColor(this.sub())
            Text(this.sleepReminderTime).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .onClick(() => { this.showSleepTimePicker = !this.showSleepTimePicker; })
            Blank()
            Image($r('app.media.ic_edit')).width(16).height(16).fillColor(this.txt()).onClick(() => { this.showSleepTimePicker = !this.showSleepTimePicker; })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 4 })

          if (this.showSleepTimePicker) {
            TimePicker({ selected: this.parseReminderTime(this.sleepReminderTime) })
              .useMilitaryTime(true)
              .width(200).height(120)
              .onChange((value: TimePickerResult) => {
                this.sleepReminderTime = this.formatReminderTime(value);
                this.updateSleepReminderTime();
              })
              .margin({ left: 16, bottom: 8 })
          }

          // 用药提醒（动态状态）
          NotifCard({
            title: '用药提醒',
            icon: $r('app.media.ic_medication'),
            isEnabled: this.medicationEnabled,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              // 用药提醒开关需在用药页面管理，点击提示跳转
              promptAction.showToast({ message: '请到用药页面管理用药闹铃' });
              router.pushUrl({ url: 'pages/MedicationPage' }).catch(() => {});
            }
          }) {
            if (this.medicationCount > 0) {
              Text('已设置 ' + this.medicationCount + ' 条用药计划，闹铃已生效')
                .fontSize(12).fontColor(this.sub()).margin({ top: 4 })
            } else {
              Text('暂无用药计划，点击添加')
                .fontSize(12).fontColor(this.sub()).margin({ top: 4 })
            }
          }
          Text('用药闹铃在用药页面添加/删除药品时自动管理')
            .fontSize(12).fontColor(this.sub()).padding({ left: 16, right: 16, top: 4, bottom: 16 })

          // ===== 目标达成通知 =====
          Divider().margin({ left: 16, right: 16, bottom: 12 })
          Row() {
            Image($r('app.media.ic_target')).width(20).height(20).fillColor(this.txt())
            Text('目标达成通知').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 8 })
          }
            .width('100%').padding({ left: 16, bottom: 12 })

          NotifCard({
            title: '步数达标通知',
            icon: $r('app.media.ic_steps'),
            isEnabled: this.goalStepsNotify,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              this.goalStepsNotify = on;
              this.saveToggle('goal_steps_notify', on);
            }
          }) {
            Text('完成每日步数目标时通知').fontSize(12).fontColor(this.sub()).margin({ top: 4 })
          }

          NotifCard({
            title: '运动达标通知',
            icon: $r('app.media.ic_sport'),
            isEnabled: this.goalSportNotify,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              this.goalSportNotify = on;
              this.saveToggle('goal_sport_notify', on);
            }
          }) {
            Text('完成每周运动目标时通知').fontSize(12).fontColor(this.sub()).margin({ top: 4 })
          }

          NotifCard({
            title: '睡眠达标通知',
            icon: $r('app.media.ic_sleep'),
            isEnabled: this.goalSleepNotify,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              this.goalSleepNotify = on;
              this.saveToggle('goal_sleep_notify', on);
            }
          }) {
            Text('达到睡眠目标时通知').fontSize(12).fontColor(this.sub()).margin({ top: 4 })
          }

          // ===== 成就通知 =====
          Divider().margin({ left: 16, right: 16, bottom: 12 })
          Row() {
            Image($r('app.media.ic_trophy')).width(20).height(20).fillColor(this.txt())
            Text('成就通知').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 8 })
          }
            .width('100%').padding({ left: 16, bottom: 12 })

          NotifCard({
            title: '成就解锁通知',
            icon: $r('app.media.ic_trophy'),
            isEnabled: this.achievementNotify,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              this.achievementNotify = on;
              this.saveToggle('achievement_notify', on);
            }
          }) {
            Text('解锁新成就时通知').fontSize(12).fontColor(this.sub()).margin({ top: 4 })
          }

          // ===== 追踪通知 =====
          Divider().margin({ left: 16, right: 16, bottom: 12 })
          Row() {
            Image($r('app.media.ic_gps')).width(20).height(20).fillColor(this.txt())
            Text('追踪通知').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 8 })
          }
            .width('100%').padding({ left: 16, bottom: 12 })

          NotifCard({
            title: '运动追踪通知',
            icon: $r('app.media.ic_gps'),
            isEnabled: this.sportTrackingNotify,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              this.sportTrackingNotify = on;
              this.saveToggle('sport_tracking_notify', on);
            }
          }) {
            Text('后台运动时显示持续通知').fontSize(12).fontColor(this.sub()).margin({ top: 4 })
          }

          NotifCard({
            title: '睡眠追踪通知',
            icon: $r('app.media.ic_moon'),
            isEnabled: this.sleepTrackingNotify,
            cardColor: this.card(),
            txtColor: this.txt(),
            subColor: this.sub(),
            accentColor: this.accent(),
            onChange: (on: boolean) => {
              this.sleepTrackingNotify = on;
              this.saveToggle('sleep_tracking_notify', on);
            }
          }) {
            Text('后台睡眠时显示持续通知').fontSize(12).fontColor(this.sub()).margin({ top: 4 })
          }

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
