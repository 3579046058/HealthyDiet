import { router, promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, ThemeColors } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';
import { CardDataHelper } from '../services/CardDataHelper';
import { NotificationService } from '../services/NotificationService';
import { GoalNotificationHelper } from '../services/GoalNotificationHelper';

@Entry
@Component
struct SleepPage {
  @State showInput: boolean = false;
  @State startTime: string = '23:00';
  @State endTime: string = '07:00';
  @State startDate: string = ''; // 入睡日期
  @State endDate: string = ''; // 醒来日期
  @State deepMin: string = '90';
  @State lightMin: string = '270';
  @State remMin: string = '120';
  @State records: DbRow[] = [];
  @State weekScores: number[] = [];
  @State weekLabels: string[] = [];
  @State avgScore: number = 0;
  @State lastRecord: string = '暂无数据';
  @State isRefreshing: boolean = false; // 下拉刷新状态
  @State listAnimTick: number = 0; // 列表展开动画触发标记
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State isSleeping: boolean = false;
  @State sleepStartTime: string = '';

  aboutToAppear(): void {
    this.loadData();
    this.loadSleepStartRecord();
    this.startAutoRefresh();
    this.initDates();
  }

  // 初始化日期（入睡日期默认昨天，醒来日期默认今天）
  async initDates(): Promise<void> {
    const today = await GlobalData.getTodayDate();
    this.endDate = today; // 醒来日期默认今天
    
    // 计算昨天的日期
    const todayDate = new Date(today);
    todayDate.setDate(todayDate.getDate() - 1);
    const yesterday = todayDate.toISOString().split('T')[0];
    this.startDate = yesterday; // 入睡日期默认昨天
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
  }

  // 处理返回逻辑（左上角返回按钮和系统返回键共用）
  handleBackPress(): void {
    console.info('[SleepPage] handleBackPress, isSleeping:', this.isSleeping);
    
    // 如果正在睡眠中，弹出对话框询问
    if (this.isSleeping) {
      this.getUIContext().getPromptAction().showDialog({
        title: '睡眠进行中',
        message: `当前已入睡（${this.sleepStartTime}），请选择：`,
        buttons: [
          { text: '取消入睡', color: '#FF5737' },
          { text: '后台继续', color: '#007DFF' }
        ]
      }).then(async (result) => {
        console.info('[SleepPage] 用户选择:', result.index);
        if (result.index === 1) {
          // 后台继续：保持睡眠状态，返回主页
          router.back();
        } else {
          // 取消入睡：删除入睡记录，取消通知，返回主页
          await this.deleteSleepStartRecord();
          this.isSleeping = false;
          NotificationService.getInstance().cancelSleepTrackingNotification();
          router.back();
        }
      }).catch((error: Error) => {
        console.error('[SleepPage] 对话框错误:', error);
      });
    } else {
      // 没有正在进行的睡眠，直接返回
      router.back();
    }
  }

  // 拦截系统返回键
  onBackPress(): boolean {
    // 如果正在睡眠中，调用处理方法并拦截返回键
    if (this.isSleeping) {
      this.handleBackPress();
      return true; // 拦截返回键
    }
    // 没有正在进行的睡眠，正常返回
    return false;
  }

  private refreshTimer: number = -1;

  startAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
    }
    this.refreshTimer = setInterval(() => {
      this.loadData();
    }, 15000);
  }

  stopAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  async loadData(): Promise<void> {
    try {
      const end = new Date();
      const start = new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
      const rows = await GlobalData.db.getSleepRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      // animateTo 包裹数据更新，触发列表项 transition 进入动画
      animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
        this.records = rows;
      });

      // 按天聚合睡眠记录（同一天多段睡眠合并为一天）
      const dayMap = new Map<string, DbRow[]>();
      for (const r of rows) {
        const day: string = String(r.date);
        const dayRows: DbRow[] | undefined = dayMap.get(day);
        if (dayRows) {
          dayRows.push(r);
        } else {
          dayMap.set(day, [r]);
        }
      }
      // 按日期倒序取最近 7 天
      const dayKeys: string[] = Array.from(dayMap.keys()).sort().reverse().slice(0, 7);
      const recent: DbRow[][] = [];
      for (const k of dayKeys) {
        const arr: DbRow[] | undefined = dayMap.get(k);
        if (arr) {
          recent.push(arr);
        }
      }
      this.weekLabels = dayKeys.map((d: string) => d.slice(5)).reverse();
      // 每天用聚合评分（多段合并），不是分钟数
      this.weekScores = recent.map((dayRows: DbRow[]) => this.calcAggregatedScore(dayRows)).reverse();
      if (this.weekScores.length > 0) {
        this.avgScore = Math.round(this.weekScores.reduce((a: number, b: number) => a + b, 0) / this.weekScores.length);
      }

      if (rows.length > 0) {
        const last = rows[0];
        this.lastRecord = last.date + ' ' + last.start_time + ' - ' + last.end_time;
      }
    } catch (err) {
      console.error('SleepPage loadData error:', JSON.stringify(err));
    }
  }

  async loadSleepStartRecord(): Promise<void> {
    try {
      const record = await GlobalData.db.getLatestSleepStartRecord();
      if (record) {
        this.isSleeping = true;
        this.sleepStartTime = String(record.start_time || '');
        this.startTime = String(record.start_time || '');
      }
    } catch (err) {
      console.error('SleepPage loadSleepStartRecord error:', JSON.stringify(err));
    }
  }

  async deleteSleepStartRecord(): Promise<void> {
    try {
      const record = await GlobalData.db.getLatestSleepStartRecord();
      if (record && record.id) {
        await GlobalData.db.deleteSleepStartRecord(Number(record.id));
        this.isSleeping = false;
        this.sleepStartTime = '';
        this.startTime = '';
        this.getUIContext().getPromptAction().showToast({ message: '已删除入睡记录' });
      }
    } catch (err) {
      console.error('SleepPage deleteSleepStartRecord error:', JSON.stringify(err));
    }
  }

  parseTimeToDate(timeStr: string): Date {
    const parts: string[] = timeStr.split(':');
    const h: number = parseInt(parts[0]) || 0;
    const m: number = parseInt(parts[1]) || 0;
    const d: Date = new Date();
    d.setHours(h, m, 0, 0);
    return d;
  }

  formatPickerTime(value: TimePickerResult): string {
    const h: number = value.hour;
    const m: number = value.minute;
    const hStr: string = h < 10 ? '0' + h : '' + h;
    const mStr: string = m < 10 ? '0' + m : '' + m;
    return hStr + ':' + mStr;
  }

  autoTotalMin(): number {
    const startParts = this.startTime.split(':');
    const endParts = this.endTime.split(':');
    const sh = parseInt(startParts[0]) || 0;
    const sm = parseInt(startParts[1]) || 0;
    const eh = parseInt(endParts[0]) || 0;
    const em = parseInt(endParts[1]) || 0;
    const startMin = sh * 60 + sm;
    const endMin = eh * 60 + em;
    let duration = endMin - startMin;
    if (duration < 0) {
      duration += 24 * 60;
    }
    return duration;
  }

  autoDeepMin(): number {
    return Math.round(this.autoTotalMin() * 0.2);
  }

  autoLightMin(): number {
    return Math.round(this.autoTotalMin() * 0.55);
  }

  autoRemMin(): number {
    return Math.round(this.autoTotalMin() * 0.25);
  }

  calcScore(): number {
    const d = parseInt(this.deepMin) || 0;
    const l = parseInt(this.lightMin) || 0;
    const r = parseInt(this.remMin) || 0;
    const total = d + l + r;
    if (total <= 0) return 0;
    const deepRatio = d / total;
    const lightRatio = l / total;
    const remRatio = r / total;

    // 总分 100，分四维打分
    // 1. 总时长 (40分): 7-9h 满分，每少/多 30min 扣 5
    let durationScore = 0;
    if (total >= 420 && total <= 540) {
      durationScore = 40;
    } else if (total >= 360 && total <= 600) {
      durationScore = 32;
    } else if (total >= 300) {
      durationScore = 24;
    } else {
      durationScore = 12;
    }

    // 2. 深睡比例 (25分): 15%-25% 满分，偏离越多扣越多
    let deepScore = 0;
    const deepDiff = Math.abs(deepRatio - 0.2);
    if (deepRatio >= 0.15 && deepRatio <= 0.25) {
      deepScore = 25;
    } else if (deepDiff <= 0.1) {
      deepScore = 18;
    } else {
      deepScore = 10;
    }

    // 3. REM 比例 (20分): 20%-25% 满分
    let remScore = 0;
    const remDiff = Math.abs(remRatio - 0.22);
    if (remRatio >= 0.2 && remRatio <= 0.25) {
      remScore = 20;
    } else if (remDiff <= 0.1) {
      remScore = 14;
    } else {
      remScore = 8;
    }

    // 4. 浅睡比例 (15分): 45%-60% 健康
    let lightScore = 0;
    if (lightRatio >= 0.45 && lightRatio <= 0.6) {
      lightScore = 15;
    } else if (lightRatio >= 0.35 && lightRatio <= 0.65) {
      lightScore = 11;
    } else {
      lightScore = 6;
    }

    return Math.min(100, durationScore + deepScore + remScore + lightScore);
  }

  // 按某天所有睡眠段聚合计算评分（多段睡眠：总时长+按比例加权分期，跨天归属按醒来日期）
  calcAggregatedScore(records: DbRow[]): number {
    let totalMin: number = 0;
    let deepMin: number = 0;
    let lightMin: number = 0;
    let remMin: number = 0;
    for (const r of records) {
      totalMin += Number(r.total_minutes) || 0;
      deepMin += Number(r.deep_sleep_min) || 0;
      lightMin += Number(r.light_sleep_min) || 0;
      remMin += Number(r.rem_min) || 0;
    }
    if (totalMin <= 0) {
      return 0;
    }
    const deepRatio: number = totalMin > 0 ? deepMin / totalMin : 0;
    const lightRatio: number = totalMin > 0 ? lightMin / totalMin : 0;
    const remRatio: number = totalMin > 0 ? remMin / totalMin : 0;

    // 与 calcScore 相同的四维评分
    let durationScore = 0;
    if (totalMin >= 420 && totalMin <= 540) {
      durationScore = 40;
    } else if (totalMin >= 360 && totalMin <= 600) {
      durationScore = 32;
    } else if (totalMin >= 300) {
      durationScore = 24;
    } else {
      durationScore = 12;
    }

    let deepScore = 0;
    const deepDiff = Math.abs(deepRatio - 0.2);
    if (deepRatio >= 0.15 && deepRatio <= 0.25) {
      deepScore = 25;
    } else if (deepDiff <= 0.1) {
      deepScore = 18;
    } else {
      deepScore = 10;
    }

    let remScore = 0;
    const remDiff = Math.abs(remRatio - 0.22);
    if (remRatio >= 0.2 && remRatio <= 0.25) {
      remScore = 20;
    } else if (remDiff <= 0.1) {
      remScore = 14;
    } else {
      remScore = 8;
    }

    let lightScore = 0;
    if (lightRatio >= 0.45 && lightRatio <= 0.6) {
      lightScore = 15;
    } else if (lightRatio >= 0.35 && lightRatio <= 0.65) {
      lightScore = 11;
    } else {
      lightScore = 6;
    }

    return Math.min(100, durationScore + deepScore + remScore + lightScore);
  }

  // 重算某天的聚合睡眠数据（多段合并），写入 summary
  async recalcDailySleepSummary(date: string): Promise<void> {
    try {
      const rows: DbRow[] = await GlobalData.db.getSleepRecords(date, date);
      let totalMin: number = 0;
      for (const r of rows) {
        totalMin += Number(r.total_minutes) || 0;
      }
      const aggregatedScore: number = this.calcAggregatedScore(rows);
      const hours: number = Math.round(totalMin / 60 * 10) / 10;
      await GlobalData.db.updateDailySummaryField(date, 'sleep_score', aggregatedScore);
      await GlobalData.db.updateDailySummaryField(date, 'sleep_hours', hours);
      console.info('[SleepPage] recalc ' + date + ' segments=' + String(rows.length) +
        ' totalMin=' + String(totalMin) + ' score=' + String(aggregatedScore));
    } catch (err) {
      console.error('SleepPage recalcDailySleepSummary error:', JSON.stringify(err));
    }
  }

  async saveSleep(): Promise<void> {
    const startParts = this.startTime.split(':');
    const endParts = this.endTime.split(':');
    const sh = parseInt(startParts[0]) || 0;
    const sm = parseInt(startParts[1]) || 0;
    const eh = parseInt(endParts[0]) || 0;
    const em = parseInt(endParts[1]) || 0;
    const startMin = sh * 60 + sm;
    const endMin = eh * 60 + em;
    
    // 计算睡眠时长，考虑跨天和跨日期的情况
    let sleepDuration = endMin - startMin;
    
    // 如果醒来日期和入睡日期不同，需要加上天数差
    const startDateObj = new Date(this.startDate);
    const endDateObj = new Date(this.endDate);
    const daysDiff = Math.floor((endDateObj.getTime() - startDateObj.getTime()) / (24 * 60 * 60 * 1000));
    
    if (daysDiff > 0) {
      sleepDuration += daysDiff * 24 * 60;
    } else if (sleepDuration < 0) {
      sleepDuration += 24 * 60;
    }
    
    if (startMin === endMin && daysDiff === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '入睡和醒来时间不能相同' });
      return;
    }
    if (sleepDuration < 30) {
      this.getUIContext().getPromptAction().showToast({ message: '睡眠时长太短，至少半小时' });
      return;
    }
    if (sleepDuration > 18 * 60) {
      this.getUIContext().getPromptAction().showToast({ message: '睡眠时长异常，请检查时间设置' });
      return;
    }

    // 按健康睡眠比例自动估算分期：深睡20%、浅睡55%、REM25%
    const d: number = Math.round(sleepDuration * 0.2);
    const l: number = Math.round(sleepDuration * 0.55);
    const r: number = Math.round(sleepDuration * 0.25);
    this.deepMin = String(d);
    this.lightMin = String(l);
    this.remMin = String(r);

    const score = this.calcScore();
    const record: DbRow = {
      date: this.endDate, // 使用醒来日期作为记录日期
      start_time: this.startTime,
      end_time: this.endTime,
      deep_sleep_min: d,
      light_sleep_min: l,
      rem_min: r,
      total_minutes: sleepDuration,
      score: score,
    };
    const ok: boolean = await GlobalData.db.addSleepRecord(record);
    if (!ok) {
      this.getUIContext().getPromptAction().showToast({ message: '与已有睡眠记录时间重叠，无法添加' });
      return;
    }
    // 保存后按醒来日期聚合重算当天所有睡眠段（多段睡眠合并评分）
    await this.recalcDailySleepSummary(this.endDate);
    await CardDataHelper.refreshWidget(getContext(this));
    // 通知 Index 页面数据已更新
    AppStorage.setOrCreate('dataUpdateTrigger', `sleep_${Date.now()}`);
    this.showInput = false;

    // 手动保存成功后，清理未完成的入睡记录，避免同一睡眠被重复保存
    const sleepStartRecord = await GlobalData.db.getLatestSleepStartRecord();
    if (sleepStartRecord && sleepStartRecord.id) {
      await GlobalData.db.deleteSleepStartRecord(Number(sleepStartRecord.id));
    }
    this.isSleeping = false;
    this.sleepStartTime = '';

    // 重置日期为默认值
    await this.initDates();
    await this.loadData();
  }

  async saveSleepFromButtons(): Promise<void> {
    const startParts = this.startTime.split(':');
    const endParts = this.endTime.split(':');
    const sh = parseInt(startParts[0]) || 0;
    const sm = parseInt(startParts[1]) || 0;
    const eh = parseInt(endParts[0]) || 0;
    const em = parseInt(endParts[1]) || 0;
    const startMin = sh * 60 + sm;
    const endMin = eh * 60 + em;
    if (startMin === endMin) {
      this.getUIContext().getPromptAction().showToast({ message: '入睡和醒来时间不能相同' });
      return;
    }
    let sleepDuration = endMin - startMin;
    if (sleepDuration < 0) {
      sleepDuration += 24 * 60;
    }
    if (sleepDuration < 120) {
      this.getUIContext().getPromptAction().showToast({ message: '睡眠时长太短，至少2小时' });
      return;
    }
    if (sleepDuration > 18 * 60) {
      this.getUIContext().getPromptAction().showToast({ message: '睡眠时长异常，请检查时间设置' });
      return;
    }

    // 按健康睡眠比例自动估算分期：深睡20%、浅睡55%、REM25%
    const d: number = Math.round(sleepDuration * 0.2);
    const l: number = Math.round(sleepDuration * 0.55);
    const r: number = Math.round(sleepDuration * 0.25);
    this.deepMin = String(d);
    this.lightMin = String(l);
    this.remMin = String(r);

    const today = await GlobalData.getTodayDate();
    const score = this.calcScore();
    const record: DbRow = {
      date: today,
      start_time: this.startTime,
      end_time: this.endTime,
      deep_sleep_min: d,
      light_sleep_min: l,
      rem_min: r,
      total_minutes: sleepDuration,
      score: score,
    };
    const ok: boolean = await GlobalData.db.addSleepRecord(record);
    if (!ok) {
      this.getUIContext().getPromptAction().showToast({ message: '与已有睡眠记录时间重叠，无法保存' });
      return;
    }
    // 保存后按醒来日期聚合重算当天所有睡眠段
    await this.recalcDailySleepSummary(today);
    await CardDataHelper.refreshWidget(getContext(this));
    // 通知 Index 页面数据已更新
    AppStorage.setOrCreate('dataUpdateTrigger', `sleep_${Date.now()}`);
    // 删除入睡记录
    const sleepStartRecord = await GlobalData.db.getLatestSleepStartRecord();
    if (sleepStartRecord && sleepStartRecord.id) {
      await GlobalData.db.deleteSleepStartRecord(Number(sleepStartRecord.id));
    }
    
    // 取消睡眠追踪通知，发送睡眠完成通知
    NotificationService.getInstance().cancelSleepTrackingNotification();
    NotificationService.getInstance().notifySleepCompleted(sleepDuration * 60, score);
    
    // 检查睡眠目标达成
    GoalNotificationHelper.getInstance().checkSleepGoal(sleepDuration * 60).catch((err: Error) => {
      console.error('Sleep goal check error:', JSON.stringify(err));
    });
    
    // 重置睡眠状态
    this.isSleeping = false;
    this.sleepStartTime = '';
    
    this.getUIContext().getPromptAction().showToast({ message: '睡眠记录已保存！评分: ' + score });
    await this.loadData();
  }

  async deleteRecord(id: number): Promise<void> {
    // 先查出被删记录属于哪天（用于重算该天聚合）
    let deletedDate: string = '';
    for (const r of this.records) {
      if (Number(r.id) === id) {
        deletedDate = String(r.date);
        break;
      }
    }
    await GlobalData.db.deleteSleepRecord(id);
    await this.loadData();
    if (deletedDate.length > 0) {
      // 按被删记录的日期重算当天聚合（保留当天其他睡眠段）
      await this.recalcDailySleepSummary(deletedDate);
    }
    await CardDataHelper.refreshWidget(getContext(this));
    // 通知 Index 页面数据已更新
    AppStorage.setOrCreate('dataUpdateTrigger', `sleep_${Date.now()}`);
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt()).onClick(() => { this.handleBackPress(); })
        Text('睡眠分析').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
        Button('+')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width(40)
          .height(40)
          .backgroundColor('#9C27B0')
          .fontColor(Color.White)
          .borderRadius(20)
          .padding(0)
          .onClick(() => {
            this.showInput = !this.showInput;
          })
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          // 睡眠概览
          Row() {
            Column() {
              Text(String(this.avgScore)).fontSize(48).fontWeight(FontWeight.Bold).fontColor('#9C27B0')
              Text('平均睡眠评分').fontSize(13).fontColor(this.sub()).margin({ top: 4 })
            }
            Divider().vertical(true).height(70).margin({ left: 30, right: 30 })
            Column() {
              Text(this.lastRecord).fontSize(14).fontColor(this.sub())
            }
          }
          .width('100%').justifyContent(FlexAlign.Center).padding(20)

          // 睡眠记录按钮
          Row() {
            Button(this.isSleeping ? '已入睡: ' + this.sleepStartTime : '入睡')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.isSleeping ? '#666666' : '#9C27B0')
              .fontColor(Color.White)
              .borderRadius(12)
              .layoutWeight(1)
              .height(50)
              .onClick(async () => {
                if (!this.isSleeping) {
                  // 记录入睡时间
                  const now = new Date();
                  const hours = now.getHours();
                  const minutes = now.getMinutes();
                  const timeStr = (hours < 10 ? '0' + hours : hours) + ':' + (minutes < 10 ? '0' + minutes : minutes);
                  this.sleepStartTime = timeStr;
                  this.startTime = timeStr;
                  this.isSleeping = true;
                  
                  // 保存入睡记录到数据库
                  const today = await GlobalData.getTodayDate();
                  await GlobalData.db.addSleepStartRecord(today, timeStr);
                  this.getUIContext().getPromptAction().showToast({ message: '已记录入睡时间: ' + timeStr });
                  
                  // 发送睡眠开始通知和持续通知
                  NotificationService.getInstance().notifySleepStarted(timeStr);
                  NotificationService.getInstance().showSleepTrackingNotification(timeStr);
                }
              })

            Blank().width(16)

            Button('醒来记录时间')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor('#4CAF50')
              .fontColor(Color.White)
              .borderRadius(12)
              .layoutWeight(1)
              .height(50)
              .enabled(this.isSleeping)
              .opacity(this.isSleeping ? 1 : 0.5)
              .onClick(() => {
                if (this.isSleeping) {
                  // 记录醒来时间并保存
                  const now = new Date();
                  const hours = now.getHours();
                  const minutes = now.getMinutes();
                  const timeStr = (hours < 10 ? '0' + hours : hours) + ':' + (minutes < 10 ? '0' + minutes : minutes);
                  this.endTime = timeStr;
                  promptAction.showToast({ message: '已记录醒来时间: ' + timeStr });
                  // 保存睡眠记录
                  this.saveSleepFromButtons();
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })

          // 记录输入
          if (this.showInput) {
            Column() {
              Text('添加睡眠记录').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ bottom: 12 })

              Row() {
                Text('入睡日期: ').fontSize(14).fontColor(this.sub()).width(90)
                DatePicker({ selected: new Date(this.startDate) })
                  .width(160)
                  .onChange((value: DatePickerResult) => {
                    if (value.year !== undefined && value.month !== undefined && value.day !== undefined) {
                      this.startDate = `${value.year}-${String(value.month + 1).padStart(2, '0')}-${String(value.day).padStart(2, '0')}`;
                    }
                  })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Text('入睡时间: ').fontSize(14).fontColor(this.sub()).width(90)
                TimePicker({ selected: this.parseTimeToDate(this.startTime) })
                  .useMilitaryTime(true)
                  .width(160)
                  .onChange((value: TimePickerResult) => {
                    this.startTime = this.formatPickerTime(value);
                  })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Text('醒来日期: ').fontSize(14).fontColor(this.sub()).width(90)
                DatePicker({ selected: new Date(this.endDate) })
                  .width(160)
                  .onChange((value: DatePickerResult) => {
                    if (value.year !== undefined && value.month !== undefined && value.day !== undefined) {
                      this.endDate = `${value.year}-${String(value.month + 1).padStart(2, '0')}-${String(value.day).padStart(2, '0')}`;
                    }
                  })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Text('醒来时间: ').fontSize(14).fontColor(this.sub()).width(90)
                TimePicker({ selected: this.parseTimeToDate(this.endTime) })
                  .useMilitaryTime(true)
                  .width(160)
                  .onChange((value: TimePickerResult) => {
                    this.endTime = this.formatPickerTime(value);
                  })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Image($r('app.media.ic_lightbulb')).width(14).height(14).fillColor(this.sub())
                Text('深睡/浅睡/REM 将按健康睡眠比例自动估算').fontSize(12).fontColor(this.sub()).margin({ left: 4 })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Text('深睡 ≈ ').fontSize(14).fontColor(this.sub())
                Text(String(this.autoDeepMin())).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.txt())
                Text(' min').fontSize(12).fontColor(this.sub())
                Text('  浅睡 ≈ ').fontSize(14).fontColor(this.sub()).margin({ left: 8 })
                Text(String(this.autoLightMin())).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.txt())
                Text(' min').fontSize(12).fontColor(this.sub())
              }.width('100%').padding({ bottom: 4 })

              Row() {
                Text('REM ≈ ').fontSize(14).fontColor(this.sub())
                Text(String(this.autoRemMin())).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.txt())
                Text(' min').fontSize(12).fontColor(this.sub())
                Text('  总时长 ').fontSize(14).fontColor(this.sub()).margin({ left: 8 })
                Text(String(this.autoTotalMin())).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.txt())
                Text(' min').fontSize(12).fontColor(this.sub())
              }.width('100%').padding({ bottom: 8 })

              Button('保存').width('100%').backgroundColor('#9C27B0').borderRadius(12)
                .margin({ top: 8 }).onClick(() => { this.saveSleep(); })
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(16)
            .margin({ left: 16, right: 16, bottom: 16 })
          }

          // 近七天趋势图（睡眠评分）
          if (this.weekScores.length > 1) {
            Text('近七天睡眠评分趋势').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .width('100%').padding({ left: 16, bottom: 8 })
            TrendChart({
              dataPoints: this.weekScores,
              lineColor: Constants.COLOR_SLEEP,
              fillColor: '#9C27B022',
              labels: this.weekLabels
            }).height(180).padding({ left: 16, right: 16 })
          }

          // 历史记录
          Row() {
            Text('历史记录').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
            Blank()
            Text('共 ' + this.records.length + ' 条记录').fontSize(12).fontColor(this.sub())
          }
          .width('100%').padding({ left: 16, right: 16, top: 20, bottom: 8 })

          // 入睡记录（未完成）
          if (this.isSleeping) {
            Column() {
              Row() {
                Column() {
                  Row() {
                    Text('●').fontSize(12).fontColor('#9C27B0')
                    Text(' 入睡中').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#9C27B0')
                  }
                  Text(this.sleepStartTime + ' 入睡').fontSize(13).fontColor(this.sub()).margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                
                Column() {
                  Text('等待醒来').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#4CAF50')
                  Button('删除')
                    .fontSize(12)
                    .backgroundColor('#FF5722')
                    .fontColor(Color.White)
                    .height(28)
                    .padding({ left: 12, right: 12 })
                    .margin({ top: 4 })
                    .onClick(async () => {
                      await this.deleteSleepStartRecord();
                    })
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(12)
            .margin({ left: 16, right: 16, bottom: 8 })
          }

          ForEach(this.records, (record: DbRow) => {
            Column() {
              Row() {
                Column() {
                  Text(String(record.date)).fontSize(13).fontColor(this.sub())
                  Text(String(record.start_time) + ' - ' + String(record.end_time)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.txt())
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                
                Column() {
                  Text(String(record.total_minutes) + ' 分钟').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#9C27B0')
                  Text('评分 ' + String(record.score)).fontSize(13).fontColor(this.sub())
                }
                .alignItems(HorizontalAlign.End)
                
                Button('删除')
                  .fontSize(12)
                  .backgroundColor('#FF5722')
                  .fontColor(Color.White)
                  .height(28)
                  .padding({ left: 8, right: 8 })
                  .margin({ left: 8 })
                  .onClick(() => { this.deleteRecord(Number(record.id)); })
              }
              .width('100%')
              
              // 睡眠详情
              Row() {
                Column() {
                  Text('深睡').fontSize(11).fontColor(this.sub())
                  Text(String(record.deep_sleep_min) + 'min').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.txt())
                }
                Column() {
                  Text('浅睡').fontSize(11).fontColor(this.sub())
                  Text(String(record.light_sleep_min) + 'min').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.txt())
                }
                Column() {
                  Text('REM').fontSize(11).fontColor(this.sub())
                  Text(String(record.rem_min) + 'min').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.txt())
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceEvenly)
              .margin({ top: 8 })
              .padding({ top: 8 })
              .border({ width: { top: 1 }, color: this.sub() })
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(12)
            .margin({ left: 16, right: 16, bottom: 8 })
            .transition(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: 30 }))
                .animation({
                  duration: 350,
                  curve: Curve.EaseOut
                })
            )
          })

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%').height('100%').backgroundColor(this.bg())
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .onRefreshing(() => {
        // 下拉刷新：重新加载睡眠数据
        this.loadData().then(() => {
          setTimeout(() => { this.isRefreshing = false; }, 600);
        }).catch(() => { this.isRefreshing = false; });
      })
    }
    .width('100%').height('100%')
    .backgroundColor(this.bg())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn })
      .slide(SlideEffect.Left)
  }
}
