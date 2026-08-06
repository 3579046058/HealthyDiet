import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { FoodCalories, AiDefaults } from '../common/Constants';

// [修改] 扩展接口，增加每100g原始营养字段（用于缩放）
export interface RecognizedFoodItem {
  id: string;
  foodName: string;
  grams: number;
  calories: number;               // 当前克数下的实际热量
  isSnack: boolean;
  snackReason: string;
  saved: boolean;
  isCalcCalories: boolean;
  isJudgingSnack: boolean;
  snackAnswer: string;
  snackAnswerIsSnack: boolean;
  protein?: number;               // 当前克数下的实际蛋白质
  fat?: number;                   // 当前克数下的实际脂肪
  carbs?: number;                 // 当前克数下的实际碳水
  // 新增：每100g原始营养值（用于缩放）
  caloriesPer100?: number;
  proteinPer100?: number;
  fatPer100?: number;
  carbsPer100?: number;
  // 用户手动选择的餐次（为空时用自动逻辑）
  selectedMealType?: string;
}

export interface RecognitionOutcome {
  foodName: string;
  confidence: number;
  source: string;
  error?: string;
  foodItems?: RecognizedFoodItem[];
}

export interface SnackJudge {
  isSnack: boolean;
  reason: string;
  // 是否真实调用了 AI（false 表示云端未配置/跳过，未参与判断）
  aiUsed: boolean;
}

export interface FoodJudge {
  isFood: boolean;
  reason: string;
}

export class RecognitionMode {
  static readonly LOCAL: string = 'local';
  static readonly CLOUD: string = 'cloud';
}

// 每100g营养接口
export interface NutritionPer100 {
  cal: number;
  pro: number;
  fat: number;
  carb: number;
}

interface GlmContent {
  type: string;
  image_url?: Record<string, string>;
  text?: string;
}

interface GlmMessage {
  role: string;
  content: Array<GlmContent>;
}

interface GlmRequestBody {
  model: string;
  messages: Array<GlmMessage>;
  temperature?: number;
}

// 文字模型请求：content 是纯字符串（GLM 要求）
interface ChatTextMessage {
  role: string;
  content: string;
}

interface ChatTextRequestBody {
  model: string;
  messages: Array<ChatTextMessage>;
  temperature?: number;
}

export class FoodRecognitionService {
  private static instance: FoodRecognitionService;
  private glmApiKey: string = '';
  private static readonly VISION_URL: string = AiDefaults.API_URL;
  private static readonly VISION_MODEL: string = AiDefaults.VISION_MODEL;
  private static readonly CHAT_MODEL: string = AiDefaults.CHAT_MODEL;

  // 缓存每100g营养
  private per100NutritionCache: Map<string, NutritionPer100> = new Map();

  static getInstance(): FoodRecognitionService {
    if (!FoodRecognitionService.instance) {
      FoodRecognitionService.instance = new FoodRecognitionService();
    }
    return FoodRecognitionService.instance;
  }

  async init(context: Context): Promise<void> {
    try {
      const resourceMgr = context.resourceManager;
      const data: Uint8Array = await resourceMgr.getRawFileContent('ai_config.json');
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const text: string = decoder.decodeToString(data);
      const parsed: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const key = parsed['glm_api_key'];
      if (typeof key === 'string') {
        this.glmApiKey = key;
      }
      console.info('FoodRecognitionService config loaded, keyLen=' + String(this.glmApiKey.length));
    } catch (err) {
      console.error('FoodRecognitionService init config error:', JSON.stringify(err));
    }
  }

  isCloudConfigured(): boolean {
    return this.glmApiKey.length > 0;
  }

