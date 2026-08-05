import { preferences } from '@kit.ArkData';
import { ChatHistoryItem, ChatRole } from './ChatModels';

const KEY_CHAT_HISTORY = 'chat_history_v1';

export class ChatPersist {
  private pref_: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    this.pref_ = await preferences.getPreferences(context, 'chat_prefs');
  }

  private get pref(): preferences.Preferences {
    if (!this.pref_) {
      throw new Error('ChatPersist not initialized');
    }
    return this.pref_;
  }

  async saveSession(messages: Array<ChatHistoryItem>): Promise<void> {
    try {
      const json: string = JSON.stringify(messages);
      await this.pref.put(KEY_CHAT_HISTORY, json);
      await this.pref.flush();
    } catch (err) {
      console.error('ChatPersist save error:', JSON.stringify(err));
    }
  }

  async loadSession(): Promise<Array<ChatHistoryItem>> {
    const result: Array<ChatHistoryItem> = [];
    try {
      const json: string = await this.pref.get(KEY_CHAT_HISTORY, '') as string;
      if (json.length === 0) {
        return result;
      }
      const rawList = JSON.parse(json) as Array<Record<string, Object>>;
      for (let i = 0; i < rawList.length; i++) {
        const item = new ChatHistoryItem();
        item.role = String(rawList[i]['role'] ?? ChatRole.ASSISTANT);
        item.content = String(rawList[i]['content'] ?? '');
        if (item.content.length > 0) {
          result.push(item);
        }
      }
    } catch (err) {
      console.error('ChatPersist load error:', JSON.stringify(err));
    }
    return result;
  }

  async clearSession(): Promise<void> {
    try {
      await this.pref.put(KEY_CHAT_HISTORY, '');
      await this.pref.flush();
    } catch (err) {
      console.error('ChatPersist clear error:', JSON.stringify(err));
    }
  }
}
