import { sensor } from '@kit.SensorServiceKit';
import { GlobalData } from '../common/GlobalData';
import { StreakData } from '../common/Constants';
import { BusinessError } from '@kit.BasicServicesKit';

export class PedometerService {
  private static instance: PedometerService;
  private stepCallback: ((steps: number) => void) | null = null;
  private cumulativeSteps: number = 0;
  private baseSteps: number = 0; // 当日步数基准（PEDOMETER 累计值 - 基准 = 今日步数）
  private isSubscribed: boolean = false;
  private sensorMode: string = 'none';
  private syncTimer: number = -1;

  // 加速度计步态检测状态
  private lastPeakMag: number = 0;
  private lastPeakTime: number = 0;
  private lastValleyMag: number = 999;
  private lastValleyTime: number = 0;
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
    // 加载当日基准（首次或跨天时设置）
    this.loadBaseSteps();

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

  // 加载当日步数基准：跨天时重置（新的一天基准=当前累计，今日步数从0开始）
  private async loadBaseSteps(): Promise<void> {
    try {
      const today: string = await GlobalData.getTodayDate();
      const baseDateRaw: string | number | boolean = await GlobalData.prefs.get('step_base_date', '');
      const baseRaw: string | number | boolean = await GlobalData.prefs.get('step_base_value', '0');
      if (String(baseDateRaw) !== today) {
        // 跨天：基准先保留（等 PEDOMETER 首次数据到后更新），今日步数从 0 开始
        this.baseSteps = 0;
        await GlobalData.prefs.put('step_base_date', today);
        await GlobalData.prefs.put('step_base_value', '0');
        await GlobalData.prefs.flush();
      } else {
        this.baseSteps = Number(baseRaw) || 0;
      }
    } catch (err) {
      console.error('PedometerService loadBaseSteps error:', JSON.stringify(err));
    }
  }

  private trySubscribePedometer(): void {
    try {
      sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
        const totalSteps: number = data.steps;
        // PEDOMETER 返回当前步数（模拟器/多数设备为今日步数语义），直接使用
        this.cumulativeSteps = totalSteps;
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

  // 加速度计步态检测（改进版：需要完整的峰-谷-峰周期 + 幅度差 + 时间窗口，过滤车震等非步行震动）
  private processAccelerometer(data: sensor.AccelerometerResponse): void {
    const x: number = data.x;
    const y: number = data.y;
    const z: number = data.z;
    const magnitude: number = Math.sqrt(x * x + y * y + z * z);
    const now: number = Date.now();

    // 1. 追踪波峰：幅度超过重力+阈值，且比上一峰值更高
    const highThreshold: number = 10.5; // 略高于重力(9.8)
    const lowThreshold: number = 9.0;   // 波谷阈值

    if (magnitude > highThreshold) {
      if (magnitude > this.lastPeakMag) {
        this.lastPeakMag = magnitude;
        this.lastPeakTime = now;
      }
    }

    // 2. 检测波谷：幅度回落到 lowThreshold 以下
    if (magnitude < lowThreshold) {
      // 波谷出现，且之前有波峰 → 完成一个步伐周期
      const peakMag: number = this.lastPeakMag;
      if (peakMag > highThreshold && !this.stepDetected) {
        const amp: number = peakMag - magnitude;
        // 3. 幅度差足够（>1.5，真实步幅；车震幅度通常较小或频率过高）
        const minStepInterval: number = 350; // 最小步间隔 ms（≈170步/分钟上限）
        const maxStepInterval: number = 1200; // 最大步间隔 ms（正常步行频率下限）
        const interval: number = now - this.lastPeakTime;
        if (amp > 1.5 && interval >= minStepInterval && interval <= maxStepInterval) {
          this.cumulativeSteps += 1;
          AppStorage.setOrCreate('liveSteps', this.cumulativeSteps);
          if (this.stepCallback) {
            this.stepCallback(this.cumulativeSteps);
          }
          this.stepDetected = true;
        }
      }
      // 重置波峰检测
      this.lastPeakMag = 0;
      this.lastPeakTime = 0;
      // 波谷后允许下一个步伐
      if (now - this.lastValleyTime > 500) {
        this.stepDetected = false;
      }
      this.lastValleyTime = now;
    }
  }

  private resetStepDetection(): void {
    this.lastPeakMag = 0;
    this.lastPeakTime = 0;
    this.lastValleyMag = 999;
    this.lastValleyTime = 0;
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
