import { router, promptAction, window } from '@kit.ArkUI';
import { componentSnapshot } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { GlobalData } from '../common/GlobalData';
import { HealthScoreUtil } from '../services/HealthScoreUtil';
import { Constants, GoalConfig, StreakData, DbRow, ThemeColors } from '../common/Constants';
import { RingProgress } from '../components/RingProgress';
import { HealthCard } from '../components/HealthCard';
import { FoodRecognitionTab } from '../components/FoodRecognitionTab';
import { NestedRings } from '../components/NestedRings';
import { HealthTab } from '../components/HealthTab';
import { DiaryTab } from '../components/DiaryTab';
import { AccountTab } from '../components/AccountTab';
import { ChatTab } from '../components/ChatTab';
import { WeightOverlay, MoodOverlay } from '../components/OverlayDialogs';
import { SharePanel } from '../components/SharePanel';
import { NotificationService } from '../services/NotificationService';
import { AchievementHelper, AchievementInfo } from '../model/AchievementHelper';
import { AchievementDialog, AchievementListDialog } from '../components/AchievementDialog';

// 健康卡片类型定义
interface HealthCardItem {
  id: string;
  title: string;
  iconSymbol: string;
  iconColor: string;
}

// 快捷功能类型定义
interface QuickFunctionItem {
  id: string;
  icon: string;
  iconName: string; // SVG图标名称
  label: string;
  page: string;
}

@Entry
@Component
struct Index {
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @StorageLink('cardTarget') @Watch('onCardTarget') cardTarget: string = '';
  @StorageLink('appForegroundDate') @Watch('onForegroundDateChange') appForegroundDate: string = '';
  @StorageLink('dataUpdateTrigger') @Watch('onDataUpdate') dataUpdateTrigger: string = ''; // 数据更新通知
  @State showSharePanel: boolean = false;
  @State shareDiet: boolean = true;
  @State shareSport: boolean = true;
  @State shareSleep: boolean = true;
  @State shareMood: boolean = true;
  @State shareOverview: boolean = true;
  @State isGeneratingShare: boolean = false;
  @StorageLink('currentTheme') @Watch('onThemeChange') theme: string = 'dark';
  @State moveProgress: number = 0;
  @State exerciseProgress: number = 0;
  @State moodProgress: number = 0;
  @State moveCal: number = 0;
  @State exerciseMin: number = 0;
  @State moodValue: number = 0;
  @State ringDisplayMode: boolean = false; // false: 三个独立圆环, true: 嵌套圆环

  @State stepCount: number = 0;
  @State stepGoal: number = 8000;
  @State heartRate: number = 0;
  @State todayCalorieIntake: number = 0; // 今日摄入热量
  @State recommendCalorie: number = 2000; // 体重页计算的推荐热量
  @StorageLink('liveSteps') liveSteps: number = 0;
  @StorageLink('bandHeartRate') bandHeartRate: number = 0;
  @StorageLink('inAppAlarm') @Watch('onInAppAlarm') inAppAlarm: string = '';
  @State sleepScore: number = 0;
  @State sleepHours: string = '0';
  @State waterMl: number = 0;
  @State waterGoal: number = 2000;
  @State weightKg: string = '--';
  @State userName: string = '';
  @State greeting: string = '';
  @State streakCurrent: number = 0;
  @State streakBest: number = 0;
  @State makeupDaysCount: number = 0; // 补录天数数量
  @State currentTabIndex: number = 0;
  @State isLoggedIn: boolean = false;
  @State diaryDietRecords: DbRow[] = [];
  @State diarySportRecords: DbRow[] = [];
  @State diarySleepRecords: DbRow[] = [];
  @State diaryMoodRecords: DbRow[] = [];
  @State diaryDate: string = '';
  @State bgColor: string = '#121212';
  @State cardColor: string = '#1E1E2E';
  @State textColor: string = '#FFFFFF';
  @State subTextColor: string = '#AAAAAA';
  readonly accentColor: string = '#FF6B35';
  @State showWeightOverlay: boolean = false;
  @State showMoodOverlay: boolean = false;
  private moodPromptPending: boolean = false;
  private pendingMoodDate: string = '';
  private lastMoodCheckDate: string = '';
  @State overlayHeightInput: string = '170';
  @State overlayWeightInput: string = '70';
  @State overlayGender: string = '男';
  @State overlaySkipNext: boolean = false;
  readonly overlayGenders: string[] = ['男', '女'];
  @State overlayMood: number = 3;
  @State overlayMoodNote: string = '';
  @State overlayMoodDate: string = '';

  // 成就系统相关
  @State showAchievementDialog: boolean = false;
  @State showAchievementListDialog: boolean = false;
  @State currentAchievement: AchievementInfo | null = null;
  @State allAchievements: AchievementInfo[] = [];
  private achievementHelper: AchievementHelper = new AchievementHelper(GlobalData.prefs);

  // 今日概览卡片拖拽排序相关
  @State healthCardOrder: string[] = ['steps', 'calorie', 'sleep', 'water']; // 卡片顺序

  // 快捷功能拖拽排序相关
  @State quickFunctionOrder: string[] = ['sport', 'weight', 'report', 'goal', 'diet', 'women', 'medication', 'mood']; // 快捷功能顺序

  // 卡片配置数据
  private healthCardConfigs: HealthCardItem[] = [
    { id: 'steps', title: '步数', iconSymbol: 'ic_steps', iconColor: Constants.COLOR_STEP },
    { id: 'calorie', title: '热量', iconSymbol: 'ic_calorie', iconColor: Constants.COLOR_DIET },
    { id: 'sleep', title: '睡眠', iconSymbol: 'ic_sleep', iconColor: Constants.COLOR_SLEEP },
    { id: 'water', title: '喝水', iconSymbol: 'ic_water', iconColor: Constants.COLOR_WATER }
  ];

