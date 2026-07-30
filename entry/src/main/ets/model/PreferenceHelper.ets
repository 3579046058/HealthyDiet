import { preferences } from '@kit.ArkData';
import { GoalConfig } from '../common/Constants';

const KEY_STEP_GOAL = 'goal_steps';
const KEY_WATER_GOAL = 'goal_water_ml';
const KEY_SPORT_DAYS = 'goal_sport_days';
const KEY_SLEEP_HOURS = 'goal_sleep_hours';
const KEY_WEIGHT_GOAL = 'goal_weight_kg';
const KEY_STEP_COUNT = 'step_count_today';
const KEY_LAST_SYNC = 'last_sync_date';

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
    };
  }

  async saveGoalConfig(config: GoalConfig): Promise<void> {
    await this.pref.put(KEY_STEP_GOAL, config.dailySteps);
    await this.pref.put(KEY_WATER_GOAL, config.dailyWaterMl);
    await this.pref.put(KEY_SPORT_DAYS, config.weeklySportDays);
    await this.pref.put(KEY_SLEEP_HOURS, config.sleepHours);
    await this.pref.put(KEY_WEIGHT_GOAL, config.weightKg);
    await this.pref.flush();
  }

  async getStepCountToday(): Promise<number> {
    return await this.pref.get(KEY_STEP_COUNT, 0) as number;
  }

  async setStepCountToday(steps: number): Promise<void> {
    await this.pref.put(KEY_STEP_COUNT, steps);
    await this.pref.flush();
  }

  async getLastSyncDate(): Promise<string> {
    return await this.pref.get(KEY_LAST_SYNC, '') as string;
  }

  async setLastSyncDate(date: string): Promise<void> {
    await this.pref.put(KEY_LAST_SYNC, date);
    await this.pref.flush();
  }
}
