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
  static readonly PAGE_RECYCLE_BIN: string = 'pages/RecycleBinPage';

  static readonly SPORT_TYPES: SportTypeDef[] = [
    { label: '步行', value: 'walk', icon: '🚶' },
    { label: '跑步', value: 'run', icon: '🏃' },
    { label: '骑行', value: 'cycle', icon: '🚴' },
    { label: '游泳', value: 'swim', icon: '🏊' },
    { label: '瑜伽', value: 'yoga', icon: '🧘' },
    { label: '力量', value: 'strength', icon: '🏋️' },
  ];

  static readonly INTENSITIES: string[] = ['低强度', '中强度', '高强度'];

  // 运动类型分类：有位移的运动（使用 GPS）和原地运动（不使用 GPS）
  static readonly GPS_SPORTS: Set<string> = new Set<string>(['walk', 'run', 'cycle']);
  static readonly STATIONARY_SPORTS: Set<string> = new Set<string>(['swim', 'yoga', 'strength']);

  // 原地运动的强度系数（低/中/高）
  static readonly INTENSITY_MULTIPLIERS: Map<string, number> = new Map<string, number>([
    ['低强度', 0.7], ['中强度', 1.0], ['高强度', 1.3]
  ]);

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

export interface SportState {
  currentSport: string;
  durationSec: number;
  distanceKm: number;
  calorieBurn: number;
  heartRateAvg: number;
  intensity: string;
  startTime: number;
  savedAt: number;
  isBackground?: boolean; // 是否在后台继续计时
  startTimestamp?: number; // 运动开始时间戳（用于准确计算后台时长）
  isPaused?: boolean; // 是否暂停状态
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
  dailyProtein?: number;
  dailyFat?: number;
  dailyCarbs?: number;
}

export class AiConfig {
  apiUrl: string = '';
  apiKey: string = '';
  chatModel: string = '';
}

export class AiDefaults {
  static readonly API_URL: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static readonly CHAT_MODEL: string = 'glm-4-flash';
  static readonly VISION_MODEL: string = 'glm-4v-flash';
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
  static accent(theme: string): string { return '#FF6B35'; }  // 强调色（橙色，不随主题变化）
}

/**
 * 主题工具类：统一页面背景/卡片/文字配色，消除各页面重复的 getter
 */
export class ThemeManager {
  static bg(theme: string): string { return ThemeColors.pageBg(theme); }
  static card(theme: string): string { return ThemeColors.cardBg(theme); }
  static txt(theme: string): string { return ThemeColors.textPrimary(theme); }
  static sub(theme: string): string { return ThemeColors.textSecondary(theme); }
  static inputBg(theme: string): string { return ThemeColors.inputBg(theme); }
  static divider(theme: string): string { return ThemeColors.divider(theme); }
}

// ========== 新增：食物分级类型 ==========
export type FoodLevel = '较推荐' | '适量吃' | '限量吃';

export interface NutritionInfo {
  cal: number;
  pro: number;
  fat: number;
  carb: number;
}

interface FoodNutritionItem {
  name: string;
  cal: number;
  pro: number;
  fat: number;
  carb: number;
}

