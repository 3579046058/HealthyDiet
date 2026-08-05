import { describe, it, expect } from '@ohos/hypium';
import { SleepOverlap } from '../main/ets/common/SleepOverlap';

export default function sleepOverlapTest() {
  describe('SleepOverlapTest', () => {
    it('nonOverlapSameWakeDate', 0, () => {
      const a = SleepOverlap.toInterval('2026-08-04', '06:00', 480);
      const b = SleepOverlap.toInterval('2026-08-04', '10:00', 120);
      expect(SleepOverlap.intervalsOverlap(a, b)).assertFalse();
    });

    it('overlapSameWakeDate', 0, () => {
      const a = SleepOverlap.toInterval('2026-08-04', '06:00', 480);
      const b = SleepOverlap.toInterval('2026-08-04', '04:00', 240);
      expect(SleepOverlap.intervalsOverlap(a, b)).assertTrue();
    });

    it('overlapCrossMidnightContainment', 0, () => {
      const a = SleepOverlap.toInterval('2026-08-04', '07:00', 480);
      const b = SleepOverlap.toInterval('2026-08-04', '03:00', 120);
      expect(SleepOverlap.intervalsOverlap(a, b)).assertTrue();
    });

    it('adjacentNoOverlap', 0, () => {
      const a = SleepOverlap.toInterval('2026-08-04', '06:00', 480);
      const b = SleepOverlap.toInterval('2026-08-04', '10:00', 240);
      expect(SleepOverlap.intervalsOverlap(a, b)).assertFalse();
    });

    it('differentDaysNoOverlap', 0, () => {
      const a = SleepOverlap.toInterval('2026-08-04', '07:00', 480);
      const b = SleepOverlap.toInterval('2026-08-05', '07:00', 480);
      expect(SleepOverlap.intervalsOverlap(a, b)).assertFalse();
    });

    it('sameIntervalOverlap', 0, () => {
      const a = SleepOverlap.toInterval('2026-08-04', '07:00', 480);
      const b = SleepOverlap.toInterval('2026-08-04', '07:00', 480);
      expect(SleepOverlap.intervalsOverlap(a, b)).assertTrue();
    });
  });
}
