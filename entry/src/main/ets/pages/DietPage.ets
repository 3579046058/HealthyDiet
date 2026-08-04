import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { DbRow, ThemeColors, FoodCalories, GoalConfig } from '../common/Constants';
import { FoodRecognitionService } from '../services/FoodRecognitionService';

@Entry
@Component
struct DietPage {
  @State date: string = '';
  @State records: DbRow[] = [];
  @State showInput: boolean = false;
  @State mealType: string = 'breakfast';
  @State foodName: string = '';
  @State amountG: string = '';
  @State showFoodList: boolean = false;
  @State recommendCalorie: number = 2000; // 来自体重页面计算保存的推荐热量
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  aboutToAppear(): void {
    this.initDate();
    this.loadRecommendCalorie();
  }

  onPageShow(): void {
    if (this.date.length === 0) {
      this.initDate();
    } else {
      this.loadData();
    }
    // 从体重页返回后刷新推荐热量
    this.loadRecommendCalorie();
  }

  /** 读取体重页面计算保存的推荐热量GoalConfig.dailyCalorie */
  async loadRecommendCalorie(): Promise<void> {
    try {
      const cfg: GoalConfig = await GlobalData.prefs.getGoalConfig();
      this.recommendCalorie = cfg.dailyCalorie;
    } catch (err) {
      console.error("loadRecommendCalorie error", JSON.stringify(err));
    }
  }

