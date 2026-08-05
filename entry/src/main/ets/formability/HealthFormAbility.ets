import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';

import { GlobalData } from '../common/GlobalData';
import { DbRow } from '../common/Constants';
import { CardDataHelper } from '../services/CardDataHelper';

interface FormData {
  steps: string;
  stepGoal: string;
  stepPercent: string;
  heartRate: string;
  waterMl: string;
  waterGoal: string;
  date: string;
  // 快捷卡片数据
  sleepPercent: string;
  moodPercent: string;
  stepValue: string;
  sleepValue: string;
  moodValue: string;
  healthScore: string;
  scoreColor: string;
  isSleeping: string;
}

/**
 * 健康 Widget 服务卡片
 * 提供健康卡片（步数/心率/喝水）和快捷健康卡片（喝水/睡眠/评分）
 */
export default class HealthFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    // 保存 formId 用于应用内刷新卡片
    // 注意：onAddForm 是卡片进程首次执行，GlobalData 尚未初始化，必须自行初始化
    const formId = want.parameters ? want.parameters['ohos.extra.param.key.form_identity'] : undefined;
    if (formId) {
      this.saveFormId(String(formId));
    }
    return this.createDefaultData();
  }

  private saveFormId(formId: string): void {
    try {
      GlobalData.init(this.context).then(() => {
        GlobalData.prefs.put('card_form_id', formId);
        GlobalData.prefs.flush();
      }).catch((err: Error) => {
        console.error('HealthFormAbility saveFormId init error:', JSON.stringify(err));
      });
    } catch (err) {
      console.error('HealthFormAbility saveFormId error:', JSON.stringify(err));
    }
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
    console.info('HealthForm onFormEvent: ' + message);
    // 处理卡片按钮事件：water / sleep_toggle
    // message 可能是 {"action":"water"} 或直接 "water"
    let action = message;
    try {
      if (message.indexOf('{') === 0) {
        const parsed = JSON.parse(message) as Record<string, Object>;
        const a = parsed['action'];
        if (typeof a === 'string') {
          action = a;
        }
      }
    } catch (err) {
      // 非 JSON，直接用原始 message
    }
    if (action === 'water' || action === 'sleep_toggle') {
      this.handleAction(action).then(() => {
        this.refreshForm(formId);
      });
    } else if (action === 'refresh') {
      this.refreshForm(formId);
    }
  }

  onUpdateForm(formId: string): void {
    this.refreshForm(formId);
  }

  private createDefaultData(): formBindingData.FormBindingData {
    const defaultData: FormData = {
      steps: '0',
      stepGoal: '8000',
      stepPercent: '0',
      heartRate: '--',
      waterMl: '0',
      waterGoal: '2000',
      date: '',
      sleepPercent: '0',
      moodPercent: '0',
      stepValue: '--',
      sleepValue: '--',
      moodValue: '--',
      healthScore: '0',
      scoreColor: '#4CAF50',
      isSleeping: 'false'
    };
    return formBindingData.createFormBindingData(defaultData);
  }

  private async refreshForm(formId: string): Promise<void> {
    try {
      const formData = await this.getFormData();
      formProvider.updateForm(formId, formData);
    } catch (err) {
      console.error('HealthFormAbility refresh error:', JSON.stringify(err));
    }
  }

  private async handleAction(action: string): Promise<void> {
    try {
      await GlobalData.init(this.context);
      const today = await GlobalData.getTodayDate();

      if (action === 'water') {
        // 快速记录一杯水（200ml）
        const config = await GlobalData.prefs.getGoalConfig();
        const summary = await GlobalData.db.getDailySummary(today);
        const current = summary ? Number(summary.water_ml) || 0 : 0;
        const newMl = current + 200;
        await GlobalData.db.updateDailySummaryField(today, 'water_ml', newMl);
        await GlobalData.db.addWaterTimeline(today, this.getNowTime(), 200);
      } else if (action === 'sleep_toggle') {
        const latestSleep = await GlobalData.db.getLatestSleepStartRecord();
        if (latestSleep) {
          // 正在睡眠中 → 醒来，保存睡眠记录
          const endTime = this.getNowTime();
          const startTime = String(latestSleep.start_time || '07:00');
          const startParts = startTime.split(':');
          const endParts = endTime.split(':');
          const sh = parseInt(startParts[0]) || 0;
          const sm = parseInt(startParts[1]) || 0;
          const eh = parseInt(endParts[0]) || 0;
          const em = parseInt(endParts[1]) || 0;
          let totalMin = (eh * 60 + em) - (sh * 60 + sm);
          if (totalMin < 0) {
            totalMin += 24 * 60;
          }
          const d: number = Math.round(totalMin * 0.2);
          const l: number = Math.round(totalMin * 0.55);
          const r: number = Math.round(totalMin * 0.25);
          const score = this.calcSleepScore(totalMin);
          const record: DbRow = {
            date: today,
            start_time: startTime,
            end_time: endTime,
            deep_sleep_min: d,
            light_sleep_min: l,
            rem_min: r,
            total_minutes: totalMin,
            score: score,
          };
          const ok: boolean = await GlobalData.db.addSleepRecord(record);
          if (!ok) {
            console.warn('HealthFormAbility sleep_toggle rejected: overlapping sleep record');
          } else {
            await GlobalData.db.updateDailySummaryField(today, 'sleep_score', score);
          }
          if (latestSleep.id) {
            await GlobalData.db.deleteSleepStartRecord(Number(latestSleep.id));
          }
        } else {
          // 未在睡眠 → 入睡
          await GlobalData.db.addSleepStartRecord(today, this.getNowTime());
        }
      }
    } catch (err) {
      console.error('HealthFormAbility handleAction error:', JSON.stringify(err));
    }
  }

  private moodEmoji(mood: number): string {
    if (mood >= 4.5) { return '😄'; }
    if (mood >= 3.5) { return '🙂'; }
    if (mood >= 2.5) { return '😐'; }
    if (mood >= 1.5) { return '😔'; }
    return '😢';
  }

  private calcSleepScore(totalMin: number): number {
    if (totalMin >= 420 && totalMin <= 540) {
      return 100;
    }
    if (totalMin >= 360 && totalMin <= 600) {
      return 80;
    }
    if (totalMin >= 300) {
      return 60;
    }
    if (totalMin >= 180) {
      return 40;
    }
    return 20;
  }

  private getNowTime(): string {
    const now = new Date();
    const h = now.getHours();
    const m = now.getMinutes();
    return (h < 10 ? '0' + h : '' + h) + ':' + (m < 10 ? '0' + m : '' + m);
  }

  private async getFormData(): Promise<formBindingData.FormBindingData> {
    // 复用 CardDataHelper 组装完整卡片数据（并行查询，与页面一致）
    return await CardDataHelper.buildFormData(this.context);
  }
}
