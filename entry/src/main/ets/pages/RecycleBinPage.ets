import { router, promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { ThemeColors } from '../common/Constants';
import { RecycleBinItem, DataType } from '../model/RecycleBinHelper';

@Entry
@Component
struct RecycleBinPage {
  @State items: RecycleBinItem[] = [];
  @State selectedType: DataType | 'all' = 'all';
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State filteredItems: RecycleBinItem[] = [];

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      this.items = await GlobalData.db.recycleBin.getAllItems();
      this.refreshFiltered();
    } catch (err) {
      console.error('RecycleBinPage loadData error:', JSON.stringify(err));
    }
  }

  refreshFiltered(): void {
    if (this.selectedType === 'all') {
      this.filteredItems = this.items.slice();
    } else {
      this.filteredItems = this.items.filter((item: RecycleBinItem) => item.dataType === this.selectedType);
    }
  }

  getFilteredItems(): RecycleBinItem[] {
    if (this.selectedType === 'all') {
      return this.items;
    }
    return this.items.filter(item => item.dataType === this.selectedType);
  }

  getDataTypeLabel(type: string): string {
    const labels: Record<string, string> = {
      [DataType.WEIGHT]: '体重记录',
      [DataType.HEIGHT]: '身高记录',
      [DataType.SPORT]: '运动记录',
      [DataType.SLEEP]: '睡眠记录',
      [DataType.DIET]: '饮食记录',
      [DataType.MOOD]: '心情记录',
      [DataType.MEDICATION]: '药物记录',
      [DataType.PERIOD]: '经期记录',
      [DataType.WATER]: '饮水记录',
      [DataType.HEART]: '心率记录',
      [DataType.STEP]: '步数记录'
    };
    return labels[type] || type;
  }

  // 参与回收站筛选的实际数据类型（身体成分/锻炼计划已弃用，步数/心率无删除入口，均从筛选排除）
  getFilterTypes(): DataType[] {
    const all: DataType[] = [
      DataType.WEIGHT, DataType.HEIGHT, DataType.SPORT, DataType.SLEEP, DataType.DIET,
      DataType.MOOD, DataType.MEDICATION, DataType.PERIOD, DataType.WATER
    ];
    return all;
  }

  getDataContent(item: RecycleBinItem): string {
    try {
      const data = JSON.parse(item.dataContent) as Record<string, Object>;
      let summary = '';
      
      switch (item.dataType) {
        case DataType.WEIGHT:
          const weight = data['weight'] as number | undefined;
          summary = `体重: ${weight ? weight.toFixed(1) : '-'} kg`;
          if (data['date']) summary += ` | ${data['date']}`;
          break;
        case DataType.HEIGHT:
          const height = data['height_cm'] as number | undefined;
          summary = `身高: ${height ? height.toFixed(1) : '-'} cm`;
          if (data['date']) summary += ` | ${data['date']}`;
          break;
        case DataType.MEDICATION:
          summary = `💊 ${data['name'] || '药品'} | ${data['dosage'] || '-'}`;
          if (data['time']) summary += ` | ${data['time']}`;
          break;
        case DataType.SPORT:
          summary = `${data['name'] || '运动'} | ${data['duration'] || 0} 分钟`;
          if (data['date']) summary += ` | ${data['date']}`;
          break;
        case DataType.SLEEP:
          summary = `睡眠: ${data['duration'] || 0} 小时`;
          if (data['date']) summary += ` | ${data['date']}`;
          break;
        case DataType.DIET:
          summary = `${data['meal_type'] || '饮食'} | ${data['calories'] || 0} 卡路里`;
          if (data['date']) summary += ` | ${data['date']}`;
          break;
        case DataType.MOOD:
          summary = `心情评分: ${data['mood'] || '-'}`;
          if (data['date']) summary += ` | ${data['date']}`;
          break;
        case DataType.PERIOD:
          summary = `经期记录`;
          if (data['date']) summary += ` | ${data['date']}`;
          break;
        case DataType.WATER:
          summary = `饮水量: ${data['amount'] || 0} ml`;
          if (data['date']) summary += ` | ${data['date']}`;
          break;
        default:
          summary = JSON.stringify(data).substring(0, 50);
      }
      
      return summary;
    } catch (e) {
      return '数据解析失败';
    }
  }

  async restoreItem(item: RecycleBinItem): Promise<void> {
    try {
      let success = false;
      
      switch (item.dataType) {
        case DataType.WEIGHT:
          success = await GlobalData.db.restoreWeightRecord(item.id);
          break;
        case DataType.HEIGHT:
          success = await GlobalData.db.restoreHeightRecord(item.id);
          break;
        case DataType.MEDICATION:
          success = await GlobalData.db.restoreMedicationRecord(item.id);
          break;
        case DataType.SPORT:
          success = await GlobalData.db.restoreSportRecord(item.id);
          break;
        case DataType.SLEEP:
          success = await GlobalData.db.restoreSleepRecord(item.id);
          break;
        case DataType.DIET:
          success = await GlobalData.db.restoreDietRecord(item.id);
          break;
        case DataType.MOOD:
          success = await GlobalData.db.restoreMoodRecord(item.id);
          break;
        case DataType.PERIOD:
          success = await GlobalData.db.restorePeriodRecord(item.id);
          break;
        case DataType.WATER:
          success = await GlobalData.db.restoreWaterTimelineItem(item.id);
          break;
        default:
          promptAction.showToast({ message: '暂不支持恢复此类型数据' });
          return;
      }
      
      if (success) {
        promptAction.showToast({ message: '已恢复' });
        await this.loadData();
      } else {
        promptAction.showToast({ message: '恢复失败' });
      }
    } catch (err) {
      console.error('RecycleBinPage restoreItem error:', JSON.stringify(err));
      promptAction.showToast({ message: '恢复失败' });
    }
  }

  async permanentlyDeleteItem(item: RecycleBinItem): Promise<void> {
    try {
      await GlobalData.db.recycleBin.permanentlyDelete(item.id);
      promptAction.showToast({ message: '已永久删除' });
      await this.loadData();
    } catch (err) {
      console.error('RecycleBinPage permanentlyDeleteItem error:', JSON.stringify(err));
      promptAction.showToast({ message: '删除失败' });
    }
  }

  async clearAll(): Promise<void> {
    try {
      await GlobalData.db.recycleBin.clearAll();
      promptAction.showToast({ message: '回收站已清空' });
      await this.loadData();
    } catch (err) {
      console.error('RecycleBinPage clearAll error:', JSON.stringify(err));
      promptAction.showToast({ message: '清空失败' });
    }
  }

  build() {
    Column() {
      // 顶部导航栏（与其他页面一致）
      Row() {
        Text('←').fontSize(22).fontColor(ThemeColors.textPrimary(this.theme))
          .onClick(() => { router.back(); })
        Text('回收站')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ThemeColors.textPrimary(this.theme))
          .margin({ left: 12 })
        Blank()
        if (this.items.length > 0) {
          Button('清空')
            .fontSize(14)
            .fontColor('#FF6B6B')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              promptAction.showDialog({
                title: '确认清空',
                message: '确定要清空回收站吗？此操作不可撤销。',
                buttons: [
                  { text: '取消', color: '#666666' },
                  { text: '清空', color: '#FF6B6B' }
                ]
              }).then((result) => {
                if (result.index === 1) {
                  this.clearAll();
                }
              });
            })
        }
      }
      .width('100%').padding({ top: 12 + this.statusBarHeight, bottom: 12, left: 16, right: 16 })

      // 筛选器
      Scroll() {
        Row() {
          Text('筛选:')
            .fontSize(14)
            .fontColor(ThemeColors.textSecondary(this.theme))

          Button('全部')
            .fontSize(12)
            .height(32)
            .margin({ left: 8, right: 8 })
            .backgroundColor(this.selectedType === 'all' ? '#4A90E2' : ThemeColors.cardBg(this.theme))
            .fontColor(this.selectedType === 'all' ? '#FFFFFF' : ThemeColors.textPrimary(this.theme))
            .onClick(() => { this.selectedType = 'all'; this.refreshFiltered(); })

          ForEach(this.getFilterTypes(), (type: DataType) => {
            Button(this.getDataTypeLabel(type))
              .fontSize(12)
              .height(32)
              .margin({ right: 8 })
              .backgroundColor(this.selectedType === type ? '#4A90E2' : ThemeColors.cardBg(this.theme))
              .fontColor(this.selectedType === type ? '#FFFFFF' : ThemeColors.textPrimary(this.theme))
              .onClick(() => { this.selectedType = type; this.refreshFiltered(); })
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .margin({ top: 4, bottom: 4 })

      // 数据列表
      if (this.filteredItems.length === 0) {
        Column() {
          Text('🗑️')
            .fontSize(60)
            .margin({ bottom: 16 })

          Text('回收站为空')
            .fontSize(16)
            .fontColor(ThemeColors.textSecondary(this.theme))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.filteredItems, (item: RecycleBinItem) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(this.getDataTypeLabel(item.dataType))
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ThemeColors.textPrimary(this.theme))
                      .margin({ bottom: 4 })

                    Text(this.getDataContent(item))
                      .fontSize(14)
                      .fontColor(ThemeColors.textSecondary(this.theme))
                      .margin({ bottom: 4 })

                    Text(`剩余时间: ${GlobalData.db.recycleBin.formatRemainingTime(item)}`)
                      .fontSize(12)
                      .fontColor(GlobalData.db.recycleBin.getRemainingTime(item) < 24 * 60 * 60 * 1000 
                        ? '#FF6B6B' 
                        : ThemeColors.textSecondary(this.theme))
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Row() {
                    Button('恢复')
                      .fontSize(12)
                      .height(32)
                      .backgroundColor('#4A90E2')
                      .fontColor('#FFFFFF')
                      .onClick(() => this.restoreItem(item))

                    Button('删除')
                      .fontSize(12)
                      .height(32)
                      .backgroundColor('#FF6B6B')
                      .fontColor('#FFFFFF')
                      .margin({ left: 8 })
                      .onClick(() => {
                        promptAction.showDialog({
                          title: '确认删除',
                          message: '确定要永久删除此数据吗？此操作不可撤销。',
                          buttons: [
                            { text: '取消', color: '#666666' },
                            { text: '删除', color: '#FF6B6B' }
                          ]
                        }).then((result) => {
                          if (result.index === 1) {
                            this.permanentlyDeleteItem(item);
                          }
                        });
                      })
                  }
                }
                .width('100%')
                .padding(16)
                .backgroundColor(ThemeColors.cardBg(this.theme))
                .borderRadius(12)
              }
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColors.pageBg(this.theme))
  }
}
