import { relationalStore } from '@kit.ArkData';

export class Constants {
  static readonly DB_NAME: string = 'HarmonyHealth.db';
  static readonly DB_VERSION: number = 2;

  static readonly DEFAULT_STEP_GOAL: number = 8000;
  static readonly DEFAULT_WATER_GOAL_ML: number = 2000;
  static readonly DEFAULT_SLEEP_GOAL_HOURS: number = 8;
  static readonly DEFAULT_SPORT_DAYS_PER_WEEK: number = 3;
  static readonly DEFAULT_HEIGHT_CM: number = 170;

  static readonly COLOR_MOVE: string = '#FF6B35';
  static readonly COLOR_EXERCISE: string = '#4CAF50';
  static readonly COLOR_STAND: string = '#2196F3';
  static readonly COLOR_STEP: string = '#FF9800';
  static readonly COLOR_HEART: string = '#F44336';
  static readonly COLOR_SLEEP: string = '#9C27B0';
  static readonly COLOR_WATER: string = '#03A9F4';
  static readonly COLOR_WEIGHT: string = '#4CAF50';
  static readonly COLOR_SPORT: string = '#FF6B35';
  static readonly COLOR_DIET: string = '#FF5722';
  static readonly COLOR_MOOD: string = '#FFC107';
  static readonly COLOR_MED: string = '#00BCD4';
  static readonly COLOR_WOMEN: string = '#E91E63';
  static readonly COLOR_BODY: string = '#8BC34A';
  static readonly COLOR_PLAN: string = '#673AB7';
  static readonly COLOR_STREAK: string = '#FFD700';

  static readonly THEME_LIGHT: string = 'light';
  static readonly THEME_DARK: string = 'dark';

  static readonly PAGE_INDEX: string = 'pages/Index';
  static readonly PAGE_WEIGHT: string = 'pages/WeightPage';
  static readonly PAGE_WATER: string = 'pages/WaterPage';
  static readonly PAGE_SPORT: string = 'pages/SportPage';
  static readonly PAGE_SLEEP: string = 'pages/SleepPage';
  static readonly PAGE_REPORT: string = 'pages/ReportPage';
  static readonly PAGE_GOAL: string = 'pages/GoalPage';
  static readonly PAGE_DIET: string = 'pages/DietPage';
  static readonly PAGE_WOMEN: string = 'pages/WomenHealthPage';
  static readonly PAGE_MEDICATION: string = 'pages/MedicationPage';
  static readonly PAGE_MOOD: string = 'pages/MoodPage';
  static readonly PAGE_LOGIN: string = 'pages/LoginPage';
  static readonly PAGE_NOTIFICATION: string = 'pages/NotificationPage';
  static readonly PAGE_PROFILE: string = 'pages/ProfilePage';
  static readonly PAGE_SETTINGS: string = 'pages/SettingsPage';

  static readonly SPORT_TYPES: SportTypeDef[] = [
    { label: '步行', value: 'walk', icon: '🚶' },
    { label: '跑步', value: 'run', icon: '🏃' },
    { label: '骑行', value: 'cycle', icon: '🚴' },
    { label: '游泳', value: 'swim', icon: '🏊' },
    { label: '瑜伽', value: 'yoga', icon: '🧘' },
    { label: '力量', value: 'strength', icon: '🏋️' },
  ];

  static readonly INTENSITIES: string[] = ['低强度', '中强度', '高强度'];

  static readonly FOOD_CATEGORIES: string[] = ['breakfast', 'lunch', 'dinner', 'snack'];

  static readonly MET_VALUES: Map<string, number> = new Map<string, number>([
    ['walk', 3.5], ['run', 9.8], ['cycle', 7.5], ['swim', 8.0], ['yoga', 2.5], ['strength', 6.0]
  ]);

  static readonly SPEED_KMH: Map<string, number> = new Map<string, number>([
    ['walk', 5], ['run', 11], ['cycle', 18], ['swim', 3], ['yoga', 2], ['strength', 4]
  ]);

  static readonly MAX_HR: number = 200;
  static readonly REST_HR: number = 70;
}

export interface SportTypeDef {
  label: string;
  value: string;
  icon: string;
}

export interface DailySummary {
  date: string;
  steps: number;
  heartRateAvg: number;
  sleepScore: number;
  sleepHours: number;
  waterMl: number;
  caloriesBurned: number;
  exerciseMinutes: number;
  standHours: number;
}

export interface GoalConfig {
  dailySteps: number;
  dailyWaterMl: number;
  weeklySportDays: number;
  sleepHours: number;
  weightKg: number;
  heightCm: number;
  dailyCalorie: number;
  targetWeightKg?: number;
}

export interface DietRecord {
  id?: number;
  date: string;
  mealType: string;
  foodName: string;
  amountG: number;
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  timestamp: number;
}

