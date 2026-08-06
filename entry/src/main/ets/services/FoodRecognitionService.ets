import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { FoodCalories, AiDefaults } from '../common/Constants';

export interface RecognizedFoodItem {
  id: string;
  foodName: string;
  grams: number;
  calories: number;
  isSnack: boolean;
  snackReason: string;
  saved: boolean;
  isCalcCalories: boolean; // 是否正在计算卡路里
  isJudgingSnack: boolean; // 是否正在判断零食
  snackAnswer: string; // AI 零食判断答案
  snackAnswerIsSnack: boolean; // AI 判断是否是零食
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
}

export interface FoodJudge {
  isFood: boolean;
  reason: string;
}

export class RecognitionMode {
  static readonly LOCAL: string = 'local';
  static readonly CLOUD: string = 'cloud';
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

/**
 * 食物识别服务（本地 + 云端双通道）
 *
 * 通道说明：
 * - 本地通道 (LOCAL)：CoreVisionKit 本地分类，离线免费，识别单食材
 * - 云端通道 (CLOUD)：GLM-4V 多模态大模型，联网，识别复合菜
 *
 * 原则：只返回真实识别结果。识别失败时返回带 error 的结果，
 * 绝不返回随机/模拟数据伪装成功。
 */
export class FoodRecognitionService {
  private static instance: FoodRecognitionService;
  private glmApiKey: string = '';
  private static readonly VISION_URL: string = AiDefaults.API_URL;
  private static readonly VISION_MODEL: string = AiDefaults.VISION_MODEL;
  private static readonly CHAT_MODEL: string = AiDefaults.CHAT_MODEL;
  // 每100克热量缓存：同一食物首次云端计算后固定，避免多次识别数值漂移
  private per100Cache: Map<string, number> = new Map<string, number>();

  static getInstance(): FoodRecognitionService {
    if (!FoodRecognitionService.instance) {
      FoodRecognitionService.instance = new FoodRecognitionService();
    }
    return FoodRecognitionService.instance;
  }

  // 识图模型固定使用智谱 GLM（视觉管道与本地 CoreVisionKit 绑定），仅从 rawfile 加载内置密钥
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

  /**
   * 双通道识别：优先本地，本地未识别出则用云端。
   * 两者都失败时返回带 error 的结果，绝不返回模拟数据。
   */
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

