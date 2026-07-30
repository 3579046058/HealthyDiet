import { relationalStore } from '@kit.ArkData';

/**
 * 健康应用常量定义
 */
export class Constants {
  // 数据库
  static readonly DB_NAME: string = 'HarmonyHealth.db';
  static readonly DB_VERSION: number = 1;

  // 默认目标
  static readonly DEFAULT_STEP_GOAL: number = 8000;
  static readonly DEFAULT_WATER_GOAL_ML: number = 2000;
  static readonly DEFAULT_SLEEP_GOAL_HOURS: number = 8;
  static readonly DEFAULT_SPORT_DAYS_PER_WEEK: number = 3;

  // 颜色
  static readonly COLOR_MOVE: string = '#FF6B35';
  static readonly COLOR_EXERCISE: string = '#4CAF50';
  static readonly COLOR_STAND: string = '#2196F3';
  static readonly COLOR_STEP: string = '#FF9800';
  static readonly COLOR_HEART: string = '#F44336';
  static readonly COLOR_SLEEP: string = '#9C27B0';
  static readonly COLOR_WATER: string = '#03A9F4';
  static readonly COLOR_WEIGHT: string = '#4CAF50';
  static readonly COLOR_SPORT: string = '#FF6B35';

  // 页面路由
  static readonly PAGE_INDEX: string = 'pages/Index';
  static readonly PAGE_WEIGHT: string = 'pages/WeightPage';
  static readonly PAGE_WATER: string = 'pages/WaterPage';
  static readonly PAGE_SPORT: string = 'pages/SportPage';
  static readonly PAGE_SLEEP: string = 'pages/SleepPage';
  static readonly PAGE_REPORT: string = 'pages/ReportPage';
  static readonly PAGE_GOAL: string = 'pages/GoalPage';

  // 运动类型
  static readonly SPORT_TYPES: SportTypeDef[] = [
    { label: '步行', value: 'walk', icon: '🚶' },
    { label: '跑步', value: 'run', icon: '🏃' },
    { label: '骑行', value: 'cycle', icon: '🚴' },
  ];
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

export interface WeightRecord {
  id?: number;
  date: string;
  weightKg: number;
  timestamp: number;
}

export interface WaterRecord {
  id?: number;
  date: string;
  totalMl: number;
  cups: number;
  timestamp: number;
}

export interface SportRecord {
  id?: number;
  date: string;
  sportType: string;
  durationMin: number;
  distanceKm: number;
  calories: number;
  avgHeartRate: number;
  timestamp: number;
}

export interface SleepRecord {
  id?: number;
  date: string;
  startTime: string;
  endTime: string;
  deepSleepMin: number;
  lightSleepMin: number;
  remMin: number;
  totalMinutes: number;
  score: number;
  timestamp: number;
}

export interface HeartRateRecord {
  id?: number;
  date: string;
  timestamp: number;
  bpm: number;
}

export interface GoalConfig {
  dailySteps: number;
  dailyWaterMl: number;
  weeklySportDays: number;
  sleepHours: number;
  weightKg: number;
}

export interface StepRecord {
  id?: number;
  date: string;
  totalSteps: number;
  goalSteps: number;
  timestamp: number;
}

export type DbRow = relationalStore.ValuesBucket;
