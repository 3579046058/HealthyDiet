import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ThemeColors, DbRow } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { FoodRecognitionService, RecognitionOutcome, RecognizedFoodItem } from '../services/FoodRecognitionService';

@Component
export struct FoodRecognitionTab {
  @StorageLink('currentTheme') @Watch('onThemeChange') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @Prop activeTheme: string = 'dark';
  @State previewUri: string = '';
  
  // 保存成功后的回调
  onSaveSuccess: () => void = () => {};

  @State bgColor: string = '#0D0D1A';
  @State cardColor: string = '#1A1A2E';
  @State textColor: string = '#FFFFFF';
  @State subTextColor: string = '#AAAAAA';

  onThemeChange(propName: string): void {
    console.info('FoodRecognitionTab theme changed to=' + this.theme);
    this.updateThemeColors();
  }

  updateThemeColors(): void {
    this.bgColor = ThemeColors.bg(this.theme);
    this.cardColor = ThemeColors.card(this.theme);
    this.textColor = ThemeColors.text(this.theme);
    this.subTextColor = ThemeColors.subText(this.theme);
  }

  // 启动扫描动画
  startScanAnimation(): void {
    this.stopScanAnimation(); // 先停止之前的动画
    this.scanLineY = 0; // 从顶部开始
    this.scanDirection = 1; // 向下移动
    
    // 计算扫描区域高度
    const scanAreaHeight = this.imageWidth > 0 && this.imageHeight > 0 ? 
      (this.imageHeight / this.imageWidth * 320) : 220;
    
    // 每30ms更新一次位置，实现平滑动画
    this.scanTimer = setInterval(() => {
      const speed = 3; // 移动速度
      this.scanLineY += speed * this.scanDirection;
      
      // 到达底部时反向
      if (this.scanLineY >= scanAreaHeight - 3) {
        this.scanLineY = scanAreaHeight - 3;
        this.scanDirection = -1;
      }
      // 到达顶部时反向
      else if (this.scanLineY <= 0) {
        this.scanLineY = 0;
        this.scanDirection = 1;
      }
    }, 30);
  }

  // 停止扫描动画
  stopScanAnimation(): void {
    if (this.scanTimer !== -1) {
      clearInterval(this.scanTimer);
      this.scanTimer = -1;
    }
  }

  @State recognizedFood: string = '';
  @State isRecognizing: boolean = false;
  @State scanAnim: boolean = false;
  @State scanLineY: number = 0; // 扫描线Y位置
  private scanTimer: number = -1; // 扫描动画定时器
  private scanDirection: number = 1; // 扫描方向：1向下，-1向上
  @State resultMsg: string = '对准食物拍照或从相册选择，看看它是什么菜';
  @State recogSource: string = '';
  @State gramsInput: string = '200';
  @State gramsSlider: number = 200;
  @State savedSuccess: boolean = false;
  @State cloudCalories: number = 0;
  @State isCalcCalories: boolean = false;
  @State imageWidth: number = 0;
  @State imageHeight: number = 0;
  @State isAskingSnack: boolean = false;
  @State snackAnswer: string = '';
  @State snackAnswerIsSnack: boolean = false;
  @State autoSnackChecked: boolean = false;

  // 多食物识别相关状态
  @State recognizedFoodItems: RecognizedFoodItem[] = [];
  @State savedFoodList: RecognizedFoodItem[] = [];

  private uiContext: common.UIAbilityContext | null = null;

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

  // 计算单个食物项的卡路里
  async refreshItemCalories(item: RecognizedFoodItem): Promise<void> {
    if (item.foodName.length === 0 || item.grams <= 0) {
      item.calories = 0;
      return;
    }
    const result = await FoodRecognitionService.getInstance().calculateCalories(item.foodName, item.grams);
    item.calories = result >= 0 ? result : 0;
  }

  aboutToAppear(): void {
    this.uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.updateThemeColors();
    console.info('FoodRecognitionTab theme=' + this.theme);
  }

  aboutToDisappear(): void {
    // 组件销毁时停止扫描动画，避免内存泄漏
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
    this.startScanAnimation(); // 启动扫描动画
    this.savedSuccess = false;
    this.resultMsg = '正在识别...';

    setTimeout(async () => {
      try {
        const outcome: RecognitionOutcome = await FoodRecognitionService.getInstance().recognizeMultiple(uri);
        this.applyResult(outcome);
      } catch (err) {
        console.error('recognize error:', JSON.stringify(err));
        this.resultMsg = '识别失败，请重试';
      } finally {
        this.stopScanAnimation(); // 停止扫描动画
        this.isRecognizing = false;
        this.scanAnim = false;
      }
    }, 1200);
  }

