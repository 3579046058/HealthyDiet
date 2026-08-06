import { relationalStore } from '@kit.ArkData';
import { Constants, DbRow } from '../common/Constants';
import { SleepOverlap } from '../common/SleepOverlap';
import { RecycleBinHelper, DataType } from './RecycleBinHelper';

const TABLE_DAILY = 'daily_summary';
const TABLE_WEIGHT = 'weight_records';
const TABLE_HEIGHT = 'height_records';
const TABLE_WATER = 'water_records';
const TABLE_SPORT = 'sport_records';
const TABLE_SLEEP = 'sleep_records';
const TABLE_HEART = 'heart_rate_records';
const TABLE_STEP = 'step_records';
const TABLE_DIET = 'diet_records';
const TABLE_MOOD = 'mood_records';
const TABLE_MEDICATION = 'medication_records';
const TABLE_PERIOD = 'period_records';
const TABLE_BODY_COMP = 'body_composition_records';
const TABLE_PLAN = 'workout_plans';
const TABLE_WATER_TIMELINE = 'water_timeline';
const TABLE_SLEEP_START = 'sleep_start_records';

export class DatabaseHelper {
  private rdbStore: relationalStore.RdbStore | null = null;
  public recycleBin: RecycleBinHelper = new RecycleBinHelper();
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
    await this.migrateSchema();
    await this.recycleBin.init(this.rdbStore);
  }

  // 旧库结构迁移：为已存在的表补充新增字段（列已存在时 ALTER 会报错，捕获即可）
  private async migrateSchema(): Promise<void> {
    if (!this.rdbStore) return;
    try {
      await this.rdbStore.executeSql('ALTER TABLE ' + TABLE_MEDICATION + ' ADD COLUMN reminder_ids TEXT');
    } catch (err) {
      // 列已存在，忽略
    }
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
      `CREATE TABLE IF NOT EXISTS ${TABLE_HEIGHT} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        height_cm REAL,
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
      `CREATE TABLE IF NOT EXISTS ${TABLE_DIET} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        meal_type TEXT,
        food_name TEXT,
        amount_g INTEGER,
        calories INTEGER,
        protein REAL,
        fat REAL,
        carbs REAL,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_MOOD} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        mood INTEGER,
        note TEXT,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_MEDICATION} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        dosage TEXT,
        time TEXT,
        frequency TEXT,
        start_date TEXT,
        end_date TEXT,
        reminder_ids TEXT,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_PERIOD} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT,
        end_date TEXT,
        cycle_length INTEGER,
        period_length INTEGER,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_BODY_COMP} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        body_fat REAL,
        muscle_mass REAL,
        body_water REAL,
        bone_mass REAL,
        visceral_fat REAL,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_PLAN} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        duration_weeks INTEGER,
        times_per_week INTEGER,
        exercises TEXT,
        start_date TEXT,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_WATER_TIMELINE} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        time TEXT,
        ml INTEGER,
        timestamp INTEGER
      )`,
      `CREATE TABLE IF NOT EXISTS ${TABLE_SLEEP_START} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        start_time TEXT,
        timestamp INTEGER
      )`,
    ];
    if (this.rdbStore) {
      for (const sql of tables) {
        await this.rdbStore.executeSql(sql);
      }
    }
  }

  private async getTodayDate(): Promise<string> {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

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

  async getDailySummaries(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_DAILY);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByAsc('date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

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

  async addWeightRecord(date: string, weightKg: number): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      date: date, weight_kg: weightKg, timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_WEIGHT, values);
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

  async getLatestHeight(): Promise<DbRow | null> {
    if (!this.rdbStore) return null;
    const pred = new relationalStore.RdbPredicates(TABLE_HEIGHT);
    pred.orderByDesc('timestamp');
    const result = await this.rdbStore.query(pred, ['*']);
    if (result.rowCount > 0 && result.goToFirstRow()) {
      return result.getRow();
    }
    return null;
  }

  async addHeightRecord(date: string, heightCm: number): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      date: date, height_cm: heightCm, timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_HEIGHT, values);
  }

  async getHeightRecords(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_HEIGHT);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByAsc('date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async deleteHeightRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    // 查询数据并添加到回收站（与体重一致，保证可恢复）
    const pred = new relationalStore.RdbPredicates(TABLE_HEIGHT);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.HEIGHT, id, JSON.stringify(data));
    }
    resultSet.close();
    await this.rdbStore.delete(pred);
  }

  // 从回收站恢复身高记录
  async restoreHeightRecord(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;

    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        height_cm: data.height_cm,
        date: data.date,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_HEIGHT, newData);
      return true;
    } catch (err) {
      console.error('restoreHeightRecord error:', JSON.stringify(err));
      return false;
    }
  }

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
    if (existing) {
      const currentMl = Number(existing.total_ml) || 0;
      const currentCups = Number(existing.cups) || 0;
      const values: relationalStore.ValuesBucket = {
        total_ml: currentMl + cupMl, cups: currentCups + 1, timestamp: Date.now()
      };
      const pred = new relationalStore.RdbPredicates(TABLE_WATER);
      pred.equalTo('date', date);
      await this.rdbStore.update(values, pred);
    } else {
      const values: relationalStore.ValuesBucket = {
        date: date, total_ml: cupMl, cups: 1, timestamp: Date.now()
      };
      await this.rdbStore.insert(TABLE_WATER, values);
    }
  }

  async addWaterTimeline(date: string, time: string, ml: number): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      date, time, ml, timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_WATER_TIMELINE, values);
  }

  async getWaterTimeline(date: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_WATER_TIMELINE);
    pred.equalTo('date', date);
    pred.orderByAsc('time');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async addSportRecord(record: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      date: String(record.date),
      sport_type: String(record.sport_type),
      duration_min: Number(record.duration_min),
      distance_km: Number(record.distance_km),
      calories: Number(record.calories),
      avg_heart_rate: Number(record.avg_heart_rate),
      timestamp: Date.now()
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

  async addSleepRecord(record: DbRow): Promise<boolean> {
    if (!this.rdbStore) return false;
    const overlap: boolean = await this.hasSleepOverlap(record, -1);
    if (overlap) {
      console.warn('addSleepRecord rejected: overlaps an existing sleep record');
      return false;
    }
    const values: relationalStore.ValuesBucket = {
      date: String(record.date),
      start_time: String(record.start_time),
      end_time: String(record.end_time),
      deep_sleep_min: Number(record.deep_sleep_min),
      light_sleep_min: Number(record.light_sleep_min),
      rem_min: Number(record.rem_min),
      total_minutes: Number(record.total_minutes),
      score: Number(record.score),
      timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_SLEEP, values);
    return true;
  }

  async hasSleepOverlap(record: DbRow, excludeId: number): Promise<boolean> {
    if (!this.rdbStore) return false;
    const all: DbRow[] = await this.getSleepRecords('1970-01-01', '2099-12-31');
    const target = SleepOverlap.toInterval(String(record.date), String(record.end_time), Number(record.total_minutes));
    for (let i = 0; i < all.length; i++) {
      const r: DbRow = all[i];
      if (excludeId >= 0 && Number(r.id) === excludeId) {
        continue;
      }
      const other = SleepOverlap.toInterval(String(r.date), String(r.end_time), Number(r.total_minutes));
      if (SleepOverlap.intervalsOverlap(target, other)) {
        return true;
      }
    }
    return false;
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

  // 入睡记录相关方法
  async addSleepStartRecord(date: string, startTime: string): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      date: String(date),
      start_time: String(startTime),
      timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_SLEEP_START, values);
  }

  async getLatestSleepStartRecord(): Promise<DbRow | null> {
    if (!this.rdbStore) return null;
    const pred = new relationalStore.RdbPredicates(TABLE_SLEEP_START);
    pred.orderByDesc('timestamp');
    pred.limitAs(1);
    const result = await this.rdbStore.query(pred, ['*']);
    const rows = this.readAllRows(result);
    return rows.length > 0 ? rows[0] : null;
  }

  async deleteSleepStartRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    const pred = new relationalStore.RdbPredicates(TABLE_SLEEP_START);
    pred.equalTo('id', id);
    await this.rdbStore.delete(pred);
  }

  async addDietRecord(record: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const amtNum: number = Number(record.amount_g);
    console.info('addDietRecord amount_g raw=' + String(record.amount_g) + ' num=' + String(amtNum));
    const values: relationalStore.ValuesBucket = {
      date: String(record.date),
      meal_type: String(record.meal_type),
      food_name: String(record.food_name),
      amount_g: amtNum,
      calories: Number(record.calories),
      protein: Number(record.protein),
      fat: Number(record.fat),
      carbs: Number(record.carbs),
      timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_DIET, values);
  }

  // 更新饮食记录的热量（下拉刷新重新识别未识别食物后用）
  async updateDietRecordCalories(id: number, calories: number): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      calories: calories
    };
    const pred = new relationalStore.RdbPredicates(TABLE_DIET);
    pred.equalTo('id', id);
    await this.rdbStore.update(values, pred);
  }

  async getDietRecords(date: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_DIET);
    pred.equalTo('date', date);
    pred.orderByAsc('timestamp');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async getDietRecordsRange(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_DIET);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByAsc('date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async addMoodRecord(record: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      date: String(record.date),
      mood: Number(record.mood),
      note: String(record.note),
      timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_MOOD, values);
  }

  async getMoodRecords(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_MOOD);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByAsc('date');
    pred.orderByAsc('timestamp');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async addMedicationRecord(record: DbRow): Promise<number> {
    if (!this.rdbStore) return -1;
    const values: relationalStore.ValuesBucket = {
      name: String(record.name),
      dosage: String(record.dosage),
      time: String(record.time),
      frequency: String(record.frequency),
      start_date: String(record.start_date),
      end_date: String(record.end_date),
      reminder_ids: record.reminder_ids ? String(record.reminder_ids) : '',
      timestamp: Date.now()
    };
    return await this.rdbStore.insert(TABLE_MEDICATION, values);
  }

  // 更新药品的 reminder_ids（修改闹铃后回写）
  async updateMedicationReminderIds(id: number, reminderIdsStr: string): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      reminder_ids: reminderIdsStr
    };
    const pred = new relationalStore.RdbPredicates(TABLE_MEDICATION);
    pred.equalTo('id', id);
    await this.rdbStore.update(values, pred);
  }

  async getMedicationRecords(): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_MEDICATION);
    pred.orderByDesc('timestamp');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async deleteMedicationRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    // 查询数据并添加到回收站
    const pred = new relationalStore.RdbPredicates(TABLE_MEDICATION);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.MEDICATION, id, JSON.stringify(data));
    }
    resultSet.close();
    await this.rdbStore.delete(pred);
  }

  // 从回收站恢复用药记录
  async restoreMedicationRecord(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;

    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        name: data.name,
        dosage: data.dosage,
        time: data.time,
        frequency: data.frequency,
        start_date: data.start_date,
        end_date: data.end_date,
        reminder_ids: data.reminder_ids,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_MEDICATION, newData);
      return true;
    } catch (err) {
      console.error('restoreMedicationRecord error:', JSON.stringify(err));
      return false;
    }
  }

  async addPeriodRecord(record: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      start_date: String(record.start_date),
      end_date: String(record.end_date),
      cycle_length: Number(record.cycle_length),
      period_length: Number(record.period_length),
      timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_PERIOD, values);
  }

  async getPeriodRecords(): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_PERIOD);
    pred.orderByDesc('start_date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async addBodyCompositionRecord(record: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      date: String(record.date),
      body_fat: Number(record.body_fat),
      muscle_mass: Number(record.muscle_mass),
      body_water: Number(record.body_water),
      bone_mass: Number(record.bone_mass),
      visceral_fat: Number(record.visceral_fat),
      timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_BODY_COMP, values);
  }

  async getBodyCompositionRecords(startDate: string, endDate: string): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_BODY_COMP);
    pred.greaterThanOrEqualTo('date', startDate);
    pred.lessThanOrEqualTo('date', endDate);
    pred.orderByDesc('date');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async getLatestBodyComposition(): Promise<DbRow | null> {
    if (!this.rdbStore) return null;
    const pred = new relationalStore.RdbPredicates(TABLE_BODY_COMP);
    pred.orderByDesc('timestamp');
    const result = await this.rdbStore.query(pred, ['*']);
    if (result.rowCount > 0 && result.goToFirstRow()) {
      return result.getRow();
    }
    return null;
  }

  async addWorkoutPlan(record: DbRow): Promise<void> {
    if (!this.rdbStore) return;
    const values: relationalStore.ValuesBucket = {
      name: String(record.name),
      duration_weeks: Number(record.duration_weeks),
      times_per_week: Number(record.times_per_week),
      exercises: String(record.exercises),
      start_date: String(record.start_date),
      timestamp: Date.now()
    };
    await this.rdbStore.insert(TABLE_PLAN, values);
  }

  async getWorkoutPlans(): Promise<DbRow[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(TABLE_PLAN);
    pred.orderByDesc('timestamp');
    const result = await this.rdbStore.query(pred, ['*']);
    return this.readAllRows(result);
  }

  async deleteWeightRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    
    // 查询数据并添加到回收站
    const pred = new relationalStore.RdbPredicates(TABLE_WEIGHT);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.WEIGHT, id, JSON.stringify(data));
    }
    resultSet.close();
    
    // 删除原数据
    await this.rdbStore.delete(pred);
  }

  async deleteSportRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    
    // 查询数据并添加到回收站
    const pred = new relationalStore.RdbPredicates(TABLE_SPORT);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.SPORT, id, JSON.stringify(data));
    }
    resultSet.close();
    
    // 删除原数据
    await this.rdbStore.delete(pred);
  }

  async deleteSleepRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    
    // 查询数据并添加到回收站
    const pred = new relationalStore.RdbPredicates(TABLE_SLEEP);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.SLEEP, id, JSON.stringify(data));
    }
    resultSet.close();
    
    // 删除原数据
    await this.rdbStore.delete(pred);
  }

  async deleteDietRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    
    // 查询数据并添加到回收站
    const pred = new relationalStore.RdbPredicates(TABLE_DIET);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.DIET, id, JSON.stringify(data));
    }
    resultSet.close();
    
    // 删除原数据
    await this.rdbStore.delete(pred);
  }

  async deleteMoodRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    console.info('DatabaseHelper deleteMoodRecord id=' + String(id));
    
    // 查询数据并添加到回收站
    const pred = new relationalStore.RdbPredicates(TABLE_MOOD);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.MOOD, id, JSON.stringify(data));
    }
    resultSet.close();
    
    // 删除原数据
    const rows = await this.rdbStore.delete(pred);
    console.info('DatabaseHelper deleteMoodRecord deleted rows=' + String(rows));
  }

  async deletePeriodRecord(id: number): Promise<void> {
    if (!this.rdbStore) return;
    
    // 查询数据并添加到回收站
    const pred = new relationalStore.RdbPredicates(TABLE_PERIOD);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.PERIOD, id, JSON.stringify(data));
    }
    resultSet.close();
    
    // 删除原数据
    await this.rdbStore.delete(pred);
  }

  async deleteWaterTimelineItem(id: number): Promise<void> {
    if (!this.rdbStore) return;
    
    // 查询数据并添加到回收站
    const pred = new relationalStore.RdbPredicates(TABLE_WATER_TIMELINE);
    pred.equalTo('id', id);
    const resultSet = await this.rdbStore.query(pred);
    if (resultSet.goToFirstRow()) {
      const data = resultSet.getRow();
      await this.recycleBin.addToRecycleBin(DataType.WATER, id, JSON.stringify(data));
    }
    resultSet.close();
    
    // 删除原数据
    await this.rdbStore.delete(pred);
  }

  async upsertSteps(date: string, steps: number, goal: number): Promise<void> {
    if (!this.rdbStore) return;
    const pred = new relationalStore.RdbPredicates(TABLE_STEP);
    pred.equalTo('date', date);
    const result = await this.rdbStore.query(pred, ['*']);
    if (result.rowCount > 0) {
      const values: relationalStore.ValuesBucket = {
        total_steps: steps, goal_steps: goal, timestamp: Date.now()
      };
      await this.rdbStore.update(values, pred);
    } else {
      const values: relationalStore.ValuesBucket = {
        date: date, total_steps: steps, goal_steps: goal, timestamp: Date.now()
      };
      await this.rdbStore.insert(TABLE_STEP, values);
    }
    await this.upsertDailySummary({ date: date, steps: steps });
  }

  async updateDailySummaryField(date: string, field: string, value: number): Promise<void> {
    if (!this.rdbStore) return;
    const existing = await this.getDailySummary(date);
    const updates: relationalStore.ValuesBucket = {};
    updates[field] = value;
    if (existing) {
      const pred = new relationalStore.RdbPredicates(TABLE_DAILY);
      pred.equalTo('date', date);
      await this.rdbStore.update(updates, pred);
    } else {
      const values: relationalStore.ValuesBucket = { date: date };
      values[field] = value;
      await this.rdbStore.insert(TABLE_DAILY, values);
    }
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

  // 恢复数据方法
  async restoreWeightRecord(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;
    
    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        weight: data.weight,
        date: data.date,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_WEIGHT, newData);
      return true;
    } catch (e) {
      console.error('Failed to restore weight record:', e);
      return false;
    }
  }

  async restoreSportRecord(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;
    
    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        name: data.name,
        duration: data.duration,
        calories: data.calories,
        date: data.date,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_SPORT, newData);
      return true;
    } catch (e) {
      console.error('Failed to restore sport record:', e);
      return false;
    }
  }

  async restoreSleepRecord(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;
    
    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        start_time: data.start_time,
        end_time: data.end_time,
        duration: data.duration,
        quality: data.quality,
        date: data.date,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_SLEEP, newData);
      return true;
    } catch (e) {
      console.error('Failed to restore sleep record:', e);
      return false;
    }
  }

  async restoreDietRecord(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;
    
    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        meal_type: data.meal_type,
        food_name: data.food_name,
        calories: data.calories,
        protein: data.protein,
        carbs: data.carbs,
        fat: data.fat,
        date: data.date,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_DIET, newData);
      return true;
    } catch (e) {
      console.error('Failed to restore diet record:', e);
      return false;
    }
  }

  async restoreMoodRecord(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;
    
    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        mood: data.mood,
        note: data.note,
        date: data.date,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_MOOD, newData);
      return true;
    } catch (e) {
      console.error('Failed to restore mood record:', e);
      return false;
    }
  }

  async restorePeriodRecord(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;
    
    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        start_date: data.start_date,
        end_date: data.end_date,
        cycle_length: data.cycle_length,
        period_length: data.period_length,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_PERIOD, newData);
      return true;
    } catch (e) {
      console.error('Failed to restore period record:', e);
      return false;
    }
  }

  async restoreWaterTimelineItem(recycleBinId: number): Promise<boolean> {
    const dataContent = await this.recycleBin.restoreFromRecycleBin(recycleBinId);
    if (!dataContent || !this.rdbStore) return false;
    
    try {
      const data = JSON.parse(dataContent) as relationalStore.ValuesBucket;
      const newData: relationalStore.ValuesBucket = {
        date: data.date,
        time: data.time,
        amount: data.amount,
        timestamp: data.timestamp
      };
      await this.rdbStore.insert(TABLE_WATER_TIMELINE, newData);
      return true;
    } catch (e) {
      console.error('Failed to restore water timeline item:', e);
      return false;
    }
  }
}
