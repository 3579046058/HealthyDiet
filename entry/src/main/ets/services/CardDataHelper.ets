import { formBindingData, formProvider } from '@kit.FormKit';
import { GlobalData } from '../common/GlobalData';
import { DbRow, GoalConfig } from '../common/Constants';
import { HealthScoreUtil } from './HealthScoreUtil';

export interface CardFormFields {
  steps: string;
  stepGoal: string;
  stepPercent: string;
  heartRate: string;
  waterMl: string;
  waterGoal: string;
  date: string;
  sleepPercent: string;
  moodPercent: string;
  stepValue: string;
  sleepValue: string;
  moodValue: string;
  healthScore: string;
  scoreColor: string;
  isSleeping: string;
  updateTime: string;
}

/**
 * 桌面卡片数据组装（HealthFormAbility 和页面共用，保证数据一致完整）
 */
export class CardDataHelper {
  static async buildFormData(context: Context): Promise<formBindingData.FormBindingData> {
    try {
      await GlobalData.init(context);
    } catch (err) {
      console.error('CardDataHelper init error:', JSON.stringify(err));
    }
    const defaultData: CardFormFields = {
      steps: '0',
      stepGoal: '8000',
      stepPercent: '0',
      heartRate: '--',
      waterMl: '0',
      waterGoal: '2000',
      date: '',
      sleepPercent: '0',
      moodPercent: '0',
      stepValue: '--',
      sleepValue: '--',
      moodValue: '--',
      healthScore: '0',
      scoreColor: '#4CAF50',
      isSleeping: 'false',
      updateTime: ''
    };
    try {
      const today = await GlobalData.getTodayDate();
      // 并行执行相互独立的 DB 查询，避免串行等待拖慢卡片刷新
      const results = await Promise.all([
        GlobalData.prefs.getGoalConfig(),
        GlobalData.db.getDailySummary(today),
        GlobalData.db.getLatestSleepStartRecord(),
        GlobalData.db.getMoodRecords(today, today),
        HealthScoreUtil.getCalorieIntake(today)
      ]);
      const config = results[0] as GoalConfig;
      const summary = results[1] as DbRow | null;
      const latestSleep = results[2] as DbRow | null;
      const moodRows = results[3] as DbRow[];
      const calorieIntake = results[4] as number;

      const steps = summary?.steps ? Number(summary.steps) : 0;
      const heartRate = summary?.heart_rate_avg ? Number(summary.heart_rate_avg) : 72;
      const waterMl = summary?.water_ml ? Number(summary.water_ml) : 0;
      const sleepHours = summary?.sleep_hours ? Number(summary.sleep_hours) : 0;
      const sleepScore = summary?.sleep_score ? Number(summary.sleep_score) : 0;
      const stepGoal = config.dailySteps;
      const waterGoal = config.dailyWaterMl;
      const stepPercent = stepGoal > 0 ? Math.round(steps / stepGoal * 100) : 0;
      const sleepPercent = Math.min(100, Math.round(sleepHours / 8 * 100));

      // 心情
      let moodVal = 0;
      if (moodRows.length > 0) {
        const lastMood = moodRows[moodRows.length - 1];
        moodVal = Number(lastMood.mood) || 0;
      }
      const moodPercent = Math.min(100, Math.round((moodVal / 5) * 100));
      const moodValue = moodVal > 0 ? CardDataHelper.moodEmoji(moodVal) : '--';

      // 健康评分（与应用首页统一的加权累加 + 短板加权算法）
      const exerciseMin = summary?.exercise_minutes ? Number(summary.exercise_minutes) : 0;
      const hasData = steps > 0 || sleepScore > 0 || waterMl > 0 || exerciseMin > 0;
      const score = hasData ? HealthScoreUtil.calcByData(steps, stepGoal, sleepScore, waterMl, waterGoal,
        exerciseMin, calorieIntake, config.dailyCalorie) : 0;
      const scoreColor = !hasData ? '#9E9E9E' : (score >= 80 ? '#4CAF50' : (score >= 60 ? '#FF9800' : (score >= 40 ? '#FFC107' : '#F44336')));
      const scoreValue = hasData ? String(score) : '--';

      const stepValue = steps > 0 ? String(steps) : '--';
      const sleepValue = sleepHours > 0 ? sleepHours.toFixed(1) + 'h' : '--';

      // 生成更新时间（HH:MM 格式）
      const now = new Date();
      const updateTime = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');

      const formData: CardFormFields = {
        steps: String(steps),
        stepGoal: String(stepGoal),
        stepPercent: String(stepPercent),
        heartRate: String(heartRate),
        waterMl: String(waterMl),
        waterGoal: String(waterGoal),
        date: today,
        sleepPercent: String(sleepPercent),
        moodPercent: String(moodPercent),
        stepValue: stepValue,
        sleepValue: sleepValue,
        moodValue: moodValue,
        healthScore: scoreValue,
        scoreColor: scoreColor,
        isSleeping: latestSleep ? 'true' : 'false',
        updateTime: updateTime
      };
      return formBindingData.createFormBindingData(formData);
    } catch (err) {
      console.error('CardDataHelper buildFormData error:', JSON.stringify(err));
      return formBindingData.createFormBindingData(defaultData);
    }
  }

  static moodEmoji(mood: number): string {
    if (mood >= 4.5) { return '😄'; }
    if (mood >= 3.5) { return '🙂'; }
    if (mood >= 2.5) { return '😐'; }
    if (mood >= 1.5) { return '😔'; }
    return '😢';
  }

  /**
   * 刷新桌面小组件数据（带节流：2 秒内多次调用只执行一次，避免频繁刷新）
   * 在任何健康数据更新后调用此方法
   */
  static lastRefreshTs: number = 0;
  static async refreshWidget(context: Context): Promise<void> {
    const now = Date.now();
    if (now - CardDataHelper.lastRefreshTs < 2000) {
      return;
    }
    CardDataHelper.lastRefreshTs = now;
    try {
      const raw = await GlobalData.prefs.get('card_form_id', '');
      const formId = typeof raw === 'string' ? raw : '';
      if (formId.length > 0) {
        const formData = await CardDataHelper.buildFormData(context);
        await formProvider.updateForm(formId, formData);
      }
    } catch (err) {
      console.error('CardDataHelper refreshWidget error:', JSON.stringify(err));
    }
  }
}
