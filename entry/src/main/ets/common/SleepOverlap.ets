export class SleepInterval {
  startMs: number;
  endMs: number;

  constructor(startMs: number, endMs: number) {
    this.startMs = startMs;
    this.endMs = endMs;
  }
}

export class SleepOverlap {
  static toInterval(date: string, endTime: string, totalMinutes: number): SleepInterval {
    const endMs: number = Date.parse(date + 'T' + endTime + ':00');
    const startMs: number = endMs - totalMinutes * 60000;
    return new SleepInterval(startMs, endMs);
  }

  static intervalsOverlap(a: SleepInterval, b: SleepInterval): boolean {
    return a.startMs < b.endMs && b.startMs < a.endMs;
  }
}
