 import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
 import { hilog } from '@kit.PerformanceAnalysisKit';
 import { window } from '@kit.ArkUI';
 import { GlobalData } from '../common/GlobalData';
 
 const DOMAIN = 0x0000;
 const TAG = 'HarmonyHealth';
 
 export default class EntryAbility extends UIAbility {
   onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
     hilog.info(DOMAIN, TAG, 'Ability onCreate');
   }
 
   onDestroy(): void {
     hilog.info(DOMAIN, TAG, 'Ability onDestroy');
   }
 
   async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
     hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
 
     // 初始化数据库和偏好设置
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
   }
 
   onWindowStageDestroy(): void {
     hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
   }
 
   onForeground(): void {
     hilog.info(DOMAIN, TAG, 'Ability onForeground');
   }
 
   onBackground(): void {
     hilog.info(DOMAIN, TAG, 'Ability onBackground');
   }
 }