  async initDate(): Promise<void> {
    this.date = await GlobalData.getTodayDate();
    await this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      this.records = await GlobalData.db.getDietRecords(this.date);
    } catch (err) {
      console.error('DietPage loadData error:', JSON.stringify(err));
    }
  }

  async saveRecord(): Promise<void> {
    const name: string = this.foodName.trim();
    const amount: string = this.amountG.trim();
    if (name === '' || amount === '') {
      return;
    }
    const grams: number = parseFloat(amount);
    if (isNaN(grams) || grams <= 0) {
      return;
    }
    // 云端计算卡路里（优先），失败则用本地食物库
    let calories: number = FoodCalories.calcCalories(name, grams);
    const cloud = await FoodRecognitionService.getInstance().calculateCalories(name, grams);
    if (cloud >= 0) {
      calories = cloud;
    }
    const record: DbRow = {
      date: this.date,
      meal_type: this.mealType,
      food_name: name,
      amount_g: grams,
      calories: calories,
      protein: 0,
      fat: 0,
      carbs: 0,
      timestamp: Date.now()
    };
    try {
      await GlobalData.db.addDietRecord(record);
      this.foodName = '';
      this.amountG = '';
      this.showInput = false;
      await this.loadData();
    } catch (err) {
      console.error('DietPage saveRecord error:', JSON.stringify(err));
    }
  }

  async deleteDietRecord(id: number): Promise<void> {
    await GlobalData.db.deleteDietRecord(id);
    await this.loadData();
  }

  previewCalories(): number {
    const grams: number = parseFloat(this.amountG);
    if (isNaN(grams) || grams <= 0) {
      return 0;
    }
    return FoodCalories.calcCalories(this.foodName.trim(), grams);
  }

  getFilteredRecords(meal: string): DbRow[] {
    const result: DbRow[] = [];
    for (const r of this.records) {
      if (String(r.meal_type) === meal) {
        result.push(r);
      }
    }
    return result;
  }

  getGramsByMeal(meal: string): number {
    let total: number = 0;
    for (const r of this.records) {
      if (String(r.meal_type) === meal) {
        total += Number(r.amount_g);
      }
    }
    return total;
  }

  getCaloriesByMeal(meal: string): number {
    let total: number = 0;
    for (const r of this.records) {
      if (String(r.meal_type) === meal) {
        total += Number(r.calories);
      }
    }
    return total;
  }

  getTotalCalories(): number {
    let total: number = 0;
    for (const r of this.records) {
      total += Number(r.calories);
    }
    return total;
  }

  getTotalGrams(): number {
    let total: number = 0;
    for (const r of this.records) {
      total += Number(r.amount_g);
    }
    return total;
  }

  getAmountText(item: DbRow): string {
    const v = item.amount_g;
    if (v === undefined || v === null) {
      return '0';
    }
    return String(v);
  }

  getAddTime(item: DbRow): string {
    const ts = item.timestamp;
    const num: number = typeof ts === 'number' ? ts : Number(ts);
    if (isNaN(num) || num <= 0) {
      return '--:--';
    }
    const d = new Date(num);
    return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
  }

  // 计算距离推荐热量差值
  getRemainCalories(): number {
    return this.recommendCalorie - this.getTotalCalories();
  }

  // 颜色：超出推荐值红色，剩余为橙色
  getRemainTextColor(): string {
    const remain = this.getRemainCalories();
    if (remain < 0) {
      return '#F44336';
    } else {
      return '#FF9800';
    }
  }

  @Builder
  mealButton(emoji: string, type: string): void {
    Button(emoji)
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor(this.mealType === type ? '#FF5722' : '#333344')
      .fontSize(24)
      .onClick(() => {
        this.mealType = type;
      })
  }

  @Builder
  mealSection(emoji: string, type: string, label: string): void {
    Column() {
      Row() {
        Text(emoji + ' ' + label)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.getGramsByMeal(type) + 'g · ' + this.getCaloriesByMeal(type) + 'kcal')
          .fontSize(14)
          .fontColor(this.sub())
      }
      .width('100%')
      .padding({ bottom: 8 })

      if (this.getFilteredRecords(type).length > 0) {
        ForEach(this.getFilteredRecords(type), (item: DbRow) => {
          Row() {
            Column() {
              Text(String(item.food_name))
                .fontSize(14)
              Text(this.getAmountText(item) + 'g' + ' · ' + this.getAddTime(item))
                .fontSize(11)
                .fontColor(this.sub())
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text(Number(item.calories) > 0 ? String(Number(item.calories)) + ' kcal' : '未识别')
              .fontSize(12)
              .fontColor('#FF9800')
            Text('🗑').fontSize(16).margin({ left: 8 })
              .onClick(() => { this.deleteDietRecord(Number(item.id)); })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.card())
          .borderRadius(8)
          .margin({ bottom: 6 })
        }, (item: DbRow): string => String(item.id))
      } else {
        Text('暂无记录')
          .fontSize(12)
          .fontColor(this.sub())
          .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            router.back();
          })
        Text('饮食记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
        Blank()
        Text(this.date)
          .fontSize(14)
          .fontColor(this.sub())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Scroll() {
        Column() {
          if (!this.showInput) {
            Button('+ 添加食物')
              .width('100%')
              .backgroundColor('#FF5722')
              .borderRadius(10)
              .margin({ bottom: 16 })
              .onClick(() => {
                this.showInput = true;
              })
          } else {
            Column() {
              Text('添加食物')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .margin({ bottom: 12 })

              Row() {
                this.mealButton('🌅', 'breakfast')
                this.mealButton('🌞', 'lunch')
                this.mealButton('🌙', 'dinner')
                this.mealButton('🍪', 'snack')
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceEvenly)
              .margin({ bottom: 12 })

              Row() {
                TextInput({ placeholder: '食物名称', text: this.foodName })
                  .backgroundColor(ThemeColors.inputBg(this.theme))
                  .fontColor(this.txt())
                  .placeholderColor(ThemeColors.textSecondary(this.theme))
                  .layoutWeight(1)
                  .onChange((v: string) => {
                    this.foodName = v;
                  })
                Button('📖 食物库')
                  .fontSize(13)
                  .backgroundColor('#FF9800')
                  .borderRadius(10)
                  .height(40)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.showFoodList = !this.showFoodList;
                  })
              }
              .width('100%')
              .margin({ bottom: 8 })

              if (this.showFoodList) {
                Column() {
                  Text('可识别食物（每100g热量）')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.sub())
                    .width('100%')
                    .margin({ bottom: 6 })

                  Scroll() {
                    Column() {
                      ForEach(FoodCalories.getFoodNames(), (food: string) => {
                        Row() {
                          Text(food)
                            .fontSize(14)
                            .fontColor(this.txt())
                          Blank()
                          Text(String(FoodCalories.getCaloriesFor(food)) + ' kcal')
                            .fontSize(12)
                            .fontColor('#FF9800')
                        }
                        .width('100%')
                        .padding({ top: 6, bottom: 6 })
                        .onClick(() => {
                          this.foodName = food;
                          this.showFoodList = false;
                        })
                      })
                    }
                  }
                  .height(220)
                  .width('100%')
                }
                .width('100%')
                .padding(12)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .borderRadius(10)
                .margin({ bottom: 8 })
              }

              TextInput({ placeholder: '份量 (克)', text: this.amountG })
                .width('100%')
                .type(InputType.Number)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .margin({ bottom: 8 })
                .onChange((v: string) => {
                  this.amountG = v;
                })

              if (this.foodName.trim().length > 0 && this.amountG.trim().length > 0) {
                Text('预计 ' + String(this.previewCalories()) + ' kcal')
                  .fontSize(13)
                  .fontColor('#FF9800')
                  .width('100%')
                  .margin({ bottom: 8 })
              }

              Row() {
                Button('取消')
                  .backgroundColor('#555555')
                  .borderRadius(20)
                  .flexGrow(1)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.showInput = false;
                    this.foodName = '';
                    this.amountG = '';
                  })
                Button('保存')
                  .backgroundColor('#4CAF50')
                  .borderRadius(20)
                  .flexGrow(1)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.saveRecord();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.card())
            .borderRadius(12)
            .margin({ bottom: 16 })
          }

          // ==========今日统计卡片：已摄入 / 推荐热量 / 剩余/超出==========
          Column() {
            Row() {
              Text('🍽️ 今日热量统计')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
              Blank()
            }
            .width('100%')
            .margin({ bottom: 8 })

            Row() {
              Column() {
                Text('已摄入')
                  .fontSize(12)
                  .fontColor(this.sub())
                Text(this.getTotalCalories().toString() + ' kcal')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              Column() {
                Text('推荐热量')
                  .fontSize(12)
                  .fontColor(this.sub())
                Text(this.recommendCalorie.toString() + ' kcal')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              Column() {
                Text(this.getRemainCalories() >= 0 ? '剩余可摄入' : '超出推荐')
                  .fontSize(12)
                  .fontColor(this.sub())
                Text(Math.abs(this.getRemainCalories()).toString() + ' kcal')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getRemainTextColor())
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')

            Text('总重量：' + this.getTotalGrams() + ' g')
              .fontSize(12)
              .fontColor(this.sub())
              .width('100%')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.card())
          .borderRadius(10)
          .margin({ bottom: 16 })

          this.mealSection('🌅', 'breakfast', '早餐')
          this.mealSection('🌞', 'lunch', '午餐')
          this.mealSection('🌙', 'dinner', '晚餐')
          this.mealSection('🍪', 'snack', '零食')
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}