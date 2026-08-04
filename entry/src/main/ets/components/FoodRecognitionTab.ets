import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ThemeColors, DbRow } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { FoodRecognitionService, RecognitionOutcome } from '../services/FoodRecognitionService';

@Component
export struct FoodRecognitionTab {
  @StorageLink('currentTheme') theme: string = 'dark';
  @State previewUri: string = '';
  @State recognizedFood: string = '';
  @State isRecognizing: boolean = false;
  @State scanAnim: boolean = false;
  @State resultMsg: string = '对准食物拍照或从相册选择，看看它是什么菜';
  @State recogSource: string = '';
  @State gramsInput: string = '200';
  @State gramsSlider: number = 200;
  @State savedSuccess: boolean = false;
  @State cloudCalories: number = 0;
  @State isCalcCalories: boolean = false;

  private uiContext: common.UIAbilityContext | null = null;

  get bg(): string { return ThemeColors.bg(this.theme); }
  get card(): string { return ThemeColors.card(this.theme); }
  get txt(): string { return ThemeColors.text(this.theme); }
  get sub(): string { return ThemeColors.subText(this.theme); }

  get currentGrams(): number {
    const v = parseFloat(this.gramsInput);
    if (isNaN(v) || v <= 0) {
      return 0;
    }
    return v;
  }

  async refreshCloudCalories(grams?: number): Promise<void> {
    const g = grams !== undefined ? grams : this.currentGrams;
    if (this.recognizedFood.length === 0 || g <= 0) {
      this.cloudCalories = 0;
      return;
    }
    this.isCalcCalories = true;
    const result = await FoodRecognitionService.getInstance().calculateCalories(this.recognizedFood, g);
    this.cloudCalories = result >= 0 ? result : 0;
    this.isCalcCalories = false;
  }

  aboutToAppear(): void {
    this.uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async takePhoto(): Promise<void> {
    if (!this.uiContext) {
      return;
    }
    try {
      const result = await cameraPicker.pick(this.uiContext, [cameraPicker.PickerMediaType.PHOTO], {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      });
      const uri: string = result.resultUri;
      if (uri.length > 0) {
        this.previewUri = uri;
        this.recognizeFromUri(uri);
      }
    } catch (err) {
      console.error('takePhoto error:', JSON.stringify(err));
      promptAction.showToast({ message: '拍照失败或已取消' });
    }
  }

  async pickFromAlbum(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      if (result.photoUris.length > 0) {
        this.previewUri = result.photoUris[0];
        this.recognizeFromUri(result.photoUris[0]);
      }
    } catch (err) {
      console.error('pickFromAlbum error:', JSON.stringify(err));
      promptAction.showToast({ message: '选择图片失败或已取消' });
    }
  }

  async recognizeFromUri(uri: string): Promise<void> {
    this.isRecognizing = true;
    this.scanAnim = true;
    this.savedSuccess = false;
    this.resultMsg = '正在识别...';

    setTimeout(async () => {
      try {
        const outcome: RecognitionOutcome = await FoodRecognitionService.getInstance().recognize(uri);
        this.applyResult(outcome);
      } catch (err) {
        console.error('recognize error:', JSON.stringify(err));
        this.resultMsg = '识别失败，请重试';
      } finally {
        this.isRecognizing = false;
        this.scanAnim = false;
      }
    }, 1200);
  }

  applyResult(outcome: RecognitionOutcome): void {
    if (outcome.foodName.length === 0) {
      this.recognizedFood = '';
      this.recogSource = '';
      this.cloudCalories = 0;
      this.resultMsg = outcome.error && outcome.error.length > 0 ? outcome.error : '未识别出菜品，换个角度或光线试试';
      return;
    }
    this.recognizedFood = outcome.foodName;
    this.recogSource = outcome.source;
    this.gramsInput = '200';
    this.gramsSlider = 200;
    this.cloudCalories = 0;
    this.refreshCloudCalories();
    if (outcome.source === 'cloud') {
      this.resultMsg = '云端 AI 识别完成';
    } else if (outcome.source === 'local') {
      this.resultMsg = '本地识别完成';
    }
  }

