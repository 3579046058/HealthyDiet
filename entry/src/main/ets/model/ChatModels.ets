export class ChatRole {
  static readonly SYSTEM: string = 'system';
  static readonly USER: string = 'user';
  static readonly ASSISTANT: string = 'assistant';
}

@ObservedV2
export class ChatMessage {
  id: number = 0;
  role: string = ChatRole.ASSISTANT;
  @Trace content: string = '';
  @Trace isError: boolean = false;
  @Trace isThinking: boolean = false;
  @Trace isSearching: boolean = false;
}

export class ChatHistoryItem {
  role: string = ChatRole.ASSISTANT;
  content: string = '';
}

export class ChatSession {
  id: string = '';
  title: string = '';
  messages: Array<ChatHistoryItem> = [];
  updatedAt: number = 0;
}
