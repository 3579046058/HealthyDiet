import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { GlobalData } from '../common/GlobalData';

export class ReminderScheduler {
  private static instance: ReminderScheduler;
  private context: common.UIAbilityContext | null = null;
  private waterReminderIds: number[] = [];

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
      const waterTimeRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_time', '10:00');
      const waterTimes: string[] = String(waterTimeRaw).split(',').filter((t: string) => t.length > 0);
      if (String(waterEnabledRaw) === 'true') {
        this.scheduleWaterReminder(waterTimes.length > 0 ? waterTimes : ['10:00']);
      }
      // 打卡提醒（默认 20:00）
      const checkinEnabledRaw: string | number | boolean = await GlobalData.prefs.get('checkin_reminder_enabled', 'false');
      if (String(checkinEnabledRaw) === 'true') {
        const checkinTimeRaw: string | number | boolean = await GlobalData.prefs.get('checkin_reminder_time', '20:00');
        this.scheduleCheckinReminder(String(checkinTimeRaw));
      }
    } catch (err) {
      console.error('ReminderScheduler startAll error:', JSON.stringify(err));
    }
  }

  async setWaterTimes(times: string[]): Promise<void> {
    const list: string[] = times.filter((t: string) => t.length > 0);
    await GlobalData.prefs.put('water_reminder_time', list.join(','));
    const enabledRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_enabled', 'false');
    if (String(enabledRaw) === 'true') {
      this.scheduleWaterReminder(list.length > 0 ? list : ['10:00']);
    }
  }

  async toggleWaterReminder(enabled: boolean): Promise<void> {
    await GlobalData.prefs.put('water_reminder_enabled', String(enabled));
    if (enabled) {
      const timeRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_time', '10:00');
      const times: string[] = String(timeRaw).split(',').filter((t: string) => t.length > 0);
      this.scheduleWaterReminder(times.length > 0 ? times : ['10:00']);
    } else {
      this.cancelWaterReminder();
    }
  }

  async scheduleWaterReminder(times: string[]): Promise<void> {
    this.cancelWaterReminder();
    const ids: number[] = [];
    for (const time of times) {
      const h: number = this.parseHour(time);
      const m: number = this.parseMinute(time);
      const id: number = await this.publishAlarm(h, m, 1001, '💧 喝水提醒', '该喝水啦！记得补充水分哦～');
      if (id > 0) {
        ids.push(id);
      }
    }
    this.waterReminderIds = ids;
  }

  /**
   * 发布用药提醒（支持一天多个时间点 + 指定星期）
   * @param times 时间点列表，如 ["08:00","12:00","18:00"]
   * @param name 药品名称
   * @param oldReminderIds 该药品之前发布的 reminderId 列表（先取消旧的）
   * @param daysOfWeek 提醒星期（1=周一 ... 7=周日），默认全周
   * @returns 新发布的 reminderId 列表
   */
  async scheduleMedicationReminder(times: string[], name: string, oldReminderIds: number[],
    daysOfWeek: number[] = [1, 2, 3, 4, 5, 6, 7]): Promise<number[]> {
    // 1. 先取消旧的提醒
    for (const id of oldReminderIds) {
      if (id > 0) {
        try {
          await reminderAgentManager.cancelReminder(id);
        } catch (err) {
          console.error('scheduleMedicationReminder cancel old id=' + String(id) + ' error');
        }
      }
    }
    // 2. 为每个时间点发布一个闹铃（按选定星期重复）
    const newIds: number[] = [];
    for (const time of times) {
      const h: number = this.parseHour(time);
      const m: number = this.parseMinute(time);
      const id: number = await this.publishAlarm(h, m, 1003, '💊 用药提醒', '该服用 ' + name + ' 了！', daysOfWeek);
      if (id > 0) {
        newIds.push(id);
      }
    }
    return newIds;
  }

  /**
   * 发布睡眠提醒（单时间点）
   * @param time 提醒时间，如 "22:30"
   * @returns 新发布的 reminderId
   */
  async scheduleSleepReminder(time: string): Promise<number> {
    // 先取消旧的睡眠提醒
    await this.cancelSleepReminder();
    
    const h: number = this.parseHour(time);
    const m: number = this.parseMinute(time);
    const id: number = await this.publishAlarm(h, m, 1004, '🌙 睡眠提醒', '该睡觉啦！保持规律作息有助于健康');
    return id;
  }

  async cancelSleepReminder(): Promise<void> {
    try {
      const idRaw: string | number | boolean = await GlobalData.prefs.get('sleep_reminder_id', -1);
      const id: number = Number(idRaw);
      if (id > 0) {
        await reminderAgentManager.cancelReminder(id);
        await GlobalData.prefs.put('sleep_reminder_id', -1);
      }
    } catch (err) {
      console.error('cancelSleepReminder error:', JSON.stringify(err));
    }
  }

  /**
   * 发布打卡提醒（单时间点，默认 20:00）
   * @param time 提醒时间，如 "20:00"
   */
  async scheduleCheckinReminder(time: string): Promise<number> {
    await this.cancelCheckinReminder();
    const h: number = this.parseHour(time);
    const m: number = this.parseMinute(time);
    const id: number = await this.publishAlarm(h, m, 1005, '📝 打卡提醒', '今天还没有打卡，记得记录健康数据完成打卡哦！');
    if (id > 0) {
      await GlobalData.prefs.put('checkin_reminder_id', id);
    }
    return id;
  }

  async cancelCheckinReminder(): Promise<void> {
    try {
      const idRaw: string | number | boolean = await GlobalData.prefs.get('checkin_reminder_id', -1);
      const id: number = Number(idRaw);
      if (id > 0) {
        await reminderAgentManager.cancelReminder(id);
        await GlobalData.prefs.put('checkin_reminder_id', -1);
      }
    } catch (err) {
      console.error('cancelCheckinReminder error:', JSON.stringify(err));
    }
  }

  private parseHour(time: string): number {
    const parts: string[] = time.split(':');
    return parseInt(parts[0]) || 10;
  }

  private parseMinute(time: string): number {
    const parts: string[] = time.split(':');
    return parseInt(parts[1]) || 0;
  }

  private async publishAlarm(hour: number, minute: number, notificationId: number, title: string, content: string,
    daysOfWeek: number[] = [1, 2, 3, 4, 5, 6, 7]): Promise<number> {
    try {
      const request: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: hour,
        minute: minute,
        daysOfWeek: daysOfWeek,
        wantAgent: {
          pkgName: 'com.yourcompany.healthapp',
          abilityName: 'EntryAbility'
        },
        maxScreenWantAgent: {
          pkgName: 'com.yourcompany.healthapp',
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
    await this.cancelMedicationReminders(this.waterReminderIds);
    this.waterReminderIds = [];
  }

  // 取消一批提醒（用药提醒删除时用）
  async cancelMedicationReminders(ids: number[]): Promise<void> {
    for (const id of ids) {
      if (id > 0) {
        try {
          await reminderAgentManager.cancelReminder(id);
        } catch (err) {
          console.error('cancelMedicationReminders id=' + String(id) + ' error');
        }
      }
    }
  }

  async stopAll(): Promise<void> {
    await this.cancelWaterReminder();
  }
}
