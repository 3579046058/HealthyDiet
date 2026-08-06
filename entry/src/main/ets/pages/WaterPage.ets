import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { DbRow, ThemeColors } from '../common/Constants';
import { CardDataHelper } from '../services/CardDataHelper';
import { SoundEffectService } from '../services/SoundEffectService';

@Entry
@Component
struct WaterPage {
  @State currentMl: number = 0;
  @State goalMl: number = 2000;
  @State cupMl: number = 250;
  @State showGoalInput: boolean = false;
  @State goalInput: string = '';
  @State timeline: DbRow[] = [];
  @State detailRecord: DbRow | null = null;
  @State barAnimWidth: number = 0; // 进度条动画宽度，从0开始渐变到目标值
  @State barHeights: number[] = []; // 柱状图每根柱子的动画高度，从0渐变到目标值
  @State isRefreshing: boolean = false; // 下拉刷新状态
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  private lastClickTime: number = 0;

  isDoubleClick(): boolean {
    const now = Date.now();
    if (now - this.lastClickTime < 400) {
      this.lastClickTime = 0;
      return true;
    }
    this.lastClickTime = now;
    return false;
  }

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const config = await GlobalData.prefs.getGoalConfig();
      this.goalMl = config.dailyWaterMl;
      this.timeline = await GlobalData.db.getWaterTimeline(today);
      let total: number = 0;
      for (const r of this.timeline) {
        total += Number(r.ml);
      }
      this.currentMl = total;
      await GlobalData.db.updateDailySummaryField(today, 'water_ml', total);
      
      // 通知 Index 页面数据已更新
      AppStorage.setOrCreate('dataUpdateTrigger', `water_${Date.now()}`);