  async saveToDiet(): Promise<void> {
    if (this.recognizedFood.length === 0) {
      promptAction.showToast({ message: '请先识别食物' });
      return;
    }
    const gramsVal: number = this.currentGrams;
    const grams: number = gramsVal > 0 ? gramsVal : this.gramsSlider;
    if (grams <= 0) {
      promptAction.showToast({ message: '请输入有效的克数' });
      return;
    }
    if (grams > 2000) {
      promptAction.showToast({ message: '单次最多2000克' });
      return;
    }
    let calories: number = this.cloudCalories;
    if (calories <= 0) {
      const cloud = await FoodRecognitionService.getInstance().calculateCalories(this.recognizedFood, grams);
      calories = cloud >= 0 ? cloud : 0;
    }
    const today = await GlobalData.getTodayDate();
    const record: DbRow = {
      date: today,
      meal_type: 'snack',
      food_name: this.recognizedFood,
      amount_g: grams,
      calories: calories,
      protein: 0,
      fat: 0,
      carbs: 0,
      timestamp: Date.now()
    };
    try {
      await GlobalData.db.addDietRecord(record);
      this.savedSuccess = true;
      promptAction.showToast({ message: '已添加到饮食记录' });
    } catch (err) {
      console.error('saveToDiet error:', JSON.stringify(err));
      promptAction.showToast({ message: '保存失败' });
    }
  }

