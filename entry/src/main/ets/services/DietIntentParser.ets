import { DietAgentDraft, DietAgentPayload, DietIntentResult } from '../model/HealthAgentModels';

export class DietIntentParser {
  static parse(content: string): DietIntentResult {
    const result: DietIntentResult = new DietIntentResult();
    const jsonText: string = DietIntentParser.extractJson(content);
    if (jsonText.length === 0) {
      result.errorMessage = 'AI 未返回有效操作';
      return result;
    }
    let payload: DietAgentPayload;
    try {
      payload = JSON.parse(jsonText);
    } catch (err) {
      result.errorMessage = 'AI 操作格式无效';
      return result;
    }
    if (payload === null || typeof payload.action !== 'string') {
      result.errorMessage = 'AI 操作字段类型无效';
      return result;
    }
    if (payload.action !== 'record_diet') {
      return result;
    }
    if (typeof payload.foodName !== 'string' ||
      (payload.amountG !== undefined && typeof payload.amountG !== 'number') ||
      (payload.count !== undefined && typeof payload.count !== 'number') ||
      (payload.unit !== undefined && typeof payload.unit !== 'string') ||
      (payload.mealType !== undefined && typeof payload.mealType !== 'string')) {
      result.errorMessage = 'AI 饮食字段类型无效';
      return result;
    }
    const foodName: string = payload.foodName.trim();
    if (foodName.length === 0 || foodName.length > 40) {
      result.errorMessage = '没有识别到有效食物名称';
      return result;
    }
    const amountG: number = payload.amountG ?? 0;
    const count: number = payload.count ?? 0;
    if (!DietIntentParser.isValidOptionalNumber(amountG, 10000) ||
      !DietIntentParser.isValidOptionalNumber(count, 100)) {
      result.errorMessage = '食物数量超出有效范围';
      return result;
    }
    const draft: DietAgentDraft = new DietAgentDraft();
    draft.foodName = foodName;
    draft.amountG = amountG;
    draft.count = count;
    draft.unit = DietIntentParser.normalizeUnit(payload.unit ?? '');
    draft.mealType = DietIntentParser.normalizeMealType(payload.mealType ?? '');
    draft.requiresAmount = amountG <= 0;
    result.isDietAction = true;
    result.draft = draft;
    return result;
  }

  static isCandidate(text: string): boolean {
    const value: string = text.trim();
    return value.indexOf('吃了') >= 0 || value.indexOf('喝了') >= 0 ||
      value.indexOf('刚吃') >= 0 || value.indexOf('刚喝') >= 0 ||
      value.indexOf('已吃') >= 0 || value.indexOf('已喝') >= 0 ||
      value.indexOf('帮我记') >= 0 || value.indexOf('记录一下') >= 0 || value.indexOf('记一下') >= 0;
  }

  private static extractJson(content: string): string {
    const text: string = content.trim();
    const start: number = text.indexOf('{');
    const end: number = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return '';
    }
    return text.slice(start, end + 1);
  }

  private static isValidOptionalNumber(value: number, max: number): boolean {
    return Number.isFinite(value) && value >= 0 && value <= max;
  }

  private static normalizeUnit(unit: string): string {
    const value: string = unit.trim();
    return value.length <= 8 ? value : '';
  }

  private static normalizeMealType(mealType: string): string {
    const value: string = mealType.trim().toLowerCase();
    if (value === 'breakfast' || value === '早餐') {
      return 'breakfast';
    }
    if (value === 'lunch' || value === '午餐') {
      return 'lunch';
    }
    if (value === 'dinner' || value === '晚餐') {
      return 'dinner';
    }
    if (value === 'snack' || value === '加餐' || value === '零食') {
      return 'snack';
    }
    return '';
  }
}
