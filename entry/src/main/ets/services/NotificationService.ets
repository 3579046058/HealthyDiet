import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

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

  async sendWaterReminder(): Promise<void> {
    await this.publish(1001, '💧 喝水提醒', '该喝水啦！记得补充水分哦～');
  }

  async sendSedentaryReminder(): Promise<void> {
    await this.publish(1002, '🚶 久坐提醒', '起来活动一下吧！久坐不利于健康～');
  }

  async sendMedicationReminder(name: string): Promise<void> {
    await this.publish(1003, '💊 用药提醒', '该服用 ' + name + ' 了！');
  }

  async sendTestReminder(): Promise<void> {
    await this.publish(1000, '⏰ 测试通知', '这是一条系统通知，看看你是否收到了！');
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
}