  async applyResult(outcome: RecognitionOutcome): Promise<void> {
    // 处理多食物识别结果
    if (outcome.foodItems && outcome.foodItems.length > 0) {
      this.recognizedFoodItems = outcome.foodItems;
      this.recognizedFood = outcome.foodName;
      this.recogSource = outcome.source;
      this.savedFoodList = [];
      if (outcome.source === 'cloud') {
        this.resultMsg = '云端 AI 识别完成，共识别到 ' + outcome.foodItems.length + ' 种食物';
      } else if (outcome.source === 'local') {
        this.resultMsg = '本地识别完成，共识别到 ' + outcome.foodItems.length + ' 种食物';
      }
      // 为每个食物项计算初始卡路里
      for (const item of this.recognizedFoodItems) {
        await this.refreshItemCalories(item);
      }
      return;
    }

    // 兼容单食物识别结果
    if (outcome.foodName.length === 0) {
      this.recognizedFood = '';
      this.recogSource = '';
      this.cloudCalories = 0;
      this.snackAnswer = '';
      this.snackAnswerIsSnack = false;
      this.autoSnackChecked = false;
      this.recognizedFoodItems = [];
      this.resultMsg = outcome.error && outcome.error.length > 0 ? outcome.error : '未识别出菜品，换个角度或光线试试';
      return;
    }
    this.recognizedFood = outcome.foodName;
    this.recogSource = outcome.source;
    this.gramsInput = '200';
    this.gramsSlider = 200;
    this.cloudCalories = 0;
    this.snackAnswer = '';
    this.snackAnswerIsSnack = false;
    this.autoSnackChecked = false;
    this.refreshCloudCalories();
    if (outcome.source === 'cloud') {
      this.resultMsg = '云端 AI 识别完成';
    } else if (outcome.source === 'local') {
      this.resultMsg = '本地识别完成';
    }
    // 识别完成后自动询问 AI 是否零食，用于归类餐次
    this.askIsSnack();
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

  getFinalMealLabel(): string {
    if (this.autoSnackChecked && this.snackAnswerIsSnack) {
      return '零食';
    }
    return this.getMealTypeLabel(this.getCurrentMealType());
  }

  getTimeStr(): string {
    const now = new Date();
    return String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
  }

  async askIsSnack(): Promise<void> {
    if (this.recognizedFood.length === 0) {
      promptAction.showToast({ message: '请先识别食物' });
      return;
    }
    this.isAskingSnack = true;
    this.snackAnswer = '';
    try {
      const judge = await FoodRecognitionService.getInstance().askIsSnack(this.recognizedFood);
      this.snackAnswerIsSnack = judge.isSnack;
      this.snackAnswer = judge.reason;
    } catch (err) {
      console.error('askIsSnack error:', JSON.stringify(err));
      this.snackAnswerIsSnack = false;
      this.snackAnswer = 'AI 判断失败，按时间归类';
    } finally {
      this.isAskingSnack = false;
      this.autoSnackChecked = true;
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
    // 归类餐次：AI 判定为零食则归入零食，否则按当前时间归入早/中/晚餐
    let mealType: string;
    if (this.autoSnackChecked && this.snackAnswerIsSnack) {
      mealType = 'snack';
    } else {
      mealType = this.getCurrentMealType();
    }
    const now = Date.now();
    const record: DbRow = {
      date: today,
      meal_type: mealType,
      food_name: this.recognizedFood,
      amount_g: grams,
      calories: calories,
      protein: 0,
      fat: 0,
      carbs: 0,
      timestamp: now
    };
    try {
      await GlobalData.db.addDietRecord(record);
      this.savedSuccess = true;
      promptAction.showToast({ message: '已添加到' + this.getMealTypeLabel(mealType) + '记录' });
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
    this.imageWidth = 0;
    this.imageHeight = 0;
    this.snackAnswer = '';
    this.snackAnswerIsSnack = false;
    this.isAskingSnack = false;
    this.autoSnackChecked = false;
    // 清空多食物相关状态
    this.recognizedFoodItems = [];
    this.savedFoodList = [];
  }

  // 保存单个食物
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

      // 判断餐次
      let mealType = '加餐';
      if (item.isSnack) {
        mealType = '零食';
      } else if (hour >= 6 && hour < 9) {
        mealType = '早餐';
      } else if (hour >= 11 && hour < 14) {
        mealType = '午餐';
      } else if (hour >= 17 && hour < 20) {
        mealType = '晚餐';
      }

      // 创建 DbRow 对象
      const record: DbRow = {
        date: today,
        time: timeStr,
        meal_type: mealType,
        food_name: item.foodName,
        amount_g: item.grams,
        calories: item.calories
      };
      await GlobalData.db.addDietRecord(record);

      // 标记为已保存
      item.saved = true;
      // 手动复制对象属性，避免使用展开运算符
      const savedItem: RecognizedFoodItem = {
        id: item.id,
        foodName: item.foodName,
        grams: item.grams,
        calories: item.calories,
        isSnack: item.isSnack,
        snackReason: item.snackReason,
        saved: item.saved
      };
      this.savedFoodList.push(savedItem);

      promptAction.showToast({ message: '已保存：' + item.foodName });
    } catch (err) {
      console.error('saveFoodItem error:', JSON.stringify(err));
      promptAction.showToast({ message: '保存失败，请重试' });
    }
  }

  // 保存所有食物
  async saveAll(): Promise<void> {
    const unsavedItems = this.recognizedFoodItems.filter(item => !item.saved);
    if (unsavedItems.length === 0) {
      promptAction.showToast({ message: '所有食物已保存' });
      return;
    }

    let savedCount = 0;
    for (const item of unsavedItems) {
      try {
        await this.saveFoodItem(item);
        savedCount++;
      } catch (err) {
        console.error('saveAll error for item:', item.foodName, JSON.stringify(err));
      }
    }

    if (savedCount > 0) {
      promptAction.showToast({ message: '已保存 ' + savedCount + ' 个食物' });
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

        // 中央识别区（扫描线动画）
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
                Text('🍽️').fontSize(72)
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

          // 扫描线动画
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
              // 旋转加载动画
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
          // 多食物识别结果
          if (this.recognizedFoodItems.length > 1) {
            Column() {
              Text('🍽️ 识别结果')
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                .width('100%').margin({ bottom: 12 })

              // 多食物列表
              ForEach(this.recognizedFoodItems, (item: RecognizedFoodItem, index: number) => {
                Column() {
                  Row() {
                    Text('🍽️').fontSize(24)
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

                  // 份量输入
                  Row() {
                    Text('份量:').fontSize(13).fontColor(this.subTextColor)
                    Slider({ value: item.grams, min: 10, max: 2000, step: 10, style: SliderStyle.OutSet })
                      .layoutWeight(1)
                      .selectedColor('#FF6B35')
                      .onChange((value: number, mode: SliderChangeMode) => {
                        if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                          const valid: number = isNaN(value) ? 200 : value;
                          item.grams = valid;
                          this.refreshItemCalories(item);
                        }
                      })
                    Text(String(item.grams) + 'g')
                      .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                      .width(60)
                  }
                  .width('100%')

                  // 卡路里显示
                  Row() {
                    Text('热量:').fontSize(13).fontColor(this.subTextColor)
                    Blank()
                    Text(item.calories > 0 ? String(item.calories) + ' 千卡' : '-- 千卡')
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
                  }
                  .width('100%').margin({ top: 8 })

                  // 保存按钮
                  if (!item.saved) {
                    Button('保存此食物')
                      .width('100%').height(40)
                      .backgroundColor('#FF6B35')
                      .borderRadius(20)
                      .fontColor(Color.White).fontSize(14)
                      .margin({ top: 12 })
                      .onClick(() => { this.saveFoodItem(item); })
                  } else {
                    Text('已保存')
                      .fontSize(13).fontColor('#4CAF50')
                      .width('100%').margin({ top: 8 })
                  }
                }
                .width('100%').padding(12)
                .backgroundColor(this.theme === 'dark' ? '#252538' : '#F5F5F5')
                .borderRadius(10)
                .margin({ bottom: 12 })
              }, (item: RecognizedFoodItem) => item.id)

              // 底部操作按钮
              Row() {
                Button('✅ 全部保存')
                  .layoutWeight(1).height(44)
                  .backgroundColor('#4CAF50')
                  .borderRadius(22)
                  .fontColor(Color.White).fontSize(14)
                  .onClick(() => { this.saveAll(); })

                Button('🔄 重新识别')
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
            // 单食物识别（兼容原有逻辑）
            Column() {
            Row() {
              Text('🍽️').fontSize(32)
              Column() {
                Text(this.recognizedFood)
                  .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.textColor)
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

            Divider().color(ThemeColors.divider(this.theme)).height(1).margin({ top: 12, bottom: 12 })

            // 克数滑块 + 文本输入
            Text('食物份量').fontSize(13).fontColor(this.subTextColor).width('100%')
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
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                .margin({ left: 10 }).width(60)
            }
            .width('100%')

            Row() {
              Text('或手动输入(克):').fontSize(12).fontColor(this.subTextColor)
              TextInput({ placeholder: '200', text: this.gramsInput })
                .type(InputType.Number)
                .width(120).height(36)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.textColor)
                .placeholderColor(this.subTextColor)
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
              Text('g').fontSize(12).fontColor(this.subTextColor).margin({ left: 6 })
            }
            .width('100%').margin({ top: 8 })

            // 卡路里显示（云端计算）
            Row() {
              Text('预计热量: ').fontSize(14).fontColor(this.subTextColor)
              Blank()
              if (this.isCalcCalories) {
                Text('计算中...').fontSize(16).fontColor(this.subTextColor)
              } else if (this.cloudCalories > 0) {
                Text(String(this.cloudCalories) + ' 千卡')
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
              } else {
                Text('-- 千卡').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.subTextColor)
              }
            }
            .width('100%').margin({ top: 12 })

            // 自动归类餐次（AI 判定零食优先，否则按时间）
            Row() {
              Text('⏰ 将记录为: ').fontSize(13).fontColor(this.subTextColor)
              Text(this.getFinalMealLabel())
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
              Text('（' + this.getTimeStr() + '）').fontSize(12).fontColor(this.subTextColor).margin({ left: 4 })
              Blank()
            }
            .width('100%').margin({ top: 10 })

            // AI 零食判断（自动执行，可重新询问）
            Row() {
              Button(this.snackAnswer.length > 0 ? '🔄 重新判断' : '🤔 AI判断中...')
                .layoutWeight(1).height(40)
                .backgroundColor('#7B68EE')
                .borderRadius(20)
                .fontColor(Color.White).fontSize(14)
                .enabled(!this.isAskingSnack)
                .onClick(() => { this.askIsSnack(); })
            }
            .width('100%').margin({ top: 10 })

            if (this.isAskingSnack) {
              Text('AI 正在判断是否属于零食...').fontSize(12).fontColor(this.subTextColor).width('100%').margin({ top: 6 })
            } else if (this.snackAnswer.length > 0) {
              Row() {
                Text(this.snackAnswerIsSnack ? '🍪 AI判定：零食，归入零食' : '🍽️ AI判定：正餐，按时间归类')
                  .fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor(this.snackAnswerIsSnack ? '#FF9800' : '#4CAF50')
              }
              .width('100%').margin({ top: 6 })
              Text(this.snackAnswer).fontSize(12).fontColor(this.subTextColor).width('100%').margin({ top: 4 })
            }

            // 添加记录按钮 + 重新识别按钮
            Row() {
              Button('➕ 添加到饮食记录')
                .layoutWeight(1).height(48)
                .backgroundColor(this.savedSuccess ? '#4CAF50' : '#FF6B35')
                .borderRadius(24)
                .fontColor(Color.White).fontSize(15)
                .onClick(() => { this.saveToDiet(); })

              Button('🔄 重新识别')
                .layoutWeight(1).height(48)
                .backgroundColor(this.subTextColor)
                .borderRadius(24)
                .fontColor(Color.White).fontSize(15)
                .margin({ left: 12 })
                .onClick(() => { this.resetAll(); })
            }
            .width('100%').margin({ top: 12 })

            if (this.savedSuccess) {
              Text('✅ 已记录到今天的饮食，可在饮食页查看')
                .fontSize(12).fontColor('#4CAF50').width('100%').margin({ top: 8 })
            }
          }
          .width('100%').padding(16)
          .backgroundColor(this.cardColor).borderRadius(14)
          .margin({ left: 16, right: 16, top: 20 })
          }
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