export class FoodCalories {
  // 完整食物营养数据表（每100g）
  private static readonly FOOD_TABLE: FoodNutritionItem[] = [
    {name:"米饭",cal:116,pro:2.6,fat:0.3,carb:25.9},
    {name:"面条",cal:110,pro:3.5,fat:1.1,carb:22.8},
    {name:"馒头",cal:223,pro:7.0,fat:1.1,carb:47.0},
    {name:"包子",cal:227,pro:7.3,fat:10.0,carb:28.0},
    {name:"饺子",cal:240,pro:8.0,fat:10.0,carb:30.0},
    {name:"面包",cal:313,pro:8.3,fat:5.1,carb:58.6},
    {name:"鸡蛋",cal:144,pro:13.3,fat:8.8,carb:2.8},
    {name:"牛奶",cal:54,pro:3.2,fat:3.8,carb:4.8},
    {name:"酸奶",cal:72,pro:2.5,fat:2.7,carb:9.3},
    {name:"豆浆",cal:31,pro:2.0,fat:1.2,carb:3.0},
    {name:"猪肉",cal:395,pro:13.0,fat:37.0,carb:0.0},
    {name:"牛肉",cal:125,pro:20.2,fat:4.2,carb:0.0},
    {name:"羊肉",cal:203,pro:19.0,fat:14.1,carb:0.0},
    {name:"鸡肉",cal:167,pro:19.3,fat:9.4,carb:1.3},
    {name:"鸭肉",cal:240,pro:15.0,fat:19.7,carb:0.2},
    {name:"鱼肉",cal:113,pro:18.0,fat:3.4,carb:0.0},
    {name:"虾",cal:93,pro:18.6,fat:0.8,carb:2.8},
    {name:"蟹",cal:95,pro:18.9,fat:2.3,carb:0.0},
    {name:"苹果",cal:52,pro:0.3,fat:0.2,carb:14.0},
    {name:"香蕉",cal:89,pro:1.1,fat:0.3,carb:22.8},
    {name:"橙子",cal:47,pro:0.8,fat:0.2,carb:11.1},
    {name:"葡萄",cal:43,pro:0.5,fat:0.2,carb:10.3},
    {name:"西瓜",cal:26,pro:0.6,fat:0.1,carb:5.8},
    {name:"梨",cal:44,pro:0.4,fat:0.2,carb:13.0},
    {name:"桃子",cal:48,pro:0.9,fat:0.1,carb:11.0},
    {name:"白菜",cal:17,pro:1.5,fat:0.2,carb:3.0},
    {name:"菠菜",cal:23,pro:2.6,fat:0.3,carb:4.5},
    {name:"西兰花",cal:34,pro:4.1,fat:0.6,carb:4.3},
    {name:"胡萝卜",cal:41,pro:1.0,fat:0.2,carb:8.8},
    {name:"土豆",cal:81,pro:2.0,fat:0.1,carb:17.2},
    {name:"番茄",cal:15,pro:0.9,fat:0.2,carb:3.5},
    {name:"黄瓜",cal:16,pro:0.8,fat:0.2,carb:2.9},
    {name:"豆腐",cal:82,pro:8.1,fat:3.7,carb:3.8},
    {name:"花生",cal:574,pro:26.0,fat:49.0,carb:16.0},
    {name:"核桃",cal:654,pro:15.0,fat:65.0,carb:14.0},
    {name:"蛋糕",cal:348,pro:6.0,fat:15.0,carb:50.0},
    {name:"巧克力",cal:589,pro:4.3,fat:51.0,carb:54.0},
    {name:"饼干",cal:435,pro:9.0,fat:13.0,carb:70.0},
    {name:"薯片",cal:548,pro:7.5,fat:30.0,carb:50.0},
    {name:"可乐",cal:43,pro:0.0,fat:0.0,carb:11.0},
    {name:"布丁",cal:130,pro:2.5,fat:5.0,carb:20.0},
    {name:"果冻",cal:60,pro:0.0,fat:0.0,carb:15.0},
    {name:"冰淇淋",cal:207,pro:2.7,fat:10.0,carb:25.0},
    {name:"奶茶",cal:55,pro:1.0,fat:1.2,carb:12.0},
    {name:"咖啡",cal:2,pro:0.1,fat:0.0,carb:0.3},
    {name:"蛋挞",cal:375,pro:4.0,fat:22.0,carb:40.0},
    {name:"月饼",cal:400,pro:5.0,fat:18.0,carb:55.0},
    {name:"汤圆",cal:310,pro:4.0,fat:8.0,carb:55.0},
    {name:"粽子",cal:195,pro:5.0,fat:1.0,carb:40.0},
    {name:"油条",cal:388,pro:6.9,fat:17.0,carb:50.0}
  ];