  async recognize(uri: string): Promise<RecognitionOutcome> {
    const local = await this.recognizeLocal(uri);
    if (local.foodName.length > 0) {
      return local;
    }
    if (this.isCloudConfigured()) {
      const cloud = await this.recognizeCloud(uri);
      if (cloud.foodName.length > 0) {
        return cloud;
      }
      return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD, error: '云端识别失败，请检查网络或稍后重试' };
    }
    return { foodName: '', confidence: 0, source: RecognitionMode.LOCAL, error: '未配置云端识别 Key' };
  }

  async recognizeMultiple(uri: string): Promise<RecognitionOutcome> {
    if (!this.isCloudConfigured()) {
      return { foodName: '', confidence: 0, source: RecognitionMode.LOCAL, error: '未配置云端识别 Key' };
    }
    try {
      const base64 = await this.uriToBase64(uri);
      if (base64.length === 0) {
        console.error('recognizeMultiple: base64 empty, uri=' + uri);
        return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD, error: '图片读取失败' };
      }
      const imageUrl: Record<string, string> = { 'url': 'data:image/jpeg;base64,' + base64 };
      const imgContent: GlmContent = {
        type: 'image_url',
        image_url: imageUrl
      };
      const textContent: GlmContent = {
        type: 'text',
        text: '请识别图片中所有主要的菜品或食物名称。要求：1. 如果图片中有多个菜（如餐桌上的多道菜），尽量全部识别出来；2. 最多返回5个，按视觉主次排序；3. 只返回菜品/食物名称（如"鱼香肉丝""宫保鸡丁""米饭"），不要列出辣椒、花椒、肉末等配料或单一食材；4. 如果图片中没有任何可食用的食物（如风景、物品、人物、建筑），只返回"无"；5. 用英文逗号严格分隔，禁止序号、解释、换行、顿号等多余内容。例如：鱼香肉丝,米饭,紫菜蛋花汤'
      };
      const contents: Array<GlmContent> = [imgContent, textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.VISION_MODEL,
        messages: messages
      };
      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.VISION_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.glmApiKey
        },
        extraData: JSON.stringify(requestBody),
        connectTimeout: 15000,
        readTimeout: 30000
      });
      request.destroy();
      const code: number = response.responseCode;
      const result: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
          if (code === 200) {
        const parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
        const choicesObj = parsed['choices'];
        if (choicesObj !== undefined && Array.isArray(choicesObj)) {
          const choicesArr = choicesObj as Array<Record<string, Object>>;
          if (choicesArr.length > 0) {
            const first = choicesArr[0];
            const messageObj = first['message'] as Record<string, Object>;
            const content: string = String(messageObj['content'] ?? '');
            console.info('[Recog] GLM raw content: ' + content.substring(0, 300));
            const foodNames = this.parseMultipleFoodNames(content);
            // 非食物图：GLM 返回"无"或空 → 直接拒绝
            if (foodNames.length === 0) {
              console.info('[Recog] GLM returned no food, rejecting');
              return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD,
                error: '未识别到可食用的食物，请对准食物拍照' };
            }
            // 限制最多 5 个（避免 GLM 联想出过多相似菜）
            const limited: string[] = foodNames.slice(0, 5);
            console.info('[Recog] parsed food count=' + String(foodNames.length) + ' limited=' + String(limited.length) +
              ' names=' + limited.join(','));
            if (limited.length > 0) {
              const items: RecognizedFoodItem[] = [];
              for (let i = 0; i < limited.length; i++) {
                const name = limited[i];
                // 先创建基础对象，稍后填充营养
                const item: RecognizedFoodItem = {
                  id: 'food_' + Date.now() + '_' + i,
                  foodName: name,
                  grams: 200,
                  calories: 0,
                  isSnack: false,
                  snackReason: '',
                  saved: false,
                  isCalcCalories: false,
                  isJudgingSnack: false,
                  snackAnswer: '',
                  snackAnswerIsSnack: false,
                  protein: 0,
                  fat: 0,
                  carbs: 0,
                  caloriesPer100: 0,
                  proteinPer100: 0,
                  fatPer100: 0,
                  carbsPer100: 0
                };
                items.push(item);
              }

              // 串行获取营养（避免并发打爆 GLM 免费 key，减少失败率）
              for (let i = 0; i < items.length; i++) {
                const item = items[i];
                try {
                  const nutrition = await this.getFoodNutrition(item.foodName);
                  if (nutrition) {
                    item.caloriesPer100 = nutrition.cal;
                    item.proteinPer100 = nutrition.pro;
                    item.fatPer100 = nutrition.fat;
                    item.carbsPer100 = nutrition.carb;
                    item.calories = Math.round(nutrition.cal * 200 / 100);
                    item.protein = Math.round(nutrition.pro * 200 / 100);
                    item.fat = Math.round(nutrition.fat * 200 / 100);
                    item.carbs = Math.round(nutrition.carb * 200 / 100);
                  } else {
                    const local = FoodCalories.getNutrition(item.foodName, 100);
                    if (local.cal > 0) {
                      item.caloriesPer100 = local.cal;
                      item.proteinPer100 = local.pro;
                      item.fatPer100 = local.fat;
                      item.carbsPer100 = local.carb;
                      item.calories = Math.round(local.cal * 200 / 100);
                      item.protein = Math.round(local.pro * 200 / 100);
                      item.fat = Math.round(local.fat * 200 / 100);
                      item.carbs = Math.round(local.carb * 200 / 100);
                    }
                  }
                } catch (e) {
                  console.error('[Recog] nutrition error for ' + item.foodName, JSON.stringify(e));
                }
                // 串行间隔，避免瞬时并发
                if (i < items.length - 1) {
                  await new Promise<void>((resolve) => setTimeout(resolve, 300));
                }
              }

              return {
                foodName: items.map(item => item.foodName).join(','),
                confidence: 0.8,
                source: RecognitionMode.CLOUD,
                foodItems: items
              };
            }
          }
        }
      } else {
        // 打印完整错误码，便于真机排查（连不了 hdc 时也可通过错误信息判断）
        console.error('GLM request failed code=' + String(code) + ' resp=' + result.substring(0, 200));
        let errMsg: string = '云端识别失败（' + String(code) + '）';
        if (code === 401) {
          errMsg = '云端识别失败：API Key 无效';
        } else if (code === 429) {
          errMsg = '云端识别失败：请求过于频繁，请稍后再试';
        } else if (code === 400) {
          errMsg = '云端识别失败：请求参数异常';
        }
        return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD, error: errMsg };
      }
      return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD, error: '云端识别失败，请检查网络或稍后重试' };
    } catch (err) {
      const e = err as BusinessError;
      console.error('recognizeMultiple error: ' + e.code + ' ' + e.message);
      return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD, error: '识别过程出错（' + e.code + '）' };
    }
  }

  private parseMultipleFoodNames(raw: string): string[] {
    let text = raw.trim();
    if (text.length === 0) {
      return [];
    }
    // 非食物图：GLM 可能返回"无"/"没有"/"未识别"等
    if (text === '无' || text === '没有' || text === '未识别到食物' || text === '未识别到' ||
      text.indexOf('无食物') >= 0 || text.indexOf('没有食物') >= 0 || text.indexOf('不是食物') >= 0 ||
      text.indexOf('无任何') >= 0) {
      return [];
    }
    text = text.replace(/[\n\r「」""'']/g, '');
    text = text.replace(/^(识别结果|答案|食物名称|菜品)[:：]\s*/, '');
    text = text.replace(/\d+[.、\)）]\s*/g, '');
    text = text.replace(/[一二三四五六七八九十]+[、\)）]\s*/g, '');
    const names = text.split(/[,，、；;\s]+/)
      .map(s => s.trim())
      .filter(s => s.length > 0 && s.length <= 20 && s !== '无' && s !== '没有' && s !== '无食物');
    return names;
  }

  // 获取每100g营养（公开方法）
  async getFoodNutrition(foodName: string): Promise<NutritionPer100 | null> {
    const key = foodName.trim();
    if (key === '' || !this.isCloudConfigured()) {
      return null;
    }

    if (this.per100NutritionCache.has(key)) {
      return this.per100NutritionCache.get(key)!;
    }

    const local = FoodCalories.getNutrition(key, 100);
    if (local.cal > 0) {
      const result: NutritionPer100 = { cal: local.cal, pro: local.pro, fat: local.fat, carb: local.carb };
      this.per100NutritionCache.set(key, result);
      return result;
    }

    try {
      const foodJudge = await this.askIsFood(key);
      if (!foodJudge.isFood) {
        console.info('getFoodNutrition rejected non-food: ' + key);
        return null;
      }

      const promptText = `请提供"${key}"每100克可食用部分的营养成分，包括热量（千卡）、蛋白质（克）、脂肪（克）、碳水化合物（克）。只返回一个JSON对象，格式为{"cal":数值,"pro":数值,"fat":数值,"carb":数值}，不要任何其他文字。`;
      // 文字模型：content 必须是纯字符串（不能是对象数组）
      const textBody: ChatTextRequestBody = {
        model: FoodRecognitionService.CHAT_MODEL,
        messages: [
          {
            role: 'user',
            content: promptText
          }
        ],
        temperature: 0
      };
      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.VISION_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.glmApiKey
        },
        extraData: JSON.stringify(textBody),
        connectTimeout: 15000,
        readTimeout: 30000
      });
      request.destroy();
        const code: number = response.responseCode;
      if (code !== 200) {
        console.error('getFoodNutrition http failed code=' + String(code));
        return null;
      }
      const result: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      console.info('[Nutrition] GLM resp for "' + key + '": ' + result.substring(0, 200));
      const parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
      const choicesObj = parsed['choices'];
      if (choicesObj !== undefined && Array.isArray(choicesObj)) {
        const choicesArr = choicesObj as Array<Record<string, Object>>;
        if (choicesArr.length > 0) {
          const messageObj = choicesArr[0]['message'] as Record<string, Object>;
          const content: string = String(messageObj['content'] ?? '');
          const jsonMatch = content.match(/\{.*\}/);
          if (jsonMatch) {
            try {
              const data = JSON.parse(jsonMatch[0]) as NutritionPer100;
              const cal = parseFloat(String(data.cal));
              const pro = parseFloat(String(data.pro));
              const fat = parseFloat(String(data.fat));
              const carb = parseFloat(String(data.carb));
              console.info('[Nutrition] parsed cal=' + String(cal) + ' pro=' + String(pro) +
                ' fat=' + String(fat) + ' carb=' + String(carb));
              // 放宽热量范围：>=5 视为有效（原 >=10）
              if (!isNaN(cal) && !isNaN(pro) && !isNaN(fat) && !isNaN(carb) && cal >= 5 && cal <= 2000) {
                const nutrition: NutritionPer100 = { cal, pro, fat, carb };
                this.per100NutritionCache.set(key, nutrition);
                return nutrition;
              }
            } catch (e) {
              console.warn('parse nutrition JSON failed', e);
            }
          } else {
            console.warn('[Nutrition] no JSON found in content: ' + content.substring(0, 150));
          }
        }
      }
      return null;
    } catch (err) {
      const e = err as BusinessError;
      console.error('getFoodNutrition error: ' + e.code + ' ' + e.message);
      return null;
    }
  }

  // 计算卡路里（复用营养获取）
  async calculateCalories(foodName: string, grams: number, forceRefresh: boolean = false): Promise<number> {
    if (!this.isCloudConfigured()) {
      return -1;
    }
    if (grams <= 0) {
      return -1;
    }
    const key: string = foodName.trim();
    if (key === '') {
      return -1;
    }

    if (forceRefresh) {
      this.per100NutritionCache.delete(key);
    }

    const nutrition = await this.getFoodNutrition(key);
    if (nutrition) {
      return Math.round(nutrition.cal * grams / 100);
    }
    return -1;
  }

  async calculateSportCalories(sportType: string, minutes: number, intensity: string, weightKg: number, distanceKm: number = 0): Promise<number> {
    if (!this.isCloudConfigured()) {
      return -1;
    }
    try {
      let promptText: string;
      if (distanceKm > 0) {
        promptText = '我做了' + sportType + '运动，时长' + String(minutes) +
          '分钟，实际路程' + distanceKm.toFixed(2) + '公里，强度为' + intensity +
          '，体重' + String(Math.round(weightKg)) +
          '公斤。请结合路程和体重估算这次运动消耗的千卡数。只回答一个数字（总千卡数），不要任何其他文字。';
      } else {
        promptText = '我做了' + sportType + '运动，时长' + String(minutes) +
          '分钟，强度为' + intensity + '，体重' + String(Math.round(weightKg)) +
          '公斤。请估算这次运动消耗的千卡数。只回答一个数字（总千卡数），不要任何其他文字。';
      }
      // 文字模型：content 必须是纯字符串（不能是对象数组）
      const textBody: ChatTextRequestBody = {
        model: FoodRecognitionService.CHAT_MODEL,
        messages: [
          {
            role: 'user',
            content: promptText
          }
        ],
        temperature: 0
      };
      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.VISION_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.glmApiKey
        },
        extraData: JSON.stringify(textBody),
        connectTimeout: 15000,
        readTimeout: 30000
      });
      request.destroy();
      const code: number = response.responseCode;
      if (code !== 200) {
        console.error('calculateSportCalories http failed code=' + String(code));
        return -1;
      }
      const result: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
      const choicesObj = parsed['choices'];
      if (choicesObj !== undefined && Array.isArray(choicesObj)) {
        const choicesArr = choicesObj as Array<Record<string, Object>>;
        if (choicesArr.length > 0) {
          const messageObj = choicesArr[0]['message'] as Record<string, Object>;
          const content: string = String(messageObj['content'] ?? '');
          const num = this.parseCalories(content);
          if (num >= 0) {
            return num;
          }
        }
      }
      return -1;
    } catch (err) {
      const e = err as BusinessError;
      console.error('calculateSportCalories error: ' + e.code + ' ' + e.message);
      return -1;
    }
  }

  private parseCalories(raw: string): number {
    const text: string = raw.trim();
    if (text === '') {
      return -1;
    }
    const range = text.match(/(\d+(?:\.\d+)?)\s*[-~至到]\s*(\d+(?:\.\d+)?)/);
    if (range && range.length >= 3) {
      const a: number = parseFloat(range[1]);
      const b: number = parseFloat(range[2]);
      const mid: number = Math.round((a + b) / 2);
      if (this.isReasonablePer100(mid)) {
        return mid;
      }
    }
    const numbers: number[] = [];
    const re = /\d+(?:\.\d+)?/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(text)) !== null) {
      numbers.push(parseFloat(m[0]));
    }
    if (numbers.length === 0) {
      return -1;
    }
    const candidates = numbers.filter((n: number) => this.isReasonablePer100(n));
    if (candidates.length > 0) {
      return Math.round(candidates[candidates.length - 1]);
    }
    return -1;
  }

  private isReasonablePer100(n: number): boolean {
    return n >= 10 && n <= 900;
  }

  // 本地识别（暂未实现）
  private async recognizeLocal(uri: string): Promise<RecognitionOutcome> {
    void uri;
    try {
      return { foodName: '', confidence: 0, source: RecognitionMode.LOCAL };
    } catch (err) {
      return { foodName: '', confidence: 0, source: RecognitionMode.LOCAL };
    }
  }

  private async recognizeCloud(uri: string): Promise<RecognitionOutcome> {
    try {
      const base64 = await this.uriToBase64(uri);
      if (base64.length === 0) {
        console.error('recognizeCloud: base64 empty, uri=' + uri);
        return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD };
      }
      const imageUrl: Record<string, string> = { 'url': 'data:image/jpeg;base64,' + base64 };
      const imgContent: GlmContent = {
        type: 'image_url',
        image_url: imageUrl
      };
      const textContent: GlmContent = {
        type: 'text',
        text: '请识别图片中的主食/菜品/食材，只返回最准确的中文食物名称，禁止添加任何解释、序号、标点、单位、前缀后缀。例如：番茄炒蛋'
      };
      const contents: Array<GlmContent> = [imgContent, textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.VISION_MODEL,
        messages: messages
      };
      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.VISION_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.glmApiKey
        },
        extraData: JSON.stringify(requestBody),
        connectTimeout: 15000,
        readTimeout: 30000
      });
      request.destroy();
      const code: number = response.responseCode;
      const result: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      if (code === 200) {
        const parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
        const choicesObj = parsed['choices'];
        if (choicesObj !== undefined && Array.isArray(choicesObj)) {
          const choicesArr = choicesObj as Array<Record<string, Object>>;
          if (choicesArr.length > 0) {
            const first = choicesArr[0];
            const messageObj = first['message'] as Record<string, Object>;
            const content: string = String(messageObj['content'] ?? '');
            const foodName = this.cleanCloudResult(content);
            if (foodName.length > 0) {
              return { foodName: foodName, confidence: 0.8, source: RecognitionMode.CLOUD };
            }
          }
        }
      } else {
        console.error('GLM request failed code=' + String(code) + ' resp=' + result);
      }
      return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD };
    } catch (err) {
      const e = err as BusinessError;
      console.error('recognizeCloud error: ' + e.code + ' ' + e.message);
      return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD };
    }
  }

  private cleanCloudResult(raw: string): string {
    let text = raw.trim();
    text = text.replace(/[\n\r「」""'']/g, '');
    if (text.includes(':')) {
      text = text.substring(text.indexOf(':') + 1);
    }
    if (text.includes('：')) {
      text = text.substring(text.indexOf('：') + 1);
    }
    text = text.replace(/^\d+[.、\)）]\s*/, '');
    text = text.replace(/^[一二三四五六七八九十]+[、\)）]\s*/, '');
    text = text.trim();
    if (text.length > 20) {
      text = text.substring(0, 20);
    }
    return text;
  }

  async askIsSnack(foodName: string): Promise<SnackJudge> {
    const result: SnackJudge = { isSnack: false, reason: '', aiUsed: false };
    if (!this.isCloudConfigured() || foodName.trim().length === 0) {
      return result;
    }
    try {
      const promptText = '判断"' + foodName.trim() + '"是否属于零食（非正餐的小吃、甜点、加餐食品）。' +
        '用以下格式回答，不要多余文字：' +
        '是或不是' + '|' + '简要理由（20字以内）';
      // 文字模型：content 必须是纯字符串（不能是对象数组）
      const textBody: ChatTextRequestBody = {
        model: FoodRecognitionService.CHAT_MODEL,
        messages: [
          {
            role: 'user',
            content: promptText
          }
        ],
        temperature: 0
      };
      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.VISION_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.glmApiKey
        },
        extraData: JSON.stringify(textBody),
        connectTimeout: 15000,
        readTimeout: 30000
      });
      request.destroy();
      const code: number = response.responseCode;
      if (code !== 200) {
        console.error('askIsSnack http failed code=' + String(code));
        return result;
      }
      // 请求已成功发出并返回，AI 参与了判断
      result.aiUsed = true;
      const resp: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const parsed: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
      const choicesObj = parsed['choices'];
      if (choicesObj !== undefined && Array.isArray(choicesObj)) {
        const choicesArr = choicesObj as Array<Record<string, Object>>;
        if (choicesArr.length > 0) {
          const messageObj = choicesArr[0]['message'] as Record<string, Object>;
          const content: string = String(messageObj['content'] ?? '');
          const parts: string[] = content.split('|');
          const answer: string = parts.length > 0 ? parts[0].trim() : '';
          result.isSnack = answer.indexOf('是') >= 0 && answer.indexOf('不是') < 0;
          result.reason = parts.length > 1 ? parts[1].trim() : content;
        }
      }
      return result;
    } catch (err) {
      const e = err as BusinessError;
      console.error('askIsSnack error: ' + e.code + ' ' + e.message);
      return result;
    }
  }

  async askIsFood(foodName: string): Promise<FoodJudge> {
    const result: FoodJudge = { isFood: false, reason: '' };
    const key = foodName.trim();
    if (!this.isCloudConfigured() || key.length === 0) {
      result.isFood = true;
      result.reason = '云端不可用，跳过校验';
      return result;
    }
    // 常见食材/配料直接放行（AI 可能误判为"非食物"，但实际可食用）
    const ingredientWhitelist: string[] = ['肉末', '肉丝', '肉片', '辣椒', '花椒', '蘑菇', '木耳',
      '葱', '姜', '蒜', '蒜末', '姜末', '葱花', '香菜', '豆瓣', '酱油', '醋', '糖', '盐',
      '鸡肉', '猪肉', '牛肉', '鱼肉', '虾', '鸡蛋', '豆腐', '土豆', '白菜', '青菜', '胡萝卜',
      '洋葱', '番茄', '黄瓜', '茄子', '青椒', '豆角', '玉米', '花生', '芝麻', '粉丝', '粉条',
      '大米', '面条', '米饭', '馒头', '包子', '饺子', '馄饨', '粥'];
    const isIngredient: boolean = ingredientWhitelist.some((w: string) => key.indexOf(w) >= 0);
    if (isIngredient) {
      result.isFood = true;
      result.reason = '常见食材，直接放行';
      return result;
    }
    try {
      const promptText = '判断"' + key + '"是否是可食用的食物或饮品（包括水果、蔬菜、肉类、主食、零食、饮料、调味品等任何可以吃进肚子里的东西）。' +
        '如果是食物或饮品回答"是"，如果是手机、桌子、汽车、电脑、书本等非食用物品回答"不是"。' +
        '用以下格式回答，不要多余文字：' +
        '是或不是' + '|' + '简要理由（15字以内）';
      // 文字模型：content 必须是纯字符串（不能是对象数组）
      const textBody: ChatTextRequestBody = {
        model: FoodRecognitionService.CHAT_MODEL,
        messages: [
          {
            role: 'user',
            content: promptText
          }
        ],
        temperature: 0
      };
      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.VISION_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.glmApiKey
        },
        extraData: JSON.stringify(textBody),
        connectTimeout: 15000,
        readTimeout: 30000
      });
      request.destroy();
      const code: number = response.responseCode;
      if (code !== 200) {
        console.error('askIsFood http failed code=' + String(code));
        result.isFood = true;
        result.reason = '校验服务异常，放行';
        return result;
      }
      const resp: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const parsed: Record<string, Object> = JSON.parse(resp) as Record<string, Object>;
      const choicesObj = parsed['choices'];
      if (choicesObj !== undefined && Array.isArray(choicesObj)) {
        const choicesArr = choicesObj as Array<Record<string, Object>>;
        if (choicesArr.length > 0) {
          const messageObj = choicesArr[0]['message'] as Record<string, Object>;
          const content: string = String(messageObj['content'] ?? '');
          const parts: string[] = content.split('|');
          const answer: string = parts.length > 0 ? parts[0].trim() : '';
          // 只有明确回答"不是/否"才拒绝；含糊/包含"是"都放行（宁多勿漏）
          const clearlyNotFood: boolean = (answer.indexOf('不是') >= 0 || answer.indexOf('否') >= 0 ||
            answer.indexOf('不能吃') >= 0 || answer.indexOf('非食物') >= 0) &&
            answer.indexOf('是') < 0;
          result.isFood = !clearlyNotFood;
          result.reason = parts.length > 1 ? parts[1].trim() : content;
        }
      }
      return result;
    } catch (err) {
      const e = err as BusinessError;
      console.error('askIsFood error: ' + e.code + ' ' + e.message);
      result.isFood = true;
      result.reason = '校验异常，放行';
      return result;
    }
  }

  async uriToBase64(uri: string): Promise<string> {
    let fd: number = -1;
    try {
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      fd = file.fd;
      const source = image.createImageSource(fd);
      // 压缩到 256px 并降低质量，控制 base64 体积（真机大图避免请求体过大被拒）
      const opts: image.DecodingOptions = {
        desiredSize: { width: 256, height: 256 },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      const pixelMap = await source.createPixelMap(opts);
      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: 55
      };
      const data: ArrayBuffer = await packer.packing(pixelMap, packOpts);
      const base64Helper = new util.Base64Helper();
      const b64: string = base64Helper.encodeToStringSync(new Uint8Array(data));
      console.info('uriToBase64 success, len=' + String(b64.length));
      return b64;
    } catch (err) {
      console.error('uriToBase64 error:', JSON.stringify(err));
      return '';
    } finally {
      if (fd !== -1) {
        try {
          fileIo.closeSync(fd);
        } catch (err) {
          console.error('close fd error');
        }
      }
    }
  }
}