  // 快捷功能配置数据
  private quickFunctionConfigs: QuickFunctionItem[] = [
    { id: 'sport', icon: '🏃', iconName: 'ic_sport', label: '运动', page: Constants.PAGE_SPORT },
    { id: 'weight', icon: '⚖️', iconName: 'ic_weight', label: '体重', page: Constants.PAGE_WEIGHT },
    { id: 'report', icon: '📊', iconName: 'ic_report', label: '周报', page: Constants.PAGE_REPORT },
    { id: 'goal', icon: '🎯', iconName: 'ic_goal', label: '目标', page: Constants.PAGE_GOAL },
    { id: 'diet', icon: '🍎', iconName: 'ic_diet', label: '饮食', page: Constants.PAGE_DIET },
    { id: 'women', icon: '🌸', iconName: 'ic_women', label: '健康', page: Constants.PAGE_WOMEN },
    { id: 'medication', icon: '💊', iconName: 'ic_medication', label: '用药', page: Constants.PAGE_MEDICATION },
    { id: 'mood', icon: '😊', iconName: 'ic_mood', label: '情绪', page: Constants.PAGE_MOOD }
  ];

  updateThemeColors(): void {
    this.bgColor = ThemeColors.bg(this.theme);
    this.cardColor = ThemeColors.card(this.theme);
    this.textColor = ThemeColors.text(this.theme);
    this.subTextColor = ThemeColors.subText(this.theme);
  }

  aboutToAppear(): void {
    this.loadAllData();
    this.startAutoRefresh();
    this.checkWeightPrompt();
    this.checkMoodPrompt();
    this.loadHealthCardOrder(); // 加载卡片顺序
    this.loadQuickFunctionOrder(); // 加载快捷功能顺序
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
  }

  // 加载卡片顺序
  async loadHealthCardOrder(): Promise<void> {
    try {
      const savedOrder = await GlobalData.prefs.getHealthCardOrder();
      if (savedOrder && savedOrder.length === 4) {
        this.healthCardOrder = savedOrder;
      }
    } catch (err) {
      console.error('loadHealthCardOrder error:', JSON.stringify(err));
    }
  }

  // 保存卡片顺序
  async saveHealthCardOrder(): Promise<void> {
    try {
      await GlobalData.prefs.setHealthCardOrder(this.healthCardOrder);
    } catch (err) {
      console.error('saveHealthCardOrder error:', JSON.stringify(err));
    }
  }

  // 加载快捷功能顺序
  async loadQuickFunctionOrder(): Promise<void> {
    try {
      const savedOrder = await GlobalData.prefs.getQuickFunctionOrder();
      if (savedOrder && savedOrder.length === 8) {
        this.quickFunctionOrder = savedOrder;
      }
    } catch (err) {
      console.error('loadQuickFunctionOrder error:', JSON.stringify(err));
    }
  }

  // 保存快捷功能顺序
  async saveQuickFunctionOrder(): Promise<void> {
    try {
      await GlobalData.prefs.setQuickFunctionOrder(this.quickFunctionOrder);
    } catch (err) {
      console.error('saveQuickFunctionOrder error:', JSON.stringify(err));
    }
  }

  // 获取卡片配置
  getCardConfig(cardId: string): HealthCardItem | undefined {
    return this.healthCardConfigs.find(card => card.id === cardId);
  }

  // 渲染健康卡片
  async checkWeightPrompt(): Promise<void> {
    try {
      const skip = await GlobalData.prefs.getWeightSkipPrompt();
      const configured = await GlobalData.prefs.isWeightConfigured();
      if (skip || configured) {
        return;
      }
      // 延迟显示确保页面已渲染
      setTimeout(() => {
        this.showWeightOverlay = true;
      }, 800);
    } catch (err) {
      console.error('checkWeightPrompt error:', JSON.stringify(err));
    }
  }

