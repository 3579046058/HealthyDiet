import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { DbRow, ThemeColors } from '../common/Constants';

@Entry
@Component
struct WorkoutPlanPage {
  @State showInput: boolean = false;
  @State name: string = '';
  @State durationWeeks: string = '4';
  @State timesPerWeek: string = '3';
  @State exercises: string = '';
  @State startDate: string = '';
  @State plans: DbRow[] = [];
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.loadPlans();
  }

  async loadPlans(): Promise<void> {
    try {
      this.plans = await GlobalData.db.getWorkoutPlans();
    } catch (err) {
      console.error('WorkoutPlanPage load error:', JSON.stringify(err));
    }
  }

  async savePlan(): Promise<void> {
    if (!this.name || !this.exercises) return;
    const today = await GlobalData.getTodayDate();
    const record: DbRow = {
      name: this.name,
      duration_weeks: parseInt(this.durationWeeks) || 4,
      times_per_week: parseInt(this.timesPerWeek) || 3,
      exercises: this.exercises,
      start_date: this.startDate || today,
    };
    await GlobalData.db.addWorkoutPlan(record);
    this.showInput = false;
    this.name = '';
    this.exercises = '';
    this.durationWeeks = '4';
    this.timesPerWeek = '3';
    await this.loadPlans();
  }

  async deletePlan(id: number): Promise<void> {
    await GlobalData.db.deleteWorkoutPlan(id);
    await this.loadPlans();
  }

  parseDate(dateStr: string): Date {
    if (dateStr.length === 0) {
      return new Date();
    }
    const parts: string[] = dateStr.split('-');
    const y: number = parseInt(parts[0]) || 2026;
    const m: number = parseInt(parts[1]) || 1;
    const d: number = parseInt(parts[2]) || 1;
    return new Date(y, m - 1, d);
  }

  formatDate(date: Date): string {
    const year: number = date.getFullYear();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const monthStr: string = month < 10 ? '0' + month : '' + month;
    const dayStr: string = day < 10 ? '0' + day : '' + day;
    return year + '-' + monthStr + '-' + dayStr;
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).onClick(() => { router.back(); })
        Text('锻炼计划').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
        Blank()
        Text('+ 新建').fontSize(14).fontColor('#673AB7')
          .onClick(() => { this.showInput = !this.showInput; })
      }
      .width('100%').padding(16)

      Scroll() {
        Column() {
          if (this.showInput) {
            Column() {
              Text('新建计划').fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })

            Row() {
              Text('计划名称').fontSize(14).width(100)
              TextInput({ placeholder: '如: 增肌计划', text: this.name })
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .width(180).height(40)
                .onChange((v: string) => { this.name = v; })
            }.width('100%').padding({ bottom: 8 })

            Row() {
              Text('持续(周)').fontSize(14).width(100)
              TextInput({ placeholder: '4', text: this.durationWeeks })
                .type(InputType.Number).width(100).height(40)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((v: string) => { this.durationWeeks = v; })
            }.width('100%').padding({ bottom: 8 })

            Row() {
              Text('每周次数').fontSize(14).width(100)
              TextInput({ placeholder: '3', text: this.timesPerWeek })
                .type(InputType.Number).width(100).height(40)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .onChange((v: string) => { this.timesPerWeek = v; })
            }.width('100%').padding({ bottom: 8 })

            Row() {
              Text('包含动作').fontSize(14).width(100)
              TextInput({ placeholder: '如: 深蹲,卧推,引体', text: this.exercises })
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt())
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .width(180).height(40)
                .onChange((v: string) => { this.exercises = v; })
            }.width('100%').padding({ bottom: 8 })

            Row() {
              Text('开始日期').fontSize(14).width(100)
              DatePicker({ selected: this.parseDate(this.startDate) })
                .onDateChange((value: Date) => { this.startDate = this.formatDate(value); })
            }.width('100%').padding({ bottom: 8 })

              Button('保存计划').width('100%').backgroundColor('#673AB7').borderRadius(12)
                .margin({ top: 8 }).onClick(() => { this.savePlan(); })
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(14)
            .margin({ left: 16, right: 16, bottom: 16 })
          }

          if (this.plans.length === 0 && !this.showInput) {
            Text('暂无锻炼计划').fontSize(16).fontColor(this.sub()).margin({ top: 60 })
            Text('点击右上角"+ 新建"创建计划').fontSize(14).fontColor(this.sub()).margin({ top: 8 })
          }

          ForEach(this.plans, (plan: DbRow) => {
            Column() {
              Row() {
                Text('✅').fontSize(20)
                Text(String(plan.name)).fontSize(18).fontWeight(FontWeight.Bold).margin({ left: 8 })
                Blank()
                Text('🗑').fontSize(18).onClick(() => { this.deletePlan(Number(plan.id)); })
              }
              .width('100%')

              Text('⏱ ' + String(plan.times_per_week) + '次/周 × ' + String(plan.duration_weeks) + '周')
                .fontSize(13).fontColor(this.sub()).width('100%').margin({ top: 4 })

              if (plan.exercises) {
                Text('🏋️ ' + String(plan.exercises))
                  .fontSize(13).fontColor(this.txt()).width('100%').margin({ top: 4 })
              }

              if (plan.start_date) {
                Text('📅 开始: ' + String(plan.start_date))
                  .fontSize(12).fontColor(this.sub()).width('100%').margin({ top: 4 })
              }
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(14)
            .margin({ left: 16, right: 16, bottom: 12 })
          })

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%')    .backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
