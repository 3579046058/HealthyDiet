import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { GlobalData } from '../common/GlobalData';

// 通知ID常量类
export class NOTIFICATION_ID {
  static readonly WATER_REMINDER: number = 1001;
  static readonly MEDICATION_REMINDER: number = 1003;
  static readonly SLEEP_REMINDER: number = 1004;
  static readonly SPORT_TRACKING: number = 2001;      // 后台运动追踪（持续通知）
  static readonly SLEEP_TRACKING: number = 2002;      // 后台睡眠追踪（持续通知）
  static readonly SPORT_STATUS: number = 3001;        // 运动状态通知
  static readonly SLEEP_STATUS: number = 3002;        // 睡眠状态通知
  static readonly GOAL_ACHIEVED: number = 4001;       // 目标达成通知
  static readonly ACHIEVEMENT: number = 5001;         // 成就解锁通知
}

export class NotificationService {
  private static instance: NotificationService;
  private context: common.UIAbilityContext | null = null;

  static getInstance(): NotificationService {
    if (!NotificationService.instance) {
      NotificationService.instance = new NotificationService();
    }
    return NotificationService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async checkEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (err) {
      console.error('NotificationService checkEnabled error:', JSON.stringify(err));
      return false;
    }
  }

  async requestEnable(): Promise<void> {
    if (!this.context) {
      return;
    }
    try {
      const enabled: boolean = await this.checkEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(this.context);
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error('NotificationService requestEnable error: ' + error.code + ' ' + error.message);
    }
  }

  // ===== 基础提醒通知 =====
  async sendWaterReminder(): Promise<void> {
    await this.publish(NOTIFICATION_ID.WATER_REMINDER, '💧 喝水提醒', '该喝水啦！记得补充水分哦～');
  }

  async sendMedicationReminder(name: string): Promise<void> {
    await this.publish(NOTIFICATION_ID.MEDICATION_REMINDER, '💊 用药提醒', '该服用 ' + name + ' 了！');
  }

  async sendSleepReminder(): Promise<void> {
    await this.publish(NOTIFICATION_ID.SLEEP_REMINDER, '🌙 睡眠提醒', '该睡觉啦！保持规律作息有助于健康');
  }

  async sendTestReminder(): Promise<void> {
    await this.publish(1000, '⏰ 测试通知', '这是一条系统通知，看看你是否收到了！');
  }

  // ===== 后台运动追踪通知（持续通知） =====
  async showSportTrackingNotification(sport: string, duration: number, distance: number): Promise<void> {
    if (!await this.isNotifyEnabled('sport_tracking_notify')) {
      return;
    }
    const durationStr: string = this.formatDuration(duration);
    const distanceStr: string = distance > 0 ? distance.toFixed(2) + 'km' : '--';
    const title: string = '🏃 正在后台追踪运动';
    const text: string = sport + ' · ' + durationStr + ' · ' + distanceStr;
    await this.publishOngoing(NOTIFICATION_ID.SPORT_TRACKING, title, text);
  }

  async updateSportTrackingNotification(sport: string, duration: number, distance: number): Promise<void> {
    await this.showSportTrackingNotification(sport, duration, distance);
  }

  async cancelSportTrackingNotification(): Promise<void> {
    await this.cancel(NOTIFICATION_ID.SPORT_TRACKING);
  }

  // ===== 后台睡眠追踪通知（持续通知） =====
  async showSleepTrackingNotification(startTime: string): Promise<void> {
    if (!await this.isNotifyEnabled('sleep_tracking_notify')) {
      return;
    }
    const title: string = '🌙 正在追踪睡眠';
    const text: string = '入睡时间：' + startTime;
    await this.publishOngoing(NOTIFICATION_ID.SLEEP_TRACKING, title, text);
  }

  async cancelSleepTrackingNotification(): Promise<void> {
    await this.cancel(NOTIFICATION_ID.SLEEP_TRACKING);
  }

  // ===== 运动状态通知 =====
  async notifySportStarted(sport: string): Promise<void> {
    await this.publish(NOTIFICATION_ID.SPORT_STATUS, '🏃 ' + sport + '已开始', '正在追踪您的运动数据');
  }

  async notifySportPaused(sport: string, duration: number, distance: number): Promise<void> {
    const durationStr: string = this.formatDuration(duration);
    const distanceStr: string = distance > 0 ? distance.toFixed(2) + 'km' : '--';
    await this.publish(NOTIFICATION_ID.SPORT_STATUS, '⏸️ 运动已暂停',
      '时长：' + durationStr + '，距离：' + distanceStr);
  }

  async notifySportCompleted(sport: string, duration: number, distance: number, calories: number): Promise<void> {
    const durationStr: string = this.formatDuration(duration);
    const distanceStr: string = distance > 0 ? distance.toFixed(2) + 'km' : '--';
    await this.publish(NOTIFICATION_ID.SPORT_STATUS, '✅ ' + sport + '已完成',
      '时长：' + durationStr + '，距离：' + distanceStr + '，消耗：' + Math.round(calories) + '卡');
  }

