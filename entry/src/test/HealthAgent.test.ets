import { describe, it, expect } from '@ohos/hypium';
import { DietIntentParser } from '../main/ets/services/DietIntentParser';
import { HealthDataService } from '../main/ets/services/HealthDataService';
import { DietIntentResult, DietRecordInput, PreparedDietRecord } from '../main/ets/model/HealthAgentModels';

export default function healthAgentTest() {
  describe('DietIntentParserTest', () => {
    it('parseExplicitGrams', 0, () => {
      const result: DietIntentResult = DietIntentParser.parse(
        '{"action":"record_diet","foodName":"鸡蛋","amountG":100,"count":0,"unit":"","mealType":"breakfast"}');
      expect(result.isDietAction).assertTrue();
      expect(result.draft.foodName).assertEqual('鸡蛋');
      expect(result.draft.amountG).assertEqual(100);
      expect(result.draft.requiresAmount).assertFalse();
      expect(result.draft.mealType).assertEqual('breakfast');
    });

    it('parseCountRequiresWeight', 0, () => {
      const result: DietIntentResult = DietIntentParser.parse(
        '```json\n{"action":"record_diet","foodName":"鸡蛋","amountG":0,"count":2,"unit":"个","mealType":""}\n```');
      expect(result.isDietAction).assertTrue();
      expect(result.draft.count).assertEqual(2);
      expect(result.draft.unit).assertEqual('个');
      expect(result.draft.requiresAmount).assertTrue();
    });

    it('normalizeChineseMeal', 0, () => {
      const result: DietIntentResult = DietIntentParser.parse(
        '{"action":"record_diet","foodName":"米饭","amountG":200,"count":0,"unit":"","mealType":"午餐"}');
      expect(result.draft.mealType).assertEqual('lunch');
    });

    it('ignoreNonAction', 0, () => {
      const result: DietIntentResult = DietIntentParser.parse('{"action":"none"}');
      expect(result.isDietAction).assertFalse();
    });

    it('rejectInvalidJson', 0, () => {
      const result: DietIntentResult = DietIntentParser.parse('not-json');
      expect(result.isDietAction).assertFalse();
      expect(result.errorMessage.length > 0).assertTrue();
    });

    it('rejectNegativeAmount', 0, () => {
      const result: DietIntentResult = DietIntentParser.parse(
        '{"action":"record_diet","foodName":"鸡蛋","amountG":-1,"count":0,"unit":"","mealType":"snack"}');
      expect(result.isDietAction).assertFalse();
    });

    it('rejectMissingFood', 0, () => {
      const result: DietIntentResult = DietIntentParser.parse(
        '{"action":"record_diet","foodName":"","amountG":100,"count":0,"unit":"","mealType":"snack"}');
      expect(result.isDietAction).assertFalse();
    });

    it('rejectWrongFieldTypes', 0, () => {
      const result: DietIntentResult = DietIntentParser.parse(
        '{"action":"record_diet","foodName":1,"amountG":"100","count":0,"unit":"","mealType":"snack"}');
      expect(result.isDietAction).assertFalse();
      expect(result.errorMessage.length > 0).assertTrue();
    });

    it('detectConsumptionCandidate', 0, () => {
      expect(DietIntentParser.isCandidate('我吃了两个鸡蛋')).assertTrue();
      expect(DietIntentParser.isCandidate('今天吃什么比较好')).assertFalse();
      expect(DietIntentParser.isCandidate('帮我记录一下100克米饭')).assertTrue();
    });
  });

  describe('HealthDataServiceTest', () => {
    it('prepareKnownFood', 0, () => {
      const input: DietRecordInput = new DietRecordInput();
      input.date = '2026-08-07';
      input.mealType = 'breakfast';
      input.foodName = '鸡蛋';
      input.amountG = 100;
      const record: PreparedDietRecord = HealthDataService.getInstance().prepareDietRecord(input);
      expect(record.valid).assertTrue();
      expect(record.calories).assertEqual(144);
      expect(record.protein).assertEqual(13.3);
      expect(record.fat).assertEqual(8.8);
      expect(record.carbs).assertEqual(2.8);
    });

    it('rejectZeroWeight', 0, () => {
      const input: DietRecordInput = new DietRecordInput();
      input.foodName = '鸡蛋';
      input.amountG = 0;
      const record: PreparedDietRecord = HealthDataService.getInstance().prepareDietRecord(input);
      expect(record.valid).assertFalse();
    });

    it('rejectUnknownFoodLocally', 0, () => {
      const input: DietRecordInput = new DietRecordInput();
      input.foodName = '不存在的食物XYZ';
      input.amountG = 100;
      const record: PreparedDietRecord = HealthDataService.getInstance().prepareDietRecord(input);
      expect(record.valid).assertFalse();
    });

    it('inferMealBoundaries', 0, () => {
      expect(HealthDataService.inferMealType(8)).assertEqual('breakfast');
      expect(HealthDataService.inferMealType(12)).assertEqual('lunch');
      expect(HealthDataService.inferMealType(18)).assertEqual('dinner');
      expect(HealthDataService.inferMealType(22)).assertEqual('snack');
    });
  });
}
