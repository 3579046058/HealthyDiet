import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';

import { GlobalData } from '../common/GlobalData';

interface FormData {
  steps: string;
  stepGoal: string;
  stepPercent: string;
  heartRate: string;
  waterMl: string;
  date: string;
}

/**
 * 健康 Widget 服务卡片
 * 在桌面上显示今日步数、心率和活动状态
 */
export default class HealthFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const defaultData: FormData = {
      steps: '0',
      stepGoal: '8000',
      stepPercent: '0',
      heartRate: '--',
      waterMl: '0',
      date: ''
    };
    return formBindingData.createFormBindingData(defaultData);
  }

  onCastToNormalForm(formId: string): void {
    // 从临时卡片转为常态
  }

  onRemoveForm(formId: string): void {
    // Called when a form has been destroyed.
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  onFormEvent(formId: string, message: string): void {
    // 处理卡片事件
    if (message === 'refresh') {
      this.refreshForm(formId);
    }
  }

  onUpdateForm(formId: string): void {
    this.refreshForm(formId);
  }

  private async refreshForm(formId: string): Promise<void> {
    try {
      const formData = await this.getFormData();
      formProvider.updateForm(formId, formData);
    } catch (err) {
      console.error('HealthFormAbility refresh error:', JSON.stringify(err));
    }
  }

  private async getFormData(): Promise<formBindingData.FormBindingData> {
    try {
      await GlobalData.init(this.context);
      const today = await GlobalData.getTodayDate();
      const config = await GlobalData.prefs.getGoalConfig();
      const summary = await GlobalData.db.getDailySummary(today);

      const steps = summary?.steps ? Number(summary.steps) : 0;
      const heartRate = summary?.heart_rate_avg ? Number(summary.heart_rate_avg) : 72;
      const waterMl = summary?.water_ml ? Number(summary.water_ml) : 0;
      const stepGoal = config.dailySteps;
      const stepPercent = stepGoal > 0 ? Math.round(steps / stepGoal * 100) : 0;

      const formData: FormData = {
        steps: String(steps),
        stepGoal: String(stepGoal),
        stepPercent: String(stepPercent),
        heartRate: String(heartRate),
        waterMl: String(waterMl),
        date: today,
      };
      return formBindingData.createFormBindingData(formData);
    } catch (err) {
      const defaultData: FormData = {
        steps: '0',
        stepGoal: '8000',
        stepPercent: '0',
        heartRate: '--',
        waterMl: '0',
        date: ''
      };
      return formBindingData.createFormBindingData(defaultData);
    }
  }
}

