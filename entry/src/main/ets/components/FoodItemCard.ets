import { RecognizedFoodItem } from '../services/FoodRecognitionService';
import { ThemeColors } from '../common/Constants';
import promptAction from '@ohos.promptAction';

// 通用食物卡片组件（单食物和多食物复用）
@Component
export struct FoodItemCard {
  // 食物数据
  @Prop @Watch('onItemChange') item: RecognizedFoodItem = {
    id: '',
    foodName: '',
    grams: 200,
    calories: 0,
    isSnack: false,
    snackReason: '',
    saved: false,
    isCalcCalories: false,
    isJudgingSnack: false,
    snackAnswer: '',
    snackAnswerIsSnack: false,
    // 新增：三大营养素默认值，兼容新数据结构，不影响原有逻辑
    protein: 0,
    fat: 0,
    carbs: 0
  };
  // 识别来源（cloud/local）
  @Prop recogSource: string = 'cloud';
  // AI 零食判断状态
  @Prop isJudgingSnack: boolean = false;
  @Prop snackAnswer: string = '';
  @Prop snackAnswerIsSnack: boolean = false;
  // 保存状态
  @Prop savedSuccess: boolean = false;
  // 是否显示重新识别按钮（单食物显示，多食物不显示）
  @Prop showResetButton: boolean = true;
  // 主题
  @StorageLink('currentTheme') @Watch('onThemeChange') theme: string = 'dark';

  // 回调函数
  onSave: (item: RecognizedFoodItem) => void = () => {};
  onGramsChange: (item: RecognizedFoodItem, grams: number) => void = () => {};
  onSnackJudge: () => void = () => {};
  onReset: () => void = () => {};

  // 内部状态
  @State gramsInput: string = '200';
  @State bgColor: string = '#0D0D1A';
  @State cardColor: string = '#1A1A2E';
  @State textColor: string = '#FFFFFF';
  @State subTextColor: string = '#AAAAAA';
  @State selectedMeal: string = ''; // 用户选择的餐次（空=自动）

  // 主题变化监听
  onThemeChange(): void {
    this.updateThemeColors();
  }

  // 食物数据变化监听：同步输入框数值
  onItemChange(): void {
    this.gramsInput = String(this.item.grams);
  }

  updateThemeColors(): void {
    this.bgColor = ThemeColors.bg(this.theme);
    this.cardColor = ThemeColors.card(this.theme);
    this.textColor = ThemeColors.text(this.theme);
    this.subTextColor = ThemeColors.subText(this.theme);
  }

  aboutToAppear(): void {
    this.gramsInput = String(this.item.grams);
    this.updateThemeColors();
  }

  // 获取餐次标签
  getFinalMealLabel(): string {
    if (this.item.isSnack) {
      return '零食';
    }
    const hour = new Date().getHours();
    if (hour >= 4 && hour < 10) return '早餐';
    if (hour >= 10 && hour < 14) return '午餐';
    if (hour >= 17 && hour < 20) return '晚餐';
    return '零食';
  }

  // 自动餐次（默认值，用户可改）
  getAutoMealType(): string {
    if (this.item.isSnack) {
      return 'snack';
    }
    const hour = new Date().getHours();
    if (hour >= 4 && hour < 10) return 'breakfast';
    if (hour >= 10 && hour < 14) return 'lunch';
    if (hour >= 17 && hour < 20) return 'dinner';
    return 'snack';
  }

  // 当前生效的餐次（用户选择优先，否则自动）
  getActiveMealType(): string {
    if (this.selectedMeal.length > 0) {
      return this.selectedMeal;
    }
    return this.getAutoMealType();
  }

  getMealTypeLabel(mealType: string): string {
    if (mealType === 'breakfast') return '早餐';
    if (mealType === 'lunch') return '午餐';
    if (mealType === 'dinner') return '晚餐';
    return '零食';
  }

  // 获取时间字符串
  getTimeStr(): string {
    const now = new Date();
    const hour = now.getHours();
    const minute = now.getMinutes();
    return `${hour < 10 ? '0' + hour : hour}:${minute < 10 ? '0' + minute : minute}`;
  }

  // AI 判定提示文案：准确反映判定依据
  getSnackJudgeText(): string {
    if (this.snackAnswerIsSnack) {
      return 'AI判定：零食（因食物种类）';
    }
    const hour: number = new Date().getHours();
    const isMealTime: boolean = (hour >= 4 && hour < 10) || (hour >= 10 && hour < 14) || (hour >= 17 && hour < 20);
    if (isMealTime) {
      return '正餐食物，按当前时间归入' + this.getMealTypeLabel(this.getAutoMealType());
    }
    return '正餐食物，但当前时间（' + this.getTimeStr() + '）不在正餐时段，默认归零食，可手动修改';
  }

