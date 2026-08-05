import { AchievementInfo } from '../model/AchievementHelper';

@Component
export struct AchievementDialog {
  @Prop achievement: AchievementInfo | null = null;
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop accentColor: string = '#FF6B35';
  onClose: () => void = () => {};

  build() {
    Column() {
      Blank()
      
      Column() {
        // 背景遮罩
        Column() {
          // 弹窗内容
          Column() {
            // 奖牌图标
            Column() {
              Image($r(`app.media.${this.achievement?.icon}`))
                .width(120)
                .height(120)
                .objectFit(ImageFit.Contain)
            }
            .width(140)
            .height(140)
            .borderRadius(70)
            .backgroundColor('rgba(255, 215, 0, 0.1)')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 20, bottom: 20 })

            // 成就名称
            Text(this.achievement?.name || '成就解锁')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .margin({ bottom: 8 })

            // 成就描述
            Text(this.achievement?.description || '')
              .fontSize(16)
              .fontColor(this.subTextColor)
              .margin({ bottom: 16 })

            // 天数标签
            Row() {
              Text('🎉 ')
                .fontSize(20)
              Text(`${this.achievement?.days}天`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.accentColor)
              Text(' 健康生活')
                .fontSize(16)
                .fontColor(this.subTextColor)
            }
            .margin({ bottom: 24 })

            // 关闭按钮
            Button('太棒了！')
              .width('80%')
              .height(44)
              .backgroundColor(this.accentColor)
              .fontColor('#FFFFFF')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .borderRadius(22)
              .onClick(() => {
                this.onClose();
              })
          }
          .width('80%')
          .padding(24)
          .borderRadius(20)
          .backgroundColor(this.cardColor)
          .shadow({
            radius: 20,
            color: 'rgba(0, 0, 0, 0.3)',
            offsetX: 0,
            offsetY: 10
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0, 0, 0, 0.6)')
      .onClick(() => {
        this.onClose();
      })

      Blank()
    }
    .width('100%')
    .height('100%')
  }
}

// 成就列表弹窗
@Component
export struct AchievementListDialog {
  @Prop achievements: AchievementInfo[] = [];
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop accentColor: string = '#FF6B35';
  @Prop currentStreak: number = 0;
  onClose: () => void = () => {};

  build() {
    Column() {
      Blank()
      
      Column() {
        // 背景遮罩
        Column() {
          // 弹窗内容
          Column() {
            // 标题
            Row() {
              Text('🏆 成就系统')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.textColor)
              
              Blank()
              
              // 关闭按钮
              Text('✕')
                .fontSize(24)
                .fontColor(this.subTextColor)
                .onClick(() => {
                  this.onClose();
                })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // 当前连续天数
            Row() {
              Text('当前连续：')
                .fontSize(14)
                .fontColor(this.subTextColor)
              Text(`${this.currentStreak}天`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.accentColor)
            }
            .width('100%')
            .margin({ bottom: 16 })

            // 成就列表
            List() {
              ForEach(this.achievements, (achievement: AchievementInfo) => {
                ListItem() {
                  Row() {
                    // 成就图标
                    Image($r(`app.media.${achievement.icon}`))
                      .width(50)
                      .height(50)
                      .objectFit(ImageFit.Contain)
                      .opacity(achievement.unlocked ? 1 : 0.3)
                    
                    // 成就信息
                    Column() {
                      Text(achievement.name)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(achievement.unlocked ? this.textColor : this.subTextColor)
                      
                      Text(achievement.description)
                        .fontSize(12)
                        .fontColor(this.subTextColor)
                        .margin({ top: 4 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ left: 12 })

                    // 状态标签
                    if (achievement.unlocked) {
                      Text('✓')
                        .fontSize(20)
                        .fontColor('#4CAF50')
                    } else {
                      Text(`${achievement.days}天`)
                        .fontSize(12)
                        .fontColor(this.subTextColor)
                    }
                  }
                  .width('100%')
                  .padding(12)
                  .borderRadius(12)
                  .backgroundColor(achievement.unlocked ? 'rgba(255, 215, 0, 0.1)' : 'rgba(255, 255, 255, 0.05)')
                }
                .margin({ bottom: 8 })
              })
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
          }
          .width('85%')
          .height('70%')
          .padding(20)
          .borderRadius(20)
          .backgroundColor(this.cardColor)
          .shadow({
            radius: 20,
            color: 'rgba(0, 0, 0, 0.3)',
            offsetX: 0,
            offsetY: 10
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0, 0, 0, 0.6)')
      .onClick(() => {
        this.onClose();
      })

      Blank()
    }
    .width('100%')
    .height('100%')
  }
}
