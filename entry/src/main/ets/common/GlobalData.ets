import { DatabaseHelper } from '../model/DatabaseHelper';
import { PreferenceHelper } from '../model/PreferenceHelper';

export class GlobalData {
  static db: DatabaseHelper;
  static prefs: PreferenceHelper;
  static initialized: boolean = false;

  static async init(context: Context): Promise<void> {
    if (GlobalData.initialized) return;
    GlobalData.db = new DatabaseHelper(context);
    GlobalData.prefs = new PreferenceHelper();
    await GlobalData.db.init();
    await GlobalData.prefs.init(context);
    GlobalData.initialized = true;
  }

  static async getTodayDate(): Promise<string> {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  static formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  static getTimeStr(): string {
    const now = new Date();
    return String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
  }
}
