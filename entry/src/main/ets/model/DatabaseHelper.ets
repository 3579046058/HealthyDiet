import { relationalStore } from '@kit.ArkData';
import { Constants, DbRow } from '../common/Constants';

const TABLE_DAILY = 'daily_summary';
const TABLE_WEIGHT = 'weight_records';
const TABLE_WATER = 'water_records';
const TABLE_SPORT = 'sport_records';
const TABLE_SLEEP = 'sleep_records';
const TABLE_HEART = 'heart_rate_records';
const TABLE_STEP = 'step_records';

export class DatabaseHelper {
  private rdbStore: relationalStore.RdbStore | null = null;
  private context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  async init(): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: Constants.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
    };
    this.rdbStore = await relationalStore.getRdbStore(this.context, config);
    await this.createTables();
  }

  private async createTables(): Promise<void> {
    const tables = [
      `CREATE TABLE IF NOT EXISTS ${TABLE_DAILY} (
        date TEXT PRIMARY KEY,
        steps INTEGER DEFAULT 0,
        heart_rate_avg INTEGER DEFAULT 72,
        sleep_score INTEGER DEFAULT 0,
        sleep_hours REAL DEFAULT 0,
        water_ml INTEGER DEFAULT 0,
        calories_burned INTEGER DEFAULT 0,
        exercise_minutes INTEGER DEFAULT 0,
        stand_hours INTEGER DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_WEIGHT} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        weight_kg REAL,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_WATER} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        total_ml INTEGER DEFAULT 0,
        cups INTEGER DEFAULT 0,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_SPORT} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        sport_type TEXT,
        duration_min INTEGER,
        distance_km REAL,
        calories INTEGER,
        avg_heart_rate INTEGER,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_SLEEP} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        start_time TEXT,
        end_time TEXT,
        deep_sleep_min INTEGER,
        light_sleep_min INTEGER,
        rem_min INTEGER,
        total_minutes INTEGER,
        score INTEGER,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_HEART} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        timestamp INTEGER,
        bpm INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_STEP} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        total_steps INTEGER,
        goal_steps INTEGER,
        timestamp INTEGER
      )`,
    ];

    if (this.rdbStore) {
      for (const sql of tables) {
        await this.rdbStore.executeSql(sql);
      }
    }
  }

  // === Daily Summary ===
  async getDailySummary(date: string): Promise<DbRow | null> {
    if (!this.rdbStore) return null;
    const pred = new relationalStore.RdbPredicates(TABLE_DAILY);
    pred.equalTo('date', date);
    const result = await this.rdbStore.query(pred, ['*']);
    if (result.rowCount > 0 && result.goToFirstRow()) {
      return result.getRow();
    }
    return null;
  }

  async upsertDailySummary(summary: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const existing = await this.getDailySummary(String(summary.date));
    if (existing) {
      const pred = new relationalStore.RdbPredicates(TABLE_DAILY);
      pred.equalTo('date', String(summary.date));
      await this.rdbStore.update(summary, pred);
    } else {
      await this.rdbStore.insert(TABLE_DAILY, summary);
    }
  }

  // === Weight ===
  async getLatestWeight(): Promise<DbRow | null> {
    if (!this.rdbStore) return null;
    const pred = new relationalStore.RdbPredicates(TABLE_WEIGHT);
    pred.orderByDesc('timestamp');
    const result = await this.rdbStore.query(pred, ['*']);
    if (result.rowCount > 0 && result.goToFirstRow()) {
      return result.getRow();
    }
    return null;
  }

  async insertWeight(weightKg: number): Promise<void> {
    if (!this.rdbStore) return;
    const now = Date.now();
    const today = await this.getTodayDate();
    const values: relationalStore.ValuesBucket = {
      date: today,
      weight_kg: weightKg,
      timestamp: now
    };
    await this.rdbStore.insert(TABLE_WEIGHT, values);
  }

  // === Water ===
  async getWaterRecord(date: string): Promise<DbRow | null> {
    if (!this.rdbStore) return null;
    const pred = new relationalStore.RdbPredicates(TABLE_WATER);
    pred.equalTo('date', date);
    const result = await this.rdbStore.query(pred, ['*']);
    if (result.rowCount > 0 && result.goToFirstRow()) {
      return result.getRow();
    }
    return null;
  }

  async addWaterCup(date: string, cupMl: number): Promise<void> {
    if (!this.rdbStore) return;
    const existing = await this.getWaterRecord(date);
    const now = Date.now();

    if (existing) {
      const currentMl = Number(existing.total_ml) || 0;
      const currentCups = Number(existing.cups) || 0;
      const waterMl = currentMl + cupMl;
      const cups = currentCups + 1;
      const values: relationalStore.ValuesBucket = {
        total_ml: waterMl,
        cups: cups,
        timestamp: now
      };
      const pred = new relationalStore.RdbPredicates(TABLE_WATER);
      pred.equalTo('date', date);
      await this.rdbStore.update(values, pred);
    } else {
      const values: relationalStore.ValuesBucket = {
        date: date,
        total_ml: cupMl,
        cups: 1,
        timestamp: now
      };
      await this.rdbStore.insert(TABLE_WATER, values);
    }
  }

  // === Sport ===
  async insertSportRecord(record: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const now = Date.now();
    const values: relationalStore.ValuesBucket = {
      date: String(record.date),
      sport_type: String(record.sport_type),
      duration_min: Number(record.duration_min),
      distance_km: Number(record.distance_km),
      calories: Number(record.calories),
      avg_heart_rate: Number(record.avg_heart_rate),
      timestamp: now
    };
    await this.rdbStore.insert(TABLE_SPORT, values);
  }

  async getSportRecords(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_SPORT);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByDesc('date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  // === Sleep ===
  async getSleepRecord(date: string): Promise<DbRow | null> {
    if (!this.rdbStore) return null;
    const pred = new relationalStore.RdbPredicates(TABLE_SLEEP);
    pred.equalTo('date', date);
    const result = await this.rdbStore.query(pred, ['*']);
    if (result.rowCount > 0 && result.goToFirstRow()) {
      return result.getRow();
    }
    return null;
  }

  async upsertSleepRecord(record: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const existing = await this.getSleepRecord(String(record.date));
    const now = Date.now();
    const values: relationalStore.ValuesBucket = {
      date: String(record.date),
      start_time: String(record.start_time),
      end_time: String(record.end_time),
      deep_sleep_min: Number(record.deep_sleep_min),
      light_sleep_min: Number(record.light_sleep_min),
      rem_min: Number(record.rem_min),
      total_minutes: Number(record.total_minutes),
      score: Number(record.score),
      timestamp: now
    };

    if (existing) {
      const pred = new relationalStore.RdbPredicates(TABLE_SLEEP);
      pred.equalTo('date', String(record.date));
      await this.rdbStore.update(values, pred);
    } else {
      await this.rdbStore.insert(TABLE_SLEEP, values);
    }
  }

  // === Heart Rate ===
  async insertHeartRate(date: string, bpm: number): Promise<void> {
    if (!this.rdbStore) return;
    const now = Date.now();
    const values: relationalStore.ValuesBucket = {
      date: date,
      timestamp: now,
      bpm: bpm
    };
    await this.rdbStore.insert(TABLE_HEART, values);
  }

  async getHeartRates(date: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_HEART);
    pred.equalTo('date', date);
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  // === Steps ===
  async upsertSteps(date: string, steps: number, goal: number): Promise<void> {
    if (!this.rdbStore) return;
    const existing = await this.getStepRecord(date);
    const now = Date.now();
    const values: relationalStore.ValuesBucket = {
      date: date,
      total_steps: steps,
      goal_steps: goal,
      timestamp: now
    };

    if (existing) {
      const pred = new relationalStore.RdbPredicates(TABLE_STEP);
      pred.equalTo('date', date);
      await this.rdbStore.update(values, pred);
    } else {
      await this.rdbStore.insert(TABLE_STEP, values);
    }
  }

  async getStepRecord(date: string): Promise<DbRow | null> {
    if (!this.rdbStore) return null;
    const pred = new relationalStore.RdbPredicates(TABLE_STEP);
    pred.equalTo('date', date);
    const result = await this.rdbStore.query(pred, ['*']);
    if (result.rowCount > 0 && result.goToFirstRow()) {
      return result.getRow();
    }
    return null;
  }

  // === Helpers ===
  private async getTodayDate(): Promise<string> {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  private readAllRows(resultSet: relationalStore.ResultSet): DbRow[] {
    const rows: DbRow[] = [];
    if (resultSet.rowCount > 0 && resultSet.goToFirstRow()) {
      do {
        rows.push(resultSet.getRow());
      } while (resultSet.goToNextRow());
    }
    return rows;
  }

  // === Compatibility methods for pages ===
  async getDailySummaries(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_DAILY);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByAsc('date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async addWeightRecord(date: string, weightKg: number): Promise<void> {
    await this.insertWeight(weightKg);
  }

  async getWeightRecords(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_WEIGHT);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByAsc('date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async addSportRecord(record: DbRow): Promise<void> {
    await this.insertSportRecord(record);
  }

  async addSleepRecord(record: DbRow): Promise<void> {
    await this.upsertSleepRecord(record);
  }

  async getSleepRecords(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_SLEEP);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByDesc('date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async addHeartRateRecord(date: string, bpm: number): Promise<void> {
    await this.insertHeartRate(date, bpm);
  }

  async updateStepCount(date: string, steps: number, goal: number): Promise<void> {
    await this.upsertSteps(date, steps, goal);
  }
}
