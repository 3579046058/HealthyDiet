import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { PedometerService } from '../services/PedometerService';
import { PermissionService } from '../services/PermissionService';
import { ReminderScheduler } from '../services/ReminderScheduler';
import { FoodRecognitionService } from '../services/FoodRecognitionService';
import { CardDataHelper } from '../services/CardDataHelper';
import { ChatService } from '../services/ChatService';
import { GoalNotificationHelper } from '../services/GoalNotificationHelper';
import { BackgroundTaskService } from '../services/BackgroundTaskService';

const DOMAIN = 0x0000;
const TAG = 'HarmonyHealth';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    ReminderScheduler.getInstance().setContext(this.context);
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    PedometerService.getInstance().stopListening();
    ReminderScheduler.getInstance().stopAll().then(() => {
      hilog.info(DOMAIN, TAG, 'Reminders stopped');
    });
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    try {
      await GlobalData.init(this.context);
      hilog.info(DOMAIN, TAG, 'GlobalData initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to init GlobalData: %{public}s', JSON.stringify(err));
    }

    // 初始化 AI 配置（从 rawfile 读取 API 密钥）
    try {
      await FoodRecognitionService.getInstance().init(this.context);
      hilog.info(DOMAIN, TAG, 'FoodRecognitionService initialized');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to init FoodRecognitionService: %{public}s', JSON.stringify(err));
    }

    try {
      await ChatService.getInstance().init(this.context);
      hilog.info(DOMAIN, TAG, 'ChatService initialized');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to init ChatService: %{public}s', JSON.stringify(err));
    }

    // 初始化后台任务服务
    try {
      BackgroundTaskService.getInstance().setContext(this.context);
      await BackgroundTaskService.getInstance().requestNotificationPermission();
      hilog.info(DOMAIN, TAG, 'BackgroundTaskService initialized');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to init BackgroundTaskService: %{public}s', JSON.stringify(err));
    }

    const win = windowStage.getMainWindowSync();
    this.mainWindow = win;
    AppStorage.setOrCreate('mainWindow', win);

    // 沉浸式状态栏：全屏布局 + 状态栏透明
    try {
      win.setWindowLayoutFullScreen(true);
      const props: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000'
      };
      win.setWindowSystemBarProperties(props);
      const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topRect = avoidArea.topRect;
      // getWindowAvoidArea 返回 px，需转 vp 供布局使用
      const topPx: number = topRect.height;
      const topVp: number = topPx > 0 ? this.px2vp(topPx) : 47;
      AppStorage.setOrCreate('statusBarHeight', topVp);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to setup immersive status bar: %{public}s', JSON.stringify(err));
    }

    // 根据系统深浅色解析当前主题
    const systemMode = this.context.config.colorMode;
    const systemDark = systemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate('systemDark', systemDark);
    const savedTheme = await GlobalData.prefs.getTheme();
    const resolved = this.resolveTheme(savedTheme, systemMode);
    AppStorage.setOrCreate('currentTheme', resolved);
    this.applySystemBarColor(resolved);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });

    PermissionService.getInstance().requestRequiredPermissions(this.context).then(() => {
      let lastRefreshSteps = 0;
      PedometerService.getInstance().startListening((steps: number) => {
        hilog.info(DOMAIN, TAG, 'Pedometer steps: %{public}d', steps);
        // 步数变化超过50步时刷新卡片（避免频繁刷新）
        if (Math.abs(steps - lastRefreshSteps) >= 50) {
          lastRefreshSteps = steps;
          CardDataHelper.refreshWidget(this.context).catch((err: Error) => {
            hilog.error(DOMAIN, TAG, 'Refresh widget error: %{public}s', JSON.stringify(err));
          });
        }
        // 检查步数目标达成
        GoalNotificationHelper.getInstance().checkStepsGoal(steps).catch((err: Error) => {
          hilog.error(DOMAIN, TAG, 'Goal check error: %{public}s', JSON.stringify(err));
        });
      });
      ReminderScheduler.getInstance().startAll();
    });
  }

  resolveTheme(savedTheme: string, systemMode: number | undefined): string {
    if (savedTheme === 'dark' || savedTheme === 'light') {
      return savedTheme;
    }
    if (systemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      return 'dark';
    }
    return 'light';
  }

  // 处理服务卡片 router 事件（点击卡片跳转指定页面）
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onNewWant');
    let target: string = '';
    if (want.parameters && want.parameters['params']) {
      try {
        const raw = want.parameters['params'];
        if (typeof raw === 'string') {
          const params = JSON.parse(raw) as Record<string, Object>;
          const t = params['targetPage'];
          if (typeof t === 'string') {
            target = t;
          }
        } else {
          const params = JSON.parse(JSON.stringify(raw)) as Record<string, Object>;
          const t = params['targetPage'];
          if (typeof t === 'string') {
            target = t;
          }
        }
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'onNewWant parse error: %{public}s', JSON.stringify(err));
      }
    }
    // 兜底：直接读取 want.parameters.targetPage
    if (target.length === 0 && want.parameters && typeof want.parameters['targetPage'] === 'string') {
      target = want.parameters['targetPage'] as string;
    }
    if (target.length > 0) {
      hilog.info(DOMAIN, TAG, 'Card router to: %{public}s', target);
      AppStorage.setOrCreate('cardTarget', target);
    }
  }

  px2vp(px: number): number {
    try {
      const density: number = display.getDefaultDisplaySync().densityPixels;
      if (density > 0) {
        return px / density;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'get density failed: %{public}s', JSON.stringify(err));
    }
    return 47;
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, TAG, 'Ability onConfigurationUpdate, colorMode: %{public}d', newConfig.colorMode);
    this.applyCurrentTheme();
  }

  async applyCurrentTheme(): Promise<void> {
    try {
      const savedTheme = await GlobalData.prefs.getTheme();
      const systemMode = this.context.config.colorMode;
      AppStorage.setOrCreate('systemDark', systemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      const resolved = this.resolveTheme(savedTheme, systemMode);
      AppStorage.setOrCreate('currentTheme', resolved);
      this.applySystemBarColor(resolved);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'applyCurrentTheme error: %{public}s', JSON.stringify(err));
    }
  }

  applySystemBarColor(theme: string): void {
    if (!this.mainWindow) {
      return;
    }
    const isDark = theme === 'dark';
    const props: window.SystemBarProperties = {
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
      navigationBarContentColor: isDark ? '#FFFFFF' : '#000000'
    };
    try {
      this.mainWindow.setWindowSystemBarProperties(props);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'applySystemBarColor error: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // 停止后台长时任务
    BackgroundTaskService.getInstance().stopBackgroundTask();
    PedometerService.getInstance().startListening((steps: number) => {
      hilog.info(DOMAIN, TAG, 'Pedometer resumed: %{public}d', steps);
    });
    // 检测日期变化：后台跨天后回到前台，通知页面触发每日情绪弹窗
    const now = new Date();
    const todayStr = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') +
      '-' + String(now.getDate()).padStart(2, '0');
    AppStorage.setOrCreate('appForegroundDate', todayStr);
    // 开屏/回到前台时主动刷新桌面卡片（updateForm 不消耗定时刷新配额）
    CardDataHelper.refreshWidget(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Foreground refresh widget error: %{public}s', JSON.stringify(err));
    });
    hilog.info(DOMAIN, TAG, 'Ability onForeground, date=%{public}s', todayStr);
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
    // 启动后台长时任务，保持定时提醒正常运行
    BackgroundTaskService.getInstance().startBackgroundTask('HealthReminder').then((success: boolean) => {
      hilog.info(DOMAIN, TAG, 'Background task started: %{public}s', success.toString());
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to start background task: %{public}s', JSON.stringify(err));
    });
  }
}