  build() {
    Column() {
      // 食物名称 + 识别来源标签
      Row() {
        Image($r('app.media.ic_diet')).width(24).height(24).fillColor(this.textColor)
        Column() {
          Text(this.item.foodName)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          if (this.recogSource === 'cloud') {
            Row() {
              Image($r('app.media.ic_cloud')).width(12).height(12).fillColor('#03A9F4')
              Text('云端识别').fontSize(11).fontColor('#03A9F4').margin({ left: 3 })
            }
          } else if (this.recogSource === 'local') {
            Row() {
              Image($r('app.media.ic_phone')).width(12).height(12).fillColor('#4CAF50')
              Text('本地识别').fontSize(11).fontColor('#4CAF50').margin({ left: 3 })
            }
          }
        }
        .alignItems(HorizontalAlign.Start).margin({ left: 10 })
        Blank()
        // 多食物场景显示已保存标记
        if (!this.showResetButton && this.item.saved) {
          Text('✅').fontSize(16)
        }
      }
      .width('100%')

      Divider().color(ThemeColors.divider(this.theme)).height(1).margin({ top: 12, bottom: 12 })

      // 克数滑块 + 文本输入
      Text('食物份量').fontSize(13).fontColor(this.subTextColor).width('100%')
      Row() {
        Slider({ value: this.item.grams, min: 10, max: 2000, step: 10, style: SliderStyle.OutSet })
          .layoutWeight(1)
          .selectedColor('#FF6B35')
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              const valid: number = isNaN(value) ? 200 : value;
              this.gramsInput = String(valid);
              this.onGramsChange(this.item, valid);
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
              this.onGramsChange(this.item, num);
            } else if (!isNaN(num) && num > 2000) {
              promptAction.showToast({ message: '单次最多2000克' });
              this.gramsInput = '2000';
              this.onGramsChange(this.item, 2000);
            }
          })
        Text('g').fontSize(12).fontColor(this.subTextColor).margin({ left: 6 })
      }
      .width('100%').margin({ top: 8 })

      // 卡路里显示
      Row() {
        Text('每100g热量: ').fontSize(14).fontColor(this.subTextColor)
        Blank()
        if (this.item.isCalcCalories) {
          Text('AI 计算中...').fontSize(16).fontColor(this.subTextColor)
        } else if (this.item.calories > 0) {
          Text(String(this.item.calories) + ' 千卡')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
        } else {
          Text('-- 千卡').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.subTextColor)
        }
      }
      .width('100%').margin({ top: 12 })

      // 自动归类餐次 + AI 零食判定原因
      Row() {
        Image($r('app.media.ic_alarm')).width(14).height(14).fillColor(this.subTextColor)
        Text('将记录为: ').fontSize(13).fontColor(this.subTextColor).margin({ left: 4 })
        Text(this.getFinalMealLabel())
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
        Text('（' + this.getTimeStr() + '）').fontSize(12).fontColor(this.subTextColor).margin({ left: 4 })
        Blank()
      }
      .width('100%').margin({ top: 10 })

      // AI 零食判定结果 + 原因（种类还是时间）
      if (this.isJudgingSnack) {
        Row() {
          Image($r('app.media.ic_ai')).width(14).height(14).fillColor(this.subTextColor)
          Text('AI 正在判断是否为零食...').fontSize(12).fontColor(this.subTextColor).margin({ left: 4 })
        }
        .width('100%').margin({ top: 6 })
      } else if (this.snackAnswer.length > 0) {
        Row() {
          Image($r('app.media.ic_ai')).width(14).height(14).fillColor(this.snackAnswerIsSnack ? '#FF9800' : '#4CAF50')
          Text(this.getSnackJudgeText())
            .fontSize(13).fontWeight(FontWeight.Bold)
            .fontColor(this.snackAnswerIsSnack ? '#FF9800' : '#4CAF50')
            .margin({ left: 4 })
        }
        .width('100%').margin({ top: 6 })
        Text(this.snackAnswer).fontSize(11).fontColor(this.subTextColor).width('100%').margin({ top: 2 })
      }

      // 餐次选择（自动默认，用户可改）
      Row() {
        Text('归入餐次：').fontSize(13).fontColor(this.subTextColor)
        this.mealChip('breakfast', '早餐')
        this.mealChip('lunch', '午餐')
        this.mealChip('dinner', '晚餐')
        this.mealChip('snack', '零食')
      }
      .width('100%').margin({ top: 10 })

      // 添加记录按钮
      Row() {
        Button(this.showResetButton ? '➕ 添加到饮食记录' : (this.item.saved ? '✅ 已保存' : '保存此食物'))
          .layoutWeight(1).height(48)
          .backgroundColor(this.item.saved ? '#4CAF50' : '#FF6B35')
          .borderRadius(24)
          .fontColor(Color.White).fontSize(15)
          .enabled(!this.item.saved)
          .onClick(() => {
            // 把用户选择的餐次写入 item，供保存逻辑使用
            const active = this.getActiveMealType();
            this.item.selectedMealType = active;
            this.onSave(this.item);
          })

        // 单食物场景显示重新识别按钮
        if (this.showResetButton) {
          Button() {
            Row() {
              Image($r('app.media.ic_refresh')).width(16).height(16).fillColor(Color.White)
              Text('重新识别').fontSize(15).fontColor(Color.White).margin({ left: 4 })
            }
          }
          .layoutWeight(1).height(48)
          .backgroundColor(this.subTextColor)
          .borderRadius(24)
          .fontColor(Color.White).fontSize(15)
          .margin({ left: 12 })
          .onClick(() => { this.onReset(); })
        }
      }
      .width('100%').margin({ top: 12 })

      // 保存成功提示
      if (this.savedSuccess) {
        Text('✅ 已记录到今天的饮食，可在饮食页查看')
          .fontSize(12).fontColor('#4CAF50').width('100%').margin({ top: 8 })
      }
    }
    .width('100%').padding(16)
    .backgroundColor(this.cardColor).borderRadius(14)
  }

  @Builder
  mealChip(mealType: string, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.getActiveMealType() === mealType ? Color.White : this.textColor)
      .backgroundColor(this.getActiveMealType() === mealType ? '#FF6B35' : this.bgColor)
      .borderRadius(12)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .margin({ left: 4 })
      .onClick(() => {
        this.selectedMeal = mealType;
      })
  }
}