import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

export interface RecognitionOutcome {
  foodName: string;
  confidence: number;
  source: string;
  error?: string;
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
  private static readonly GLM_API_KEY: string = '114f70a49f924bf895668890a1ced59a.Gi4Yz9MNpRbHnCru';
  private static readonly GLM_URL: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  private static readonly GLM_MODEL: string = 'glm-4v-flash';

  static getInstance(): FoodRecognitionService {
    if (!FoodRecognitionService.instance) {
      FoodRecognitionService.instance = new FoodRecognitionService();
    }
    return FoodRecognitionService.instance;
  }

  isCloudConfigured(): boolean {
    return FoodRecognitionService.GLM_API_KEY.length > 0;
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
      const textContent: GlmContent = {
        type: 'text',
        text: '请识别图片中的食物，只回答食物名称（中文），不要多余文字。'
      };
      const contents: Array<GlmContent> = [imgContent, textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.GLM_MODEL,
        messages: messages
      };

      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.GLM_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + FoodRecognitionService.GLM_API_KEY
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
   */
  async calculateCalories(foodName: string, grams: number): Promise<number> {
    if (!this.isCloudConfigured()) {
      return -1;
    }
    if (grams <= 0) {
      return -1;
    }
    try {
      // 让 GLM 只返回每100克热量，本地再乘克数，避免大克数计算误差
      const promptText = '"' + foodName + '"每100克的热量是多少千卡？' +
        '只回答一个数字（每100克的千卡数），不要任何其他文字。';
      const textContent: GlmContent = { type: 'text', text: promptText };
      const contents: Array<GlmContent> = [textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.GLM_MODEL,
        messages: messages
      };

      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.GLM_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + FoodRecognitionService.GLM_API_KEY
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
            return Math.round(per100 * grams / 100);
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

  private parseCalories(raw: string): number {
    const match = raw.match(/\d+/);
    if (match && match.length > 0) {
      return parseInt(match[0]);
    }
    return -1;
  }

  /**
   * 云端计算运动热量：根据运动类型 + 时长 + 烈度 + 体重，让 GLM 估算
   * 返回 -1 表示计算失败
   */
  async calculateSportCalories(sportType: string, minutes: number, intensity: string, weightKg: number): Promise<number> {
    if (!this.isCloudConfigured()) {
      return -1;
    }
    try {
      const promptText = '我做了' + sportType + '运动，时长' + String(minutes) +
        '分钟，强度为' + intensity + '，体重' + String(Math.round(weightKg)) +
        '公斤。请估算这次运动消耗的千卡数。只回答一个数字（总千卡数），不要任何其他文字。';
      const textContent: GlmContent = { type: 'text', text: promptText };
      const contents: Array<GlmContent> = [textContent];
      const message: GlmMessage = { role: 'user', content: contents };
      const messages: Array<GlmMessage> = [message];
      const requestBody: GlmRequestBody = {
        model: FoodRecognitionService.GLM_MODEL,
        messages: messages
      };

      const request = http.createHttp();
      const response = await request.request(FoodRecognitionService.GLM_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + FoodRecognitionService.GLM_API_KEY
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

  private cleanCloudResult(raw: string): string {
    let text = raw.trim();
    text = text.replace(/[「」"'\n\r]/g, '');
    text = text.split(':')[0];
    if (text.length > 20) {
      text = text.substring(0, 20);
    }
    return text;
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
