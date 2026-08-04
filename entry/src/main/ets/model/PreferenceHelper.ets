import { preferences } from '@kit.ArkData';
import { GoalConfig, StreakData } from '../common/Constants';

const KEY_STEP_GOAL = 'goal_steps';
const KEY_WATER_GOAL = 'goal_water_ml';
const KEY_SPORT_DAYS = 'goal_sport_days';
const KEY_SLEEP_HOURS = 'goal_sleep_hours';
const KEY_WEIGHT_GOAL = 'goal_weight_kg';
const KEY_HEIGHT_CM = 'height_cm';
const KEY_THEME = 'theme_mode';
const KEY_STEP_COUNT = 'step_count_today';
const KEY_STREAK_CURRENT = 'streak_current';
const KEY_STREAK_BEST = 'streak_best';
const KEY_LAST_ACTIVE_DATE = 'last_active_date';
const KEY_WEIGHT_SKIP_PROMPT = 'weight_skip_prompt';
const KEY_WEIGHT_CONFIGURED = 'weight_configured';
const KEY_GENDER = 'gender';
const KEY_HEALTH_CARD_ORDER = 'health_card_order';
const KEY_QUICK_FUNCTION_ORDER = 'quick_function_order';
const KEY_DAILY_CALORIE = "dailyCalorie";

