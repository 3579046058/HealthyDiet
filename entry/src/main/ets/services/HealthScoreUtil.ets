import { GlobalData } from '../common/GlobalData';

export interface ScoreBreakdown {
  stepScore: number;
  sleepScoreOut: number;
  waterScore: number;
  exerciseScore: number;
  dietScore: number;
  total: number;
  hasData: boolean;
}

/**
 * 健康计分公共工具（加权累加 + 短板加权）
 * 原理：
 *  1. 各分项独立计分（完成率 × 权重），权重合计满分 100，不随短板变化
 *  2. 水桶加权：完成率最低的分项获得额外权重（在其原有权重上放大），
 *     其余分项按比例缩小，总分满分保持 100
 *  3. 饮食按推荐热量(GoalConfig.dailyCalorie)计分：90%~110% 满分，
 *     吃太少/超标梯度扣分
 *  4. 总分范围 [-100, 100]
 * 首页 / 桌面卡片 / 报告共用，保证分数一致
 */
export class HealthScoreUtil {
  static readonly STEP_GOAL_DEFAULT: number = 8000;
  static readonly WATER_GOAL_DEFAULT: number = 2000;
  static readonly EXERCISE_MIN_GOAL: number = 60;

  // 各分项基础权重（满分合计 100，不含饮食；饮食为附加分/倒扣）
  static readonly W_STEP: number = 30;
  static readonly W_SLEEP: number = 20;
  static readonly W_WATER: number = 30;
  static readonly W_EXERCISE: number = 20;
  // 饮食附加分（满分 +10）与倒扣档位
  static readonly W_DIET: number = 10;
  static readonly DIET_PENALTY_1: number = 8;   // 110%~130%
  static readonly DIET_PENALTY_2: number = 15;  // 130%~160%
  static readonly DIET_PENALTY_3: number = 20;  // >160%
  // 短板加权放大系数：最低完成率项权重放大为 1+BOOST
  static readonly BOOST: number = 0.5;

