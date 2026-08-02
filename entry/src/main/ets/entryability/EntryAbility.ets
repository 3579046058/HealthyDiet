import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { PedometerService } from '../services/PedometerService';
import { PermissionService } from '../services/PermissionService';
import { ReminderScheduler } from '../services/ReminderScheduler';

const DOMAIN = 0x0000;
const TAG = 'HarmonyHealth';

export default class EntryAbility extends UIAbility {
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

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });

    PermissionService.getInstance().requestRequiredPermissions(this.context).then(() => {
      PedometerService.getInstance().startListening((steps: number) => {
        hilog.info(DOMAIN, TAG, 'Pedometer steps: %{public}d', steps);
      });
      ReminderScheduler.getInstance().startAll();
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    PedometerService.getInstance().startListening((steps: number) => {
      hilog.info(DOMAIN, TAG, 'Pedometer resumed: %{public}d', steps);
    });
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
