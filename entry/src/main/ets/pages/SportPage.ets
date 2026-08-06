import { router, promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, SportTypeDef, ThemeColors, SportState } from '../common/Constants';
import { FoodRecognitionService } from '../services/FoodRecognitionService';
import { LocationTrackerService } from '../services/LocationTrackerService';
import { CardDataHelper } from '../services/CardDataHelper';
import { NotificationService, NOTIFICATION_ID } from '../services/NotificationService';
import { GoalNotificationHelper } from '../services/GoalNotificationHelper';
import { BackgroundTaskService } from '../services/BackgroundTaskService';

@Entry
@Component
struct SportPage {
  @State currentSport: string = 'walk';
  @State durationSec: number = 0;
  @State distanceKm: number = 0;
  @State isTracking: boolean = false;
  @State isPaused: boolean = false;
  @State timerId: number = -1;
  @State calorieBurn: number = 0;
  @State heartRateAvg: number = 0;
  @State records: DbRow[] = [];
  @State isRefreshing: boolean = false; // 下拉刷新状态
  @State bodyWeight: number = 70;
  @State intensity: string = '中强度';
  @State showManualAdd: boolean = false;
  @State manualMin: string = '30';
  @State manualKm: string = '';
  @State manualSport: string = 'walk';
  @State isCalcCalories: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State useGps: boolean = false;
  @State gpsStatus: string = '';
  @State isBackgroundTracking: boolean = false; // 是否在后台继续计时
  private backgroundGpsSaveTimerId: number = -1; // 后台GPS保存定时器
  private sportStartTimestamp: number = 0; // 运动开始时间戳（用于准确计算后台时长）

  aboutToAppear(): void {
    this.loadWeight();
    this.loadHistory();
    this.checkAndRestoreSportState();
  }

  // 处理返回逻辑（左上角返回按钮和系统返回键共用）
  handleBackPress(): void {
    console.info('[SportPage] handleBackPress, isTracking:', this.isTracking, 'isBackgroundTracking:', this.isBackgroundTracking);
    
    // 如果正在运动中，弹出对话框询问
    if (this.isTracking && !this.isPaused && this.durationSec > 0) {
      this.getUIContext().getPromptAction().showDialog({
        title: '运动进行中',
        message: `当前运动已进行${this.formatDuration(this.durationSec)}，请选择：`,
        buttons: [
          { text: '暂停并退出', color: '#666666' },
          { text: '停止并保存', color: '#FF5737' },
          { text: '后台继续', color: '#007DFF' }
        ]
      }).then(async (result) => {
        console.info('[SportPage] 用户选择:', result.index);
        if (result.index === 2) {
          // 后台继续：保存状态，显示后台追踪通知，返回主页
          this.isBackgroundTracking = true;
          // 启动后台长时任务（location 模式），保持 GPS 后台持续定位
          const bgOk: boolean = await BackgroundTaskService.getInstance().startBackgroundTask('SportTracking');
          console.info('[SportPage] 后台长时任务启动: ' + String(bgOk));
          // 显示后台追踪通知
          const sportName = this.getSportName(this.currentSport);
          await NotificationService.getInstance().showSportTrackingNotification(sportName, this.durationSec, this.distanceKm);
          await this.saveCurrentSportState();
          router.back();
        } else if (result.index === 1) {
          // 停止并保存：停止计时器，保存状态，返回主页
          this.isBackgroundTracking = false;
          await BackgroundTaskService.getInstance().stopBackgroundTask();
          await this.saveCurrentSportState();
          this.stopTracking();
          router.back();
        } else {
          // 暂停并退出：暂停运动，保存状态，返回主页
          this.isBackgroundTracking = false;
          await BackgroundTaskService.getInstance().stopBackgroundTask();
          this.pauseTracking(); // 暂停运动
          await this.saveCurrentSportState(); // 保存状态（下次可继续）
          router.back();
        }
      }).catch((error: Error) => {
        console.error('[SportPage] 对话框错误:', error);
      });
    } else {
      // 没有正在进行的运动，直接返回
      router.back();
    }
  }

  // 拦截系统返回键
  onBackPress(): boolean {
    // 如果正在运动中，调用处理方法并拦截返回键
    if (this.isTracking && !this.isPaused && this.durationSec > 0) {
      this.handleBackPress();
      return true; // 拦截返回键
    }
    // 没有正在进行的运动，正常返回
    return false;
  }

