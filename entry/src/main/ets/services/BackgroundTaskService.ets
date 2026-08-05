import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 后台任务管理服务
 * 用于保持应用在后台持续运行，确保定时任务正常执行
 */
export class BackgroundTaskService {
  private static instance: BackgroundTaskService;
  private context: common.UIAbilityContext | null = null;
  private isRunning: boolean = false;

  static getInstance(): BackgroundTaskService {
    if (!BackgroundTaskService.instance) {
      BackgroundTaskService.instance = new BackgroundTaskService();
    }
    return BackgroundTaskService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 启动后台长时任务
   * @param taskName 任务名称
   * @returns 是否启动成功
   */
  async startBackgroundTask(taskName: string = 'HealthTracking'): Promise<boolean> {
    if (!this.context) {
      console.error('BackgroundTaskService: context not set');
      return false;
    }

    if (this.isRunning) {
      console.info('BackgroundTaskService: already running');
      return true;
    }

    try {
      // 创建 WantAgent，用于点击通知时打开应用
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: this.context.applicationInfo.name,
            abilityName: 'EntryAbility'
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const agent: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);

      // 请求后台长时任务（数据传输模式）
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        ['dataTransfer'],  // 数据传输模式，用于后台同步健康数据
        agent
      );

      this.isRunning = true;
      console.info('BackgroundTaskService started, taskName=' + taskName);
      return true;
    } catch (err) {
      const error = err as BusinessError;
      console.error('BackgroundTaskService startBackgroundTask error: code=' + error.code + ', message=' + error.message);
      return false;
    }
  }

  /**
   * 停止后台长时任务
   */
  async stopBackgroundTask(): Promise<void> {
    if (!this.isRunning || !this.context) {
      console.info('BackgroundTaskService: not running');
      return;
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.isRunning = false;
      console.info('BackgroundTaskService stopped');
    } catch (err) {
      const error = err as BusinessError;
      console.error('BackgroundTaskService stopBackgroundTask error: code=' + error.code + ', message=' + error.message);
    }
  }

  /**
   * 检查后台任务是否正在运行
   */
  isBackgroundTaskRunning(): boolean {
    return this.isRunning;
  }

  /**
   * 请求后台通知权限
   */
  async requestNotificationPermission(): Promise<boolean> {
    if (!this.context) {
      console.error('BackgroundTaskService: context not set');
      return false;
    }

    try {
      const isEnabled = await notificationManager.isNotificationEnabled();
      if (!isEnabled) {
        await notificationManager.requestEnableNotification(this.context);
      }
      console.info('BackgroundTaskService: notification permission granted');
      return true;
    } catch (err) {
      console.error('BackgroundTaskService requestNotificationPermission error: ' + JSON.stringify(err));
      return false;
    }
  }
}
