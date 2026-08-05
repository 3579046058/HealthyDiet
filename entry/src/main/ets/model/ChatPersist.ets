import { preferences } from '@kit.ArkData';
import { ChatHistoryItem, ChatRole, ChatSession } from './ChatModels';

const KEY_SESSIONS = 'chat_sessions_v1';
const KEY_CURRENT_SESSION = 'chat_current_session';
const KEY_LEGACY_HISTORY = 'chat_history_v1';

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

  async loadSessions(): Promise<Array<ChatSession>> {
    const result: Array<ChatSession> = [];
    try {
      const json: string = await this.pref.get(KEY_SESSIONS, '') as string;
      if (json.length === 0) {
        return result;
      }
      const rawList = JSON.parse(json) as Array<Record<string, Object>>;
      for (let i = 0; i < rawList.length; i++) {
        const raw: Record<string, Object> = rawList[i];
        const session: ChatSession = new ChatSession();
        session.id = String(raw['id'] ?? '');
        session.title = String(raw['title'] ?? '');
        session.updatedAt = Number(raw['updatedAt'] ?? 0);
        const rawMessages = raw['messages'];
        if (rawMessages !== undefined) {
          const msgList = rawMessages as Array<Record<string, Object>>;
          for (let j = 0; j < msgList.length; j++) {
            const item: ChatHistoryItem = new ChatHistoryItem();
            item.role = String(msgList[j]['role'] ?? ChatRole.ASSISTANT);
            item.content = String(msgList[j]['content'] ?? '');
            if (item.content.length > 0) {
              session.messages.push(item);
            }
          }
        }
        if (session.id.length > 0) {
          result.push(session);
        }
      }
    } catch (err) {
      console.error('ChatPersist loadSessions error:', JSON.stringify(err));
    }
    return result;
  }

  async saveSessions(sessions: Array<ChatSession>): Promise<void> {
    try {
      await this.pref.put(KEY_SESSIONS, JSON.stringify(sessions));
      await this.pref.flush();
    } catch (err) {
      console.error('ChatPersist saveSessions error:', JSON.stringify(err));
    }
  }

  async getCurrentSessionId(): Promise<string> {
    try {
      return await this.pref.get(KEY_CURRENT_SESSION, '') as string;
    } catch (err) {
      return '';
    }
  }

  async setCurrentSessionId(id: string): Promise<void> {
    try {
      await this.pref.put(KEY_CURRENT_SESSION, id);
      await this.pref.flush();
    } catch (err) {
      console.error('ChatPersist setCurrentSessionId error:', JSON.stringify(err));
    }
  }

  async loadLegacyHistory(): Promise<Array<ChatHistoryItem>> {
    const result: Array<ChatHistoryItem> = [];
    try {
      const json: string = await this.pref.get(KEY_LEGACY_HISTORY, '') as string;
      if (json.length === 0) {
        return result;
      }
      const rawList = JSON.parse(json) as Array<Record<string, Object>>;
      for (let i = 0; i < rawList.length; i++) {
        const item: ChatHistoryItem = new ChatHistoryItem();
        item.role = String(rawList[i]['role'] ?? ChatRole.ASSISTANT);
        item.content = String(rawList[i]['content'] ?? '');
        if (item.content.length > 0) {
          result.push(item);
        }
      }
    } catch (err) {
      console.error('ChatPersist loadLegacyHistory error:', JSON.stringify(err));
    }
    return result;
  }

  async clearLegacyHistory(): Promise<void> {
    try {
      await this.pref.put(KEY_LEGACY_HISTORY, '');
      await this.pref.flush();
    } catch (err) {
      console.error('ChatPersist clearLegacyHistory error:', JSON.stringify(err));
    }
  }
}
