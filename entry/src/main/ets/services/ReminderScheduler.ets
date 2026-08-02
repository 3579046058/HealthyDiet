import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { GlobalData } from '../common/GlobalData';

export class ReminderScheduler {
  private static instance: ReminderScheduler;
  private context: common.UIAbilityContext | null = null;
  private waterReminderId: number = -1;
  private sedentaryReminderId: number = -1;

  static getInstance(): ReminderScheduler {
    if (!ReminderScheduler.instance) {
      ReminderScheduler.instance = new ReminderScheduler();
    }
    return ReminderScheduler.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async startAll(): Promise<void> {
    try {
      const waterEnabledRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_enabled', 'false');
      const sedentaryEnabledRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_enabled', 'false');
      const waterTimeRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_time', '10:00');
      const sedentaryTimeRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_time', '14:00');
      const waterTime: string = String(waterTimeRaw);
      const sedentaryTime: string = String(sedentaryTimeRaw);
      if (String(waterEnabledRaw) === 'true') {
        this.scheduleWaterReminder(waterTime);
      }
      if (String(sedentaryEnabledRaw) === 'true') {
        this.scheduleSedentaryReminder(sedentaryTime);
      }
    } catch (err) {
      console.error('ReminderScheduler startAll error:', JSON.stringify(err));
    }
  }

  async setWaterTime(time: string): Promise<void> {
    await GlobalData.prefs.put('water_reminder_time', time);
    const enabledRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_enabled', 'false');
    if (String(enabledRaw) === 'true') {
      this.scheduleWaterReminder(time);
    }
  }

  async setSedentaryTime(time: string): Promise<void> {
    await GlobalData.prefs.put('sedentary_reminder_time', time);
    const enabledRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_enabled', 'false');
    if (String(enabledRaw) === 'true') {
      this.scheduleSedentaryReminder(time);
    }
  }

  async toggleWaterReminder(enabled: boolean): Promise<void> {
    await GlobalData.prefs.put('water_reminder_enabled', String(enabled));
    if (enabled) {
      const timeRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_time', '10:00');
      this.scheduleWaterReminder(String(timeRaw));
    } else {
      this.cancelWaterReminder();
    }
  }

  async toggleSedentaryReminder(enabled: boolean): Promise<void> {
    await GlobalData.prefs.put('sedentary_reminder_enabled', String(enabled));
    if (enabled) {
      const timeRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_time', '14:00');
      this.scheduleSedentaryReminder(String(timeRaw));
    } else {
      this.cancelSedentaryReminder();
    }
  }

  async scheduleWaterReminder(time: string): Promise<void> {
    this.cancelWaterReminder();
    const h: number = this.parseHour(time);
    const m: number = this.parseMinute(time);
    this.waterReminderId = await this.publishAlarm(h, m, 1001, '💧 喝水提醒', '该喝水啦！记得补充水分哦～');
  }

  async scheduleSedentaryReminder(time: string): Promise<void> {
    this.cancelSedentaryReminder();
    const h: number = this.parseHour(time);
    const m: number = this.parseMinute(time);
    this.sedentaryReminderId = await this.publishAlarm(h, m, 1002, '🚶 久坐提醒', '起来活动一下吧！久坐不利于健康～');
  }

  async scheduleMedicationReminder(time: string, name: string): Promise<void> {
    const h: number = this.parseHour(time);
    const m: number = this.parseMinute(time);
    await this.publishAlarm(h, m, 1003, '💊 用药提醒', '该服用 ' + name + ' 了！');
  }

  private parseHour(time: string): number {
    const parts: string[] = time.split(':');
    return parseInt(parts[0]) || 10;
  }

  private parseMinute(time: string): number {
    const parts: string[] = time.split(':');
    return parseInt(parts[1]) || 0;
  }

  private async publishAlarm(hour: number, minute: number, notificationId: number, title: string, content: string): Promise<number> {
    try {
      const request: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: hour,
        minute: minute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        wantAgent: {
          pkgName: 'com.harmonyhealth.app',
          abilityName: 'EntryAbility'
        },
        maxScreenWantAgent: {
          pkgName: 'com.harmonyhealth.app',
          abilityName: 'EntryAbility'
        },
        ringDuration: 10,
        snoozeTimes: 2,
        timeInterval: 5,
        title: title,
        content: content,
        expiredContent: title,
        snoozeContent: title,
        notificationId: notificationId,
        slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
      };
      const id: number = await reminderAgentManager.publishReminder(request);
      console.info('ReminderScheduler: published ' + title + ' id=' + String(id));
      return id;
    } catch (err) {
      const error = err as BusinessError;
      console.error('ReminderScheduler publishAlarm error: ' + error.code + ' ' + error.message);
      return -1;
    }
  }

  async cancelWaterReminder(): Promise<void> {
    if (this.waterReminderId > 0) {
      try {
        await reminderAgentManager.cancelReminder(this.waterReminderId);
      } catch (err) {
        console.error('cancelWaterReminder error');
      }
      this.waterReminderId = -1;
    }
  }

  async cancelSedentaryReminder(): Promise<void> {
    if (this.sedentaryReminderId > 0) {
      try {
        await reminderAgentManager.cancelReminder(this.sedentaryReminderId);
      } catch (err) {
        console.error('cancelSedentaryReminder error');
      }
      this.sedentaryReminderId = -1;
    }
  }

  async stopAll(): Promise<void> {
    await this.cancelWaterReminder();
    await this.cancelSedentaryReminder();
  }
}