      // 进度条从0动画过渡到目标宽度
      const targetWidth = Math.min(100, (total / this.goalMl) * 100);
      animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
        this.barAnimWidth = targetWidth;
      });
      // 柱状图从0动画过渡到目标高度
      this.animateBarChart();
    } catch (err) {
      console.error('WaterPage loadData error:', JSON.stringify(err));
    }
  }

  async deleteTimelineItem(id: number): Promise<void> {
    // 找到要删除的柱子在 timeline 中的索引
    const idx = this.timeline.findIndex((r: DbRow) => Number(r.id) === id);
    if (idx >= 0 && idx < this.barHeights.length) {
      // 先让被删柱子动画从当前高度缩到 0，其他柱子不动
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.barHeights[idx] = 0;
      });
      // 等待动画完成后，从数据和数组中移除该柱子
      setTimeout(async () => {
        await GlobalData.db.deleteWaterTimelineItem(id);
        const today = await GlobalData.getTodayDate();
        this.timeline = await GlobalData.db.getWaterTimeline(today);
        this.barHeights.splice(idx, 1);
        await this.syncWaterSummary(today);
        promptAction.showToast({ message: '记录删除成功', duration: 2000, bottom: 80 });
      }, 500);
      return;
    }
    // fallback：索引未找到时直接删除
    await GlobalData.db.deleteWaterTimelineItem(id);
    const today = await GlobalData.getTodayDate();
    this.timeline = await GlobalData.db.getWaterTimeline(today);
    this.animateBarChart();
    await this.syncWaterSummary(today);
    promptAction.showToast({ message: '记录删除成功', duration: 2000, bottom: 80 });
  }

  async addCup(): Promise<void> {
    const today = await GlobalData.getTodayDate();
    const now = GlobalData.getTimeStr();
    await GlobalData.db.addWaterCup(today, this.cupMl);
    await GlobalData.db.addWaterTimeline(today, now, this.cupMl);
    // 注意：不在此处手动叠加 currentMl，统一由 syncWaterSummary 从 timeline 重算，避免双源计数错误
    const prevLen = this.barHeights.length;
    this.timeline = await GlobalData.db.getWaterTimeline(today);

    // 仅动画新添加的柱子：在 barHeights 末尾追加 0，然后渐变到目标高度，已有柱子不动
    const newCount = this.timeline.length - prevLen;
    if (newCount > 0) {
      this.barHeights = [...this.barHeights, ...new Array<number>(newCount).fill(0)];
      const targetHeights = this.timeline.slice(prevLen).map((r: DbRow) => this.calcBarHeight(Number(r.ml)));
      animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
        const updated = [...this.barHeights];
        for (let i = 0; i < newCount; i++) {
          updated[prevLen + i] = targetHeights[i];
        }
        this.barHeights = updated;
      });
    }

    await this.syncWaterSummary(today);
    this.refreshCard();
    // 播放喝水音效
    SoundEffectService.getInstance().play('water');
    promptAction.showToast({ message: `喝水记录添加成功  +${this.cupMl}ml`, duration: 2000, bottom: 80 });
  }

  // 刷新桌面卡片（复用完整数据，包含三环/评分/心情等所有字段）
  async refreshCard(): Promise<void> {
    await CardDataHelper.refreshWidget(getContext(this));
  }

  async syncWaterSummary(date: string): Promise<void> {
    try {
      const rows = await GlobalData.db.getWaterTimeline(date);
      let total: number = 0;
      for (const r of rows) {
        total += Number(r.ml);
      }
      this.currentMl = total;
      await GlobalData.db.updateDailySummaryField(date, 'water_ml', total);
      
      // 通知 Index 页面数据已更新
      AppStorage.setOrCreate('dataUpdateTrigger', `water_${Date.now()}`);

      // 进度条动画过渡到新的宽度
      const targetWidth = Math.min(100, (total / this.goalMl) * 100);
      animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
        this.barAnimWidth = targetWidth;
      });
    } catch (err) {
      console.error('WaterPage syncWaterSummary error:', JSON.stringify(err));
    }
  }

  async updateGoal(): Promise<void> {
    const val = parseInt(this.goalInput);
    if (isNaN(val) || val <= 0) return;
    const config = await GlobalData.prefs.getGoalConfig();
    config.dailyWaterMl = val;
    await GlobalData.prefs.saveGoalConfig(config);
    this.goalMl = val;
    this.showGoalInput = false;
    this.goalInput = '';
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  calcBarHeight(ml: number): number {
    return Math.max(10, Math.min(90, ml / 5));
  }

  animateBarChart(): void {
    if (this.timeline.length === 0) {
      this.barHeights = [];
      return;
    }
    const targetHeights = this.timeline.map((r: DbRow) => this.calcBarHeight(Number(r.ml)));
    // 先重置为0，触发"从短到长"的动画起点
    this.barHeights = targetHeights.map(() => 0);
    // animateTo 驱动高度从0渐变到目标值
    animateTo({ duration: 700, curve: Curve.EaseOut }, () => {
      this.barHeights = targetHeights;
    });
  }

  build() {
    Stack() {
      Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt())
          .accessibilityText('返回上一页')
          .accessibilityLevel('important')
          .onClick(() => { router.back(); })
        Text('喝水提醒').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
        Text('设置目标').fontSize(14).fontColor('#03A9F4')
          .onClick(() => { this.showGoalInput = !this.showGoalInput; })
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          if (this.showGoalInput) {
            Row() {
              TextInput({ placeholder: '每日目标 (ml)', text: this.goalInput })
                .width(180).type(InputType.Number)
                .onChange((v: string) => { this.goalInput = v; })
              Button('保存').backgroundColor('#03A9F4').borderRadius(20).margin({ left: 8 })
                .onClick(() => { this.updateGoal(); })
            }
            .padding(16)
          }

          Column() {
            Text('💧').fontSize(60)
            Text(String(this.currentMl) + ' / ' + String(this.goalMl) + ' ml')
              .fontSize(24).fontWeight(FontWeight.Bold).margin({ top: 8 })
            Stack() {
              Row().width('100%').height(14).backgroundColor(ThemeColors.divider(this.theme)).borderRadius(7)
              Row()
                .width(this.barAnimWidth + '%')
                .height(14).backgroundColor('#03A9F4').borderRadius(7)
            }
            .width('80%').margin({ top: 16 })
            Text('已喝 ' + String(Math.floor(this.currentMl / this.cupMl)) + ' 杯')
              .fontSize(14).fontColor(this.sub()).margin({ top: 8 })
            Text('双击 💧 快速记录一杯 (' + String(this.cupMl) + 'ml)')
              .fontSize(11).fontColor(this.sub()).margin({ top: 6 })
          }
          .width('100%').padding(32)
          .onClick(() => {
            if (this.isDoubleClick()) {
              this.addCup();
            }
          })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach([100, 150, 200, 250, 300, 500], (ml: number) => {
              Button(String(ml) + 'ml')
                .width(90).height(46)
                .backgroundColor(this.cupMl === ml ? '#03A9F4' : this.card())
                .borderRadius(23)
                .fontColor(this.cupMl === ml ? '#FFFFFF' : this.sub())
                .margin(6)
                .onClick(() => {
                  if (this.isDoubleClick()) {
                    this.cupMl = ml;
                    this.addCup();
                  } else {
                    this.cupMl = ml;
                  }
                })
            })
          }
          .margin({ top: 16 })

          Button() {
            Text('+ ' + String(this.cupMl) + 'ml 记录喝水').fontSize(18).fontColor(this.txt())
          }
          .width(240).height(54).backgroundColor('#03A9F4').borderRadius(27)
          .margin({ top: 24 })
          .onClick(() => { this.addCup(); })

          if (this.timeline.length > 0) {
            Text('喝水时间线').fontSize(16).fontWeight(FontWeight.Bold)
              .width('100%').padding({ left: 16, top: 24, bottom: 8 })
            // 柱状图：每根柱子代表一次喝水，高度按 ml 比例
            Scroll() {
              Row() {
                ForEach(this.timeline, (item: DbRow, index: number) => {
                  Column() {
                    // 柱子（点击弹出详情卡片，删除功能在卡片里）
                    Row()
                      .width(20)
                      .height(index < this.barHeights.length ? this.barHeights[index] : 0)
                      .backgroundColor('#03A9F4')
                      .borderRadius({ topLeft: 6, topRight: 6 })
                    // 时间
                    Text(String(item.time)).fontSize(10).fontColor(this.sub()).margin({ top: 4 })
                    // 水量
                    Text(String(item.ml)).fontSize(10).fontColor(this.sub()).margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Center)
                  .width(44)
                  .height(150)
                  .justifyContent(FlexAlign.End)
                  .margin({ left: 10, right: 10 })
                  .onClick(() => {
                    console.info('WaterPage bar clicked: id=' + String(item.id) + ' ml=' + String(item.ml));
                    this.detailRecord = item;
                  })
                })
              }
              .alignItems(VerticalAlign.Bottom)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            }
            .scrollable(ScrollDirection.Horizontal)
            .width('100%')
            .height(180)
          }

          Text('💧 每天喝水，健康又美丽')
            .fontSize(14).fontColor(this.sub())
            .margin({ top: 16, bottom: 24 })
      }
      .width('100%')
      }
      }
      .width('100%').height('100%')
      .backgroundColor(this.bg())
      .onRefreshing(() => {
        // 下拉刷新：重新加载喝水记录，进度条/柱状图由原有 animateTo 机制从 0 动画
        this.loadData().then(() => {
          setTimeout(() => {
            this.isRefreshing = false;
          }, 600);
        }).catch(() => {
          this.isRefreshing = false;
        });
      })

      // 点击水柱弹出的详情悬浮卡片
      if (this.detailRecord !== null) {
        Column() {
          Text('喝水详情').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
          Divider().color(ThemeColors.divider(this.theme)).margin({ top: 12, bottom: 12 })
          Row() {
            Text('时间').fontSize(14).fontColor(this.sub())
            Blank()
            Text(String(this.detailRecord.time)).fontSize(15).fontColor(this.txt())
          }
          .width('100%').margin({ bottom: 10 })
          Row() {
            Text('水量').fontSize(14).fontColor(this.sub())
            Blank()
            Text(String(this.detailRecord.ml) + ' ml').fontSize(15).fontColor(this.txt())
          }
          .width('100%').margin({ bottom: 10 })
          Row() {
            Text('占目标').fontSize(14).fontColor(this.sub())
            Blank()
            Text(this.goalMl > 0 ? Math.round(Number(this.detailRecord.ml) / this.goalMl * 100) + '%' : '--')
              .fontSize(15).fontColor(this.txt())
          }
          .width('100%').margin({ bottom: 20 })

          Row() {
            Button('取消').backgroundColor(this.card()).fontColor(this.sub()).borderRadius(20)
              .layoutWeight(1).height(40)
              .onClick(() => { this.detailRecord = null; })
            Button('删除这条记录').backgroundColor('#F44336').fontColor('#FFFFFF').borderRadius(20)
              .layoutWeight(1).height(40).margin({ left: 12 })
              .onClick(() => {
                const rec = this.detailRecord;
                if (rec !== null) {
                  const id = Number(rec.id);
                  this.detailRecord = null;
                  this.deleteTimelineItem(id);
                }
              })
          }
          .width('100%')
        }
        .width('82%')
        .padding(20)
        .backgroundColor(this.card())
        .borderRadius(20)
        .shadow({ radius: 24, color: '#66000000', offsetY: 6 })
        .position({ x: '9%', y: '35%' })  // 绝对定位在屏幕中央
        .zIndex(999)  // 确保在最上层
      }
      }
    }
    .width('100%').height('100%')
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