  // 检查并恢复运动状态
  async checkAndRestoreSportState(): Promise<void> {
    console.info('[SportPage] 检查是否有保存的运动状态...');
    const hasState = await this.restoreSportState();
    console.info('[SportPage] 检查结果:', hasState, '当前运动:', this.currentSport, '时长:', this.durationSec);
    if (hasState) {
      // 如果是后台继续模式，自动继续计时
      if (this.isBackgroundTracking) {
        console.info('[SportPage] 后台继续模式，自动恢复计时');
        this.isTracking = true;
        // 已回到前台，停止后台长时任务
        BackgroundTaskService.getInstance().stopBackgroundTask();
        this.startTimer();
        // 停止后台GPS保存（已返回前台）
        this.stopBackgroundGpsSave();
        // 取消后台追踪通知，显示正常追踪通知
        const sportName = this.getSportName(this.currentSport);
        NotificationService.getInstance().cancelSportTrackingNotification();
        NotificationService.getInstance().showSportTrackingNotification(sportName, this.durationSec, this.distanceKm);
        this.getUIContext().getPromptAction().showToast({ 
          message: `已恢复${this.getSportName(this.currentSport)}运动，继续计时`, 
          duration: 2000 
        });
        return;
      }
      
      // 提示用户是否继续之前的运动
      const wasPaused = this.isPaused; // 记录之前的暂停状态
      const statusText = wasPaused ? '（已暂停）' : '';
      this.getUIContext().getPromptAction().showDialog({
        title: '发现未完成的运动',
        message: `检测到之前的${this.getSportName(this.currentSport)}运动${statusText}（已进行${this.formatDuration(this.durationSec)}），是否继续？`,
        buttons: [
          { text: '放弃', color: '#FF5737' },
          { text: '继续', color: '#007DFF' }
        ]
      }).then(async (result) => {
        console.info('[SportPage] 用户选择:', result.index);
        if (result.index === 1) {
          // 用户选择继续
          this.isTracking = true;
          if (wasPaused) {
            // 之前是暂停状态，恢复为暂停状态（不自动开始计时）
            this.isPaused = true;
            // 显示暂停通知
            const sportName = this.getSportName(this.currentSport);
            NotificationService.getInstance().notifySportPaused(sportName, this.durationSec, this.distanceKm);
            this.getUIContext().getPromptAction().showToast({ message: '已恢复运动状态（暂停中）', duration: 1500 });
          } else {
            // 之前不是暂停状态，开始计时
            this.isPaused = false;
            this.startTimer();
            this.getUIContext().getPromptAction().showToast({ message: '已恢复运动状态', duration: 1500 });
          }
        } else {
          // 用户选择放弃，清除保存的状态
          await this.clearSavedSportState();
          this.durationSec = 0;
          this.distanceKm = 0;
          this.calorieBurn = 0;
          this.isPaused = false;
        }
      }).catch(async (error: Error) => {
        console.error('[SportPage] 对话框错误:', error);
        // 出错时清除状态
        await this.clearSavedSportState();
      });
    }
  }

  // 获取运动名称
  getSportName(sportType: string): string {
    const sportNames: Record<string, string> = {
      'walk': '步行',
      'run': '跑步',
      'cycle': '骑行',
      'swim': '游泳',
      'yoga': '瑜伽',
      'plank': '平板支撑',
      'jump': '跳绳',
      'situp': '仰卧起坐',
      'pushup': '俯卧撑'
    };
    return sportNames[sportType] || sportType;
  }

  // 判断是否为 GPS 运动（有位移的运动）
  isGpsSport(): boolean {
    return Constants.GPS_SPORTS.has(this.currentSport);
  }

  // 判断是否为原地运动
  isStationarySport(): boolean {
    return Constants.STATIONARY_SPORTS.has(this.currentSport);
  }

  async loadWeight(): Promise<void> {
    try {
      // 优先从体重记录表读取最新体重（与体重页数据源一致）
      const latestWeight = await GlobalData.db.getLatestWeight();
      if (latestWeight && Number(latestWeight.weight_kg) > 0) {
        this.bodyWeight = Number(latestWeight.weight_kg);
        return;
      }
      // 无记录时回退到 prefs 配置的体重
      const config = await GlobalData.prefs.getGoalConfig();
      if (config.weightKg > 0) {
        this.bodyWeight = config.weightKg;
      }
    } catch (err) {
      console.error('SportPage loadWeight error:', JSON.stringify(err));
    }
  }

  aboutToDisappear(): void {
    console.info('[SportPage] aboutToDisappear, isTracking:', this.isTracking, 
      'isBackgroundTracking:', this.isBackgroundTracking, 'isPaused:', this.isPaused, 'durationSec:', this.durationSec);
    
    // 如果已暂停，停止计时器并保存状态
    if (this.isPaused) {
      console.info('[SportPage] 运动已暂停，停止计时器并保存状态');
      if (this.timerId !== -1) {
        clearInterval(this.timerId);
        this.timerId = -1;
      }
      if (this.useGps) {
        LocationTrackerService.getInstance().stop();
        this.useGps = false;
        this.gpsStatus = '';
      }
      this.saveCurrentSportState();
      return;
    }
    
    // 如果是后台继续模式，停止计时器但保存状态（页面销毁后计时器无法运行）
    if (this.isBackgroundTracking) {
      console.info('[SportPage] 后台继续模式，停止计时器并保存状态');
      // 停止计时器（页面销毁后计时器回调无法执行）
      if (this.timerId !== -1) {
        clearInterval(this.timerId);
        this.timerId = -1;
      }
      // GPS保持运行（后台定位权限已配置）
      if (this.useGps) {
        console.info('[SportPage] GPS将在后台继续运行');
      }
      // 后台期间每10秒刷新追踪通知 + 保存状态（GPS/非GPS 都启动，保证通知实时更新）
      this.startBackgroundGpsSave();
      // 保存当前状态
      this.saveCurrentSportState();
      return;
    }
    
    // 如果正在运动中，保存当前状态
    if (this.isTracking && !this.isPaused && this.durationSec > 0) {
      // 先停止计时器和GPS，但不清除保存的状态
      if (this.timerId !== -1) {
        clearInterval(this.timerId);
        this.timerId = -1;
      }
      if (this.useGps) {
        LocationTrackerService.getInstance().stop();
        this.useGps = false;
        this.gpsStatus = '';
      }
      // 保存运动状态
      this.saveCurrentSportState();
    } else {
      this.stopTracking();
    }
  }

