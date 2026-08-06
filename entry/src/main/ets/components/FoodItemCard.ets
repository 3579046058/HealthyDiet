import { RecognizedFoodItem } from '../services/FoodRecognitionService';
import { ThemeColors } from '../common/Constants';
import promptAction from '@ohos.promptAction';

// 通用食物卡片组件（单食物和多食物复用）
@Component
export struct FoodItemCard {
  // 食物数据
  @Prop item: RecognizedFoodItem = {
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
    snackAnswerIsSnack: false
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
  @StorageLink('currentTheme') theme: string = 'dark';
  
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
  
  aboutToAppear(): void {
    this.gramsInput = String(this.item.grams);
  }
  
  // 获取餐次标签
  getFinalMealLabel(): string {
    if (this.item.isSnack) {
      return '零食';
    }
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 10) return '早餐';
    if (hour >= 10 && hour < 14) return '午餐';
    if (hour >= 17 && hour < 20) return '晚餐';
    return '零食';
  }
  
  // 获取时间字符串
  getTimeStr(): string {
    const now = new Date();
    const hour = now.getHours();
    const minute = now.getMinutes();
    return `${hour < 10 ? '0' + hour : hour}:${minute < 10 ? '0' + minute : minute}`;
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
        Text('预计热量: ').fontSize(14).fontColor(this.subTextColor)
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
      
      // 自动归类餐次
      Row() {
        Image($r('app.media.ic_alarm')).width(14).height(14).fillColor(this.subTextColor)
        Text('将记录为: ').fontSize(13).fontColor(this.subTextColor).margin({ left: 4 })
        Text(this.getFinalMealLabel())
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
        Text('（' + this.getTimeStr() + '）').fontSize(12).fontColor(this.subTextColor).margin({ left: 4 })
        Blank()
      }
      .width('100%').margin({ top: 10 })
      
      // AI 零食判断
      Row() {
        Button() {
          Row() {
            if (this.snackAnswer.length > 0) {
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
          .enabled(!this.isJudgingSnack)
          .onClick(() => { this.onSnackJudge(); })
      }
      .width('100%').margin({ top: 10 })
      
      if (this.isJudgingSnack) {
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
      
      // 添加记录按钮
      Row() {
        Button(this.showResetButton ? '➕ 添加到饮食记录' : (this.item.saved ? '✅ 已保存' : '保存此食物'))
          .layoutWeight(1).height(48)
          .backgroundColor(this.item.saved ? '#4CAF50' : '#FF6B35')
          .borderRadius(24)
          .fontColor(Color.White).fontSize(15)
          .enabled(!this.item.saved)
          .onClick(() => { this.onSave(this.item); })
        
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
}
