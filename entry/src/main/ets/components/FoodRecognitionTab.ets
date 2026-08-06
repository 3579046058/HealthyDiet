import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ThemeColors, DbRow } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { FoodRecognitionService, RecognitionOutcome, RecognizedFoodItem } from '../services/FoodRecognitionService';
import { FoodItemCard } from './FoodItemCard';

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

  @State isRecognizing: boolean = false;
  @State scanAnim: boolean = false;
  @State scanLineY: number = 0; // 扫描线Y位置
  private scanTimer: number = -1; // 扫描动画定时器
  private scanDirection: number = 1; // 扫描方向：1向下，-1向上
  @State resultMsg: string = '对准食物拍照或从相册选择，看看它是什么菜';
  @State recogSource: string = '';
  @State imageWidth: number = 0;
  @State imageHeight: number = 0;

  // 食物识别相关状态（统一使用数组）
  @State recognizedFoodItems: RecognizedFoodItem[] = [];
  @State savedFoodList: RecognizedFoodItem[] = [];

  private uiContext: common.UIAbilityContext | null = null;

  // 计算单个食物项的卡路里
  async refreshItemCalories(item: RecognizedFoodItem): Promise<void> {
    if (item.foodName.length === 0 || item.grams <= 0) {
      item.calories = 0;
      return;
    }
    item.isCalcCalories = true; // 开始计算
    const result = await FoodRecognitionService.getInstance().calculateCalories(item.foodName, item.grams);
    item.calories = result >= 0 ? result : 0;
    item.isCalcCalories = false; // 计算完成
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
      this.recogSource = outcome.source;
      this.savedFoodList = [];
      if (outcome.source === 'cloud') {
        this.resultMsg = '云端 AI 识别完成，共识别到 ' + outcome.foodItems.length + ' 种食物';
      } else if (outcome.source === 'local') {
        this.resultMsg = '本地识别完成，共识别到 ' + outcome.foodItems.length + ' 种食物';
      }
      // 为每个食物项计算初始卡路里并进行 AI 零食判断
      for (const item of this.recognizedFoodItems) {
        // 初始化 AI 零食判断相关字段
        item.isJudgingSnack = false;
        item.snackAnswer = '';
        item.snackAnswerIsSnack = false;
        
        await this.refreshItemCalories(item);
        // 为每个食物进行 AI 零食判断
        item.isJudgingSnack = true;
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
      }
      return;
    }

    // 兼容单食物识别结果 - 转换为 RecognizedFoodItem 数组
    if (outcome.foodName.length === 0) {
      this.recogSource = '';
      this.recognizedFoodItems = [];
      this.resultMsg = outcome.error && outcome.error.length > 0 ? outcome.error : '未识别出菜品，换个角度或光线试试';
      return;
    }
    
    // 将单食物转换为 RecognizedFoodItem 数组（只包含一个元素）
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
      snackAnswerIsSnack: false
    };
    
    this.recognizedFoodItems = [singleItem];
    this.recogSource = outcome.source;
    this.savedFoodList = [];
    
    // 计算初始卡路里
    await this.refreshItemCalories(singleItem);
    
    // 进行 AI 零食判断
    singleItem.isJudgingSnack = true;
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

  // 获取单个食物项的餐次标签
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
    // 清空食物相关状态
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

      // 判断餐次（使用英文值以匹配DietPage的过滤逻辑）
      let mealType = this.getCurrentMealType();
      if (item.isSnack) {
        mealType = 'snack';
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
        saved: item.saved,
        isCalcCalories: item.isCalcCalories,
        isJudgingSnack: item.isJudgingSnack,
        snackAnswer: item.snackAnswer,
        snackAnswerIsSnack: item.snackAnswerIsSnack
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

  // 将所有食物添加到饮食记录（统一添加按钮）
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
        // 触发首页数据更新
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

        // 识别结果 + 克数输入 + 添加记录
        if (this.recognizedFoodItems.length > 0) {
          // 识别结果
          if (this.recognizedFoodItems.length > 0) {
            Column() {
              Row() {
                Image($r('app.media.ic_diet')).width(18).height(18).fillColor(this.textColor)
                Text('识别结果')
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                  .margin({ left: 6 })
              }
                .width('100%').margin({ bottom: 12 })

              // 多食物列表
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

                  // 克数滑块 + 文本输入
                  Text('食物份量').fontSize(13).fontColor(this.subTextColor).width('100%')
                  Row() {
                    Slider({ value: item.grams, min: 10, max: 2000, step: 10, style: SliderStyle.OutSet })
                      .layoutWeight(1)
                      .selectedColor('#FF6B35')
                      .onChange((value: number, mode: SliderChangeMode) => {
                        if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                          const valid: number = isNaN(value) ? 200 : value;
                          // 更新数组元素的值
                          this.recognizedFoodItems[index].grams = valid;
                          // 刷新卡路里计算
                          this.refreshItemCalories(this.recognizedFoodItems[index]);
                          // 触发数组响应式更新
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
                          // 更新数组元素的值
                          this.recognizedFoodItems[index].grams = num;
                          // 刷新卡路里计算
                          this.refreshItemCalories(this.recognizedFoodItems[index]);
                          // 触发数组响应式更新
                          this.recognizedFoodItems = [...this.recognizedFoodItems];
                        }
                      })
                    Text('g').fontSize(12).fontColor(this.subTextColor).margin({ left: 6 })
                  }
                  .width('100%').margin({ top: 8 })

                  // 卡路里显示
                  Row() {
                    Text('预计热量: ').fontSize(14).fontColor(this.subTextColor)
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

                  // 餐次归类显示
                  Row() {
                    Image($r('app.media.ic_alarm')).width(14).height(14).fillColor(this.subTextColor)
                    Text('将记录为: ').fontSize(13).fontColor(this.subTextColor).margin({ left: 4 })
                    Text(this.getMealLabelForItem(item))
                      .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
                    Text('（' + this.getTimeStr() + '）').fontSize(12).fontColor(this.subTextColor).margin({ left: 4 })
                    Blank()
                  }
                  .width('100%').margin({ top: 10 })

                  // AI 零食判断
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