  async notifyGPSLost(): Promise<void> {
    await this.publish(NOTIFICATION_ID.SPORT_STATUS, '⚠️ GPS信号丢失', '无法追踪距离，请移动到开阔区域');
  }

  // ===== 睡眠状态通知 =====
  async notifySleepStarted(time: string): Promise<void> {
    await this.publish(NOTIFICATION_ID.SLEEP_STATUS, '🌙 睡眠追踪已开始', '入睡时间：' + time);
  }

  async notifySleepCompleted(duration: number, score: number): Promise<void> {
    const durationStr: string = this.formatDuration(duration);
    await this.publish(NOTIFICATION_ID.SLEEP_STATUS, '☀️ 早安！睡眠已记录',
      '睡眠时长：' + durationStr + '，评分：' + score + '分');
  }

  // ===== 目标达成通知 =====
  async notifyStepsGoalAchieved(steps: number): Promise<void> {
    if (!await this.isNotifyEnabled('goal_steps_notify')) {
      return;
    }
    await this.publish(NOTIFICATION_ID.GOAL_ACHIEVED, '🎉 步数目标已达成！', '今日已走 ' + steps + ' 步');
  }

  async notifySportGoalAchieved(days: number): Promise<void> {
    if (!await this.isNotifyEnabled('goal_sport_notify')) {
      return;
    }
    await this.publish(NOTIFICATION_ID.GOAL_ACHIEVED, '🎉 运动目标已达成！', '本周已运动 ' + days + ' 天');
  }

  async notifySleepGoalAchieved(duration: number): Promise<void> {
    if (!await this.isNotifyEnabled('goal_sleep_notify')) {
      return;
    }
    const hours: number = Math.floor(duration / 3600);
    const minutes: number = Math.floor((duration % 3600) / 60);
    const durationStr: string = hours > 0 ? hours + '小时' + minutes + '分钟' : minutes + '分钟';
    await this.publish(NOTIFICATION_ID.GOAL_ACHIEVED, '🎉 睡眠目标已达成！', '今日睡眠 ' + durationStr);
  }

  // ===== 成就解锁通知 =====
  async notifyAchievementUnlocked(name: string, description: string): Promise<void> {
    if (!await this.isNotifyEnabled('achievement_notify')) {
      return;
    }
    await this.publish(NOTIFICATION_ID.ACHIEVEMENT, '🏆 成就解锁：' + name, description);
  }

  // ===== 私有方法 =====
  // 检查通知设置页的开关是否开启（key 对应 prefs 存储）
  private async isNotifyEnabled(key: string): Promise<boolean> {
    try {
      const raw: string | number | boolean = await GlobalData.prefs.get(key, 'true');
      return String(raw) === 'true';
    } catch (err) {
      return true;
    }
  }
  private async publish(id: number, title: string, text: string): Promise<void> {
    try {
      const enabled: boolean = await this.checkEnabled();
      if (!enabled) {
        console.error('NotificationService: notifications not enabled, skip publish');
        return;
      }
      const request: notificationManager.NotificationRequest = {
        id: id,
        notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
          },
        },
      };
      await notificationManager.publish(request);
      console.info('NotificationService: published ' + title);
    } catch (err) {
      const error = err as BusinessError;
      console.error('NotificationService publish error: ' + error.code + ' ' + error.message);
    }
  }

  // 持续通知（ongoing: true，常驻通知栏）
  private async publishOngoing(id: number, title: string, text: string): Promise<void> {
    try {
      const enabled: boolean = await this.checkEnabled();
      if (!enabled) {
        console.error('NotificationService: notifications not enabled, skip publishOngoing');
        return;
      }
      const request: notificationManager.NotificationRequest = {
        id: id,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        isOngoing: true,           // 持续通知，不可滑动删除
        isUnremovable: false,      // 可手动删除
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
          },
        },
      };
      await notificationManager.publish(request);
      console.info('NotificationService: published ongoing ' + title);
    } catch (err) {
      const error = err as BusinessError;
      console.error('NotificationService publishOngoing error: ' + error.code + ' ' + error.message);
    }
  }

  async cancel(id: number): Promise<void> {
    try {
      await notificationManager.cancel(id);
      console.info('NotificationService: canceled id=' + String(id));
    } catch (err) {
      const error = err as BusinessError;
      console.error('NotificationService cancel error: ' + error.code + ' ' + error.message);
    }
  }

  async cancelAll(): Promise<void> {
    try {
      await notificationManager.cancelAll();
      console.info('NotificationService: canceled all');
    } catch (err) {
      const error = err as BusinessError;
      console.error('NotificationService cancelAll error: ' + error.code + ' ' + error.message);
    }
  }

  private formatDuration(seconds: number): string {
    const hours: number = Math.floor(seconds / 3600);
    const minutes: number = Math.floor((seconds % 3600) / 60);
    const secs: number = seconds % 60;
    if (hours > 0) {
      return hours + '小时' + minutes + '分钟';
    } else if (minutes > 0) {
      return minutes + '分钟' + secs + '秒';
    } else {
      return secs + '秒';
    }
  }
}
