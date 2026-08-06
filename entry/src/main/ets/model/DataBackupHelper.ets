import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DatabaseHelper } from './DatabaseHelper';
import { DbRow } from '../common/Constants';

// 备份元数据
export class BackupMeta {
  version: string = '';
  timestamp: string = '';
  tables: Record<string, DbRow[]> = {};
}

/**
 * 数据备份：导出/导入所有业务表数据为 JSON 文件
 */
export class DataBackupHelper {
  private dbHelper: DatabaseHelper;
  private context: common.UIAbilityContext;

  // 需要备份的业务表（排除系统表）
  private static readonly TABLES: string[] = [
    'daily_summary', 'weight_records', 'height_records', 'water_records',
    'sport_records', 'sleep_records', 'heart_rate_records', 'step_records',
    'diet_records', 'mood_records', 'medication_records', 'period_records',
    'body_composition_records', 'workout_plans', 'water_timeline', 'sleep_start_records'
  ];

  constructor(dbHelper: DatabaseHelper, context: common.UIAbilityContext) {
    this.dbHelper = dbHelper;
    this.context = context;
  }

  // 导出所有表数据为 JSON 字符串
  async exportData(): Promise<string> {
    const rdbStore: relationalStore.RdbStore | null = this.dbHelper.getRdbStore();
    if (!rdbStore) {
      throw new Error('数据库未初始化');
    }

    const backupData: Record<string, DbRow[]> = {};
    for (let i = 0; i < DataBackupHelper.TABLES.length; i++) {
      const tableName: string = DataBackupHelper.TABLES[i];
      const rows: DbRow[] = [];
      try {
        const predicates = new relationalStore.RdbPredicates(tableName);
        const resultSet: relationalStore.ResultSet = await rdbStore.query(predicates);
        while (resultSet.goToNextRow()) {
          const row: DbRow = resultSet.getRow();
          rows.push(row);
        }
        resultSet.close();
      } catch (err) {
        console.error('导出表 ' + tableName + ' 失败:', JSON.stringify(err));
      }
      backupData[tableName] = rows;
    }

    // 用显式类承载备份元数据
    const backupMeta: BackupMeta = new BackupMeta();
    backupMeta.version = '1.0';
    backupMeta.timestamp = new Date().toISOString();
    backupMeta.tables = backupData;
    return JSON.stringify(backupMeta);
  }

  // 导出并保存备份文件（通过系统文件选择器保存到用户可见位置，如 Download）
  async saveBackupFile(): Promise<string> {
    const jsonData: string = await this.exportData();
    const fileName: string = 'health_backup_' + String(Date.now()) + '.json';

    try {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [fileName];
      const documentPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await documentPicker.save(documentSaveOptions);
      if (uris.length === 0) {
        throw new Error('用户取消保存');
      }
      const uri: string = uris[0];
      // 写入文件内容
      const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, jsonData);
      fs.closeSync(file);
      console.info('备份已保存到: ' + uri);
      return uri;
    } catch (err) {
      const e = err as BusinessError;
      console.error('saveBackupFile error: ' + e.code + ' ' + e.message);
      throw new Error('备份操作失败');
    }
  }

  // 从 JSON 导入数据（清空后重建）
  async importData(jsonData: string): Promise<void> {
    const rdbStore: relationalStore.RdbStore | null = this.dbHelper.getRdbStore();
    if (!rdbStore) {
      throw new Error('数据库未初始化');
    }

    const parsed = JSON.parse(jsonData) as Record<string, Object>;
    const tablesObj = parsed['tables'] as Record<string, DbRow[]>;
    if (!tablesObj) {
      throw new Error('无效的备份文件格式');
    }

    const tableNames: string[] = Object.keys(tablesObj);
    for (let i = 0; i < tableNames.length; i++) {
      const tableName: string = tableNames[i];
      const rows: DbRow[] = tablesObj[tableName] || [];
      try {
        // 清空表
        const predicates = new relationalStore.RdbPredicates(tableName);
        await rdbStore.delete(predicates);
        // 逐行插入
        for (let j = 0; j < rows.length; j++) {
          const row: DbRow = rows[j];
          const values: relationalStore.ValuesBucket = row as relationalStore.ValuesBucket;
          await rdbStore.insert(tableName, values);
        }
      } catch (err) {
        console.error('导入表 ' + tableName + ' 失败:', JSON.stringify(err));
      }
    }
  }

  // 从文件读取备份数据（uri 或路径）
  async readBackupFile(fileUriOrPath: string): Promise<string> {
    const file = fs.openSync(fileUriOrPath, fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(fileUriOrPath);
    const buffer = new ArrayBuffer(stat.size);
    fs.readSync(file.fd, buffer);
    fs.closeSync(file);

    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(buffer));
  }

  // 通过系统文件选择器选择备份文件并读取内容
  async pickAndReadBackupFile(): Promise<string> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await documentPicker.select(documentSelectOptions);
      if (uris.length === 0) {
        throw new Error('用户取消选择');
      }
      return await this.readBackupFile(uris[0]);
    } catch (err) {
      const e = err as BusinessError;
      console.error('pickAndReadBackupFile error: ' + e.code + ' ' + e.message);
      throw new Error('备份操作失败');
    }
  }
}