export class PreferenceHelper {
  private pref_: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    this.pref_ = await preferences.getPreferences(context, 'health_preferences');
  }

  private get pref(): preferences.Preferences {
    if (!this.pref_) {
      throw new Error('Preferences not initialized');
    }
    return this.pref_;
  }

  async getGoalConfig(): Promise<GoalConfig> {
    return {
      dailySteps: await this.pref.get(KEY_STEP_GOAL, 8000) as number,
      dailyWaterMl: await this.pref.get(KEY_WATER_GOAL, 2000) as number,
      weeklySportDays: await this.pref.get(KEY_SPORT_DAYS, 3) as number,
      sleepHours: await this.pref.get(KEY_SLEEP_HOURS, 8) as number,
      weightKg: await this.pref.get(KEY_WEIGHT_GOAL, 70) as number,
      heightCm: await this.pref.get(KEY_HEIGHT_CM, 170) as number,
      dailyCalorie: await this.pref.getSync(KEY_DAILY_CALORIE,2000) as number,
    };
  }

  async saveGoalConfig(config: GoalConfig): Promise<void> {
    await this.pref.put(KEY_STEP_GOAL, config.dailySteps);
    await this.pref.put(KEY_WATER_GOAL, config.dailyWaterMl);
    await this.pref.put(KEY_SPORT_DAYS, config.weeklySportDays);
    await this.pref.put(KEY_SLEEP_HOURS, config.sleepHours);
    await this.pref.put(KEY_WEIGHT_GOAL, config.weightKg);
    await this.pref.put(KEY_HEIGHT_CM, config.heightCm);
    await this.pref.putSync(KEY_DAILY_CALORIE,config.dailyCalorie);
    await this.pref.flush();
  }

  async getTheme(): Promise<string> {
    return await this.pref.get(KEY_THEME, 'follow') as string;
  }

  async setTheme(theme: string): Promise<void> {
    await this.pref.put(KEY_THEME, theme);
    await this.pref.flush();
  }

  async getWeight(): Promise<number> {
    return await this.pref.get(KEY_WEIGHT_GOAL, 70) as number;
  }

  async setWeight(weightKg: number): Promise<void> {
    await this.pref.put(KEY_WEIGHT_GOAL, weightKg);
    await this.pref.flush();
  }

  async getWeightSkipPrompt(): Promise<boolean> {
    return await this.pref.get(KEY_WEIGHT_SKIP_PROMPT, false) as boolean;
  }

  async setWeightSkipPrompt(skip: boolean): Promise<void> {
    await this.pref.put(KEY_WEIGHT_SKIP_PROMPT, skip);
    await this.pref.flush();
  }

  async isWeightConfigured(): Promise<boolean> {
    return await this.pref.get(KEY_WEIGHT_CONFIGURED, false) as boolean;
  }

  async markWeightConfigured(): Promise<void> {
    await this.pref.put(KEY_WEIGHT_CONFIGURED, true);
    await this.pref.flush();
  }

  async getGender(): Promise<string> {
    return await this.pref.get(KEY_GENDER, '') as string;
  }

  async setGender(gender: string): Promise<void> {
    await this.pref.put(KEY_GENDER, gender);
    await this.pref.flush();
  }

  async get(key: string, defValue: string | number | boolean): Promise<string | number | boolean> {
    const val = await this.pref.get(key, defValue);
    if (typeof val === 'bigint') {
      return Number(val);
    }
    if (typeof val === 'number') {
      return val;
    }
    if (typeof val === 'boolean') {
      return val;
    }
    return String(val);
  }

  async put(key: string, value: string | number | boolean): Promise<void> {
    if (typeof value === 'string') {
      await this.pref.put(key, value);
    } else if (typeof value === 'number') {
      await this.pref.put(key, value);
    } else {
      await this.pref.put(key, value);
    }
  }

  async flush(): Promise<void> {
    await this.pref.flush();
  }

  async setStepCountToday(steps: number): Promise<void> {
    await this.pref.put(KEY_STEP_COUNT, steps);
    await this.pref.flush();
  }

  async getStreakData(): Promise<StreakData> {
    const current = await this.pref.get(KEY_STREAK_CURRENT, 0) as number;
    const best = await this.pref.get(KEY_STREAK_BEST, 0) as number;
    return { current, best };
  }

  async updateStreak(achieved: boolean): Promise<StreakData> {
    const lastActive = await this.pref.get(KEY_LAST_ACTIVE_DATE, '') as string;
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

    let current = await this.pref.get(KEY_STREAK_CURRENT, 0) as number;
    let best = await this.pref.get(KEY_STREAK_BEST, 0) as number;

    if (lastActive === todayStr) {
      return { current, best };
    }

    const yesterday = new Date(today.getTime() - 86400000);
    const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;

    if (achieved) {
      if (lastActive === yesterdayStr || lastActive === '') {
        current++;
      } else {
        current = 1;
      }
      if (current > best) {
        best = current;
      }
    } else {
      current = 0;
    }

    await this.pref.put(KEY_STREAK_CURRENT, current);
    await this.pref.put(KEY_STREAK_BEST, best);
    await this.pref.put(KEY_LAST_ACTIVE_DATE, todayStr);
    await this.pref.flush();

    return { current, best };
  }

  // 健康卡片顺序相关
  async getHealthCardOrder(): Promise<string[]> {
    try {
      const orderStr = await this.pref.get(KEY_HEALTH_CARD_ORDER, 'steps,heart,sleep,water') as string;
      return orderStr.split(',');
    } catch (err) {
      console.error('getHealthCardOrder error:', JSON.stringify(err));
      return ['steps', 'heart', 'sleep', 'water'];
    }
  }

  async setHealthCardOrder(order: string[]): Promise<void> {
    try {
      const orderStr = order.join(',');
      await this.pref.put(KEY_HEALTH_CARD_ORDER, orderStr);
      await this.pref.flush();
    } catch (err) {
      console.error('setHealthCardOrder error:', JSON.stringify(err));
    }
  }

  // 快捷功能顺序相关
  async getQuickFunctionOrder(): Promise<string[]> {
    try {
      const orderStr = await this.pref.get(KEY_QUICK_FUNCTION_ORDER, 'sport,weight,report,goal,diet,women,medication,mood') as string;
      return orderStr.split(',');
    } catch (err) {
      console.error('getQuickFunctionOrder error:', JSON.stringify(err));
      return ['sport', 'weight', 'report', 'goal', 'diet', 'women', 'medication', 'mood'];
    }
  }

  async setQuickFunctionOrder(order: string[]): Promise<void> {
    try {
      const orderStr = order.join(',');
      await this.pref.put(KEY_QUICK_FUNCTION_ORDER, orderStr);
      await this.pref.flush();
    } catch (err) {
      console.error('setQuickFunctionOrder error:', JSON.stringify(err));
    }
  }
}
