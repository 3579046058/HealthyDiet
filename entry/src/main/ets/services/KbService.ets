import { util } from '@kit.ArkTS';

export class KbChunk {
  source: string = '';
  title: string = '';
  content: string = '';
  score: number = 0;
}

export class KbService {
  private static instance: KbService;
  private static readonly KB_DIR: string = 'kb/';
  private static readonly KB_FILES: Array<string> = [
    'app_guide.md',
    'diet_guide.md',
    'sleep_guide.md',
    'exercise_guide.md'
  ];
  private chunks: Array<KbChunk> = [];
  private loaded: boolean = false;
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  static getInstance(): KbService {
    if (!KbService.instance) {
      KbService.instance = new KbService();
    }
    return KbService.instance;
  }

  async init(context: Context): Promise<void> {
    if (this.loaded) {
      return;
    }
    const all: Array<KbChunk> = [];
    for (let i = 0; i < KbService.KB_FILES.length; i++) {
      const fileName: string = KbService.KB_FILES[i];
      try {
        const data: Uint8Array = await context.resourceManager.getRawFileContent(KbService.KB_DIR + fileName);
        const text: string = this.decoder.decodeToString(data);
        const parsed: Array<KbChunk> = this.parseMarkdown(fileName, text);
        for (let j = 0; j < parsed.length; j++) {
          all.push(parsed[j]);
        }
      } catch (err) {
        console.error('KbService load ' + fileName + ' error:', JSON.stringify(err));
      }
    }
    this.chunks = all;
    this.loaded = true;
    console.info('KbService loaded, chunks=' + String(this.chunks.length));
  }

  private parseMarkdown(fileName: string, text: string): Array<KbChunk> {
    const result: Array<KbChunk> = [];
    const lines: Array<string> = text.split('\n');
    let title: string = fileName;
    let buffer: string = '';
    for (let i = 0; i < lines.length; i++) {
      const line: string = lines[i].trim();
      if (line.startsWith('# ') && title === fileName) {
        title = line.substring(2).trim();
      }
      if (line.length === 0) {
        this.flushChunk(result, fileName, title, buffer);
        buffer = '';
        continue;
      }
      buffer += line + '\n';
      if (buffer.length > 300) {
        this.flushChunk(result, fileName, title, buffer);
        buffer = '';
      }
    }
    this.flushChunk(result, fileName, title, buffer);
    return result;
  }

  private flushChunk(result: Array<KbChunk>, fileName: string, title: string, buffer: string): void {
    const content: string = buffer.trim();
    if (content.length === 0) {
      return;
    }
    const chunk: KbChunk = new KbChunk();
    chunk.source = fileName;
    chunk.title = title;
    chunk.content = content;
    result.push(chunk);
  }

  search(query: string, limit: number): Array<KbChunk> {
    const result: Array<KbChunk> = [];
    const trimmed: string = query.trim();
    if (trimmed.length === 0 || this.chunks.length === 0) {
      return result;
    }
    const terms: Array<string> = this.extractTerms(trimmed);
    if (terms.length === 0) {
      return result;
    }
    const scored: Array<KbChunk> = [];
    for (let i = 0; i < this.chunks.length; i++) {
      const chunk: KbChunk = this.chunks[i];
      const text: string = chunk.title + '\n' + chunk.content;
      let score: number = 0;
      for (let j = 0; j < terms.length; j++) {
        const term: string = terms[j];
        if (text.indexOf(term) >= 0) {
          score += term.length >= 3 ? 2 : 1;
        }
      }
      if (score > 0) {
        const hit: KbChunk = new KbChunk();
        hit.source = chunk.source;
        hit.title = chunk.title;
        hit.content = chunk.content;
        hit.score = score;
        scored.push(hit);
      }
    }
    scored.sort((a: KbChunk, b: KbChunk): number => b.score - a.score);
    const count: number = scored.length < limit ? scored.length : limit;
    for (let i = 0; i < count; i++) {
      result.push(scored[i]);
    }
    return result;
  }

  private extractTerms(query: string): Array<string> {
    const result: Array<string> = [];
    const re: RegExp = new RegExp('[^0-9a-zA-Z\\u4e00-\\u9fa5]+');
    const words: Array<string> = query.split(re);
    for (let i = 0; i < words.length; i++) {
      const word: string = words[i].trim();
      if (word.length >= 2 && result.indexOf(word) < 0) {
        result.push(word);
      }
    }
    for (let i = 0; i < query.length - 1; i++) {
      const c1: number = query.charCodeAt(i);
      const c2: number = query.charCodeAt(i + 1);
      if (c1 >= 0x4e00 && c1 <= 0x9fa5 && c2 >= 0x4e00 && c2 <= 0x9fa5) {
        const bigram: string = query.substring(i, i + 2);
        if (result.indexOf(bigram) < 0) {
          result.push(bigram);
        }
      }
    }
    return result;
  }
}