export interface MoodRecord {
  id?: number;
  date: string;
  mood: number;
  note: string;
  timestamp: number;
}

export interface MedicationRecord {
  id?: number;
  name: string;
  dosage: string;
  time: string;
  frequency: string;
  startDate: string;
  endDate: string;
  timestamp: number;
}

export interface PeriodRecord {
  id?: number;
  startDate: string;
  endDate: string;
  cycleLength: number;
  periodLength: number;
  timestamp: number;
}

export interface BodyCompositionRecord {
  id?: number;
  date: string;
  bodyFat: number;
  muscleMass: number;
  bodyWater: number;
  boneMass: number;
  visceralFat: number;
  timestamp: number;
}

export interface WorkoutPlan {
  id?: number;
  name: string;
  durationWeeks: number;
  timesPerWeek: number;
  exercises: string;
  startDate: string;
  timestamp: number;
}

export interface StreakData {
  current: number;
  best: number;
}

export interface WaterTimeEntry {
  time: string;
  ml: number;
}

export interface BLEDevice {
  name: string;
  address: string;
  rssi: number;
}

export interface HealthBandData {
  heartRate: number;
  spo2: number;
  battery: number;
  connected: boolean;
}

export type DbRow = relationalStore.ValuesBucket;

export class ThemeColors {
  static bg(theme: string): string { return theme === 'dark' ? '#121212' : '#F5F5F5'; }
  static card(theme: string): string { return theme === 'dark' ? '#1E1E2E' : '#FFFFFF'; }
  static text(theme: string): string { return theme === 'dark' ? '#FFFFFF' : '#1A1A1A'; }
  static subText(theme: string): string { return theme === 'dark' ? '#AAAAAA' : '#666666'; }
  static pageBg(theme: string): string { return theme === 'dark' ? '#0D0D1A' : '#F0F0F5'; }
  static cardBg(theme: string): string { return theme === 'dark' ? '#1A1A2E' : '#FFFFFF'; }
  static textPrimary(theme: string): string { return theme === 'dark' ? '#FFFFFF' : '#111111'; }
  static textSecondary(theme: string): string { return theme === 'dark' ? '#888888' : '#777777'; }
  static inputBg(theme: string): string { return theme === 'dark' ? '#1A1A2E' : '#E8E8F0'; }
  static divider(theme: string): string { return theme === 'dark' ? '#333333' : '#DDDDDD'; }
}

export class FoodCalories {
  static readonly CAL_PER_100G: Map<string, number> = new Map<string, number>([
    ['米饭', 116], ['面条', 110], ['馒头', 223], ['包子', 227], ['饺子', 240],
    ['面包', 313], ['鸡蛋', 144], ['牛奶', 54], ['酸奶', 72], ['豆浆', 31],
    ['猪肉', 395], ['牛肉', 125], ['羊肉', 203], ['鸡肉', 167], ['鸭肉', 240],
    ['鱼肉', 113], ['虾', 93], ['蟹', 95], ['苹果', 52], ['香蕉', 89],
    ['橙子', 47], ['葡萄', 43], ['西瓜', 26], ['梨', 44], ['桃子', 48],
    ['白菜', 17], ['菠菜', 23], ['西兰花', 34], ['胡萝卜', 41], ['土豆', 81],
    ['番茄', 15], ['黄瓜', 16], ['豆腐', 82], ['花生', 574], ['核桃', 654],
    ['蛋糕', 348], ['巧克力', 589], ['饼干', 435], ['薯片', 548], ['可乐', 43],
    ['布丁', 130], ['果冻', 60], ['冰淇淋', 207], ['奶茶', 55], ['咖啡', 2],
    ['蛋挞', 375], ['月饼', 400], ['汤圆', 310], ['粽子', 195], ['油条', 388]
  ]);

  static lookupCaloriesPer100g(foodName: string): number {
    const lowerName: string = foodName.toLowerCase();
    const matched: Map<string, number> = new Map<string, number>();
    FoodCalories.CAL_PER_100G.forEach((value: number, key: string) => {
      if (lowerName.indexOf(key.toLowerCase()) >= 0) {
        matched.set(key, value);
      }
    });
    if (matched.size > 0) {
      const firstKey: string | undefined = matched.keys().next().value;
      return matched.get(String(firstKey)) ?? 0;
    }
    return 0;
  }

  static calcCalories(foodName: string, grams: number): number {
    const per100: number = FoodCalories.lookupCaloriesPer100g(foodName);
    if (per100 <= 0) {
      return 0;
    }
    return Math.round(per100 * grams / 100);
  }

  static getFoodNames(): string[] {
    const names: string[] = [];
    FoodCalories.CAL_PER_100G.forEach((value: number, key: string) => {
      names.push(key);
    });
    return names;
  }

  static getCaloriesFor(foodName: string): number {
    return FoodCalories.CAL_PER_100G.get(foodName) ?? 0;
  }
}
