import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'LocationTracker';

export interface TrackPoint {
  latitude: number;
  longitude: number;
  timestamp: number;
  accuracy: number;
}

export class LocationTrackerService {
  private static instance: LocationTrackerService;
  private enabled: boolean = false;
  private points: TrackPoint[] = [];
  private totalDistanceM: number = 0;
  private lastPoint: TrackPoint | null = null;
  private locationCallback: (location: geoLocationManager.Location) => void =
    this.onLocationChange.bind(this);
  private distanceListener: ((distanceM: number) => void) | null = null;

  static getInstance(): LocationTrackerService {
    if (!LocationTrackerService.instance) {
      LocationTrackerService.instance = new LocationTrackerService();
    }
    return LocationTrackerService.instance;
  }

  onDistanceChanged(listener: (distanceM: number) => void): void {
    this.distanceListener = listener;
  }

  isTracking(): boolean {
    return this.enabled;
  }

  getDistanceM(): number {
    return this.totalDistanceM;
  }

  getPointCount(): number {
    return this.points.length;
  }

  start(): void {
    if (this.enabled) {
      return;
    }
    this.points = [];
    this.totalDistanceM = 0;
    this.lastPoint = null;
    try {
      const request: geoLocationManager.ContinuousLocationRequest = {
        interval: 2,
        locationScenario: geoLocationManager.UserActivityScenario.SPORT
      };
      geoLocationManager.on('locationChange', request, this.locationCallback);
      this.enabled = true;
      hilog.info(DOMAIN, TAG, 'Location tracking started');
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'start location failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
  }

  pause(): void {
    if (!this.enabled) {
      return;
    }
    try {
      geoLocationManager.off('locationChange', this.locationCallback);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'pause location failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
    this.enabled = false;
    hilog.info(DOMAIN, TAG, 'Location tracking paused, total=%{public}d m', Math.round(this.totalDistanceM));
  }

  resume(): void {
    if (this.enabled) {
      return;
    }
    try {
      const request: geoLocationManager.ContinuousLocationRequest = {
        interval: 2,
        locationScenario: geoLocationManager.UserActivityScenario.SPORT
      };
      geoLocationManager.on('locationChange', request, this.locationCallback);
      this.enabled = true;
      hilog.info(DOMAIN, TAG, 'Location tracking resumed');
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'resume location failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
  }

  stop(): void {
    if (!this.enabled) {
      return;
    }
    try {
      geoLocationManager.off('locationChange', this.locationCallback);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'stop location failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
    this.enabled = false;
    this.distanceListener = null;
    hilog.info(DOMAIN, TAG, 'Location tracking stopped, total=%{public}d m', Math.round(this.totalDistanceM));
  }

  reset(): void {
    this.points = [];
    this.totalDistanceM = 0;
    this.lastPoint = null;
  }

  private onLocationChange(location: geoLocationManager.Location): void {
    const lat: number = location.latitude;
    const lng: number = location.longitude;
    const acc: number = location.accuracy ?? 50;
    if (lat === 0 && lng === 0) {
      return;
    }
    if (acc > 60) {
      return;
    }
    const now = Date.now();
    const point: TrackPoint = {
      latitude: lat,
      longitude: lng,
      timestamp: now,
      accuracy: acc
    };
    if (this.lastPoint !== null) {
      const dt: number = now - this.lastPoint.timestamp;
      if (dt > 10000) {
        this.lastPoint = point;
        this.points.push(point);
        return;
      }
      const d: number = this.haversineM(this.lastPoint.latitude, this.lastPoint.longitude, lat, lng);
      const dtSec: number = dt / 1000;
      // 首次定位/信号漂移防护：速度超过 40m/s（144km/h，远超骑行）视为异常点，
      // 不累计距离。若漂移持续超过 8s 则重新校准基准点，避免连续误判
      const speed: number = dtSec > 0 ? d / dtSec : Number.POSITIVE_INFINITY;
      if (speed > 40) {
        hilog.warn(DOMAIN, TAG, 'Drop drifting point, d=%{public}d m, speed=%{public}d m/s',
          Math.round(d), Math.round(speed));
        if (dt >= 8000) {
          this.lastPoint = point;
        }
        return;
      }
      if (d >= 3) {
        this.totalDistanceM += d;
        this.points.push(point);
        if (this.distanceListener !== null) {
          this.distanceListener(this.totalDistanceM);
        }
      }
    } else {
      this.points.push(point);
    }
    this.lastPoint = point;
  }

  haversineM(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371000;
    const rad = Math.PI / 180;
    const dLat = (lat2 - lat1) * rad;
    const dLng = (lng2 - lng1) * rad;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}
