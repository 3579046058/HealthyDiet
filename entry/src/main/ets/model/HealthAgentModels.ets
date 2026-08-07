export class DietAgentDraft {
  foodName: string = '';
  amountG: number = 0;
  count: number = 0;
  unit: string = '';
  mealType: string = '';
  requiresAmount: boolean = true;
}

export class DietIntentResult {
  isDietAction: boolean = false;
  draft: DietAgentDraft = new DietAgentDraft();
  errorMessage: string = '';
}

export interface DietAgentPayload {
  action?: string;
  foodName?: string;
  amountG?: number;
  count?: number;
  unit?: string;
  mealType?: string;
}

export class DietRecordInput {
  date: string = '';
  mealType: string = '';
  foodName: string = '';
  amountG: number = 0;
}

export class PreparedDietRecord {
  valid: boolean = false;
  message: string = '';
  date: string = '';
  mealType: string = '';
  foodName: string = '';
  amountG: number = 0;
  calories: number = 0;
  protein: number = 0;
  fat: number = 0;
  carbs: number = 0;
}

export class DietRecordResult {
  success: boolean = false;
  message: string = '';
  record: PreparedDietRecord = new PreparedDietRecord();
}
