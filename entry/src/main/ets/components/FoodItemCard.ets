import { RecognizedFoodItem } from '../services/FoodRecognitionService';
import { ThemeColors } from '../common/Constants';

// 多食物列表项组件
@Component
export struct FoodItemCard {
  @Prop item: RecognizedFoodItem = {
    id: '',
    foodName: '',
    grams: 200,
    calories: 0,
    isSnack: false,
    snackReason: '',
    saved: false
  };
  @StorageLink('currentTheme') theme: string = 'dark';
  onSave: (item: RecognizedFoodItem) => void = () => {};
  onGramsChange: (item: RecognizedFoodItem, grams: number) => void = () => {};

  @State bgColor: string = '#0D0D1A';
  @State cardColor: string = '#1A1A2E';
  @State textColor: string = '#FFFFFF';
  @State subTextColor: string = '#AAAAAA';

  build() {
    Column() {
      Row() {
        Text('🍽️').fontSize(24)
        Text(this.item.foodName)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .margin({ left: 8 })
        Blank()
        if (this.item.saved) {
          Text('✅').fontSize(16)
        }
      }
      .width('100%')

      Divider().color(ThemeColors.divider(this.theme)).height(1).margin({ top: 8, bottom: 8 })

      // 份量输入
      Row() {
        Text('份量:').fontSize(13).fontColor(this.subTextColor)
        Slider({ value: this.item.grams, min: 10, max: 2000, step: 10, style: SliderStyle.OutSet })
          .layoutWeight(1)
          .selectedColor('#FF6B35')
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              const valid: number = isNaN(value) ? 200 : value;
              this.onGramsChange(this.item, valid);
            }
          })
        Text(String(this.item.grams) + 'g')
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width(60)
      }
      .width('100%')

      // 卡路里显示
      Row() {
        Text('热量:').fontSize(13).fontColor(this.subTextColor)
        Blank()
        Text(this.item.calories > 0 ? String(this.item.calories) + ' 千卡' : '-- 千卡')
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
      }
      .width('100%').margin({ top: 8 })

      // 保存按钮
      if (!this.item.saved) {
        Button('保存此食物')
          .width('100%').height(40)
          .backgroundColor('#FF6B35')
          .borderRadius(20)
          .fontColor(Color.White).fontSize(14)
          .margin({ top: 12 })
          .onClick(() => { this.onSave(this.item); })
      } else {
        Text('已保存')
          .fontSize(13).fontColor('#4CAF50')
          .width('100%').margin({ top: 8 })
      }
    }
    .width('100%').padding(12)
    .backgroundColor(this.theme === 'dark' ? '#252538' : '#F5F5F5')
    .borderRadius(10)
  }
}
