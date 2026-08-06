import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ThemeColors, DbRow, FoodCalories } from '../common/Constants'; // 添加 FoodCalories
import { GlobalData } from '../common/GlobalData';
import { FoodRecognitionService, RecognitionOutcome, RecognizedFoodItem } from '../services/FoodRecognitionService';
// 移除未使用的 FoodItemCard 导入

@Component
export struct FoodRecognitionTab {
  @StorageLink('currentTheme') @Watch('onThemeChange') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @Prop activeTheme: string = 'dark';
  @State previewUri: string = '';

  onSaveSuccess: () => void = () => {};
  @State bgColor: string = '#0D0D1A';
  @State cardColor: string = '#1A1A2E';
  @State textColor: string = '#FFFFFF';
  @State subTextColor: string = '#AAAAAA';

  // 修复：移除未使用的 propName 参数
  onThemeChange(_: string): void {
    console.info('FoodRecognitionTab theme changed to=' + this.theme);
    this.updateThemeColors();
  }

  updateThemeColors(): void {
    this.bgColor = ThemeColors.bg(this.theme);
    this.cardColor = ThemeColors.card(this.theme);
    this.textColor = ThemeColors.text(this.theme);
    this.subTextColor = ThemeColors.subText(this.theme);
  }

  startScanAnimation(): void {
    this.stopScanAnimation();
    this.scanLineY = 0;
    this.scanDirection = 1;
    const scanAreaHeight = this.imageWidth > 0 && this.imageHeight > 0 ?
      (this.imageHeight / this.imageWidth * 320) : 220;
    this.scanTimer = setInterval(() => {
      const speed = 3;
      this.scanLineY += speed * this.scanDirection;
      if (this.scanLineY >= scanAreaHeight - 3) {
        this.scanLineY = scanAreaHeight - 3;
        this.scanDirection = -1;
      } else if (this.scanLineY <= 0) {
        this.scanLineY = 0;
        this.scanDirection = 1;
      }
    }, 30);
  }

  stopScanAnimation(): void {
    if (this.scanTimer !== -1) {
      clearInterval(this.scanTimer);
      this.scanTimer = -1;
    }
  }

  @State isRecognizing: boolean = false;
  @State scanAnim: boolean = false;
  @State scanLineY: number = 0;
  private scanTimer: number = -1;
  private scanDirection: number = 1;
  @State resultMsg: string = '对准食物拍照或从相册选择，看看它是什么菜';
  @State recogSource: string = '';
  @State imageWidth: number = 0;
  @State imageHeight: number = 0;
  @State recognizedFoodItems: RecognizedFoodItem[] = [];
  @State savedFoodList: RecognizedFoodItem[] = [];
  private uiContext: common.UIAbilityContext | null = null;

  // 根据每100g原始值缩放所有营养（热量、蛋白质、脂肪、碳水）
  private updateItemNutrition(item: RecognizedFoodItem): void {
    const grams = item.grams;
    if (grams <= 0) return;

    if (item.caloriesPer100 !== undefined && item.caloriesPer100 > 0) {
      item.calories = Math.round(item.caloriesPer100 * grams / 100);
    }
    if (item.proteinPer100 !== undefined && item.proteinPer100 > 0) {
      item.protein = Math.round(item.proteinPer100 * grams / 100);
    }
    if (item.fatPer100 !== undefined && item.fatPer100 > 0) {
      item.fat = Math.round(item.fatPer100 * grams / 100);
    }
    if (item.carbsPer100 !== undefined && item.carbsPer100 > 0) {
      item.carbs = Math.round(item.carbsPer100 * grams / 100);
    }
  }

  aboutToAppear(): void {
    this.uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.updateThemeColors();
    console.info('FoodRecognitionTab theme=' + this.theme);
  }

