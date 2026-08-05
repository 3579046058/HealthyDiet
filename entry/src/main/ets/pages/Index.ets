import { router, promptAction } from '@kit.ArkUI';
import { componentSnapshot } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { GlobalData } from '../common/GlobalData';
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
  @State showSharePanel: boolean = false;
  @State shareDiet: boolean = true;
  @State shareSport: boolean = true;
  @State shareSleep: boolean = true;
  @State shareMood: boolean = true;
  @State shareOverview: boolean = true;
  @State isGeneratingShare: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
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
    } catch (err) {
      console.error('loadData error:', JSON.stringify(err));
    }
  }

  @StorageLink('themeMode') themeMode: string = 'follow';
  @StorageLink('systemDark') systemDark: boolean = false;

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
    this.updateThemeColors();
    console.info('THEME toggle next=' + next + ' currentTheme=' + AppStorage.get<string>('currentTheme'));
  }

  navigateTo(page: string): void {
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
      const pixelMap: image.PixelMap = await snap.createFromBuilder((): void => { this.shareCard(); }, 800);
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
    let score: number = 0;
    if (this.stepCount > 0) {
      score += Math.min(30, Math.round(this.stepCount / (this.stepGoal || 8000) * 30));
    }
    if (this.sleepScore > 0) {
      score += Math.min(25, Math.round(this.sleepScore * 0.3));
    }
    if (this.waterMl > 0) {
      score += Math.min(25, Math.round(this.waterMl / (this.waterGoal || 2000) * 25));
    }
    if (this.exerciseMin > 0) {
      score += Math.min(20, Math.round(this.exerciseMin / 60 * 20));
    }
    return Math.round(score);
  }

  getScoreDetails(): string {
    let details: string[] = [];
    
    // 步数得分
    if (this.stepCount > 0) {
      let stepScore = Math.min(30, Math.round(this.stepCount / (this.stepGoal || 8000) * 30));
      if (stepScore > 0) {
        details.push(`步数+${stepScore}`);
      }
    }
    
    // 睡眠得分
    if (this.sleepScore > 0) {
      let sleepScoreValue = Math.min(25, Math.round(this.sleepScore * 0.3));
      if (sleepScoreValue > 0) {
        details.push(`睡眠+${sleepScoreValue}`);
      }
    }
    
    // 饮水得分
    if (this.waterMl > 0) {
      let waterScore = Math.min(25, Math.round(this.waterMl / (this.waterGoal || 2000) * 25));
      if (waterScore > 0) {
        details.push(`饮水+${waterScore}`);
      }
    }
    
    // 运动得分
    if (this.exerciseMin > 0) {
      let exerciseScore = Math.min(20, Math.round(this.exerciseMin / 60 * 20));
      if (exerciseScore > 0) {
        details.push(`运动+${exerciseScore}`);
      }
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

  onForegroundDateChange(propName: string): void {
    // 每次从后台回到前台触发，检测是否跨天需要弹情绪弹窗
    this.checkMoodPrompt();
  }

  onCardTarget(propName: string): void {
    // 服务卡片 router 事件：跳转到指定页面
    const target = this.cardTarget;
    if (target.length > 0) {
      AppStorage.setOrCreate('cardTarget', '');
      let page: string = 'pages/Index';
      if (target === 'WaterPage') { page = 'pages/WaterPage'; }
      else if (target === 'SleepPage') { page = 'pages/SleepPage'; }
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
              streakCurrent: this.streakCurrent,
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
              liveSteps: this.liveSteps,
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
              onNavigate: (page: string) => { this.navigateTo(page); }
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
              onShare: () => { this.showSharePanel = true; }
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
    }
    .width('100%')
    .height('100%')
  }

  @Builder shareCard() {
    Column() {
      Row() {
        Column() {
          Text('健康1st').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Text('我的健康日记').fontSize(11).fontColor(this.subTextColor).margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(GlobalData.formatDate(new Date())).fontSize(12).fontColor(this.subTextColor)
      }
      .width('100%')

      if (this.shareOverview) {
        Row() {
          Column() {
            Text('健康评分').fontSize(11).fontColor(this.subTextColor)
            Text(String(this.getHealthScore())).fontSize(30).fontWeight(FontWeight.Bold).fontColor(this.getScoreColor(this.getHealthScore()))
          }
          .onClick(() => { this.navigateTo(Constants.PAGE_REPORT); })
          Column() {
            Text('步数').fontSize(11).fontColor(this.subTextColor)
            Text(this.getDisplaySteps() > 0 ? this.formatLargeNumber(this.getDisplaySteps()) : '--')
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Column() {
            Text('运动').fontSize(11).fontColor(this.subTextColor)
            Text(this.exerciseMin > 0 ? String(this.exerciseMin) + '分' : '--').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          }
          Column() {
            Text('睡眠').fontSize(11).fontColor(this.subTextColor)
            Text(this.sleepHours !== '0' && this.sleepHours !== '0.0' ? this.sleepHours + '时' : '--').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          }
        }
        .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding(16)
        .backgroundColor(this.cardColor).borderRadius(12).margin({ top: 12 })
      }

      if (this.shareDiet && this.diaryDietRecords.length > 0) {
        Text('🍎 饮食').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 12 })
        ForEach(this.diaryDietRecords.slice(0, 3), (item: DbRow) => {
          Row() {
            Text(String(item.food_name)).fontSize(12).fontColor(this.textColor)
            Blank()
            Text(Number(item.calories) + ' kcal').fontSize(11).fontColor(this.subTextColor)
          }
          .width('100%').padding(8).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 4 })
        }, (item: DbRow): string => String(item.id))
      }

      if (this.shareSport && this.diarySportRecords.length > 0) {
        Text('🏃 运动').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 12 })
        ForEach(this.diarySportRecords.slice(0, 3), (item: DbRow) => {
          Row() {
            Text(String(item.sport_type)).fontSize(12).fontColor(this.textColor)
            Blank()
            Text(Number(item.duration_min) + 'min ' + Number(item.calories) + 'kcal').fontSize(11).fontColor(this.subTextColor)
          }
          .width('100%').padding(8).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 4 })
        }, (item: DbRow): string => String(item.id))
      }

      if (this.shareSleep && this.diarySleepRecords.length > 0) {
        Text('😴 睡眠').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 12 })
        ForEach(this.diarySleepRecords.slice(0, 3), (item: DbRow) => {
          Row() {
            Text(String(item.date)).fontSize(12).fontColor(this.textColor)
            Blank()
            Text(Number(item.total_minutes) / 60 + '时 · 评分' + Number(item.score)).fontSize(11).fontColor(this.subTextColor)
          }
          .width('100%').padding(8).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 4 })
        }, (item: DbRow): string => String(item.id))
      }

      if (this.shareMood && this.diaryMoodRecords.length > 0) {
        Text('😊 情绪').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 12 })
        Row() {
          ForEach(this.diaryMoodRecords.slice(0, 7), (item: DbRow) => {
            Text(this.getMoodEmoji(Number(item.mood))).fontSize(24).margin({ right: 8 })
          }, (item: DbRow): string => String(item.id))
        }
        .width('100%').padding(8).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 4 })
      }

      Text('来自「健康1st」健康管理应用').fontSize(10).fontColor(this.subTextColor).width('100%')
        .textAlign(TextAlign.Center).margin({ top: 16 })
    }
    .width(320)
    .padding(20)
    .backgroundColor(this.bgColor)
    .borderRadius(16)
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