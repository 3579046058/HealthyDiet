import { preferences } from '@kit.ArkData';
import { GoalConfig, StreakData, AiConfig } from '../common/Constants';

// 基础存储key
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
const KEY_LAST_MOOD_PROMPT = 'last_mood_prompt_date';
const KEY_HEALTH_CARD_ORDER = 'health_card_order';
const KEY_QUICK_FUNCTION_ORDER = 'quick_function_order';
const KEY_DAILY_CALORIE = "dailyCalorie";
const KEY_AI_API_URL = 'ai_api_url';
const KEY_AI_API_KEY = 'ai_api_key';
const KEY_AI_CHAT_MODEL = 'ai_chat_model';
// 远程新增三大营养素key
const KEY_DAILY_PROTEIN = "daily_protein";
const KEY_DAILY_FAT = "daily_fat";
const KEY_DAILY_CARBS = "daily_carbs";
// 本地新增成就系统key
const KEY_ACHIEVEMENT_DAYS = 'achievement_days'; // 已解锁的成就天数列表
const KEY_ACHIEVEMENT_DATES = 'achievement_dates'; // 成就解锁日期映射（天数:日期）
const KEY_LAST_ACHIEVEMENT_CHECK_DATE = 'last_achievement_check_date'; // 上次检查成就的日期

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
      // 远程新增营养素读取
      dailyProtein: await this.pref.get(KEY_DAILY_PROTEIN, 60) as number,
      dailyFat: await this.pref.get(KEY_DAILY_FAT, 60) as number,
      dailyCarbs: await this.pref.get(KEY_DAILY_CARBS, 250) as number,
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
    // 远程新增营养素保存
    await this.pref.put(KEY_DAILY_PROTEIN, config.dailyProtein ?? 60);
    await this.pref.put(KEY_DAILY_FAT, config.dailyFat ?? 60);
    await this.pref.put(KEY_DAILY_CARBS, config.dailyCarbs ?? 250);
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

  async getLastMoodPromptDate(): Promise<string> {
    return await this.pref.get(KEY_LAST_MOOD_PROMPT, '') as string;
  }

  async setLastMoodPromptDate(date: string): Promise<void> {
    await this.pref.put(KEY_LAST_MOOD_PROMPT, date);
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

  async delete(key: string): Promise<void> {
    await this.pref.delete(key);
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
      const orderStr = await this.pref.get(KEY_HEALTH_CARD_ORDER, 'steps,calorie,sleep,water') as string;
      const arr: string[] = orderStr.split(',');
      // 校验：若存储的是旧版含 heart 的顺序，迁移为热量卡片
      if (arr.indexOf('heart') >= 0) {
        const migrated: string[] = arr.map((id: string) => id === 'heart' ? 'calorie' : id);
        await this.pref.put(KEY_HEALTH_CARD_ORDER, migrated.join(','));
        await this.pref.flush();
        return migrated;
      }
      return arr;
    } catch (err) {
      console.error('getHealthCardOrder error:', JSON.stringify(err));
      return ['steps', 'calorie', 'sleep', 'water'];
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

  // ========== 本地新增：成就系统相关方法 ==========
  async getAchievementDays(): Promise<number[]> {
    try {
      const daysStr = await this.pref.get(KEY_ACHIEVEMENT_DAYS, '') as string;
      if (daysStr === '') {
        return [];
      }
      return daysStr.split(',').map(d => parseInt(d)).filter(d => !isNaN(d));
    } catch (err) {
      console.error('getAchievementDays error:', JSON.stringify(err));
      return [];
    }
  }

  async setAchievementDays(days: number[]): Promise<void> {
    try {
      const daysStr = days.join(',');
      await this.pref.put(KEY_ACHIEVEMENT_DAYS, daysStr);
      await this.pref.flush();
    } catch (err) {
      console.error('setAchievementDays error:', JSON.stringify(err));
    }
  }

  // 获取成就解锁日期映射（天数 -> 解锁日期）
  async getAchievementDates(): Promise<Map<number, string>> {
    try {
      const datesStr = await this.pref.get(KEY_ACHIEVEMENT_DATES, '') as string;
      if (datesStr === '') {
        return new Map();
      }
      const map = new Map<number, string>();
      datesStr.split(',').forEach(pair => {
        const parts = pair.split(':');
        if (parts.length >= 2) {
          const days = parts[0];
          const date = parts[1];
          if (days && date) {
            map.set(parseInt(days), date);
          }
        }
      });
      return map;
    } catch (err) {
      console.error('getAchievementDates error:', JSON.stringify(err));
      return new Map();
    }
  }

  // 设置成就解锁日期
  async setAchievementDate(days: number, date: string): Promise<void> {
    try {
      const map = await this.getAchievementDates();
      map.set(days, date);
      const pairs: string[] = [];
      map.forEach((date, days) => {
        pairs.push(`${days}:${date}`);
      });
      await this.pref.put(KEY_ACHIEVEMENT_DATES, pairs.join(','));
      await this.pref.flush();
    } catch (err) {
      console.error('setAchievementDate error:', JSON.stringify(err));
    }
  }

  async getLastAchievementCheckDate(): Promise<string> {
    try {
      return await this.pref.get(KEY_LAST_ACHIEVEMENT_CHECK_DATE, '') as string;
    } catch (err) {
      console.error('getLastAchievementCheckDate error:', JSON.stringify(err));
      return '';
    }
  }

  async setLastAchievementCheckDate(date: string): Promise<void> {
    try {
      await this.pref.put(KEY_LAST_ACHIEVEMENT_CHECK_DATE, date);
      await this.pref.flush();
    } catch (err) {
      console.error('setLastAchievementCheckDate error:', JSON.stringify(err));
    }
  }

  async getAiConfig(): Promise<AiConfig> {
    const cfg: AiConfig = new AiConfig();
    try {
      cfg.apiUrl = await this.pref.get(KEY_AI_API_URL, '') as string;
      cfg.apiKey = await this.pref.get(KEY_AI_API_KEY, '') as string;
      cfg.chatModel = await this.pref.get(KEY_AI_CHAT_MODEL, '') as string;
    } catch (err) {
      console.error('getAiConfig error:', JSON.stringify(err));
    }
    return cfg;
  }

  async setAiConfig(cfg: AiConfig): Promise<void> {
    try {
      await this.pref.put(KEY_AI_API_URL, cfg.apiUrl);
      await this.pref.put(KEY_AI_API_KEY, cfg.apiKey);
      await this.pref.put(KEY_AI_CHAT_MODEL, cfg.chatModel);
      await this.pref.flush();
    } catch (err) {
      console.error('setAiConfig error:', JSON.stringify(err));
    }
  }
}