  // 每日首次进入弹出情绪记录（不透明覆盖层）
  // 幂等：同一日期只触发一次；跨天后（不重启）重新触发
  async checkMoodPrompt(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      if (this.lastMoodCheckDate === today) {
        return;
      }
      this.lastMoodCheckDate = today;
      const lastPrompt = await GlobalData.prefs.getLastMoodPromptDate();
      console.info('MOOD_PROMPT today=' + today + ' last=' + lastPrompt);
      if (lastPrompt === today) {
        console.info('MOOD_PROMPT already prompted today');
        return;
      }
      // 今天已记录情绪则不再弹出
      const rows = await GlobalData.db.getMoodRecords(today, today);
      console.info('MOOD_PROMPT moodRows=' + String(rows.length));
      if (rows.length > 0) {
        await GlobalData.prefs.setLastMoodPromptDate(today);
        console.info('MOOD_PROMPT has mood record');
        return;
      }
      // 体重弹窗关闭后再弹情绪弹窗
      this.moodPromptPending = true;
      this.pendingMoodDate = today;
      setTimeout(() => {
        if (this.showWeightOverlay) {
          console.info('MOOD_PROMPT waiting weight overlay');
          return;
        }
        console.info('MOOD_PROMPT opening overlay');
        this.openMoodOverlay(today);
      }, 1100);
    } catch (err) {
      console.error('checkMoodPrompt error:', JSON.stringify(err));
    }
  }

  private refreshTimer: number = -1;

  async saveWeightOverlay(): Promise<void> {
    const h = parseInt(this.overlayHeightInput);
    const w = parseFloat(this.overlayWeightInput);
    if (!isNaN(h) && h > 0 && !isNaN(w) && w > 0) {
      const config = await GlobalData.prefs.getGoalConfig();
      config.heightCm = h;
      config.weightKg = w;
      await GlobalData.prefs.saveGoalConfig(config);
      await GlobalData.prefs.setWeight(w);
      await GlobalData.prefs.setGender(this.overlayGender);
      // 同步更新身高体重记录表，保证各页数据源一致
      try {
        const today = await GlobalData.getTodayDate();
        const existingHeight = await GlobalData.db.getHeightRecords(today, today);
        for (const record of existingHeight) {
          await GlobalData.db.deleteHeightRecord(Number(record.id));
        }
        await GlobalData.db.addHeightRecord(today, h);
        const existingWeight = await GlobalData.db.getWeightRecords(today, today);
        for (const record of existingWeight) {
          await GlobalData.db.deleteWeightRecord(Number(record.id));
        }
        await GlobalData.db.addWeightRecord(today, w);
      } catch (err) {
        console.error('Index saveWeightOverlay sync error:', JSON.stringify(err));
      }
    }
    await GlobalData.prefs.markWeightConfigured();
    await GlobalData.prefs.setWeightSkipPrompt(this.overlaySkipNext);
    this.showWeightOverlay = false;
    this.checkPendingMoodPrompt();
  }

  async saveMoodOverlay(): Promise<void> {
    const date: string = this.overlayMoodDate.length > 0 ? this.overlayMoodDate : await GlobalData.getTodayDate();
    const record: DbRow = {
      date: date,
      mood: this.overlayMood,
      note: this.overlayMoodNote,
    };
    try {
      await GlobalData.db.addMoodRecord(record);
    } catch (err) {
      console.error('saveMoodOverlay error:', JSON.stringify(err));
    }
    this.showMoodOverlay = false;
    this.loadAllData();
  }

  openMoodOverlay(date: string): void {
    console.info('MOOD_PROMPT openMoodOverlay date=' + date);
    this.overlayMoodDate = date;
    this.overlayMood = 3;
    this.overlayMoodNote = '';
    this.showMoodOverlay = true;
    this.moodPromptPending = false;
    GlobalData.prefs.setLastMoodPromptDate(date);
  }

  checkPendingMoodPrompt(): void {
    if (this.moodPromptPending && !this.showWeightOverlay) {
      const d: string = this.pendingMoodDate.length > 0 ? this.pendingMoodDate : '';
      if (d.length > 0) {
        this.openMoodOverlay(d);
      }
    }
  }

  startAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
    }
    this.refreshTimer = setInterval(() => {
      this.loadAllData();
      this.checkMoodPrompt();
    }, 10000);
  }

  stopAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  async loadAllData(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      this.stepGoal = goalConfig.dailySteps;
      this.waterGoal = goalConfig.dailyWaterMl;
      this.recommendCalorie = goalConfig.dailyCalorie;

      const summary = await GlobalData.db.getDailySummary(today);
      if (summary) {
        this.stepCount = Number(summary.steps) || 0;
        this.heartRate = Number(summary.heart_rate_avg) || 0;
        this.sleepScore = Number(summary.sleep_score) || 0;
        this.sleepHours = summary.sleep_hours ? Number(summary.sleep_hours).toFixed(1) : '0';
        this.waterMl = Number(summary.water_ml) || 0;
        this.moveCal = Number(summary.calories_burned) || 0;
        this.exerciseMin = Number(summary.exercise_minutes) || 0;
      } else {
        this.stepCount = 0;
        this.heartRate = 0;
        this.sleepScore = 0;
        this.sleepHours = '0';
        this.waterMl = 0;
        this.moveCal = 0;
        this.exerciseMin = 0;
      }

      // 兜底：若 daily_summary 运动数据缺失，则从运动记录表实时汇总
      if (this.exerciseMin === 0) {
        const sportRows = await GlobalData.db.getSportRecords(today, today);
        let totalMin: number = 0;
        let totalCal: number = 0;
        for (const r of sportRows) {
          totalMin += Number(r.duration_min) || 0;
          totalCal += Number(r.calories) || 0;
        }
        if (totalMin > 0) {
          this.exerciseMin = totalMin;
          this.moveCal = Math.max(this.moveCal, totalCal);
        } else if (sportRows.length > 0) {
          this.exerciseMin = 1;
          this.moveCal = Math.max(this.moveCal, totalCal);
        }
      }

      this.moveProgress = Math.min(100, (this.moveCal / 800) * 100);
      this.exerciseProgress = Math.min(100, (this.exerciseMin / 60) * 100);

      // 加载今日心情（取当天最近一条心情记录，1-5）
      this.moodValue = await this.loadTodayMood();
      this.moodProgress = Math.min(100, (this.moodValue / 5) * 100);

      const weightRow = await GlobalData.db.getLatestWeight();
      if (weightRow) {
        this.weightKg = Number(weightRow.weight_kg).toFixed(1);
      }
      const hour = new Date().getHours();
      if (hour < 6) { this.greeting = '夜深了'; }
      else if (hour < 9) { this.greeting = '早上好'; }
      else if (hour < 12) { this.greeting = '上午好'; }
      else if (hour < 14) { this.greeting = '中午好'; }
      else if (hour < 18) { this.greeting = '下午好'; }
      else { this.greeting = '晚上好'; }

      const savedTheme: string = await GlobalData.prefs.getTheme();
      this.themeMode = savedTheme;
      this.theme = this.resolveTheme(savedTheme);
      AppStorage.setOrCreate('currentTheme', this.theme);
      this.updateThemeColors();

      const streak: StreakData = await GlobalData.prefs.getStreakData();
      this.streakCurrent = streak.current;
      this.streakBest = streak.best;
      
      // 加载补录天数
      const makeupDays = await GlobalData.prefs.getMakeupDays();
      this.makeupDaysCount = makeupDays.length;

      const loginRaw: string | number | boolean = await GlobalData.prefs.get('login_status', 'false');
      const loginStatus: string = String(loginRaw);
      this.isLoggedIn = loginStatus === 'true';
      const nameRaw: string | number | boolean = await GlobalData.prefs.get('user_name', '');
      this.userName = String(nameRaw);

      // 加载日记页数据（按选中日期，默认今天）
      if (this.diaryDate.length === 0) {
        this.diaryDate = today;
      }
      await this.loadDiaryData();

      // 计算今日摄入热量
      const todayDietRecords = await GlobalData.db.getDietRecordsRange(today, today);
      this.todayCalorieIntake = todayDietRecords.reduce((sum: number, record: DbRow) => sum + (Number(record.calories) || 0), 0);

      // 数据加载完成后，检查成就（评分更新时自动检查）
      await this.checkAchievements();
    } catch (err) {
      console.error('loadData error:', JSON.stringify(err));
    }
  }

  @StorageLink('themeMode') themeMode: string = 'follow';
  @StorageLink('systemDark') @Watch('onSystemThemeChange') systemDark: boolean = false;

  // 主题变化时刷新颜色和状态栏
  onThemeChange(): void {
    this.updateThemeColors();
    this.applySystemBarColor(this.theme);
    console.info('THEME changed to: ' + this.theme);
  }

  // 系统主题变化时刷新（仅跟随模式）
  onSystemThemeChange(): void {
    if (this.themeMode === 'follow') {
      const resolved: string = this.systemDark ? 'dark' : 'light';
      this.theme = resolved;
      AppStorage.setOrCreate('currentTheme', resolved);
      console.info('THEME system changed, systemDark=' + this.systemDark + ', currentTheme=' + resolved);
    }
  }

  // 更新状态栏颜色
  applySystemBarColor(theme: string): void {
    try {
      const mainWindow: window.Window | undefined = AppStorage.get('mainWindow');
      if (!mainWindow) {
        console.error('applySystemBarColor: mainWindow not found');
        return;
      }
      const isDark: boolean = theme === 'dark';
      const props: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
        navigationBarContentColor: isDark ? '#FFFFFF' : '#000000'
      };
      mainWindow.setWindowSystemBarProperties(props);
    } catch (err) {
      console.error('applySystemBarColor error: ' + JSON.stringify(err));
    }
  }

  async loadDiaryData(): Promise<void> {
    try {
      const day: string = this.diaryDate.length > 0 ? this.diaryDate : await GlobalData.getTodayDate();
      this.diaryDietRecords = await GlobalData.db.getDietRecordsRange(day, day);
      this.diarySportRecords = await GlobalData.db.getSportRecords(day, day);
      this.diarySleepRecords = await GlobalData.db.getSleepRecords(day, day);
      this.diaryMoodRecords = await GlobalData.db.getMoodRecords(day, day);
    } catch (err) {
      console.error('loadDiaryData error:', JSON.stringify(err));
    }
  }

  changeDiaryDate(offsetDays: number): void {
    const d = new Date(this.diaryDate + 'T00:00:00');
    if (isNaN(d.getTime())) {
      return;
    }
    d.setDate(d.getDate() + offsetDays);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const today = new Date();
    const todayStr = today.getFullYear() + '-' + String(today.getMonth() + 1).padStart(2, '0') +
      '-' + String(today.getDate()).padStart(2, '0');
    const candidate = y + '-' + m + '-' + day;
    if (candidate > todayStr) {
      return;
    }
    this.diaryDate = candidate;
    this.loadDiaryData();
  }

  selectDiaryDate(date: string): void {
    const today = new Date();
    const todayStr = today.getFullYear() + '-' + String(today.getMonth() + 1).padStart(2, '0') +
      '-' + String(today.getDate()).padStart(2, '0');
    if (date > todayStr) {
      return;
    }
    this.diaryDate = date;
    this.loadDiaryData();
  }

  resolveTheme(savedTheme: string): string {
    if (savedTheme === 'dark' || savedTheme === 'light') {
      return savedTheme;
    }
    if (this.systemDark) {
      return 'dark';
    }
    return 'light';
  }

  toggleTheme(): void {
    const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
    this.themeMode = next;
    GlobalData.prefs.setTheme(next);
    if (next !== 'follow') {
      this.theme = next;
      AppStorage.setOrCreate('currentTheme', next);
    } else {
      const resolved: string = this.resolveTheme('follow');
      this.theme = resolved;
      AppStorage.setOrCreate('currentTheme', resolved);
    }
    console.info('THEME toggle next=' + next + ' currentTheme=' + AppStorage.get<string>('currentTheme'));
  }

  navigateTo(page: string): void {
    if (page === 'achievement') {
      this.openAchievementList();
      return;
    }
    try {
      router.pushUrl({ url: page }).then(() => {
        console.info('Navigate to ' + page + ' succeeded');
      }).catch((err: Error) => {
        console.error('Navigate to ' + page + ' failed: ' + JSON.stringify(err));
      });
    } catch (e) {
      console.error('Navigate exception: ' + JSON.stringify(e));
    }
  }

  async generateShareCard(): Promise<void> {
    this.isGeneratingShare = true;
    try {
      console.info('generateShareCard: start snapshot');
      const snap = this.getUIContext().getComponentSnapshot();
      // 使用 waitUntilRenderFinished 确保所有内容渲染完成
      const pixelMap: image.PixelMap = await snap.createFromBuilder(
        (): void => { this.shareCard(); },
        500,  // 延迟500ms
        false, // 不检查图片状态
        { scale: 1, waitUntilRenderFinished: true }  // 等待渲染完成
      );
      console.info('generateShareCard: snapshot ok');
      const packer: image.ImagePacker = image.createImagePacker();
      const opts: image.PackingOption = { format: 'image/png', quality: 100 };
      const data: ArrayBuffer = await packer.packing(pixelMap, opts);
      console.info('generateShareCard: packing ok, size=' + data.byteLength);
      const context = getContext(this) as common.UIAbilityContext;
      const filePath = context.filesDir + '/health_share_' + Date.now() + '.png';
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, data);
      fs.closeSync(file);
      console.info('generateShareCard: saved=' + filePath);
      promptAction.showToast({ message: '分享卡片已生成，请在弹出的面板中选择应用', duration: 2000 });
      await this.shareImage(context, filePath);
    } catch (err) {
      const e: Error = err as Error;
      console.error('generateShareCard error: code=' + e.name + ' msg=' + e.message + ' stack=' + e.stack);
      promptAction.showToast({ message: '生成分享失败', duration: 2000 });
    } finally {
      this.isGeneratingShare = false;
      this.showSharePanel = false;
    }
  }

  async shareImage(context: common.UIAbilityContext, filePath: string): Promise<void> {
    const shareData = new systemShare.SharedData({
      utd: utd.UniformDataType.PNG,
      uri: fileUri.getUriFromPath(filePath)
    });
    const controller = new systemShare.ShareController(shareData);
    try {
      await controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
      console.info('Share panel shown');
    } catch (err) {
      console.error('shareImage error:', JSON.stringify(err));
      promptAction.showToast({ message: '打开分享面板失败', duration: 2500 });
    }
  }

  getMoodEmoji(moodVal: number): string {
    if (moodVal >= 4.5) { return '😄'; }
    if (moodVal >= 3.5) { return '🙂'; }
    if (moodVal >= 2.5) { return '😐'; }
    if (moodVal >= 1.5) { return '😔'; }
    return '😢';
  }

  getMoodLabel(mood: number): string {
    if (mood === 5) { return '很好'; }
    if (mood === 4) { return '不错'; }
    if (mood === 3) { return '一般'; }
    if (mood === 2) { return '不好'; }
    return '很差';
  }

  getDisplaySteps(): number {
    if (this.liveSteps > 0) {
      return this.liveSteps;
    }
    return this.stepCount;
  }

  formatLargeNumber(n: number): string {
    if (n >= 10000) {
      return (n / 10000).toFixed(1) + '万';
    }
    return String(n);
  }

  getHealthScore(): number {
    // 与首页健康Tab/桌面卡片/报告统一的加权累加 + 短板加权算法
    const currentSteps = this.liveSteps > 0 ? this.liveSteps : this.stepCount;
    return HealthScoreUtil.calcByData(
      currentSteps, this.stepGoal, this.sleepScore, this.waterMl, this.waterGoal,
      this.exerciseMin, this.todayCalorieIntake, this.recommendCalorie
    );
  }

  // 是否有有效评分数据（任一正项有记录）
  hasScoreData(): boolean {
    const currentSteps = this.liveSteps > 0 ? this.liveSteps : this.stepCount;
    return currentSteps > 0 || this.sleepScore > 0 || this.waterMl > 0 || this.exerciseMin > 0;
  }

  getScoreDetails(): string {
    const currentSteps = this.liveSteps > 0 ? this.liveSteps : this.stepCount;
    const bd = HealthScoreUtil.calcBreakdown(
      currentSteps, this.stepGoal, this.sleepScore, this.waterMl, this.waterGoal,
      this.exerciseMin, this.todayCalorieIntake, this.recommendCalorie
    );
    const details: string[] = [];
    if (bd.stepScore > 0) {
      details.push(`步数+${bd.stepScore}`);
    }
    if (bd.sleepScoreOut > 0) {
      details.push(`睡眠+${bd.sleepScoreOut}`);
    }
    if (bd.waterScore > 0) {
      details.push(`饮水+${bd.waterScore}`);
    }
    if (bd.exerciseScore > 0) {
      details.push(`运动+${bd.exerciseScore}`);
    }
    if (bd.dietScore > 0) {
      details.push(`饮食+${bd.dietScore}`);
    } else if (bd.dietScore < 0) {
      details.push(`饮食${bd.dietScore}`);
    }
    return details.join(' ');
  }

  getScoreColor(score: number): string {
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

  async loadTodayMood(): Promise<number> {
    try {
      const today = await GlobalData.getTodayDate();
      const rows = await GlobalData.db.getMoodRecords(today, today);
      if (rows.length === 0) {
        return 0;
      }
      const last = rows[rows.length - 1];
      const val: number = Number(last.mood) || 0;
      return val > 0 && val <= 5 ? val : 0;
    } catch (err) {
      console.error('Index loadTodayMood error:', JSON.stringify(err));
      return 0;
    }
  }

  onPageShow(): void {
    this.loadAllData();
    this.checkMoodPrompt();
  }

  // 检查成就
  async checkAchievements(): Promise<void> {
    try {
      const score = this.getHealthScore();
      const today = new Date();
      const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
      
      // 获取之前的连续天数
      const prevStreak = await GlobalData.prefs.getStreakData();
      const prevStreakCurrent = prevStreak.current;
      
      // 如果健康评分达到60分，更新连续天数
      if (score >= 60) {
        const streak: StreakData = await GlobalData.prefs.updateStreak(true);
        this.streakCurrent = streak.current;
        this.streakBest = streak.best;

        // 只有当连续天数增加时才检查成就
        if (streak.current > prevStreakCurrent) {
          // 检查是否达到新的成就
          const newAchievements = await this.achievementHelper.checkAchievements(streak.current);
          
          // 如果有新成就，显示弹窗
          if (newAchievements.length > 0) {
            this.currentAchievement = newAchievements[0]; // 显示第一个新成就
            this.showAchievementDialog = true;
            
            // 发送成就解锁通知
            const notifyEnabledRaw: string | number | boolean = await GlobalData.prefs.get('achievement_notify', 'true');
            if (String(notifyEnabledRaw) === 'true') {
              for (const ach of newAchievements) {
                NotificationService.getInstance().notifyAchievementUnlocked(ach.name, ach.description);
              }
            }
          }
        }
        
        // 连续天数更新时，触发数据刷新
        if (streak.current !== prevStreakCurrent) {
          this.dataUpdateTrigger = Date.now().toString();
        }
      } else {
        // 如果没有达到60分，重置连续天数
        const streak: StreakData = await GlobalData.prefs.updateStreak(false);
        this.streakCurrent = streak.current;
        this.streakBest = streak.best;
        
        // 连续天数重置时，触发数据刷新
        if (streak.current !== prevStreakCurrent) {
          this.dataUpdateTrigger = Date.now().toString();
        }
      }
    } catch (err) {
      console.error('checkAchievements error:', JSON.stringify(err));
    }
  }

  // 打开成就列表
  async openAchievementList(): Promise<void> {
    try {
      this.allAchievements = await this.achievementHelper.getAllAchievements();
      this.showAchievementListDialog = true;
    } catch (err) {
      console.error('openAchievementList error:', JSON.stringify(err));
    }
  }

  // 数据更新通知处理
  onDataUpdate(propName: string): void {
    if (this.dataUpdateTrigger.length > 0) {
      console.info('DATA_UPDATE trigger:', this.dataUpdateTrigger);
      // 重新加载数据（会自动检查成就）
      this.loadAllData();
    }
  }

  onForegroundDateChange(propName: string): void {
    // 每次从后台回到前台触发，检测是否跨天需要弹情绪弹窗
    this.checkMoodPrompt();
  }

  onCardTarget(propName: string): void {
    // 服务卡片 router 事件：跳转到指定页面（保留首页在栈底，返回可回到 app）
    const target = this.cardTarget;
    if (target.length > 0) {
      AppStorage.setOrCreate('cardTarget', '');
      let page: string = 'pages/WaterPage';
      if (target === 'SleepPage') { page = 'pages/SleepPage'; }
      else if (target === 'DietPage') { page = 'pages/DietPage'; }
      else if (target === 'SportPage') { page = 'pages/SportPage'; }
      this.navigateTo(page);
    }
  }

  onInAppAlarm(propName: string): void {
    if (this.inAppAlarm.length > 0) {
      AlertDialog.show({
        title: '⏰ 健康闹铃',
        message: this.inAppAlarm,
        primaryButton: {
          value: '知道了',
          action: () => {
            AppStorage.setOrCreate('inAppAlarm', '');
          }
        },
        autoCancel: true,
        cancel: () => {
          AppStorage.setOrCreate('inAppAlarm', '');
        }
      });
    }
  }

  build() {
    Stack() {
      Column() {
        Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
          TabContent() {
            HealthTab({
              textColor: this.textColor,
              subTextColor: this.subTextColor,
              cardColor: this.cardColor,
              accentColor: this.accentColor,
              themeMode: this.themeMode,
              theme: this.theme,
              greeting: this.greeting,
              streakCurrent: this.streakCurrent + this.makeupDaysCount, // 连续天数 + 补录天数
              ringDisplayMode: this.ringDisplayMode,
              stepCount: this.stepCount,
              stepGoal: this.stepGoal,
              sleepHours: this.sleepHours,
              moodValue: this.moodValue,
              moodProgress: this.moodProgress,
              sleepScore: this.sleepScore,
              waterMl: this.waterMl,
              waterGoal: this.waterGoal,
              todayCalorieIntake: this.todayCalorieIntake,
              exerciseMin: this.exerciseMin,
              recommendCalorie: this.recommendCalorie,
              healthCardOrder: this.healthCardOrder,
              quickFunctionOrder: this.quickFunctionOrder,
              onToggleTheme: () => { this.toggleTheme(); },
              onToggleRingMode: () => { this.ringDisplayMode = !this.ringDisplayMode; },
              onCardDrag: (from: number, to: number) => {
                const movedItem = this.healthCardOrder.splice(from, 1)[0];
                this.healthCardOrder.splice(to, 0, movedItem);
                this.saveHealthCardOrder();
              },
              onFuncDrag: (from: number, to: number) => {
                const movedItem = this.quickFunctionOrder.splice(from, 1)[0];
                this.quickFunctionOrder.splice(to, 0, movedItem);
                this.saveQuickFunctionOrder();
              },
              onNavigate: (page: string) => { this.navigateTo(page); },
              onRefreshData: async () => {
                await this.loadAllData();
                await this.loadDiaryData();
              }
            })
          }
          .tabBar(this.tabBuilder('ic_health', '健康', 0))

          TabContent() {
            DiaryTab({
              textColor: this.textColor,
              subTextColor: this.subTextColor,
              cardColor: this.cardColor,
              accentColor: this.accentColor,
              diaryDate: this.diaryDate,
              diaryDietRecords: this.diaryDietRecords,
              diarySportRecords: this.diarySportRecords,
              diarySleepRecords: this.diarySleepRecords,
              diaryMoodRecords: this.diaryMoodRecords,
              onDateChange: (offset: number) => { this.changeDiaryDate(offset); },
              onDateSelect: (date: string) => { this.selectDiaryDate(date); },
              onShare: () => { this.showSharePanel = true; },
              onRefreshData: async () => { await this.loadDiaryData(); }
            })
          }
          .tabBar(this.tabBuilder('ic_diary', '记录', 1))

          TabContent() { this.recognitionTab() }
          .tabBar(this.tabBuilder('ic_camera', '识图', 2))

          TabContent() {
            ChatTab({ activeTheme: this.theme })
          }
          .tabBar(this.tabBuilder('ic_ai', 'AI问答', 3))

          TabContent() {
            AccountTab({
              textColor: this.textColor,
              subTextColor: this.subTextColor,
              cardColor: this.cardColor,
              isLoggedIn: this.isLoggedIn,
              userName: this.userName,
              onNavigate: (page: string) => { this.navigateTo(page); }
            })
          }
          .tabBar(this.tabBuilder('ic_account', '账号', 4))
        }
        .animationDuration(200)
        .barHeight(56)
        .barWidth('100%')
        .backgroundColor(this.bgColor)
        .onChange((index: number) => {
          this.currentTabIndex = index;
          if (index === 0) { this.loadAllData(); }
          if (index === 1) { this.loadDiaryData(); }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bgColor)

      if (this.showSharePanel) {
        SharePanel({
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          cardColor: this.cardColor,
          bgColor: this.bgColor,
          accentColor: this.accentColor,
          diaryDietRecords: this.diaryDietRecords,
          diarySportRecords: this.diarySportRecords,
          diarySleepRecords: this.diarySleepRecords,
          diaryMoodRecords: this.diaryMoodRecords,
          shareDiet: this.shareDiet,
          shareSport: this.shareSport,
          shareSleep: this.shareSleep,
          shareMood: this.shareMood,
          shareOverview: this.shareOverview,
          isGeneratingShare: this.isGeneratingShare,
          healthScore: this.getHealthScore(),
          hasScoreData: this.hasScoreData(),
          steps: this.getDisplaySteps(),
          exerciseMin: this.exerciseMin,
          sleepHours: this.sleepHours,
          diaryDate: this.diaryDate.length > 0 ? this.diaryDate : GlobalData.formatDate(new Date()),
          onDietChange: (on: boolean) => { this.shareDiet = on; },
          onSportChange: (on: boolean) => { this.shareSport = on; },
          onSleepChange: (on: boolean) => { this.shareSleep = on; },
          onMoodChange: (on: boolean) => { this.shareMood = on; },
          onOverviewChange: (on: boolean) => { this.shareOverview = on; },
          onClose: () => { this.showSharePanel = false; },
          onGenerate: () => { this.generateShareCard(); }
        })
      }

      if (this.showWeightOverlay) {
        WeightOverlay({
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          cardColor: this.cardColor,
          overlayGenders: this.overlayGenders,
          overlayGender: this.overlayGender,
          overlayHeightInput: this.overlayHeightInput,
          overlayWeightInput: this.overlayWeightInput,
          overlaySkipNext: this.overlaySkipNext,
          onGenderChange: (v: string) => { this.overlayGender = v; },
          onHeightChange: (v: string) => { this.overlayHeightInput = v; },
          onWeightChange: (v: string) => { this.overlayWeightInput = v; },
          onSkipChange: (on: boolean) => { this.overlaySkipNext = on; },
          onSkip: () => {
            GlobalData.prefs.setWeightSkipPrompt(this.overlaySkipNext);
            GlobalData.prefs.markWeightConfigured();
            this.showWeightOverlay = false;
            this.checkPendingMoodPrompt();
          },
          onSave: () => { this.saveWeightOverlay(); }
        })
      }

      if (this.showMoodOverlay) {
        MoodOverlay({
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          cardColor: this.cardColor,
          overlayMoodDate: this.overlayMoodDate,
          overlayMood: this.overlayMood,
          overlayMoodNote: this.overlayMoodNote,
          onMoodChange: (mood: number) => { this.overlayMood = mood; },
          onNoteChange: (v: string) => { this.overlayMoodNote = v; },
          onCancel: () => { this.showMoodOverlay = false; },
          onSave: () => { this.saveMoodOverlay(); }
        })
      }

      // 成就弹窗
      if (this.showAchievementDialog && this.currentAchievement) {
        AchievementDialog({
          achievement: this.currentAchievement,
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          cardColor: this.cardColor,
          accentColor: this.accentColor,
          onClose: () => {
            this.showAchievementDialog = false;
            this.currentAchievement = null;
          }
        })
      }

      // 成就列表弹窗
      if (this.showAchievementListDialog) {
        AchievementListDialog({
          achievements: this.allAchievements,
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          cardColor: this.cardColor,
          accentColor: this.accentColor,
          currentStreak: this.streakCurrent,
          onClose: () => {
            this.showAchievementListDialog = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  // 计算分享卡片总高度（createFromBuilder 需要明确高度）
  getShareCardHeight(): number {
    let height: number = 40; // 标题栏
    height += 40; // padding 上下各20
    
    // 健康概览
    if (this.shareOverview) {
      height += 130; // 概览区域
    }
    
    // 饮食记录
    if (this.shareDiet && this.diaryDietRecords.length > 0) {
      height += 20; // 标题
      height += this.diaryDietRecords.length * 60; // 每条记录约60vp
    }
    
    // 运动记录
    if (this.shareSport && this.diarySportRecords.length > 0) {
      height += 20; // 标题
      height += this.diarySportRecords.length * 60;
    }
    
    // 睡眠记录
    if (this.shareSleep && this.diarySleepRecords.length > 0) {
      height += 20; // 标题
      height += this.diarySleepRecords.length * 60;
    }
    
    // 情绪记录
    if (this.shareMood && this.diaryMoodRecords.length > 0) {
      height += 20; // 标题
      for (const item of this.diaryMoodRecords) {
        height += item.note && String(item.note).length > 0 ? 80 : 60; // 有note则更高
      }
    }
    
    height += 30; // 底部文字
    
    return height;
  }

  @Builder shareCard() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Text('健康1st').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Text('我的健康日记').fontSize(11).fontColor(this.subTextColor).margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(this.diaryDate.length > 0 ? this.diaryDate : GlobalData.formatDate(new Date()))
          .fontSize(12).fontColor(this.subTextColor)
      }
      .width('100%')

      // 健康概览 - 单排放置
      if (this.shareOverview) {
        Column() {
          Row() {
            Text('健康评分').fontSize(11).fontColor(this.subTextColor)
            Blank()
            Text(this.hasScoreData() ? String(this.getHealthScore()) : '--')
              .fontSize(24).fontWeight(FontWeight.Bold)
              .fontColor(this.hasScoreData() ? this.getScoreColor(this.getHealthScore()) : this.subTextColor)
          }.width('100%')
          Row() {
            Text('步数').fontSize(11).fontColor(this.subTextColor)
            Blank()
            Text(this.getDisplaySteps() > 0 ? this.formatLargeNumber(this.getDisplaySteps()) : '--')
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          }.width('100%').margin({ top: 6 })
          Row() {
            Text('运动').fontSize(11).fontColor(this.subTextColor)
            Blank()
            Text(this.exerciseMin > 0 ? String(this.exerciseMin) + '分钟' : '--')
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          }.width('100%').margin({ top: 6 })
          Row() {
            Text('睡眠').fontSize(11).fontColor(this.subTextColor)
            Blank()
            Text(this.sleepHours !== '0' && this.sleepHours !== '0.0' ? this.sleepHours + '小时' : '--')
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          }.width('100%').margin({ top: 6 })
        }
        .width('100%').padding(12)
        .backgroundColor(this.cardColor).borderRadius(12).margin({ top: 12 })
      }

      // 饮食记录 - 显示所有
      if (this.shareDiet && this.diaryDietRecords.length > 0) {
        Text('🍎 饮食').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 12 })
        ForEach(this.diaryDietRecords, (item: DbRow) => {
          Column() {
            Row() {
              Text(this.formatShareTime(Number(item.timestamp)) || '--:--').fontSize(11).fontColor(this.accentColor)
              Text(' · ').fontSize(11).fontColor(this.subTextColor)
              Text(this.getMealTypeName(String(item.meal_type))).fontSize(11).fontColor(this.subTextColor)
              Blank()
              Text(Number(item.calories) + ' kcal').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
            }.width('100%')
            Row() {
              Text(String(item.food_name)).fontSize(13).fontColor(this.textColor)
              if (item.amount_g) {
                Text('  ' + Number(item.amount_g) + 'g').fontSize(11).fontColor(this.subTextColor)
              }
            }.width('100%').margin({ top: 2 })
          }
          .width('100%').padding(8).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 4 })
        }, (item: DbRow): string => String(item.id))
      }

      // 运动记录 - 显示所有
      if (this.shareSport && this.diarySportRecords.length > 0) {
        Text('🏃 运动').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 12 })
        ForEach(this.diarySportRecords, (item: DbRow) => {
          Column() {
            Row() {
              Text(this.formatShareTime(Number(item.timestamp)) || '--:--').fontSize(11).fontColor(this.accentColor)
              Text(' · ').fontSize(11).fontColor(this.subTextColor)
              Text(this.getSportTypeName(String(item.sport_type))).fontSize(11).fontColor(this.subTextColor)
              Blank()
              Text(Number(item.calories) + ' kcal').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
            }.width('100%')
            Row() {
              Text(this.formatShareDuration(Number(item.duration_min))).fontSize(13).fontColor(this.textColor)
              if (item.distance_km && Number(item.distance_km) > 0) {
                Text(' · ' + Number(item.distance_km).toFixed(1) + 'km').fontSize(11).fontColor(this.subTextColor)
              }
            }.width('100%').margin({ top: 2 })
          }
          .width('100%').padding(8).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 4 })
        }, (item: DbRow): string => String(item.id))
      }

      // 睡眠记录 - 显示所有
      if (this.shareSleep && this.diarySleepRecords.length > 0) {
        Text('😴 睡眠').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 12 })
        ForEach(this.diarySleepRecords, (item: DbRow) => {
          Column() {
            Row() {
              Text('入睡 ' + String(item.start_time || '--:--')).fontSize(12).fontColor(this.textColor)
              Text(' → ').fontSize(12).fontColor(this.subTextColor)
              Text('醒来 ' + String(item.end_time || '--:--')).fontSize(12).fontColor(this.textColor)
              Blank()
              Text('评分 ' + Number(item.score)).fontSize(12).fontWeight(FontWeight.Bold).fontColor(Constants.COLOR_SLEEP)
            }.width('100%')
            Row() {
              Text('总时长 ' + this.formatShareDuration(Number(item.total_minutes))).fontSize(11).fontColor(this.subTextColor)
            }.width('100%').margin({ top: 2 })
          }
          .width('100%').padding(8).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 4 })
        }, (item: DbRow): string => String(item.id))
      }

      // 情绪记录 - 显示所有，带文本
      if (this.shareMood && this.diaryMoodRecords.length > 0) {
        Text('😊 情绪').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 12 })
        ForEach(this.diaryMoodRecords, (item: DbRow) => {
          Column() {
            Row() {
              Text(this.formatShareTime(Number(item.timestamp)) || '--:--').fontSize(11).fontColor(this.accentColor)
              Blank()
              Text(this.getMoodEmoji(Number(item.mood))).fontSize(20)
            }.width('100%')
            if (item.note && String(item.note).length > 0) {
              Text(String(item.note)).fontSize(12).fontColor(this.textColor)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%').margin({ top: 4 })
            }
          }
          .width('100%').padding(8).backgroundColor(this.cardColor).borderRadius(6)
          .alignItems(HorizontalAlign.Start).margin({ top: 4 })
        }, (item: DbRow): string => String(item.id))
      }

      Text('来自「健康1st」健康管理应用').fontSize(10).fontColor(this.subTextColor).width('100%')
        .textAlign(TextAlign.Center).margin({ top: 16 })
    }
    .width(320)
    .height(this.getShareCardHeight())  // createFromBuilder 需要明确高度
    .padding(20)
    .backgroundColor(this.bgColor)
    .borderRadius(16)
  }

  // 分享卡片辅助方法
  formatShareTime(timestamp: number | undefined): string {
    if (!timestamp) return '';
    const date: Date = new Date(timestamp);
    const h: number = date.getHours();
    const m: number = date.getMinutes();
    return `${h < 10 ? '0' + h : h}:${m < 10 ? '0' + m : m}`;
  }

  getMealTypeName(mealType: string): string {
    const names: Record<string, string> = {
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack': '加餐'
    };
    return names[mealType] || mealType;
  }

  getSportTypeName(sportType: string): string {
    const names: Record<string, string> = {
      'walk': '步行',
      'run': '跑步',
      'bike': '骑行',
      'swim': '游泳',
      'gym': '健身'
    };
    return names[sportType] || sportType;
  }

  formatShareDuration(minutes: number): string {
    if (minutes < 60) {
      return `${minutes}分钟`;
    }
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    return m > 0 ? `${h}时${m}分` : `${h}小时`;
  }

  @Builder tabBuilder(iconName: string, label: string, index: number) {
    Column() {
      Image($r(`app.media.${iconName}`))
        .width(this.currentTabIndex === index ? 26 : 20)
        .height(this.currentTabIndex === index ? 26 : 20)
        .fillColor(this.currentTabIndex === index ? this.accentColor : this.subTextColor)
        .animation({ duration: 250, curve: Curve.EaseInOut })
      Text(label)
        .fontSize(10)
        .fontColor(this.currentTabIndex === index ? this.accentColor : this.subTextColor)
        .animation({ duration: 250, curve: Curve.EaseInOut })
    }
    .width(56)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder quickButton(icon: string, label: string, page: string) {
    Column() {
      Text(icon).fontSize(28)
      Text(label).fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
    }
    .width(70).height(70)
    .backgroundColor(this.cardColor).borderRadius(35)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .onClick(() => { this.navigateTo(page); })
  }

  @Builder recognitionTab() {
    FoodRecognitionTab({ activeTheme: this.theme })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