  // ========== 新增：食物分级映射表 ==========
  private static readonly FOOD_LEVEL_MAP: Map<string, FoodLevel> = new Map<string, FoodLevel>([
    // 较推荐：低卡高营养
    ['鸡蛋', '较推荐'], ['牛奶', '较推荐'], ['酸奶', '较推荐'], ['豆浆', '较推荐'],
    ['牛肉', '较推荐'], ['鸡肉', '较推荐'], ['鱼肉', '较推荐'], ['虾', '较推荐'], ['蟹', '较推荐'],
    ['苹果', '较推荐'], ['橙子', '较推荐'], ['葡萄', '较推荐'], ['西瓜', '较推荐'],
    ['梨', '较推荐'], ['桃子', '较推荐'], ['白菜', '较推荐'], ['菠菜', '较推荐'],
    ['西兰花', '较推荐'], ['胡萝卜', '较推荐'], ['番茄', '较推荐'], ['黄瓜', '较推荐'],
    ['豆腐', '较推荐'], ['咖啡', '较推荐'],
    // 适量吃：日常必需但需控量
    ['米饭', '适量吃'], ['面条', '适量吃'], ['馒头', '适量吃'], ['包子', '适量吃'],
    ['饺子', '适量吃'], ['面包', '适量吃'], ['香蕉', '适量吃'], ['土豆', '适量吃'],
    ['花生', '适量吃'], ['核桃', '适量吃'], ['羊肉', '适量吃'], ['鸭肉', '适量吃'], ['猪肉', '适量吃'],
    // 限量吃：高糖高油高热量
    ['蛋糕', '限量吃'], ['巧克力', '限量吃'], ['饼干', '限量吃'], ['薯片', '限量吃'],
    ['可乐', '限量吃'], ['布丁', '限量吃'], ['果冻', '限量吃'], ['冰淇淋', '限量吃'],
    ['奶茶', '限量吃'], ['蛋挞', '限量吃'], ['月饼', '限量吃'], ['汤圆', '限量吃'],
    ['粽子', '限量吃'], ['油条', '限量吃']
  ]);

  // 保留原有CAL_PER_100G，100%兼容旧代码
  static readonly CAL_PER_100G: Map<string, number> = (() => {
    const map = new Map<string, number>();
    FoodCalories.FOOD_TABLE.forEach(item => map.set(item.name, item.cal));
    return map;
  })();

  private static searchFood(rawName: string): FoodNutritionItem | null {
    const lowerName: string = rawName.toLowerCase();
    for (const item of FoodCalories.FOOD_TABLE) {
      if (lowerName.indexOf(item.name.toLowerCase()) >= 0) {
        return item;
      }
    }
    return null;
  }

  static lookupCaloriesPer100g(foodName: string): number {
    const item = FoodCalories.searchFood(foodName);
    return item?.cal ?? 0;
  }

  static calcCalories(foodName: string, grams: number): number {
    const per100: number = FoodCalories.lookupCaloriesPer100g(foodName);
    if (per100 <= 0) {
      return 0;
    }
    return Math.round(per100 * grams / 100);
  }

  static getFoodNames(): string[] {
    return FoodCalories.FOOD_TABLE.map(item => item.name);
  }

  static getCaloriesFor(foodName: string): number {
    return FoodCalories.CAL_PER_100G.get(foodName) ?? 0;
  }

  static getNutrition(foodName: string, grams: number): NutritionInfo {
    const empty: NutritionInfo = { cal: 0, pro: 0, fat: 0, carb: 0 };
    const food = FoodCalories.searchFood(foodName);
    if (!food) return empty;
    const rate = grams / 100;
    const result: NutritionInfo = {
      cal: Number((food.cal * rate).toFixed(2)),
      pro: Number((food.pro * rate).toFixed(2)),
      fat: Number((food.fat * rate).toFixed(2)),
      carb: Number((food.carb * rate).toFixed(2))
    };
    return result;
  }

  // ========== 新增：获取食物分级 ==========
  static getFoodLevel(foodName: string): FoodLevel {
    const food = FoodCalories.searchFood(foodName);
    if (!food) return '适量吃';
    return FoodCalories.FOOD_LEVEL_MAP.get(food.name) ?? '适量吃';
  }

  // ========== 新增：分级对应主题色，UI直接调用 ==========
  static getLevelColor(level: FoodLevel): string {
    switch (level) {
      case '较推荐':
        return '#4CAF50';
      case '适量吃':
        return '#FF9800';
      case '限量吃':
        return '#F44336';
      default:
        return '#FF9800';
    }
  }
}