  // 保存当前运动状态
  async saveCurrentSportState(): Promise<void> {
    try {
      const sportState: SportState = {
        currentSport: this.currentSport,
        durationSec: this.durationSec,
        distanceKm: this.distanceKm,
        calorieBurn: this.calorieBurn,
        heartRateAvg: this.heartRateAvg,
        intensity: this.intensity,
        startTime: Date.now() - this.durationSec * 1000, // 计算开始时间
        savedAt: Date.now(),
        isBackground: this.isBackgroundTracking, // 保存后台继续标志
        startTimestamp: this.sportStartTimestamp, // 保存运动开始时间戳
        isPaused: this.isPaused // 保存暂停状态
      };
      await GlobalData.prefs.put('ongoing_sport_state', JSON.stringify(sportState));
      await GlobalData.prefs.flush();
      console.info('[SportPage] 运动状态已保存:', JSON.stringify(sportState));
      // 显示保存成功提示
      let message = '运动状态已保存';
      if (this.isBackgroundTracking) {
        message = '运动将在后台继续计时';
      } else if (this.isPaused) {
        message = '运动已暂停，下次进入可继续';
      }
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 2000
      });
    } catch (error) {
      console.error('[SportPage] 保存运动状态失败:', error);
    }
  }

  // 恢复运动状态
  async restoreSportState(): Promise<boolean> {
    try {
      console.info('[SportPage] 尝试读取保存的运动状态...');
      const stateStr = await GlobalData.prefs.get('ongoing_sport_state', '');
      console.info('[SportPage] 读取到的状态:', stateStr);
      if (!stateStr || stateStr === '') {
        console.info('[SportPage] 没有保存的运动状态');
        return false;
      }

      const sportState: SportState = JSON.parse(String(stateStr)) as SportState;
      const savedAt: number = sportState.savedAt || 0;
      const timeDiff: number = Date.now() - savedAt;

      console.info('[SportPage] 保存时间:', savedAt, '时间差:', timeDiff, 'ms');
      // 如果保存时间超过2小时，视为过期，不恢复
      if (timeDiff > 2 * 60 * 60 * 1000) {
        console.info('[SportPage] 运动状态已过期，清除');
        await GlobalData.prefs.delete('ongoing_sport_state');
        return false;
      }

      // 恢复运动状态
      this.currentSport = sportState.currentSport || 'walk';
      this.distanceKm = sportState.distanceKm || 0;
      this.calorieBurn = sportState.calorieBurn || 0;
      this.heartRateAvg = sportState.heartRateAvg || 0;
      this.intensity = sportState.intensity || '中强度';
      this.isBackgroundTracking = sportState.isBackground || false;
      // ✅ 恢复暂停状态（如果不是后台继续模式）
      if (!this.isBackgroundTracking) {
        this.isPaused = sportState.isPaused || false;
      }

      // ✅ 关键修复：使用 startTimestamp 计算总时长（避免后台期间频繁保存导致的计时错误）
      if (sportState.startTimestamp && sportState.startTimestamp > 0) {
        // 使用运动开始时间戳计算总时长（推荐方式）
        const now = Date.now();
        this.durationSec = Math.floor((now - sportState.startTimestamp) / 1000);
        this.sportStartTimestamp = sportState.startTimestamp; // 恢复开始时间戳
        console.info('[SportPage] 使用startTimestamp计算总时长:', this.durationSec, '秒');
        
        // 如果是GPS运动，尝试从LocationTrackerService获取最新距离
        if (this.isGpsSport()) {
          const tracker = LocationTrackerService.getInstance();
          if (tracker.isTracking()) {
            // GPS仍在运行，获取最新距离
            const distance = tracker.getDistanceM();
            this.distanceKm = parseFloat((distance / 1000).toFixed(2));
            console.info('[SportPage] 从GPS服务获取最新距离:', this.distanceKm, 'km');
          } else {
            // GPS已停止（不应该发生），使用估算
            const speed = Constants.SPEED_KMH.get(this.currentSport) ?? 5;
            const backgroundDistance = (this.durationSec - sportState.durationSec) / 3600 * speed;
            this.distanceKm = parseFloat((sportState.distanceKm + backgroundDistance).toFixed(2));
            console.info('[SportPage] GPS已停止，估算后台运行距离:', backgroundDistance, 'km，总距离:', this.distanceKm, 'km');
          }
        }
        
        // 重新计算热量
        this.updateMetrics();
      } else if (sportState.isBackground && timeDiff > 0) {
        // 旧版本逻辑：使用 savedAt 计算后台时长（兼容旧版本保存的状态）
        const backgroundDuration = Math.floor(timeDiff / 1000); // 后台运行时长（秒）
        this.durationSec = sportState.durationSec + backgroundDuration; // 总时长 = 保存时时长 + 后台运行时长
        console.info('[SportPage] 后台继续模式（旧版本），计算后台运行时长:', backgroundDuration, '秒，总时长:', this.durationSec, '秒');
        
        // 重新计算热量
        this.updateMetrics();
      } else {
        // 非后台模式，直接恢复
        this.durationSec = sportState.durationSec || 0;
        this.sportStartTimestamp = Date.now() - this.durationSec * 1000; // 计算开始时间戳
      }

      console.info('[SportPage] 运动状态已恢复:', this.currentSport, this.durationSec, '秒', 
        'isBackground:', this.isBackgroundTracking);
      return true;
    } catch (error) {
      console.error('[SportPage] 恢复运动状态失败:', error);
      return false;
    }
  }

  // 清除保存的运动状态
  async clearSavedSportState(): Promise<void> {
    try {
      await GlobalData.prefs.delete('ongoing_sport_state');
    } catch (error) {
      console.error('Failed to clear sport state:', error);
    }
  }

  async deleteRecord(id: number): Promise<void> {
    await GlobalData.db.deleteSportRecord(id);
    await this.recalcDailySportSummary();
    await this.loadHistory();
  }

  async recalcDailySportSummary(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const end = new Date();
      const start = new Date(end.getTime() - 1 * 24 * 60 * 60 * 1000);
      const rows = await GlobalData.db.getSportRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      let totalMin: number = 0;
      let totalCal: number = 0;
      for (const r of rows) {
        if (String(r.date) === today) {
          totalMin += Number(r.duration_min) || 0;
          totalCal += Number(r.calories) || 0;
        }
      }
      await GlobalData.db.updateDailySummaryField(today, 'exercise_minutes', totalMin);
      await GlobalData.db.updateDailySummaryField(today, 'calories_burned', totalCal);
      await CardDataHelper.refreshWidget(getContext(this));
      // 通知 Index 页面数据已更新
      AppStorage.setOrCreate('dataUpdateTrigger', `sport_${Date.now()}`);
    } catch (err) {
      console.error('SportPage recalcDailySportSummary error:', JSON.stringify(err));
    }
  }

  async loadHistory(): Promise<void> {
    try {
      const end = new Date();
      const start = new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
      const rows = await GlobalData.db.getSportRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.records = rows;
    } catch (err) {
      console.error('SportPage loadData error:', JSON.stringify(err));
    }
  }

  startTracking(): void {
    this.isTracking = true;
    this.isPaused = false;
    this.durationSec = 0;
    this.distanceKm = 0;
    this.calorieBurn = 0;
    this.sportStartTimestamp = Date.now(); // 记录运动开始时间
    const met: number = Constants.MET_VALUES.get(this.currentSport) ?? 4.0;
    const maxHr: number = Constants.MAX_HR;
    const restHr: number = Constants.REST_HR;
    this.heartRateAvg = Math.min(maxHr, restHr + Math.round(met * 8));
    if (this.isGpsSport()) {
      const tracker = LocationTrackerService.getInstance();
      tracker.reset();
      tracker.onDistanceChanged((distanceM: number) => {
        this.distanceKm = parseFloat((distanceM / 1000).toFixed(2));
      });
      const success = tracker.start();
      this.useGps = true;
      if (success) {
        this.gpsStatus = '正在定位...';
        setTimeout(() => {
          if (this.isTracking && this.useGps) {
            this.gpsStatus = tracker.getPointCount() > 0 ? 'GPS 定位中' : '未获取到定位，正在重试';
          }
        }, 5000);
      } else {
        const errCode: number = tracker.getLastErrorCode();
        if (errCode === 3301100) {
          // 系统位置开关关闭
          this.gpsStatus = '系统位置开关未开启';
          this.getUIContext().getPromptAction().showToast({
            message: '请开启系统"位置"开关后再试', duration: 2500
          });
        } else {
          this.gpsStatus = '定位启动失败';
          this.getUIContext().getPromptAction().showToast({ message: 'GPS定位启动失败，请检查权限', duration: 2000 });
        }
      }
    } else {
      this.useGps = false;
      this.gpsStatus = '';
    }
    this.startTimer();
    
    // 发送运动开始通知（应用内计时只发开始通知，不发持续通知）
    const sportName: string = this.getSportName(this.currentSport);
    NotificationService.getInstance().notifySportStarted(sportName);
  }

  // 重新定位：定位失效后手动重启 GPS
  async restartLocation(): Promise<void> {
    if (!this.useGps) {
      return;
    }
    const tracker = LocationTrackerService.getInstance();
    this.gpsStatus = '正在重新定位...';
    console.info('[SportPage] 开始重定位...');
    
    // 重置并重启定位
    tracker.stop();
    await new Promise<void>((resolve) => {
      setTimeout(() => { resolve(); }, 500); // 增加等待时间到500ms
    });
    tracker.reset();
    tracker.onDistanceChanged((distanceM: number) => {
      this.distanceKm = parseFloat((distanceM / 1000).toFixed(2));
    });
    
    // ✅ 检查定位是否成功启动
    const success = tracker.start();
    if (!success) {
      console.error('[SportPage] 重定位失败：启动定位失败');
      this.gpsStatus = '定位启动失败，请检查权限';
      this.getUIContext().getPromptAction().showToast({ message: '定位启动失败，请检查权限设置', duration: 2000 });
      return;
    }
    
    console.info('[SportPage] 定位已重新启动，等待定位结果...');
    // 5秒后检查定位结果
    setTimeout(() => {
      if (this.isTracking && this.useGps) {
        const pointCount = tracker.getPointCount();
        console.info('[SportPage] 定位点数量:', pointCount);
        if (pointCount > 0) {
          this.gpsStatus = 'GPS 定位中';
          this.getUIContext().getPromptAction().showToast({ message: '重定位成功', duration: 1500 });
        } else {
          this.gpsStatus = '未获取到定位，点击重试';
          this.getUIContext().getPromptAction().showToast({ message: '未获取到GPS信号，请到开阔地带', duration: 2000 });
        }
      }
    }, 5000);
    this.getUIContext().getPromptAction().showToast({ message: '正在重新定位...', duration: 1500 });
  }

  // 判断 GPS 是否定位失败（需要显示重定位按钮）
  gpsNeedRetry(): boolean {
    return this.useGps && this.isTracking &&
      (this.gpsStatus.includes('未获取') || this.gpsStatus.includes('重试') || this.gpsStatus.includes('信号丢失'));
  }

  pauseTracking(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.useGps) {
      LocationTrackerService.getInstance().pause();
    }
    this.isPaused = true;
    // 暂停时把开始时间戳前移到当前暂停点（抹掉暂停前的时间），
    // 避免恢复后 restoreSportState 用 now - startTimestamp 把暂停时长也算进运动时长
    this.sportStartTimestamp = Date.now() - this.durationSec * 1000;
    // 暂停时取消后台追踪状态，避免状态冲突
    this.isBackgroundTracking = false;
    
    // 取消后台追踪通知，显示暂停通知
    const sportName: string = this.getSportName(this.currentSport);
    NotificationService.getInstance().cancelSportTrackingNotification();
    NotificationService.getInstance().notifySportPaused(sportName, this.durationSec, this.distanceKm);
  }

  resumeTracking(): void {
    if (this.isTracking && this.isPaused) {
      if (this.useGps) {
        LocationTrackerService.getInstance().resume();
      }
      this.isPaused = false;
      this.startTimer();
      
      // 取消暂停通知，恢复持续通知
      const sportName: string = this.getSportName(this.currentSport);
      NotificationService.getInstance().cancel(NOTIFICATION_ID.SPORT_STATUS);
      NotificationService.getInstance().showSportTrackingNotification(sportName, this.durationSec, this.distanceKm);
    }
  }

  private startTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
    // 应用内计时不发持续通知（开始/结束通知由 start/stop 触发）
    this.timerId = setInterval(() => {
      this.durationSec++;
      this.updateMetrics();
    }, 1000);
  }

  private updateMetrics(): void {
    if (this.isGpsSport()) {
      // GPS 运动（步行、跑步、骑行）：根据距离计算热量
      if (this.distanceKm === 0) {
        // GPS 失败或未启动，根据时间估算距离
        const spd = Constants.SPEED_KMH.get(this.currentSport) ?? 5;
        this.distanceKm = parseFloat(((this.durationSec / 3600) * spd).toFixed(2));
      }
      // 热量 = 体重 × 距离 × 每公斤每公里消耗系数
      const perKgKm: number = this.getPerKgKm();
      this.calorieBurn = Math.round(this.bodyWeight * this.distanceKm * perKgKm);
    } else if (this.isStationarySport()) {
      // 原地运动（游泳、瑜伽、力量训练）：根据体重、强度和时间计算热量
      const met: number = Constants.MET_VALUES.get(this.currentSport) ?? 4.0;
      const intensityMultiplier: number = Constants.INTENSITY_MULTIPLIERS.get(this.intensity) ?? 1.0;
      const hours: number = this.durationSec / 3600;
      // 热量 = MET × 强度系数 × 体重 × 时间
      this.calorieBurn = Math.round(met * intensityMultiplier * this.bodyWeight * hours);
    } else {
      // 其他运动：使用默认 MET 公式
      const met: number = Constants.MET_VALUES.get(this.currentSport) ?? 4.0;
      const hours: number = this.durationSec / 3600;
      this.calorieBurn = Math.round(met * this.bodyWeight * hours);
    }
  }

  // 每公斤体重每公里消耗千卡（依运动类型）
  private getPerKgKm(): number {
    if (this.currentSport === 'run') { return 1.04; }
    if (this.currentSport === 'cycle') { return 0.32; }
    if (this.currentSport === 'walk') { return 0.5; }
    return 0.5;
  }

  stopTracking(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.isTracking = false;
    this.isPaused = false;
    // 停止后台长时任务（异步）
    BackgroundTaskService.getInstance().stopBackgroundTask();
    if (this.useGps) {
      LocationTrackerService.getInstance().stop();
      this.useGps = false;
      this.gpsStatus = '';
    }
    // 停止后台GPS保存
    this.stopBackgroundGpsSave();
    // 清除保存的运动状态
    this.clearSavedSportState();
    
    // 发送运动结束通知（应用内计时只发开始/结束通知；仅实际运动过才发）
    if (this.durationSec > 0) {
      const endName: string = this.getSportName(this.currentSport);
      NotificationService.getInstance().notifySportCompleted(endName, this.durationSec, this.distanceKm, this.calorieBurn);
    }
    // 取消持续通知（若有）
    NotificationService.getInstance().cancelSportTrackingNotification();
  }

  // 启动后台GPS定期保存（每10秒保存一次GPS数据）
  // 后台期间每10秒刷新状态栏追踪通知 + 保存状态
  // 距离保持 GPS onDistanceChanged 实时回调更新（高精度），此处不干预
  private startBackgroundGpsSave(): void {
    if (this.backgroundGpsSaveTimerId !== -1) {
      clearInterval(this.backgroundGpsSaveTimerId);
    }
    this.backgroundGpsSaveTimerId = setInterval(() => {
      // 用运动开始时间戳实时计算时长（不受页面销毁/计时器停摆影响）
      if (this.sportStartTimestamp > 0) {
        this.durationSec = Math.floor((Date.now() - this.sportStartTimestamp) / 1000);
      }
      // 非GPS运动（原地运动）距离保持 0；GPS 运动距离由 onDistanceChanged 实时更新
      // 更新热量（基于最新时长和距离）
      this.updateMetrics();
      // 刷新状态栏追踪通知（10秒一次，展示最新时长/距离）
      const sportName: string = this.getSportName(this.currentSport);
      NotificationService.getInstance().updateSportTrackingNotification(sportName, this.durationSec, this.distanceKm);
      // 保存状态
      this.saveCurrentSportState();
    }, 10000); // 每10秒刷新一次
  }

  // 停止后台GPS保存
  private stopBackgroundGpsSave(): void {
    if (this.backgroundGpsSaveTimerId !== -1) {
      clearInterval(this.backgroundGpsSaveTimerId);
      this.backgroundGpsSaveTimerId = -1;
    }
  }

  adjustTime(deltaSec: number): void {
    let newVal: number = this.durationSec + deltaSec;
    if (newVal < 0) {
      newVal = 0;
    }
    this.durationSec = newVal;
    this.updateMetrics();
  }

  async saveSportRecord(): Promise<void> {
    if (this.durationSec < 60) {
      this.getUIContext().getPromptAction().showToast({ message: '运动时间太短，至少需要60秒' });
      return;
    }
    const minutes: number = Math.max(1, Math.round(this.durationSec / 60));
    let calories: number = this.calorieBurn;
    this.isCalcCalories = true;
    const cloud = await FoodRecognitionService.getInstance().calculateSportCalories(
      this.getSportLabel(this.currentSport), minutes, this.intensity, this.bodyWeight, this.distanceKm
    );
    this.isCalcCalories = false;
    if (cloud >= 0) {
      calories = cloud;
    }
    const today = await GlobalData.getTodayDate();
    const record: DbRow = {
      date: today,
      sport_type: this.currentSport,
      duration_min: minutes,
      distance_km: this.distanceKm,
      calories: calories,
      avg_heart_rate: this.heartRateAvg,
    };
    await GlobalData.db.addSportRecord(record);
    await this.saveDailySummarySport(today, minutes, calories);
    this.stopTracking();
    await this.loadHistory();
    this.getUIContext().getPromptAction().showToast({ message: '运动记录已保存' });
    
    // 发送运动完成通知
    const sportName: string = this.getSportName(this.currentSport);
    NotificationService.getInstance().notifySportCompleted(sportName, this.durationSec, this.distanceKm, calories);
    
    // 检查运动目标达成（本周运动天数）
    const now: Date = new Date();
    const dayOfWeek: number = now.getDay(); // 0=周日, 1=周一...
    const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const monday: Date = new Date(now);
    monday.setDate(now.getDate() - mondayOffset);
    monday.setHours(0, 0, 0, 0);
    const sunday: Date = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    sunday.setHours(23, 59, 59, 999);
    const startDate: string = monday.toISOString().split('T')[0];
    const endDate: string = sunday.toISOString().split('T')[0];
    const weekRecords: DbRow[] = await GlobalData.db.getSportRecords(startDate, endDate);
    const uniqueDays: Set<string> = new Set();
    for (const rec of weekRecords) {
      if (rec.date) {
        uniqueDays.add(String(rec.date));
      }
    }
    GoalNotificationHelper.getInstance().checkSportGoal(uniqueDays.size).catch((err: Error) => {
      console.error('Sport goal check error:', JSON.stringify(err));
    });
  }

  async saveManualRecord(): Promise<void> {
    const minVal = parseFloat(this.manualMin);
    if (isNaN(minVal) || minVal <= 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请输入有效的运动时长' });
      return;
    }
    const minutes: number = Math.round(minVal);
    let distKm: number = 0;
    const kmVal = parseFloat(this.manualKm);
    if (!isNaN(kmVal) && kmVal > 0) {
      distKm = kmVal;
    }
    // 本地兜底估算：根据运动类型选择不同的计算方法
    let calories: number = 0;
    const hours: number = minutes / 60;
    
    if (Constants.GPS_SPORTS.has(this.manualSport)) {
      // GPS 运动：根据距离计算热量
      if (distKm === 0) {
        // 没有输入距离，根据时间估算
        const spd = Constants.SPEED_KMH.get(this.manualSport) ?? 5;
        distKm = parseFloat((hours * spd).toFixed(2));
      }
      const perKgKm: number = this.getPerKgKmFor(this.manualSport);
      calories = Math.round(this.bodyWeight * distKm * perKgKm);
    } else if (Constants.STATIONARY_SPORTS.has(this.manualSport)) {
      // 原地运动：根据体重、强度和时间计算热量
      const met: number = Constants.MET_VALUES.get(this.manualSport) ?? 4.0;
      const intensityMultiplier: number = Constants.INTENSITY_MULTIPLIERS.get(this.intensity) ?? 1.0;
      calories = Math.round(met * intensityMultiplier * this.bodyWeight * hours);
    } else {
      // 其他运动：使用默认 MET 公式
      const met: number = Constants.MET_VALUES.get(this.manualSport) ?? 4.0;
      calories = Math.round(met * this.bodyWeight * hours);
    }
    this.isCalcCalories = true;
    const cloud = await FoodRecognitionService.getInstance().calculateSportCalories(
      this.getSportLabel(this.manualSport), minutes, this.intensity, this.bodyWeight, distKm
    );
    this.isCalcCalories = false;
    if (cloud >= 0) {
      calories = cloud;
    }
    const today = await GlobalData.getTodayDate();
    const record: DbRow = {
      date: today,
      sport_type: this.manualSport,
      duration_min: minutes,
      distance_km: distKm,
      calories: calories,
      avg_heart_rate: this.heartRateAvg,
    };
    await GlobalData.db.addSportRecord(record);
    await this.saveDailySummarySport(today, minutes, calories);
    await this.loadHistory();
    this.showManualAdd = false;
    this.getUIContext().getPromptAction().showToast({ message: '手动记录已保存' });
  }

  private getPerKgKmFor(sport: string): number {
    if (sport === 'run') { return 1.04; }
    if (sport === 'cycle') { return 0.32; }
    return 0.5;
  }

  async saveDailySummarySport(date: string, minutes: number, calories: number): Promise<void> {
    try {
      const summary = await GlobalData.db.getDailySummary(date);
      const prevMin: number = summary ? Number(summary.exercise_minutes) || 0 : 0;
      const prevCal: number = summary ? Number(summary.calories_burned) || 0 : 0;
      await GlobalData.db.updateDailySummaryField(date, 'exercise_minutes', prevMin + minutes);
      await GlobalData.db.updateDailySummaryField(date, 'calories_burned', prevCal + calories);
      await CardDataHelper.refreshWidget(getContext(this));
    } catch (err) {
      console.error('SportPage saveDailySummary error:', JSON.stringify(err));
    }
  }

  formatDuration(sec: number): string {
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = sec % 60;
    if (h > 0) {
      return String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
    }
    return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
  }

  getSportLabel(value: string): string {
    const found = Constants.SPORT_TYPES.find((s: SportTypeDef) => s.value === value);
    return found ? found.label : value;
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt())
          .accessibilityText('返回上一页')
          .accessibilityLevel('important')
          .onClick(() => { this.handleBackPress(); })
        Text('运动记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
        Text('＋ 手动添加').fontSize(14).fontColor('#FF6B35')
          .onClick(() => {
            this.showManualAdd = !this.showManualAdd;
            if (this.showManualAdd) {
              this.manualSport = this.currentSport;
              this.manualKm = '';
            }
          })
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          // 手动添加记录面板
          if (this.showManualAdd) {
            Column() {
              Text('手动添加记录').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ bottom: 12 })

              Text('运动类型').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(Constants.SPORT_TYPES, (item: SportTypeDef) => {
                  Text(item.icon + ' ' + item.label)
                    .fontSize(13)
                    .fontColor(this.manualSport === item.value ? '#FFFFFF' : this.txt())
                    .backgroundColor(this.manualSport === item.value ? '#FF6B35' : ThemeColors.inputBg(this.theme))
                    .borderRadius(16).padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => { this.manualSport = item.value; })
                })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Text('运动时长 (分钟)').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              TextInput({ placeholder: '30', text: this.manualMin })
                .type(InputType.Number).width('100%').height(44)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt()).placeholderColor(this.sub())
                .onChange((v: string) => { this.manualMin = v; })
                .margin({ bottom: 10 })

              if (Constants.GPS_SPORTS.has(this.manualSport)) {
                Text('运动距离 (公里，可选)').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
                TextInput({ placeholder: '如 3.5', text: this.manualKm })
                  .type(InputType.Number).width('100%').height(44)
                  .backgroundColor(ThemeColors.inputBg(this.theme))
                  .fontColor(this.txt()).placeholderColor(this.sub())
                  .onChange((v: string) => { this.manualKm = v; })
                  .margin({ bottom: 10 })
              }

              Text('运动强度').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              Row() {
                ForEach(Constants.INTENSITIES, (item: string) => {
                  Text(item)
                    .fontSize(13)
                    .fontColor(this.intensity === item ? '#FFFFFF' : this.sub())
                    .backgroundColor(this.intensity === item ? '#FF6B35' : this.card())
                    .borderRadius(16).padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .margin({ right: 8 })
                    .onClick(() => { this.intensity = item; })
                })
              }
              .width('100%')

              if (this.isCalcCalories) {
                Text('正在云端计算热量...').fontSize(12).fontColor('#FF6B35').width('100%').margin({ top: 10 })
              }

              Button('保存记录').width('100%').height(46)
                .backgroundColor('#FF6B35').borderRadius(23)
                .margin({ top: 12 })
                .onClick(() => { this.saveManualRecord(); })
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(12)
            .margin({ left: 16, right: 16, bottom: 16 })
          }

          if (!this.isTracking) {
            Text('选择运动类型')
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .width('100%').padding({ left: 16, bottom: 8 })

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              ForEach(Constants.SPORT_TYPES, (item: SportTypeDef) => {
                Column() {
                  Text(item.icon).fontSize(28)
                  Text(item.label).fontSize(12).fontColor(this.sub()).margin({ top: 4 })
                }
                .width(64).height(64)
                .backgroundColor(this.currentSport === item.value ? '#FF6B3544' : this.card())
                .borderRadius(32)
                .border(this.currentSport === item.value ? { style: BorderStyle.Solid, width: 2, color: '#FF6B35' } : { style: BorderStyle.Dashed, width: 0, color: 'transparent' })
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .margin(6)
                .onClick(() => { this.currentSport = item.value; })
              })
            }
            .width('100%').padding({ left: 16, right: 16 })

            // 烈度选择
            Text('运动强度').fontSize(13).fontColor(this.sub())
              .width('100%').padding({ left: 16, top: 8, bottom: 4 })
            Row() {
              ForEach(Constants.INTENSITIES, (item: string) => {
                Text(item)
                  .fontSize(13)
                  .fontColor(this.intensity === item ? '#FFFFFF' : this.sub())
                  .backgroundColor(this.intensity === item ? '#FF6B35' : this.card())
                  .borderRadius(16).padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .margin({ right: 8 })
                  .onClick(() => { this.intensity = item; })
              })
            }
            .width('100%').padding({ left: 16, right: 16 })

            Button() {
              Text('▶ 开始运动').fontSize(20).fontColor(this.txt())
            }
            .width(200).height(56).backgroundColor('#FF6B35').borderRadius(28)
            .margin({ top: 20 })
            .onClick(() => { this.startTracking(); })
            if (this.isGpsSport()) {
              Text('🚶 走路/跑步/骑行将使用 GPS 记录真实路程').fontSize(11)
                .fontColor(this.sub()).margin({ top: 8 })
            }
          } else {
            Column() {
              Text(this.formatDuration(this.durationSec))
                .fontSize(56).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
              Text(this.isPaused ? '已暂停' : '运动中').fontSize(14).fontColor(this.isPaused ? '#FF9800' : this.sub())

              // 加减时间
              Row() {
                Button('-1分').fontSize(13).backgroundColor('#555555').borderRadius(16).height(36)
                  .onClick(() => { this.adjustTime(-60); })
                Button('-30秒').fontSize(13).backgroundColor('#555555').borderRadius(16).height(36).margin({ left: 8 })
                  .onClick(() => { this.adjustTime(-30); })
                Button('+30秒').fontSize(13).backgroundColor('#FF6B35').borderRadius(16).height(36).margin({ left: 8 })
                  .onClick(() => { this.adjustTime(30); })
                Button('+1分').fontSize(13).backgroundColor('#FF6B35').borderRadius(16).height(36).margin({ left: 8 })
                  .onClick(() => { this.adjustTime(60); })
              }
              .margin({ top: 8 })

              Row() {
                if (this.isGpsSport()) {
                  // GPS 运动：显示距离
                  Column() {
                    Text(this.distanceKm.toFixed(2)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                    Text(this.useGps ? '公里(GPS)' : '公里').fontSize(12).fontColor(this.sub())
                  }
                } else if (this.isStationarySport()) {
                  // 原地运动：显示强度
                  Column() {
                    Text(this.intensity.replace('强度', '')).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                    Text('运动强度').fontSize(12).fontColor(this.sub())
                  }
                } else {
                  // 其他运动：显示距离（如果有的话）
                  Column() {
                    Text(this.distanceKm.toFixed(2)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                    Text('公里').fontSize(12).fontColor(this.sub())
                  }
                }
                Divider().vertical(true).height(50).margin({ left: 24, right: 24 })
                Column() {
                  if (this.isCalcCalories) {
                    Text('...').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                  } else {
                    Text(String(this.calorieBurn)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                  }
                  Text('千卡').fontSize(12).fontColor(this.sub())
                }
                Divider().vertical(true).height(50).margin({ left: 24, right: 24 })
                Column() {
                  Text(String(this.heartRateAvg)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                  Text('bpm').fontSize(12).fontColor(this.sub())
                }
              }
              .width('100%').justifyContent(FlexAlign.Center).margin({ top: 16 })

              // 根据运动类型显示不同的热量计算提示
              if (this.isGpsSport()) {
                Text('按体重 ' + this.bodyWeight.toFixed(0) + 'kg × 路程 ' + this.distanceKm.toFixed(2) + 'km 估算')
                  .fontSize(11).fontColor(this.sub()).margin({ top: 8 })
              } else if (this.isStationarySport()) {
                Text('按体重 ' + this.bodyWeight.toFixed(0) + 'kg × ' + this.intensity + '估算')
                  .fontSize(11).fontColor(this.sub()).margin({ top: 8 })
              } else {
                Text('卡路里按体重 ' + this.bodyWeight.toFixed(0) + 'kg 估算')
                  .fontSize(11).fontColor(this.sub()).margin({ top: 8 })
              }

              if (this.useGps) {
                Row() {
                  Text('📡 ' + this.gpsStatus).fontSize(11)
                    .fontColor(this.gpsStatus.includes('定位') ? '#FF9800' : '#4CAF50')
                  if (this.gpsNeedRetry()) {
                    Button('重定位')
                      .fontSize(11)
                      .height(26)
                      .backgroundColor('#FF9800')
                      .fontColor('#FFFFFF')
                      .borderRadius(13)
                      .margin({ left: 8 })
                      .onClick(() => { this.restartLocation(); })
                  }
                }
                .margin({ top: 6 })
              }

              Row() {
                if (this.isPaused) {
                  Button('▶ 继续').width(100).height(48)
                    .backgroundColor('#4CAF50').borderRadius(24)
                    .onClick(() => { this.resumeTracking(); })
                } else {
                  Button('⏸ 暂停').width(100).height(48)
                    .backgroundColor('#FF9800').borderRadius(24)
                    .onClick(() => { this.pauseTracking(); })
                }
                Button('⏹ 结束').width(120).height(48)
                  .backgroundColor('#F44336').borderRadius(24).margin({ left: 10 })
                  .onClick(() => { this.saveSportRecord(); })
                Button('✖ 取消').width(90).height(48)
                  .backgroundColor('#555555').borderRadius(24).margin({ left: 10 })
                  .onClick(() => { this.stopTracking(); })
              }
              .margin({ top: 20 })
            }
            .width('100%').padding(24)
            .backgroundColor(this.card()).borderRadius(16)
            .margin({ left: 16, right: 16, top: 16 })
          }

          Text('运动历史').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
            .width('100%').padding({ left: 16, top: 24, bottom: 8 })

          List() {
            ForEach(this.records, (record: DbRow) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(String(record.date)).fontSize(12).fontColor(this.sub())
                    Text(this.getSportLabel(String(record.sport_type)))
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
                  }
                  .alignItems(HorizontalAlign.Start)
                  Blank()
                  Column() {
                    Text(String(record.duration_min) + 'min').fontSize(14).fontColor(this.txt())
                    Text(String(record.calories) + '千卡').fontSize(12).fontColor(this.sub())
                  }
                  .alignItems(HorizontalAlign.End)
                  Text('🗑').fontSize(16).margin({ left: 10 })
                    .onClick(() => { this.deleteRecord(Number(record.id)); })
                }
                .width('100%').padding(14)
                .backgroundColor(this.card()).borderRadius(10)
              }
            })
          }
          .width('100%').padding({ left: 16, right: 16 }).height(250)

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
      }
      .width('100%').height('100%').backgroundColor(this.bg())
      .onRefreshing(() => {
        // 下拉刷新：重新加载运动数据
        this.loadHistory().then(() => {
          this.loadWeight();
          setTimeout(() => { this.isRefreshing = false; }, 600);
        }).catch(() => { this.isRefreshing = false; });
      })
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn })
      .slide(SlideEffect.Left)
  }
}
