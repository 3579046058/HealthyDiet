import { Constants } from '../common/Constants';

@Component
export struct ScoreTrendChart {
  @Prop scores: number[] = []; // 最近7天的评分数据
  @Prop dates: string[] = []; // 最近7天的日期
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop theme: string = 'dark';

  // 获取评分颜色
  getScoreColor(score: number): string {
    if (score < 0) {
      return '#9C27B0'; // 负分：紫色
    }
    if (score >= 80) {
      return '#4CAF50';
    }
    if (score >= 60) {
      return '#FF9800';
    }
    if (score >= 40) {
      return '#FFC107';
    }
    return '#F44336';
  }

  // 计算平均分
  getAverageScore(): number {
    if (this.scores.length === 0) return 0;
    const sum = this.scores.reduce((a, b) => a + b, 0);
    return Math.round(sum / this.scores.length);
  }

  // 获取最高分
  getMaxScore(): number {
    if (this.scores.length === 0) return 0;
    return Math.max(...this.scores);
  }

  // 获取最低分
  getMinScore(): number {
    if (this.scores.length === 0) return 0;
    return Math.min(...this.scores);
  }

  build() {
    Column() {
      // 标题
      Row() {
        Text('评分趋势')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        
        Blank()
        
        Text(`平均 ${this.getAverageScore()}分`)
          .fontSize(14)
          .fontColor(this.subTextColor)
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 折线图
      if (this.scores.length > 0) {
        Stack({ alignContent: Alignment.BottomStart }) {
          // 背景网格
          Column() {
            ForEach([100, 75, 50, 25, 0], (value: number) => {
              Row()
                .width('100%')
                .height(40)
                .backgroundColor(this.theme === 'dark' ? '#2A2A3A' : '#F0F0F0')
                .margin({ bottom: 1 })
            })
          }
          .width('100%')
          .height(200)

          // 折线图绘制区域
          Row() {
            ForEach(this.scores, (score: number, index: number) => {
              Column() {
                // 数据点和连线
                Stack() {
                  // 连线（到下一个点）
                  if (index < this.scores.length - 1) {
                    Row()
                      .width(40)
                      .height(2)
                      .backgroundColor(this.getScoreColor(score))
                      .position({ x: 20, y: 100 - score })
                  }
                  
                  // 数据点
                  Column() {
                    Text(String(score))
                      .fontSize(10)
                      .fontColor(this.getScoreColor(score))
                      .fontWeight(FontWeight.Bold)
                  }
                  .width(24)
                  .height(24)
                  .borderRadius(12)
                  .backgroundColor(this.cardColor)
                  .justifyContent(FlexAlign.Center)
                  .border({ width: 2, color: this.getScoreColor(score) })
                }
                .width(40)
                .height(200)
                .alignContent(Alignment.Top)
                
                // 日期标签
                if (this.dates[index]) {
                  Text(this.dates[index])
                    .fontSize(10)
                    .fontColor(this.subTextColor)
                    .margin({ top: 4 })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
            })
          }
          .width('100%')
          .height(220)
          .padding({ top: 10 })
        }
        .width('100%')
        .height(220)
      } else {
        // 无数据提示
        Column() {
          Text('暂无历史数据')
            .fontSize(14)
            .fontColor(this.subTextColor)
        }
        .width('100%')
        .height(220)
        .justifyContent(FlexAlign.Center)
      }

      // 统计信息
      if (this.scores.length > 0) {
        Row() {
          Column() {
            Text('最高')
              .fontSize(12)
              .fontColor(this.subTextColor)
            Text(String(this.getMaxScore()) + '分')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getScoreColor(this.getMaxScore()))
              .margin({ top: 4 })
          }
          .layoutWeight(1)

          Column() {
            Text('最低')
              .fontSize(12)
              .fontColor(this.subTextColor)
            Text(String(this.getMinScore()) + '分')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getScoreColor(this.getMinScore()))
              .margin({ top: 4 })
          }
          .layoutWeight(1)

          Column() {
            Text('平均')
              .fontSize(12)
              .fontColor(this.subTextColor)
            Text(String(this.getAverageScore()) + '分')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getScoreColor(this.getAverageScore()))
              .margin({ top: 4 })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 16 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.cardColor)
    .borderRadius(16)
  }
}
