import { NotificationService } from './NotificationService';
import { GlobalData } from '../common/GlobalData';
import { GoalConfig } from '../common/Constants';

/**
 * 目标达成通知辅助类
 * 负责检测目标达成并发送通知，避免重复通知
 */
export class GoalNotificationHelper {
  private static instance: GoalNotificationHelper;
  
  // 记录今天是否已发送过目标达成通知
  private stepsGoalNotifiedToday: boolean = false;
  private sportGoalNotifiedToday: boolean = false;
  private sleepGoalNotifiedToday: boolean = false;
  private lastCheckDate: string = '';

  static getInstance(): GoalNotificationHelper {
    if (!GoalNotificationHelper.instance) {
      GoalNotificationHelper.instance = new GoalNotificationHelper();
    }
    return GoalNotificationHelper.instance;
  }

  /**
   * 检查步数目标达成并发送通知
   * @param currentSteps 当前步数
   */
  async checkStepsGoal(currentSteps: number): Promise<void> {
    try {
      // 检查是否是新的一天，重置通知标记
      this.checkAndResetDailyFlags();
      
      // 检查通知是否启用
      const notifyEnabledRaw: string | number | boolean = await GlobalData.prefs.get('goal_steps_notify', 'true');
      if (String(notifyEnabledRaw) !== 'true') {
        return;
      }
      
      // 如果今天已经通知过，不再通知
      if (this.stepsGoalNotifiedToday) {
        return;
      }
      
      // 获取步数目标
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      const goalSteps: number = goalConfig.dailySteps;
      
      // 检查是否达到目标
      if (currentSteps >= goalSteps && goalSteps > 0) {
        // 发送通知
        await NotificationService.getInstance().notifyStepsGoalAchieved(currentSteps);
        this.stepsGoalNotifiedToday = true;
        console.info('[GoalNotificationHelper] 步数目标达成通知已发送: ' + currentSteps + '/' + goalSteps);
      }
    } catch (err) {
      console.error('[GoalNotificationHelper] checkStepsGoal error:', JSON.stringify(err));
    }
  }

  /**
   * 检查运动目标达成并发送通知
   * @param sportDays 本周运动天数
   */
  async checkSportGoal(sportDays: number): Promise<void> {
    try {
      // 检查是否是新的一天，重置通知标记
      this.checkAndResetDailyFlags();
      
      // 检查通知是否启用
      const notifyEnabledRaw: string | number | boolean = await GlobalData.prefs.get('goal_sport_notify', 'true');
      if (String(notifyEnabledRaw) !== 'true') {
        return;
      }
      
      // 如果今天已经通知过，不再通知
      if (this.sportGoalNotifiedToday) {
        return;
      }
      
      // 获取运动目标
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      const goalSportDays: number = goalConfig.weeklySportDays;
      
      // 检查是否达到目标
      if (sportDays >= goalSportDays && goalSportDays > 0) {
        // 发送通知
        await NotificationService.getInstance().notifySportGoalAchieved(sportDays);
        this.sportGoalNotifiedToday = true;
        console.info('[GoalNotificationHelper] 运动目标达成通知已发送: ' + sportDays + '/' + goalSportDays);
      }
    } catch (err) {
      console.error('[GoalNotificationHelper] checkSportGoal error:', JSON.stringify(err));
    }
  }

  /**
   * 检查睡眠目标达成并发送通知
   * @param sleepSeconds 睡眠时长（秒）
   */
  async checkSleepGoal(sleepSeconds: number): Promise<void> {
    try {
      // 检查是否是新的一天，重置通知标记
      this.checkAndResetDailyFlags();
      
      // 检查通知是否启用
      const notifyEnabledRaw: string | number | boolean = await GlobalData.prefs.get('goal_sleep_notify', 'true');
      if (String(notifyEnabledRaw) !== 'true') {
        return;
      }
      
      // 如果今天已经通知过，不再通知
      if (this.sleepGoalNotifiedToday) {
        return;
      }
      
      // 获取睡眠目标（小时）
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      const goalSleepHours: number = goalConfig.sleepHours;
      const goalSleepSeconds: number = goalSleepHours * 3600;
      
      // 检查是否达到目标
      if (sleepSeconds >= goalSleepSeconds && goalSleepHours > 0) {
        // 发送通知
        await NotificationService.getInstance().notifySleepGoalAchieved(sleepSeconds);
        this.sleepGoalNotifiedToday = true;
        console.info('[GoalNotificationHelper] 睡眠目标达成通知已发送: ' + (sleepSeconds / 3600).toFixed(1) + 'h/' + goalSleepHours + 'h');
      }
    } catch (err) {
      console.error('[GoalNotificationHelper] checkSleepGoal error:', JSON.stringify(err));
    }
  }

  /**
   * 检查是否是新的一天，如果是则重置通知标记
   */
  private checkAndResetDailyFlags(): void {
    const today = this.getTodayStr();
    if (today !== this.lastCheckDate) {
      this.lastCheckDate = today;
      this.stepsGoalNotifiedToday = false;
      this.sportGoalNotifiedToday = false;
      this.sleepGoalNotifiedToday = false;
      console.info('[GoalNotificationHelper] 新的一天，重置通知标记');
    }
  }

  private getTodayStr(): string {
    const now = new Date();
    return now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') + '-' + String(now.getDate()).padStart(2, '0');
  }
}
