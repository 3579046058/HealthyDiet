import { visionKit } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FoodCalories } from '../common/Constants';

export interface FoodRecognitionResult {
  detectedFood: string;
  caloriesPer100g: number;
  confidence: number;
  rawLabel: string;
}

export class FoodRecognizer {
  private static instance: FoodRecognizer;
  private classifier: visionKit.ImageClassifier | null = null;
  private initialized: boolean = false;

  static getInstance(): FoodRecognizer {
    if (!FoodRecognizer.instance) {
      FoodRecognizer.instance = new FoodRecognizer();
    }
    return FoodRecognizer.instance;
  }

  async init(): Promise<void> {
    if (this.initialized) {
      return;
    }
    try {
      this.classifier = await visionKit.createImageClassifier({
        modelType: visionKit.ModelType.GENERAL,
        confidenceThreshold: 0.4
      });
      this.initialized = true;
      console.info('FoodRecognizer: classifier initialized');
    } catch (err) {
      const e = err as BusinessError;
      console.error('FoodRecognizer init error: ' + e.code + ' ' + e.message);
    }
  }

  async recognizePixelMap(pixelMap: image.PixelMap): Promise<FoodRecognitionResult> {
    await this.init();
    if (!this.classifier) {
      return this.emptyResult();
    }
    try {
      const result = await this.classifier.recognition(pixelMap, { topK: 5 });
      const labels: Array<visionKit.ImageClassification> = result.contents ?? [];
      for (const item of labels) {
        const rawLabel: string = item.label.toLowerCase();
        const matched: string = FoodCalories.matchFoodKeyword(rawLabel);
        if (matched.length > 0) {
          return {
            detectedFood: matched,
            caloriesPer100g: FoodCalories.getCaloriesFor(matched),
            confidence: item.confidence,
            rawLabel: rawLabel
          };
        }
      }
      if (labels.length > 0) {
        return {
          detectedFood: '',
          caloriesPer100g: 0,
          confidence: labels[0].confidence,
          rawLabel: labels[0].label
        };
      }
      return this.emptyResult();
    } catch (err) {
      const e = err as BusinessError;
      console.error('FoodRecognizer recognize error: ' + e.code + ' ' + e.message);
      return this.emptyResult();
    }
  }

  private emptyResult(): FoodRecognitionResult {
    return { detectedFood: '', caloriesPer100g: 0, confidence: 0, rawLabel: '' };
  }

  async release(): Promise<void> {
    if (this.classifier) {
      try {
        await this.classifier.release();
      } catch (err) {
        console.error('FoodRecognizer release error:', JSON.stringify(err));
      }
      this.classifier = null;
      this.initialized = false;
    }
  }
}
