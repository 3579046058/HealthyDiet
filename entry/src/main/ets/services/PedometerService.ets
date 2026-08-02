import { sensor } from '@kit.SensorServiceKit';
import { GlobalData } from '../common/GlobalData';
import { StreakData } from '../common/Constants';
import { BusinessError } from '@kit.BasicServicesKit';

export class PedometerService {
  private static instance: PedometerService;
  private stepCallback: ((steps: number) => void) | null = null;
  private cumulativeSteps: number = 0;
  private isSubscribed: boolean = false;
  private sensorMode: string = 'none';
  private syncTimer: number = -1;

  // 加速度计步态检测状态
  private lastPeakMag: number = 0;
  private lastPeakTime: number = 0;
  private lastValleyMag: number = 999;
  private stepDetected: boolean = false;

  static getInstance(): PedometerService {
    if (!PedometerService.instance) {
      PedometerService.instance = new PedometerService();
    }
    return PedometerService.instance;
  }

  startListening(callback: (steps: number) => void): void {
    this.stepCallback = callback;
    this.cumulativeSteps = 0;
    this.resetStepDetection();

    if (!this.isSubscribed) {
      this.trySubscribePedometer();
      if (this.sensorMode === 'none') {
        this.trySubscribeAccelerometer();
      }
    }

    if (this.syncTimer === -1) {
      this.syncTimer = setInterval(() => {
        if (this.cumulativeSteps > 0) {
          this.syncStepsToDatabase(this.cumulativeSteps);
        }
      }, 60000);
    }
  }

  private trySubscribePedometer(): void {
    try {
      sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
        this.cumulativeSteps = data.steps;
        AppStorage.setOrCreate('liveSteps', this.cumulativeSteps);
        if (this.stepCallback) {
          this.stepCallback(this.cumulativeSteps);
        }
      }, { interval: 100000000 });
      this.sensorMode = 'pedometer';
      this.isSubscribed = true;
      console.info('PedometerService: using PEDOMETER sensor');
    } catch (err) {
      const error = err as BusinessError;
      console.error('Pedometer sensor error: ' + error.code + ' ' + error.message);
    }
  }

  private trySubscribeAccelerometer(): void {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        this.processAccelerometer(data);
      }, { interval: 50000000 });
      this.sensorMode = 'accelerometer';
      this.isSubscribed = true;
      console.info('PedometerService: using ACCELEROMETER step detection');
    } catch (err) {
      const error = err as BusinessError;
      console.error('Accelerometer error: ' + error.code + ' ' + error.message);
      console.error('PedometerService: no sensor available, steps will show --');
    }
  }

  private processAccelerometer(data: sensor.AccelerometerResponse): void {
    const x: number = data.x;
    const y: number = data.y;
    const z: number = data.z;
    const magnitude: number = Math.sqrt(x * x + y * y + z * z);

    const now: number = Date.now();
    const minStepInterval: number = 300;
    const highThreshold: number = 11.5;
    const lowThreshold: number = 8.0;

    if (magnitude > highThreshold) {
      if (!this.stepDetected && now - this.lastPeakTime > minStepInterval) {
        this.stepDetected = true;
        this.lastPeakTime = now;
        this.lastPeakMag = magnitude;
        this.cumulativeSteps += 1;
        AppStorage.setOrCreate('liveSteps', this.cumulativeSteps);
        if (this.stepCallback) {
          this.stepCallback(this.cumulativeSteps);
        }
      }
    } else if (magnitude < lowThreshold) {
      this.stepDetected = false;
    }
    this.lastValleyMag = magnitude;
  }

  private resetStepDetection(): void {
    this.lastPeakMag = 0;
    this.lastPeakTime = 0;
    this.lastValleyMag = 999;
    this.stepDetected = false;
  }

  stopListening(): void {
    if (this.isSubscribed) {
      try {
        if (this.sensorMode === 'pedometer') {
          sensor.off(sensor.SensorId.PEDOMETER);
        } else if (this.sensorMode === 'accelerometer') {
          sensor.off(sensor.SensorId.ACCELEROMETER);
        }
      } catch (err) {
        console.error('Sensor off error');
      }
      this.isSubscribed = false;
    }
    if (this.syncTimer !== -1) {
      clearInterval(this.syncTimer);
      this.syncTimer = -1;
    }
    this.stepCallback = null;
  }

  async syncStepsToDatabase(steps: number): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const goalConfig = await GlobalData.prefs.getGoalConfig();
      await GlobalData.db.upsertSteps(today, steps, goalConfig.dailySteps);

      await GlobalData.prefs.setStepCountToday(steps);
      const achieved = steps >= goalConfig.dailySteps;
      const streak: StreakData = await GlobalData.prefs.updateStreak(achieved);
    } catch (err) {
      console.error('PedometerService sync error:', JSON.stringify(err));
    }
  }

  getSensorMode(): string {
    return this.sensorMode;
  }

  isRunning(): boolean {
    return this.syncTimer !== -1;
  }
}