  /**
   * 各项得分明细（供 UI 展示和汇总）
   * @param recommendCalorie 体重页计算的推荐热量（<=0 则饮食不计分）
   */
  static calcBreakdown(steps: number, stepGoal: number, sleepScore: number,
    waterMl: number, waterGoal: number, exerciseMin: number, calorieIntake: number,
    recommendCalorie: number): ScoreBreakdown {
    // 1. 计算各分项完成率（0-100），未添加的项不参与评分
    const rates: number[] = [];
    const weights: number[] = [];
    const names: string[] = [];

    if (steps > 0) {
      rates.push(Math.min(100, steps / (stepGoal || HealthScoreUtil.STEP_GOAL_DEFAULT) * 100));
      weights.push(HealthScoreUtil.W_STEP);
      names.push('step');
    }

    if (sleepScore > 0) {
      rates.push(Math.min(100, sleepScore));
      weights.push(HealthScoreUtil.W_SLEEP);
      names.push('sleep');
    }

    if (waterMl > 0) {
      rates.push(Math.min(100, waterMl / (waterGoal || HealthScoreUtil.WATER_GOAL_DEFAULT) * 100));
      weights.push(HealthScoreUtil.W_WATER);
      names.push('water');
    }

    if (exerciseMin > 0) {
      rates.push(Math.min(100, exerciseMin / HealthScoreUtil.EXERCISE_MIN_GOAL * 100));
      weights.push(HealthScoreUtil.W_EXERCISE);
      names.push('exercise');
    }

    // 没有任何正项数据：不算分，标记无数据
    if (rates.length === 0) {
      return {
        stepScore: 0, sleepScoreOut: 0, waterScore: 0, exerciseScore: 0,
        dietScore: 0, total: 0, hasData: false
      };
    }

    // 2. 权重归一化到满分 100（只算有数据的项），再做短板加权
    const totalW = weights.reduce((a: number, b: number) => a + b, 0);
    // 按权重比例扩展到满分 100
    const scaledWeights: number[] = [];
    for (let i = 0; i < weights.length; i++) {
      scaledWeights.push(weights[i] / totalW * 100);
    }

    // 3. 计算正项得分（权重×完成率，满分100）
    let positiveScore = 0;
    // 仅一项有数据：无短板对比，直接按完成率×100（满分100）
    let adjustedWeights: number[] = scaledWeights;
    if (rates.length > 1) {
      // 短板加权：最低完成率项权重放大，其余按比例缩小（满分保持 100）
      let minIdx = 0;
      for (let i = 1; i < rates.length; i++) {
        if (rates[i] < rates[minIdx]) {
          minIdx = i;
        }
      }
      const boostedW = scaledWeights[minIdx] * (1 + HealthScoreUtil.BOOST);
      const othersSum = scaledWeights.reduce((a: number, b: number) => a + b, 0) - scaledWeights[minIdx];
      const adj: number[] = [];
      for (let i = 0; i < scaledWeights.length; i++) {
        if (i === minIdx) {
          adj.push(boostedW);
        } else {
          // 其余项按比例缩小，保持总权重 = 100
          adj.push(othersSum > 0 ? scaledWeights[i] * (100 - boostedW) / othersSum : 0);
        }
      }
      adjustedWeights = adj;
    }

    for (let i = 0; i < rates.length; i++) {
      positiveScore += rates[i] / 100 * adjustedWeights[i];
    }
    positiveScore = Math.round(positiveScore);

    // 各分项得分（对应当前有数据的项，缺失项为 0）
    const stepScore = names.indexOf('step') >= 0 ? Math.round(rates[names.indexOf('step')] / 100 * adjustedWeights[names.indexOf('step')]) : 0;
    const sleepScoreOut = names.indexOf('sleep') >= 0 ? Math.round(rates[names.indexOf('sleep')] / 100 * adjustedWeights[names.indexOf('sleep')]) : 0;
    const waterScore = names.indexOf('water') >= 0 ? Math.round(rates[names.indexOf('water')] / 100 * adjustedWeights[names.indexOf('water')]) : 0;
    const exerciseScore = names.indexOf('exercise') >= 0 ? Math.round(rates[names.indexOf('exercise')] / 100 * adjustedWeights[names.indexOf('exercise')]) : 0;

    // 4. 饮食：以推荐热量为基准（90%~110% 满分，梯度倒扣）
    let dietScore = 0;
    if (calorieIntake > 0 && recommendCalorie > 0) {
      const rate = calorieIntake / recommendCalorie;
      if (rate >= 0.9 && rate <= 1.1) {
        dietScore = HealthScoreUtil.W_DIET; // 满分 +10
      } else if (rate < 0.9 && rate >= 0.7) {
        dietScore = 6;
      } else if (rate < 0.7 && rate >= 0.5) {
        dietScore = 3;
      } else if (rate < 0.5) {
        dietScore = 0;
      } else if (rate > 1.1 && rate <= 1.3) {
        dietScore = -HealthScoreUtil.DIET_PENALTY_1;
      } else if (rate > 1.3 && rate <= 1.6) {
        dietScore = -HealthScoreUtil.DIET_PENALTY_2;
      } else {
        dietScore = -HealthScoreUtil.DIET_PENALTY_3;
      }
    }

    // 5. 总分 = 正项(满分100) + 饮食附加分，clamp [-100, 100]
    let total = positiveScore + dietScore;
    total = Math.max(-100, Math.min(100, total));

    return {
      stepScore: stepScore,
      sleepScoreOut: sleepScoreOut,
      waterScore: waterScore,
      exerciseScore: exerciseScore,
      dietScore: dietScore,
      total: total,
      hasData: true
    };
  }

  /**
   * 按原始数据计算总分（卡片 / 报告等从数据库读取的场景）
   */
  static calcByData(steps: number, stepGoal: number, sleepScore: number,
    waterMl: number, waterGoal: number, exerciseMin: number, calorieIntake: number,
    recommendCalorie: number): number {
    return HealthScoreUtil.calcBreakdown(steps, stepGoal, sleepScore, waterMl, waterGoal,
      exerciseMin, calorieIntake, recommendCalorie).total;
  }

  /**
   * 读取某天数据库摘要计算总分（卡片进程可用，GlobalData 需已初始化）
   */
  static async calcTodayFromDb(date: string): Promise<number> {
    try {
      const summary = await GlobalData.db.getDailySummary(date);
      if (!summary) {
        return 0;
      }
      const steps = Number(summary.steps) || 0;
      const sleepScore = Number(summary.sleep_score) || 0;
      const waterMl = Number(summary.water_ml) || 0;
      const exerciseMin = Number(summary.exercise_minutes) || 0;
      const config = await GlobalData.prefs.getGoalConfig();
      const calorieIntake = await HealthScoreUtil.getCalorieIntake(date);
      return HealthScoreUtil.calcByData(steps, config.dailySteps, sleepScore, waterMl,
        config.dailyWaterMl, exerciseMin, calorieIntake, config.dailyCalorie);
    } catch (err) {
      console.error('HealthScoreUtil calcTodayFromDb error:', JSON.stringify(err));
      return 0;
    }
  }

  static async getCalorieIntake(date: string): Promise<number> {
    try {
      const rows = await GlobalData.db.getDietRecords(date);
      let total = 0;
      for (const r of rows) {
        total += Number(r.calories) || 0;
      }
      return total;
    } catch (err) {
      console.error('HealthScoreUtil getCalorieIntake error:', JSON.stringify(err));
      return 0;
    }
  }
}