  aboutToDisappear(): void {
    this.stopScanAnimation();
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
    this.startScanAnimation();
    this.resultMsg = '正在识别...';
    setTimeout(async () => {
      try {
        const outcome: RecognitionOutcome = await FoodRecognitionService.getInstance().recognizeMultiple(uri);
        this.applyResult(outcome);
      } catch (err) {
        console.error('recognize error:', JSON.stringify(err));
        this.resultMsg = '识别失败，请重试';
      } finally {
        this.stopScanAnimation();
        this.isRecognizing = false;
        this.scanAnim = false;
      }
    }, 1200);
  }

  async applyResult(outcome: RecognitionOutcome): Promise<void> {
    if (outcome.foodItems && outcome.foodItems.length > 0) {
      this.recognizedFoodItems = outcome.foodItems;
      this.recogSource = outcome.source;
      this.savedFoodList = [];
      if (outcome.source === 'cloud') {
        this.resultMsg = '云端 AI 识别完成，共识别到 ' + outcome.foodItems.length + ' 种食物';
      } else if (outcome.source === 'local') {
        this.resultMsg = '本地识别完成，共识别到 ' + outcome.foodItems.length + ' 种食物';
      }

      // AI 零食判断（原有逻辑）
      for (let i = 0; i < this.recognizedFoodItems.length; i++) {
        const item = this.recognizedFoodItems[i];
        item.isJudgingSnack = false;
        item.snackAnswer = '';
        item.snackAnswerIsSnack = false;

        item.isJudgingSnack = true;
        this.recognizedFoodItems = [...this.recognizedFoodItems];

        try {
          const judge = await FoodRecognitionService.getInstance().askIsSnack(item.foodName);
          item.isSnack = judge.isSnack;
          item.snackReason = judge.reason;
          item.snackAnswer = judge.reason;
          item.snackAnswerIsSnack = judge.isSnack;
        } catch (e) {
          item.isSnack = false;
          item.snackReason = 'AI 判断失败，按时间归类';
          item.snackAnswer = 'AI 判断失败，按时间归类';
          item.snackAnswerIsSnack = false;
        }
        item.isJudgingSnack = false;
        this.recognizedFoodItems = [...this.recognizedFoodItems];
      }
      return;
    }

    // 兼容单食物识别
    if (outcome.foodName.length === 0) {
      this.recogSource = '';
      this.recognizedFoodItems = [];
      this.resultMsg = outcome.error && outcome.error.length > 0 ? outcome.error : '未识别出菜品，换个角度或光线试试';
      return;
    }

    // 构建单食物项，尝试获取营养
    const singleItem: RecognizedFoodItem = {
      id: Date.now().toString(),
      foodName: outcome.foodName,
      grams: 200,
      calories: 0,
      isCalcCalories: false,
      isSnack: false,
      snackReason: '',
      saved: false,
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
    // 尝试获取营养（使用公开方法）
    const nutrition = await FoodRecognitionService.getInstance().getFoodNutrition(outcome.foodName);
    if (nutrition) {
      singleItem.caloriesPer100 = nutrition.cal;
      singleItem.proteinPer100 = nutrition.pro;
      singleItem.fatPer100 = nutrition.fat;
      singleItem.carbsPer100 = nutrition.carb;
      singleItem.calories = Math.round(nutrition.cal * 200 / 100);
      singleItem.protein = Math.round(nutrition.pro * 200 / 100);
      singleItem.fat = Math.round(nutrition.fat * 200 / 100);
      singleItem.carbs = Math.round(nutrition.carb * 200 / 100);
    } else {
      // 尝试本地库
      const local = FoodCalories.getNutrition(outcome.foodName, 100);
      if (local.cal > 0) {
        singleItem.caloriesPer100 = local.cal;
        singleItem.proteinPer100 = local.pro;
        singleItem.fatPer100 = local.fat;
        singleItem.carbsPer100 = local.carb;
        singleItem.calories = Math.round(local.cal * 200 / 100);
        singleItem.protein = Math.round(local.pro * 200 / 100);
        singleItem.fat = Math.round(local.fat * 200 / 100);
        singleItem.carbs = Math.round(local.carb * 200 / 100);
      }
    }
    this.recognizedFoodItems = [singleItem];
    this.recogSource = outcome.source;
    this.savedFoodList = [];

    // AI 零食判断
    singleItem.isJudgingSnack = true;
    this.recognizedFoodItems = [...this.recognizedFoodItems];
    try {
      const judge = await FoodRecognitionService.getInstance().askIsSnack(singleItem.foodName);
      singleItem.isSnack = judge.isSnack;
      singleItem.snackReason = judge.reason;
      singleItem.snackAnswer = judge.reason;
      singleItem.snackAnswerIsSnack = judge.isSnack;
    } catch (e) {
      singleItem.isSnack = false;
      singleItem.snackReason = 'AI 判断失败，按时间归类';
      singleItem.snackAnswer = 'AI 判断失败，按时间归类';
      singleItem.snackAnswerIsSnack = false;
    }
    singleItem.isJudgingSnack = false;
    this.recognizedFoodItems = [...this.recognizedFoodItems];

    if (outcome.source === 'cloud') {
      this.resultMsg = '云端 AI 识别完成';
    } else if (outcome.source === 'local') {
      this.resultMsg = '本地识别完成';
    }
  }

  getCurrentMealType(): string {
    const hour: number = new Date().getHours();
    if (hour < 10) {
      return 'breakfast';
    }
    if (hour < 14) {
      return 'lunch';
    }
    if (hour < 18) {
      return 'dinner';
    }
    return 'snack';
  }

  getMealTypeLabel(mealType: string): string {
    if (mealType === 'breakfast') {
      return '早餐';
    }
    if (mealType === 'lunch') {
      return '午餐';
    }
    if (mealType === 'dinner') {
      return '晚餐';
    }
    return '零食';
  }

  getTimeStr(): string {
    const now = new Date();
    return String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
  }

  getMealLabelForItem(item: RecognizedFoodItem): string {
    if (item.isSnack) {
      return '零食';
    }
    return this.getMealTypeLabel(this.getCurrentMealType());
  }

  resetAll(): void {
    this.previewUri = '';
    this.recogSource = '';
    this.resultMsg = '对准食物拍照或从相册选择，看看它是什么菜';
    this.imageWidth = 0;
    this.imageHeight = 0;
    this.recognizedFoodItems = [];
    this.savedFoodList = [];
  }

  // 保存单个食物（含完整营养）
  async saveFoodItem(item: RecognizedFoodItem): Promise<void> {
    if (item.saved) {
      promptAction.showToast({ message: '该食物已保存' });
      return;
    }
    try {
      const today = await GlobalData.getTodayDate();
      const now = new Date();
      const hour = now.getHours();
      const minute = now.getMinutes();
      const timeStr = String(hour).padStart(2, '0') + ':' + String(minute).padStart(2, '0');
      let mealType = this.getCurrentMealType();
      if (item.isSnack) {
        mealType = 'snack';
      }
      const record: DbRow = {
        date: today,
        time: timeStr,
        meal_type: mealType,
        food_name: item.foodName,
        amount_g: item.grams,
        calories: item.calories,
        protein: item.protein ?? 0,
        fat: item.fat ?? 0,
        carbs: item.carbs ?? 0
      };
      await GlobalData.db.addDietRecord(record);
      item.saved = true;
      const savedItem: RecognizedFoodItem = {
        id: item.id,
        foodName: item.foodName,
        grams: item.grams,
        calories: item.calories,
        isSnack: item.isSnack,
        snackReason: item.snackReason,
        saved: item.saved,
        isCalcCalories: item.isCalcCalories,
        isJudgingSnack: item.isJudgingSnack,
        snackAnswer: item.snackAnswer,
        snackAnswerIsSnack: item.snackAnswerIsSnack,
        protein: item.protein,
        fat: item.fat,
        carbs: item.carbs,
        caloriesPer100: item.caloriesPer100,
        proteinPer100: item.proteinPer100,
        fatPer100: item.fatPer100,
        carbsPer100: item.carbsPer100
      };
      this.savedFoodList.push(savedItem);
      this.recognizedFoodItems = [...this.recognizedFoodItems];
      promptAction.showToast({ message: '已保存：' + item.foodName });
    } catch (err) {
      console.error('saveFoodItem error:', JSON.stringify(err));
      promptAction.showToast({ message: '保存失败，请重试' });
    }
  }

  async saveAll(): Promise<void> {
    const unsavedItems = this.recognizedFoodItems.filter(item => !item.saved);
    if (unsavedItems.length === 0) {
      promptAction.showToast({ message: '所有食物已保存' });
      return;
    }
    let savedCount = 0;
    for (const item of unsavedItems) {
      await this.saveFoodItem(item);
      if (item.saved) {
        savedCount++;
      }
    }
    if (savedCount > 0) {
      promptAction.showToast({ message: '成功保存 ' + savedCount + ' 种食物' });
      this.onSaveSuccess();
    }
  }

  async saveAllToDiet(): Promise<void> {
    const unsavedItems = this.recognizedFoodItems.filter(item => !item.saved);
    if (unsavedItems.length === 0) {
      promptAction.showToast({ message: '所有食物已添加到饮食记录' });
      return;
    }
    try {
      let savedCount = 0;
      for (const item of unsavedItems) {
        await this.saveFoodItem(item);
        if (item.saved) {
          savedCount++;
        }
      }
      if (savedCount > 0) {
        promptAction.showToast({ message: '已添加 ' + savedCount + ' 种食物到饮食记录' });
        AppStorage.setOrCreate('dataUpdateTrigger', `food_recognition_${Date.now()}`);
        this.onSaveSuccess();
      }
    } catch (err) {
      console.error('saveAllToDiet error:', JSON.stringify(err));
      promptAction.showToast({ message: '添加失败，请重试' });
    }
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('AI 识菜').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
        }
        .width('100%').padding({ left: 20, right: 20, top: 16 + this.statusBarHeight })
        Text('拍照看看这是什么菜').fontSize(13).fontColor(this.subTextColor)
          .width('100%').padding({ left: 20, top: 4, bottom: 16 })

        // 中央识别区
        Stack() {
          Column() {
            if (this.previewUri.length > 0) {
              Image(this.previewUri)
                .width('100%')
                .height(this.imageWidth > 0 && this.imageHeight > 0 ?
                  (this.imageHeight / this.imageWidth * 320) : 220)
                .objectFit(ImageFit.Contain)
                .borderRadius(20)
                .onComplete((msg) => {
                  if (msg && msg.width && msg.height) {
                    this.imageWidth = msg.width;
                    this.imageHeight = msg.height;
                  }
                })
            } else {
              Column() {
                Image($r('app.media.ic_diet')).width(72).height(72).fillColor(this.subTextColor).opacity(0.3)
                Text('对准食物拍照或选择图片').fontSize(14).fontColor(this.subTextColor).margin({ top: 12 })
                Text('自动识别这是什么菜').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
              }
              .width('100%').height(220).justifyContent(FlexAlign.Center)
            }
          }
          .width('100%')
          .height(this.previewUri.length > 0 && this.imageWidth > 0 && this.imageHeight > 0 ?
            (this.imageHeight / this.imageWidth * 320) : 220)
          .borderRadius(20)
          .backgroundColor(this.cardColor)
          .border({ width: 2, color: '#FF6B35', style: BorderStyle.Dashed })

          if (this.scanAnim) {
            Column()
              .width('100%').height(3)
              .linearGradient({
                angle: 90,
                colors: [
                  ['rgba(255, 107, 53, 0)', 0],
                  ['#FF6B35', 0.5],
                  ['rgba(255, 107, 53, 0)', 1]
                ]
              })
              .shadow({
                radius: 8,
                color: '#FF6B35',
                offsetX: 0,
                offsetY: 0
              })
              .position({ x: 0, y: this.scanLineY })
          }

          if (this.isRecognizing) {
            Column() {
              LoadingProgress()
                .width(48)
                .height(48)
                .color('#FF6B35')
              Text('AI 识别中...').fontSize(14).fontColor(this.textColor).margin({ top: 12 })
            }
            .width(140).height(140).borderRadius(20)
            .backgroundColor('#000000CC')
            .justifyContent(FlexAlign.Center)
            .shadow({ radius: 20, color: '#00000066', offsetX: 0, offsetY: 4 })
          }
        }
        .width('calc(100% - 32vp)')
        .height(this.previewUri.length > 0 && this.imageWidth > 0 && this.imageHeight > 0 ?
          (this.imageHeight / this.imageWidth * 320) : 220)
        .margin({ left: 16, right: 16 })

        // 操作按钮
        Row() {
          Button() {
            Row() {
              Image($r('app.media.ic_camera')).width(18).height(18).fillColor(Color.White)
              Text('拍照').fontSize(15).fontColor(Color.White).margin({ left: 4 })
            }
          }
          .layoutWeight(1).height(48)
          .backgroundColor('#FF6B35').borderRadius(24)
          .fontColor(Color.White).fontSize(15)
          .onClick(() => { this.takePhoto(); })

          Button() {
            Row() {
              Image($r('app.media.ic_gallery')).width(18).height(18).fillColor(Color.White)
              Text('相册').fontSize(15).fontColor(Color.White).margin({ left: 4 })
            }
          }
          .layoutWeight(1).height(48)
          .backgroundColor('#4CAF50').borderRadius(24)
          .fontColor(Color.White).fontSize(15)
          .margin({ left: 12 })
          .onClick(() => { this.pickFromAlbum(); })
        }
        .width('100%').padding({ left: 16, right: 16, top: 16 })

        // 识别结果展示
        if (this.recognizedFoodItems.length > 0) {
          Column() {
            Row() {
              Image($r('app.media.ic_diet')).width(18).height(18).fillColor(this.textColor)
              Text('识别结果')
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                .margin({ left: 6 })
            }
            .width('100%').margin({ bottom: 12 })

            ForEach(this.recognizedFoodItems, (item: RecognizedFoodItem, index: number) => {
              Column() {
                Row() {
                  Image($r('app.media.ic_diet')).width(24).height(24).fillColor(this.textColor)
                  Text(item.foodName)
                    .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                    .margin({ left: 8 })
                  Blank()
                  if (item.saved) {
                    Text('✅').fontSize(16)
                  }
                }
                .width('100%')

                Divider().color(ThemeColors.divider(this.theme)).height(1).margin({ top: 8, bottom: 8 })

                // 份量滑块 + 输入
                Text('食物份量').fontSize(13).fontColor(this.subTextColor).width('100%')
                Row() {
                  Slider({ value: item.grams, min: 10, max: 2000, step: 10, style: SliderStyle.OutSet })
                    .layoutWeight(1)
                    .selectedColor('#FF6B35')
                    .onChange((value: number, mode: SliderChangeMode) => {
                      if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                        const valid: number = isNaN(value) ? 200 : value;
                        this.recognizedFoodItems[index].grams = valid;
                        this.updateItemNutrition(this.recognizedFoodItems[index]);
                        this.recognizedFoodItems = [...this.recognizedFoodItems];
                      }
                    })
                  Text(String(this.recognizedFoodItems[index].grams) + 'g')
                    .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                    .width(60)
                }
                .width('100%')

                Row() {
                  Text('或手动输入(克):').fontSize(12).fontColor(this.subTextColor)
                  TextInput({ placeholder: '200', text: String(this.recognizedFoodItems[index].grams) })
                    .type(InputType.Number)
                    .width(120).height(36)
                    .backgroundColor(ThemeColors.inputBg(this.theme))
                    .fontColor(this.textColor)
                    .placeholderColor(this.subTextColor)
                    .onChange((v: string) => {
                      const num = parseInt(v);
                      if (!isNaN(num) && num >= 10 && num <= 2000) {
                        this.recognizedFoodItems[index].grams = num;
                        this.updateItemNutrition(this.recognizedFoodItems[index]);
                        this.recognizedFoodItems = [...this.recognizedFoodItems];
                      }
                    })
                  Text('g').fontSize(12).fontColor(this.subTextColor).margin({ left: 6 })
                }
                .width('100%').margin({ top: 8 })

                // 卡路里显示
                Row() {
                  Text('每100g热量: ').fontSize(14).fontColor(this.subTextColor)
                  Blank()
                  if (item.isCalcCalories) {
                    Text('AI 计算中...')
                      .fontSize(14).fontColor(this.subTextColor)
                  } else if (item.calories > 0) {
                    Text(String(item.calories) + ' 千卡')
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
                  } else {
                    Text('-- 千卡')
                      .fontSize(16).fontColor(this.subTextColor)
                  }
                }
                .width('100%').margin({ top: 8 })

                // 显示蛋白质/脂肪/碳水
                Row() {
                  Text(`蛋白质 ${item.protein ?? 0}g · 脂肪 ${item.fat ?? 0}g · 碳水 ${item.carbs ?? 0}g`)
                    .fontSize(12).fontColor(this.subTextColor)
                }
                .width('100%').margin({ top: 4 })

                // 餐次归类
                Row() {
                  Image($r('app.media.ic_alarm')).width(14).height(14).fillColor(this.subTextColor)
                  Text('将记录为: ').fontSize(13).fontColor(this.subTextColor).margin({ left: 4 })
                  Text(this.getMealLabelForItem(item))
                    .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
                  Text('（' + this.getTimeStr() + '）').fontSize(12).fontColor(this.subTextColor).margin({ left: 4 })
                  Blank()
                }
                .width('100%').margin({ top: 10 })

                // AI 零食判断按钮
                Row() {
                  Button() {
                    Row() {
                      if (item.snackAnswer.length > 0) {
                        Image($r('app.media.ic_refresh')).width(16).height(16).fillColor(Color.White)
                        Text('重新判断').fontSize(14).fontColor(Color.White).margin({ left: 4 })
                      } else {
                        Image($r('app.media.ic_ai')).width(16).height(16).fillColor(Color.White)
                        Text('AI判断中...').fontSize(14).fontColor(Color.White).margin({ left: 4 })
                      }
                    }
                  }
                  .layoutWeight(1).height(40)
                  .backgroundColor('#7B68EE')
                  .borderRadius(20)
                  .fontColor(Color.White).fontSize(14)
                  .enabled(!item.isJudgingSnack)
                  .onClick(async () => {
                    item.isJudgingSnack = true;
                    item.snackAnswer = '';
                    this.recognizedFoodItems = [...this.recognizedFoodItems];
                    try {
                      const judge = await FoodRecognitionService.getInstance().askIsSnack(item.foodName);
                      item.isSnack = judge.isSnack;
                      item.snackReason = judge.reason;
                      item.snackAnswer = judge.reason;
                      item.snackAnswerIsSnack = judge.isSnack;
                    } catch (e) {
                      item.isSnack = false;
                      item.snackReason = 'AI 判断失败，按时间归类';
                      item.snackAnswer = 'AI 判断失败，按时间归类';
                      item.snackAnswerIsSnack = false;
                    }
                    item.isJudgingSnack = false;
                    this.recognizedFoodItems = [...this.recognizedFoodItems];
                  })
                }
                .width('100%').margin({ top: 10 })

                if (item.isJudgingSnack) {
                  Text('AI 正在判断是否属于零食...').fontSize(12).fontColor(this.subTextColor).width('100%').margin({ top: 6 })
                } else if (item.snackAnswer.length > 0) {
                  Row() {
                    Text(item.snackAnswerIsSnack ? '🍪 AI判定：零食，归入零食' : '🍽️ AI判定：正餐，按时间归类')
                      .fontSize(14).fontWeight(FontWeight.Bold)
                      .fontColor(item.snackAnswerIsSnack ? '#FF9800' : '#4CAF50')
                  }
                  .width('100%').margin({ top: 6 })
                  Text(item.snackAnswer).fontSize(12).fontColor(this.subTextColor).width('100%').margin({ top: 4 })
                }

                // 保存按钮
                Row() {
                  Button(item.saved ? '✅ 已保存' : '保存此食物')
                    .layoutWeight(1).height(48)
                    .backgroundColor(item.saved ? '#4CAF50' : '#FF6B35')
                    .borderRadius(24)
                    .fontColor(Color.White).fontSize(15)
                    .enabled(!item.saved)
                    .onClick(() => { this.saveFoodItem(item); })
                }
                .width('100%').margin({ top: 12 })
              }
              .width('100%').padding(12)
              .backgroundColor(this.theme === 'dark' ? '#252538' : '#F5F5F5')
              .borderRadius(10)
              .margin({ bottom: 12 })
            }, (item: RecognizedFoodItem) => item.id)

            // 底部操作按钮
            Row() {
              Button() {
                Row() {
                  Image($r('app.media.ic_add')).width(16).height(16).fillColor(Color.White)
                  Text('全部添加到饮食记录').fontSize(14).fontColor(Color.White).margin({ left: 4 })
                }
              }
              .layoutWeight(1).height(44)
              .backgroundColor('#FF6B35')
              .borderRadius(22)
              .fontColor(Color.White).fontSize(14)
              .onClick(() => { this.saveAllToDiet(); })

              Button() {
                Row() {
                  Image($r('app.media.ic_refresh')).width(16).height(16).fillColor(Color.White)
                  Text('重新识别').fontSize(14).fontColor(Color.White).margin({ left: 4 })
                }
              }
              .layoutWeight(1).height(44)
              .backgroundColor(this.subTextColor)
              .borderRadius(22)
              .fontColor(Color.White).fontSize(14)
              .margin({ left: 12 })
              .onClick(() => { this.resetAll(); })
            }
            .width('100%').margin({ top: 8 })

            // 已保存列表
            if (this.savedFoodList.length > 0) {
              Column() {
                Text('✅ 已保存的食物')
                  .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                  .width('100%').margin({ bottom: 8 })
                ForEach(this.savedFoodList, (item: RecognizedFoodItem) => {
                  Row() {
                    Text('✅ ' + item.foodName + ' ' + String(item.grams) + 'g - ' + String(item.calories) + '千卡')
                      .fontSize(13).fontColor(this.textColor)
                      .layoutWeight(1)
                  }
                  .width('100%').padding(8)
                  .backgroundColor(this.theme === 'dark' ? '#1A1A2E' : '#FFFFFF')
                  .borderRadius(8)
                  .margin({ bottom: 6 })
                }, (item: RecognizedFoodItem) => item.id)
              }
              .width('100%').padding(12)
              .backgroundColor(this.cardColor).borderRadius(10)
              .margin({ top: 16 })
            }
          }
          .width('100%').padding(16)
          .backgroundColor(this.cardColor).borderRadius(14)
          .margin({ left: 16, right: 16, top: 20 })
        } else {
          Text(this.resultMsg).fontSize(12).fontColor(this.subTextColor)
            .width('100%').padding({ left: 20, right: 20, top: 16 })
        }

        Divider().opacity(0).height(30)
      }
      .width('100%').alignItems(HorizontalAlign.Start)
    }
    .backgroundColor(this.bgColor)
    .width('100%').height('100%')
  }
}