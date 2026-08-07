import { DbRow, FoodCalories, NutritionInfo } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { DietRecordInput, DietRecordResult, PreparedDietRecord } from '../model/HealthAgentModels';
import { FoodRecognitionService, NutritionPer100 } from './FoodRecognitionService';

export class HealthDataService {
  private static instance: HealthDataService;

  static getInstance(): HealthDataService {
    if (!HealthDataService.instance) {
      HealthDataService.instance = new HealthDataService();
    }
    return HealthDataService.instance;
  }

  prepareDietRecord(input: DietRecordInput): PreparedDietRecord {
    const result: PreparedDietRecord = new PreparedDietRecord();
    const foodName: string = input.foodName.trim();
    if (foodName.length === 0) {
      result.message = '食物名称不能为空';
      return result;
    }
    if (!Number.isFinite(input.amountG) || input.amountG <= 0 || input.amountG > 10000) {
      result.message = '请输入 0 到 10000 克之间的有效重量';
      return result;
    }
    const nutrition: NutritionInfo = FoodCalories.getNutrition(foodName, input.amountG);
    result.valid = nutrition.cal > 0;
    result.message = result.valid ? '' : '本地食物库无法识别该食物';
    result.date = input.date;
    result.mealType = HealthDataService.normalizeMealType(input.mealType);
    result.foodName = foodName;
    result.amountG = input.amountG;
    result.calories = nutrition.cal;
    result.protein = nutrition.pro;
    result.fat = nutrition.fat;
    result.carbs = nutrition.carb;
    return result;
  }

  async addDietRecord(input: DietRecordInput): Promise<DietRecordResult> {
    const result: DietRecordResult = new DietRecordResult();
    const prepared: PreparedDietRecord = this.prepareDietRecord(input);
    if (!prepared.valid) {
      const cloudNutrition: NutritionPer100 | null = await FoodRecognitionService.getInstance()
        .getFoodNutrition(input.foodName);
      if (cloudNutrition === null || cloudNutrition.cal <= 0) {
        result.message = '无法确认“' + input.foodName + '”是可记录的食物';
        return result;
      }
      const rate: number = input.amountG / 100;
      prepared.valid = true;
      prepared.message = '';
      prepared.calories = Number((cloudNutrition.cal * rate).toFixed(2));
      prepared.protein = Number((cloudNutrition.pro * rate).toFixed(2));
      prepared.fat = Number((cloudNutrition.fat * rate).toFixed(2));
      prepared.carbs = Number((cloudNutrition.carb * rate).toFixed(2));
    }
    if (!GlobalData.initialized) {
      result.message = '健康数据服务尚未初始化';
      return result;
    }
    const record: DbRow = {
      date: prepared.date,
      meal_type: prepared.mealType,
      food_name: prepared.foodName,
      amount_g: prepared.amountG,
      calories: prepared.calories,
      protein: prepared.protein,
      fat: prepared.fat,
      carbs: prepared.carbs,
      timestamp: Date.now()
    };
    try {
      await GlobalData.db.addDietRecord(record);
      AppStorage.setOrCreate('dataUpdateTrigger', 'diet_agent_' + String(Date.now()));
      result.success = true;
      result.record = prepared;
      result.message = '已记录 ' + prepared.foodName + ' ' + String(prepared.amountG) + ' 克，约 ' +
        String(Math.round(prepared.calories)) + ' 千卡。';
    } catch (err) {
      console.error('HealthDataService addDietRecord error:', JSON.stringify(err));
      result.message = '饮食记录保存失败，请稍后重试';
    }
    return result;
  }

  static inferMealType(hour: number): string {
    if (hour >= 4 && hour < 10) {
      return 'breakfast';
    }
    if (hour >= 10 && hour < 14) {
      return 'lunch';
    }
    if (hour >= 17 && hour < 20) {
      return 'dinner';
    }
    return 'snack';
  }

  private static normalizeMealType(mealType: string): string {
    if (mealType === 'breakfast' || mealType === 'lunch' || mealType === 'dinner' || mealType === 'snack') {
      return mealType;
    }
    return HealthDataService.inferMealType(new Date().getHours());
  }
}