  /**
   * 多食物识别：识别图片中的所有食物
   * 返回包含多个食物项的 RecognitionOutcome
   */
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
      // 优化Prompt：严格约束输出格式，禁止序号、解释、多余符号
      const textContent: GlmContent = {
        type: 'text',
        text: '请识别图片中所有可食用的食物、菜品、食材，用英文逗号严格分隔每个食物的中文名称，禁止添加序号、解释、换行、顿号、分号等任何多余内容。例如：米饭,番茄炒蛋,清炒生菜'
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
            const foodItems = this.parseMultipleFoodResult(content);
            if (foodItems.length > 0) {
              return {
                foodName: foodItems.map(item => item.foodName).join(','),
                confidence: 0.8,
                source: RecognitionMode.CLOUD,
                foodItems: foodItems
              };
            }
          }
        }
      } else {
        console.error('GLM request failed code=' + String(code) + ' resp=' + result);
      }
      return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD, error: '云端识别失败，请检查网络或稍后重试' };
    } catch (err) {
      const e = err as BusinessError;
      console.error('recognizeMultiple error: ' + e.code + ' ' + e.message);
      return { foodName: '', confidence: 0, source: RecognitionMode.CLOUD, error: '识别过程出错' };
    }
  }

  /**
   * 解析多食物识别结果
   * 增强鲁棒性：处理序号、前缀、多种分隔符、多余符号
   */
  private parseMultipleFoodResult(raw: string): RecognizedFoodItem[] {
    let text = raw.trim();
    if (text.length === 0) {
      return [];
    }

    // 第一步：清洗原始文本，去除干扰内容
    // 去除换行、引号、特殊符号
    text = text.replace(/[\n\r「」""'']/g, '');
    // 去除常见前缀
    text = text.replace(/^(识别结果|答案|食物名称|菜品)[:：]\s*/, '');
    // 去除序号格式：1. 2、 (1) 一、 等
    text = text.replace(/\d+[.、\)）]\s*/g, '');
    text = text.replace(/[一二三四五六七八九十]+[、\)）]\s*/g, '');

    // 第二步：按多种分隔符拆分
    const foodNames = text.split(/[,，、；;\s]+/)
      .map(s => s.trim())
      .filter(s => s.length > 0 && s.length <= 20);

    // 第三步：为每个食物创建 RecognizedFoodItem
    const items: RecognizedFoodItem[] = [];
    for (let i = 0; i < foodNames.length; i++) {
      const name = foodNames[i];
      if (name.length > 0 && name.length <= 20) {
        items.push({
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
          snackAnswerIsSnack: false
        });
      }
    }

    console.info('parseMultipleFoodResult: found ' + String(items.length) + ' foods');
    return items;
  }

  /**
   * 本地通道：CoreVisionKit 图像分类（尚未接入，返回空让云端接管）
   */
  private async recognizeLocal(uri: string): Promise<RecognitionOutcome> {
    try {
      return { foodName: '', confidence: 0, source: RecognitionMode.LOCAL };
    } catch (err) {
      return { foodName: '', confidence: 0, source: RecognitionMode.LOCAL };
    }
  }

  /**
   * 云端通道：GLM-4V 多模态大模型
   * 优化Prompt约束，增强结果清洗
   */
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
      // 优化Prompt：严格约束仅返回食物名称，禁止多余内容
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

  /**
   * 云端计算卡路里：根据食物名称 + 克数，让 GLM 估算热量
   * 返回 -1 表示计算失败
   * 优化：修复小数解析bug，增强Prompt约束，提升成功率
   */
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
    // 非食物内容驳回：先判断是否可食用，不是则直接返回 -1
    const judge: FoodJudge = await this.askIsFood(key);
    if (!judge.isFood) {
      console.info('calculateCalories rejected non-food: ' + key + ' reason=' + judge.reason);
      return -1;
    }
    // 命中缓存：同一食物热量固定，避免多次识别数值漂移（forceRefresh 时跳过缓存重新识别）
    if (!forceRefresh && this.per100Cache.has(key)) {
      const cachedPer100: number = this.per100Cache.get(key) ?? -1;
      if (cachedPer100 > 0) {
        return Math.round(cachedPer100 * grams / 100);
      }
    }
    try {
      // 本地食物库参考值（每100克千卡），用于校验云端结果是否异常偏离
      const localPer100: number = FoodCalories.lookupCaloriesPer100g(foodName);
      // 优化Prompt：严格要求返回纯数字，避免单位和解释
      const promptText = '请查询"' + foodName + '"每100克的热量，只返回一个纯数字（单位：千卡），禁止添加任何解释、单位、文字、标点。例如：116';
      const textContent: GlmContent = { type: 'text', text: promptText };
      const contents: Array<GlmContent> = [textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.CHAT_MODEL,
        messages: messages,
        temperature: 0
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
      if (code !== 200) {
        console.error('calculateCalories http failed code=' + String(code));
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
          const per100 = this.parseCalories(content);
          if (per100 >= 0) {
            // 云端结果与本地参考值偏差超过 60% 时，以本地为准，避免跳变
            let finalPer100: number = per100;
            if (localPer100 > 0) {
              const diff: number = Math.abs(per100 - localPer100) / localPer100;
              if (diff > 0.6) {
                console.warn('calculateCalories cloud=' + String(per100) +
                  ' local=' + String(localPer100) + ' use local');
                finalPer100 = localPer100;
              }
            }
            // 结果不合理（每100克<10千卡）时视为识别失败，不写缓存不返回
            if (!this.isReasonablePer100(finalPer100)) {
              console.warn('calculateCalories unreasonable result=' + String(finalPer100) +
                ' for "' + key + '", treat as fail');
              return -1;
            }
            // 写入缓存，后续同食物直接复用
            this.per100Cache.set(key, finalPer100);
            return Math.round(finalPer100 * grams / 100);
          }
        }
      }
      return -1;
    } catch (err) {
      const e = err as BusinessError;
      console.error('calculateCalories error: ' + e.code + ' ' + e.message);
      return -1;
    }
  }

  /**
   * 解析热量数值
   * 修复：支持小数解析，避免整数拆分导致的数值错误
   */
  private parseCalories(raw: string): number {
    const text: string = raw.trim();
    if (text === '') {
      return -1;
    }
    // 优先识别范围格式：支持小数，如"60.5-120.3" / "80~160" / "约70到140"，取中间值
    const range = text.match(/(\d+(?:\.\d+)?)\s*[-~至到]\s*(\d+(?:\.\d+)?)/);
    if (range && range.length >= 3) {
      const a: number = parseFloat(range[1]);
      const b: number = parseFloat(range[2]);
      const mid: number = Math.round((a + b) / 2);
      if (this.isReasonablePer100(mid)) {
        return mid;
      }
    }
    // 识别所有数字（支持小数），选取位于合理范围（10~900 千卡/100g）的数值
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
      // 取最后一个合理数值（通常为热量值，排除"100克"中的100）
      return Math.round(candidates[candidates.length - 1]);
    }
    return -1;
  }

  private isReasonablePer100(n: number): boolean {
    // 每100克热量合理范围：10~900 千卡（低于10如纯水/茶几乎无热量，视为识别错误）
    return n >= 10 && n <= 900;
  }

  /**
   * 云端计算运动热量：根据运动类型 + 时长 + 烈度 + 体重 + 距离，让 GLM 估算
   * distanceKm 为实际 GPS 路程（走路/跑步/骑行），无定位时传 0
   * 返回 -1 表示计算失败
   */
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
      const textContent: GlmContent = { type: 'text', text: promptText };
      const contents: Array<GlmContent> = [textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.CHAT_MODEL,
        messages: messages,
        temperature: 0
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

  /**
   * 清洗云端识别结果
   * 增强：去除序号、前缀、多余符号，提取纯净食物名
   */
  private cleanCloudResult(raw: string): string {
    let text = raw.trim();
    // 去除换行、引号、特殊符号
    text = text.replace(/[\n\r「」""'']/g, '');
    // 去除常见前缀（冒号前的描述）
    if (text.includes(':')) {
      text = text.substring(text.indexOf(':') + 1);
    }
    if (text.includes('：')) {
      text = text.substring(text.indexOf('：') + 1);
    }
    // 去除开头序号
    text = text.replace(/^\d+[.、\)）]\s*/, '');
    text = text.replace(/^[一二三四五六七八九十]+[、\)）]\s*/, '');
    text = text.trim();
    // 长度限制
    if (text.length > 20) {
      text = text.substring(0, 20);
    }
    return text;
  }

  /**
   * 询问 AI 某食物是否属于零食
   * 返回结构：{ isSnack, reason }
   */
  async askIsSnack(foodName: string): Promise<SnackJudge> {
    const result: SnackJudge = { isSnack: false, reason: '' };
    if (!this.isCloudConfigured() || foodName.trim().length === 0) {
      return result;
    }
    try {
      const promptText = '判断"' + foodName.trim() + '"是否属于零食（非正餐的小吃、甜点、加餐食品）。' +
        '用以下格式回答，不要多余文字：' +
        '是或不是' + '|' + '简要理由（20字以内）';
      const textContent: GlmContent = { type: 'text', text: promptText };
      const contents: Array<GlmContent> = [textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.CHAT_MODEL,
        messages: messages,
        temperature: 0
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
      if (code !== 200) {
        console.error('askIsSnack http failed code=' + String(code));
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

  /**
   * 判断输入的名称是否是可食用的食物（驳回非食物内容）
   */
  async askIsFood(foodName: string): Promise<FoodJudge> {
    const result: FoodJudge = { isFood: false, reason: '' };
    const key = foodName.trim();
    if (!this.isCloudConfigured() || key.length === 0) {
      // 云端不可用时保守放行（回退本地食物库），避免误伤正常食物
      result.isFood = true;
      result.reason = '云端不可用，跳过校验';
      return result;
    }
    try {
      const promptText = '判断"' + key + '"是否是可食用的食物或饮品（包括水果、蔬菜、肉类、主食、零食、饮料、调味品等任何可以吃进肚子里的东西）。' +
        '如果是食物或饮品回答"是"，如果是手机、桌子、汽车、电脑、书本等非食用物品回答"不是"。' +
        '用以下格式回答，不要多余文字：' +
        '是或不是' + '|' + '简要理由（15字以内）';
      const textContent: GlmContent = { type: 'text', text: promptText };
      const contents: Array<GlmContent> = [textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.CHAT_MODEL,
        messages: messages,
        temperature: 0
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
      if (code !== 200) {
        console.error('askIsFood http failed code=' + String(code));
        // 网络异常时保守放行，避免误伤
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
          result.isFood = answer.indexOf('是') >= 0 && answer.indexOf('不是') < 0;
          result.reason = parts.length > 1 ? parts[1].trim() : content;
        }
      }
      return result;
    } catch (err) {
      const e = err as BusinessError;
      console.error('askIsFood error: ' + e.code + ' ' + e.message);
      // 异常时保守放行
      result.isFood = true;
      result.reason = '校验异常，放行';
      return result;
    }
  }

  /**
   * 图片 URI → base64（压缩到 512px 保证体积）
   * 相册 URI (file://media/...) 需要 fileIo 打开成 fd 才能创建 ImageSource
   */
  async uriToBase64(uri: string): Promise<string> {
    let fd: number = -1;
    try {
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      fd = file.fd;
      const source = image.createImageSource(fd);
      const opts: image.DecodingOptions = {
        desiredSize: { width: 512, height: 512 },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      const pixelMap = await source.createPixelMap(opts);
      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: 80
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