  resetAll(): void {
    this.previewUri = '';
    this.recognizedFood = '';
    this.recogSource = '';
    this.savedSuccess = false;
    this.gramsInput = '200';
    this.gramsSlider = 200;
    this.resultMsg = '对准食物拍照或从相册选择，看看它是什么菜';
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('AI 识菜').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.txt)
          Blank()
          if (this.previewUri.length > 0) {
            Text('重新识别').fontSize(13).fontColor('#FF6B35')
              .onClick(() => { this.resetAll(); })
          }
        }
        .width('100%').padding({ left: 20, right: 20, top: 16 })

        Text('拍照看看这是什么菜').fontSize(13).fontColor(this.sub)
          .width('100%').padding({ left: 20, top: 4, bottom: 16 })

        // 中央识别区（扫描线动画）
        Stack() {
          Column() {
            if (this.previewUri.length > 0) {
              Image(this.previewUri)
                .width('100%').height(220).objectFit(ImageFit.Cover).borderRadius(20)
            } else {
              Column() {
                Text('🍽️').fontSize(72)
                Text('对准食物拍照或选择图片').fontSize(14).fontColor(this.sub).margin({ top: 12 })
                Text('自动识别这是什么菜').fontSize(12).fontColor(this.sub).margin({ top: 4 })
              }
              .width('100%').height(220).justifyContent(FlexAlign.Center)
            }
          }
          .width('100%').height(220).borderRadius(20)
          .backgroundColor(this.card)
          .border({ width: 2, color: '#FF6B35', style: BorderStyle.Dashed })

          if (this.scanAnim) {
            Column()
              .width('100%').height(3)
              .backgroundColor('#FF6B35')
              .offset({ y: this.scanAnim ? 0 : 210 })
              .animation({ duration: 1200, curve: Curve.Linear, iterations: -1 })
          }

          if (this.isRecognizing) {
            Column() {
              Text('🔍').fontSize(48)
              Text('识别中...').fontSize(14).fontColor(this.txt).margin({ top: 8 })
            }
            .width(120).height(120).borderRadius(60)
            .backgroundColor('#000000AA')
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%').height(220)
        .margin({ left: 16, right: 16 })

        // 操作按钮
        Row() {
          Button('📷 拍照')
            .layoutWeight(1).height(48)
            .backgroundColor('#FF6B35').borderRadius(24)
            .fontColor(Color.White).fontSize(15)
            .onClick(() => { this.takePhoto(); })

          Button('🖼 相册')
            .layoutWeight(1).height(48)
            .backgroundColor('#4CAF50').borderRadius(24)
            .fontColor(Color.White).fontSize(15)
            .margin({ left: 12 })
            .onClick(() => { this.pickFromAlbum(); })
        }
        .width('100%').padding({ left: 16, right: 16, top: 16 })

        // 识别结果 + 克数输入 + 添加记录
        if (this.recognizedFood.length > 0) {
          Column() {
            Row() {
              Text('🍽️').fontSize(32)
              Column() {
                Text(this.recognizedFood)
                  .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt)
                if (this.recogSource === 'cloud') {
                  Text('☁️ 云端识别').fontSize(11).fontColor('#03A9F4')
                } else if (this.recogSource === 'local') {
                  Text('📱 本地识别').fontSize(11).fontColor('#4CAF50')
                }
              }
              .alignItems(HorizontalAlign.Start).margin({ left: 10 })
              Blank()
            }
            .width('100%')

            Divider().color('#333333').height(1).margin({ top: 12, bottom: 12 })

            // 克数滑块 + 文本输入
            Text('食物份量').fontSize(13).fontColor(this.sub).width('100%')
            Row() {
              Slider({ value: this.gramsSlider, min: 10, max: 2000, step: 10, style: SliderStyle.OutSet })
                .layoutWeight(1)
                .selectedColor('#FF6B35')
                .onChange((value: number, mode: SliderChangeMode) => {
                  if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                    const valid: number = isNaN(value) ? 200 : value;
                    this.gramsSlider = valid;
                    this.gramsInput = String(valid);
                    this.refreshCloudCalories(valid);
                  }
                })
              Text(this.gramsInput.length > 0 ? this.gramsInput + 'g' : '200g')
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.txt)
                .margin({ left: 10 }).width(60)
            }
            .width('100%')

            Row() {
              Text('或手动输入(克):').fontSize(12).fontColor(this.sub)
              TextInput({ placeholder: '200', text: this.gramsInput })
                .type(InputType.Number)
                .width(120).height(36)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt)
                .placeholderColor(this.sub)
                .onChange((v: string) => {
                  this.gramsInput = v;
                  const num = parseFloat(v);
                  if (!isNaN(num) && num >= 10 && num <= 2000) {
                    this.gramsSlider = num;
                  }
                  if (!isNaN(num) && num > 0 && num <= 2000) {
                    this.refreshCloudCalories(num);
                  } else if (!isNaN(num) && num > 2000) {
                    promptAction.showToast({ message: '单次最多2000克' });
                    this.gramsInput = '2000';
                    this.gramsSlider = 2000;
                    this.refreshCloudCalories(2000);
                  } else {
                    this.cloudCalories = 0;
                  }
                })
              Text('g').fontSize(12).fontColor(this.sub).margin({ left: 6 })
            }
            .width('100%').margin({ top: 8 })

            // 卡路里显示（云端计算）
            Row() {
              Text('预计热量: ').fontSize(14).fontColor(this.sub)
              Blank()
              if (this.isCalcCalories) {
                Text('计算中...').fontSize(16).fontColor(this.sub)
              } else if (this.cloudCalories > 0) {
                Text(String(this.cloudCalories) + ' 千卡')
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
              } else {
                Text('-- 千卡').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.sub)
              }
            }
            .width('100%').margin({ top: 12 })

            // 添加记录按钮
            Button('➕ 添加到饮食记录')
              .width('100%').height(48)
              .backgroundColor(this.savedSuccess ? '#4CAF50' : '#FF6B35')
              .borderRadius(24)
              .fontColor(Color.White).fontSize(15)
              .margin({ top: 12 })
              .onClick(() => { this.saveToDiet(); })

            if (this.savedSuccess) {
              Text('✅ 已记录到今天的饮食，可在饮食页查看')
                .fontSize(12).fontColor('#4CAF50').width('100%').margin({ top: 8 })
            }
          }
          .width('100%').padding(16)
          .backgroundColor(this.card).borderRadius(14)
          .margin({ left: 16, right: 16, top: 20 })
        } else {
          Text(this.resultMsg).fontSize(12).fontColor(this.sub)
            .width('100%').padding({ left: 20, right: 20, top: 16 })
        }

        Divider().opacity(0).height(30)
      }
      .width('100%').alignItems(HorizontalAlign.Start)
    }
  }
}
