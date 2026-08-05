import { relationalStore } from '@kit.ArkData';

const TABLE_RECYCLE_BIN = 'recycle_bin';
const EXPIRE_DAYS = 3; // 3天后过期

export enum DataType {
  WEIGHT = 'weight',
  HEIGHT = 'height',
  SPORT = 'sport',
  SLEEP = 'sleep',
  DIET = 'diet',
  MOOD = 'mood',
  MEDICATION = 'medication',
  PERIOD = 'period',
  WATER = 'water',
  HEART = 'heart',
  STEP = 'step'
}

export interface RecycleBinItem {
  id: number;
  dataType: string;
  originalId: number;
  dataContent: string;
  deletedTime: number;
  expireTime: number;
  userId?: number;
}

export class RecycleBinHelper {
  private rdbStore: relationalStore.RdbStore | null = null;

  async init(rdbStore: relationalStore.RdbStore): Promise<void> {
    this.rdbStore = rdbStore;
    await this.createTable();
    await this.cleanExpiredItems();
  }

  private async createTable(): Promise<void> {
    if (!this.rdbStore) return;
    
    const sql = `CREATE TABLE IF NOT EXISTS ${TABLE_RECYCLE_BIN} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      data_type TEXT NOT NULL,
      original_id INTEGER NOT NULL,
      data_content TEXT NOT NULL,
      deleted_time INTEGER NOT NULL,
      expire_time INTEGER NOT NULL,
      user_id INTEGER
    )`;
    
    await this.rdbStore.executeSql(sql);
  }

  async addToRecycleBin(
    dataType: DataType,
    originalId: number,
    dataContent: string,
    userId?: number
  ): Promise<number> {
    if (!this.rdbStore) return -1;

    const now = Date.now();
    const expireTime = now + EXPIRE_DAYS * 24 * 60 * 60 * 1000;

    const valueBucket: relationalStore.ValuesBucket = {
      data_type: dataType,
      original_id: originalId,
      data_content: dataContent,
      deleted_time: now,
      expire_time: expireTime,
      user_id: userId ?? null
    };

    const rowId = await this.rdbStore.insert(TABLE_RECYCLE_BIN, valueBucket);
    return rowId;
  }

  async restoreFromRecycleBin(id: number): Promise<string | null> {
    if (!this.rdbStore) return null;

    const predicates = new relationalStore.RdbPredicates(TABLE_RECYCLE_BIN);
    predicates.equalTo('id', id);

    const resultSet = await this.rdbStore.query(predicates);
    if (resultSet.goToFirstRow()) {
      const dataContent = resultSet.getString(resultSet.getColumnIndex('data_content'));
      resultSet.close();
      
      await this.rdbStore.delete(predicates);
      return dataContent;
    }
    
    resultSet.close();
    return null;
  }

  async permanentlyDelete(id: number): Promise<void> {
    if (!this.rdbStore) return;

    const predicates = new relationalStore.RdbPredicates(TABLE_RECYCLE_BIN);
    predicates.equalTo('id', id);
    
    await this.rdbStore.delete(predicates);
  }

  async getAllItems(): Promise<RecycleBinItem[]> {
    if (!this.rdbStore) return [];

    const predicates = new relationalStore.RdbPredicates(TABLE_RECYCLE_BIN);
    predicates.orderByDesc('deleted_time');

    const resultSet = await this.rdbStore.query(predicates);
    const items: RecycleBinItem[] = [];

    while (resultSet.goToNextRow()) {
      items.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        dataType: resultSet.getString(resultSet.getColumnIndex('data_type')),
        originalId: resultSet.getLong(resultSet.getColumnIndex('original_id')),
        dataContent: resultSet.getString(resultSet.getColumnIndex('data_content')),
        deletedTime: resultSet.getLong(resultSet.getColumnIndex('deleted_time')),
        expireTime: resultSet.getLong(resultSet.getColumnIndex('expire_time')),
        userId: resultSet.isColumnNull(resultSet.getColumnIndex('user_id')) 
          ? undefined 
          : resultSet.getLong(resultSet.getColumnIndex('user_id'))
      });
    }

    resultSet.close();
    return items;
  }

  async getItemsByType(dataType: DataType): Promise<RecycleBinItem[]> {
    if (!this.rdbStore) return [];

    const predicates = new relationalStore.RdbPredicates(TABLE_RECYCLE_BIN);
    predicates.equalTo('data_type', dataType);
    predicates.orderByDesc('deleted_time');

    const resultSet = await this.rdbStore.query(predicates);
    const items: RecycleBinItem[] = [];

    while (resultSet.goToNextRow()) {
      items.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        dataType: resultSet.getString(resultSet.getColumnIndex('data_type')),
        originalId: resultSet.getLong(resultSet.getColumnIndex('original_id')),
        dataContent: resultSet.getString(resultSet.getColumnIndex('data_content')),
        deletedTime: resultSet.getLong(resultSet.getColumnIndex('deleted_time')),
        expireTime: resultSet.getLong(resultSet.getColumnIndex('expire_time')),
        userId: resultSet.isColumnNull(resultSet.getColumnIndex('user_id')) 
          ? undefined 
          : resultSet.getLong(resultSet.getColumnIndex('user_id'))
      });
    }

    resultSet.close();
    return items;
  }

  async cleanExpiredItems(): Promise<number> {
    if (!this.rdbStore) return 0;

    const now = Date.now();
    const predicates = new relationalStore.RdbPredicates(TABLE_RECYCLE_BIN);
    predicates.lessThan('expire_time', now);

    const deletedCount = await this.rdbStore.delete(predicates);
    return deletedCount;
  }

  async getItemCount(): Promise<number> {
    if (!this.rdbStore) return 0;

    const predicates = new relationalStore.RdbPredicates(TABLE_RECYCLE_BIN);
    const resultSet = await this.rdbStore.query(predicates);
    const count = resultSet.rowCount;
    resultSet.close();
    return count;
  }

  async getItemCountByType(dataType: DataType): Promise<number> {
    if (!this.rdbStore) return 0;

    const predicates = new relationalStore.RdbPredicates(TABLE_RECYCLE_BIN);
    predicates.equalTo('data_type', dataType);
    const resultSet = await this.rdbStore.query(predicates);
    const count = resultSet.rowCount;
    resultSet.close();
    return count;
  }

  async clearAll(): Promise<void> {
    if (!this.rdbStore) return;

    const predicates = new relationalStore.RdbPredicates(TABLE_RECYCLE_BIN);
    await this.rdbStore.delete(predicates);
  }

  getRemainingTime(item: RecycleBinItem): number {
    const now = Date.now();
    const remaining = item.expireTime - now;
    return Math.max(0, remaining);
  }

  formatRemainingTime(item: RecycleBinItem): string {
    const remaining = this.getRemainingTime(item);
    if (remaining <= 0) return '已过期';

    const hours = Math.floor(remaining / (1000 * 60 * 60));
    const minutes = Math.floor((remaining % (1000 * 60 * 60)) / (1000 * 60));

    if (hours >= 24) {
      const days = Math.floor(hours / 24);
      return `${days}天${hours % 24}小时`;
    } else if (hours > 0) {
      return `${hours}小时${minutes}分钟`;
    } else {
      return `${minutes}分钟`;
    }
  }
}
