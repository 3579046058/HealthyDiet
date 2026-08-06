import { NotificationService } from './NotificationService';
import { GlobalData } from '../common/GlobalData';
import { GoalConfig } from '../common/Constants';

/**
 * 目标达成通知辅助类
 * 负责检测目标达成并发送通知，避免重复通知
 */
export class GoalNotificationHelper {
  private static instance: GoalNotificationHelper;

  static getInstance(): GoalNotificationHelper {
    if (!GoalNotificationHelper.instance) {
      GoalNotificationHelper.instance = new GoalNotificationHelper();
    }
    return GoalNotificationHelper.instance;
  }

  /**
   * 检查步数目标达成并发送通知（同一天只通知一次，持久化防重）
   * @param currentSteps 当前步数
   */
  async checkStepsGoal(currentSteps: number): Promise<void> {
    try {
      // 检查通知是否启用
      const notifyEnabledRaw: string | number | boolean = await GlobalData.prefs.get('goal_steps_notify', 'true');
      if (String(notifyEnabledRaw) !== 'true') {
        return;
      }
      
      // 持久化防重：同一天已通知过则不再通知（应用重启也不重复）
      const today: string = this.getTodayStr();
      const notifiedDate: string | number | boolean = await GlobalData.prefs.get('steps_goal_notified_date', '');
      if (String(notifiedDate) === today) {
        return;
      }
      
      // 获取步数目标
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      const goalSteps: number = goalConfig.dailySteps;
      
      // 检查是否达到目标
      if (currentSteps >= goalSteps && goalSteps > 0) {
        // 发送通知
        await NotificationService.getInstance().notifyStepsGoalAchieved(currentSteps);
        await GlobalData.prefs.put('steps_goal_notified_date', today);
        await GlobalData.prefs.flush();
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
      // 检查通知是否启用
      const notifyEnabledRaw: string | number | boolean = await GlobalData.prefs.get('goal_sport_notify', 'true');
      if (String(notifyEnabledRaw) !== 'true') {
        return;
      }
      
      // 持久化防重：同一天已通知过则不再通知
      const today: string = this.getTodayStr();
      const notifiedDate: string | number | boolean = await GlobalData.prefs.get('sport_goal_notified_date', '');
      if (String(notifiedDate) === today) {
        return;
      }
      
      // 获取运动目标
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      const goalSportDays: number = goalConfig.weeklySportDays;
      
      // 检查是否达到目标
      if (sportDays >= goalSportDays && goalSportDays > 0) {
        // 发送通知
        await NotificationService.getInstance().notifySportGoalAchieved(sportDays);
        await GlobalData.prefs.put('sport_goal_notified_date', today);
        await GlobalData.prefs.flush();
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
      // 检查通知是否启用
      const notifyEnabledRaw: string | number | boolean = await GlobalData.prefs.get('goal_sleep_notify', 'true');
      if (String(notifyEnabledRaw) !== 'true') {
        return;
      }
      
      // 持久化防重：同一天已通知过则不再通知
      const today: string = this.getTodayStr();
      const notifiedDate: string | number | boolean = await GlobalData.prefs.get('sleep_goal_notified_date', '');
      if (String(notifiedDate) === today) {
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
        await GlobalData.prefs.put('sleep_goal_notified_date', today);
        await GlobalData.prefs.flush();
        console.info('[GoalNotificationHelper] 睡眠目标达成通知已发送: ' + (sleepSeconds / 3600).toFixed(1) + 'h/' + goalSleepHours + 'h');
      }
    } catch (err) {
      console.error('[GoalNotificationHelper] checkSleepGoal error:', JSON.stringify(err));
    }
  }

  private getTodayStr(): string {
    const now = new Date();
    return now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') + '-' + String(now.getDate()).padStart(2, '0');
  }
}
