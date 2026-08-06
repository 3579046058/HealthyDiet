import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError, zlib } from '@kit.BasicServicesKit';
import { DatabaseHelper } from './DatabaseHelper';
import { DbRow } from '../common/Constants';

// 备份元数据
export class BackupMeta {
  version: string = '';
  timestamp: string = '';
  tables: Record<string, DbRow[]> = {};
}

/**
 * 数据备份：导出/导入所有业务表数据 + 音乐库文件，打包为 zip
 * zip 内结构：data.json（业务表数据）+ music/（音乐文件）
 */
export class DataBackupHelper {
  private dbHelper: DatabaseHelper;
  private context: common.UIAbilityContext;

  // 需要备份的业务表（排除系统表）
  private static readonly TABLES: string[] = [
    'daily_summary', 'weight_records', 'height_records', 'water_records',
    'sport_records', 'sleep_records', 'heart_rate_records', 'step_records',
    'diet_records', 'mood_records', 'medication_records', 'period_records',
    'body_composition_records', 'workout_plans', 'water_timeline', 'sleep_start_records',
    'music_records'
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

    const backupMeta: BackupMeta = new BackupMeta();
    backupMeta.version = '1.0';
    backupMeta.timestamp = new Date().toISOString();
    backupMeta.tables = backupData;
    return JSON.stringify(backupMeta);
  }

  // 导出并保存备份文件（zip：data.json + music/），通过系统文件选择器保存
  async saveBackupFile(): Promise<string> {
    const jsonData: string = await this.exportData();
    const fileName: string = 'health_backup_' + String(Date.now()) + '.zip';

    // 在应用缓存目录构建备份内容
    const cacheDir = this.context.cacheDir;
    const workDir = cacheDir + '/backup_work_' + String(Date.now());
    if (!this.exists(workDir)) {
      fs.mkdirSync(workDir);
    }
    const dataJsonPath = workDir + '/data.json';
    const dataFile = fs.openSync(dataJsonPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(dataFile.fd, jsonData);
    fs.closeSync(dataFile);

    // 复制音乐文件到 workDir/music/
    await this.copyMusicFiles(workDir);

    // 打包为 zip
    const zipPath = cacheDir + '/' + fileName;
    const options: zlib.Options = { level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION };
    await zlib.compressFile(workDir, zipPath, options);

    // 通过系统选择器保存到用户可见位置
    try {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [fileName];
      const documentPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await documentPicker.save(documentSaveOptions);
      if (uris.length === 0) {
        throw new Error('用户取消保存');
      }
      const uri: string = uris[0];
      // 将 zip 内容写入用户选择的位置
      const srcFile = fs.openSync(zipPath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(zipPath);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(srcFile.fd, buffer);
      fs.closeSync(srcFile);
      const dstFile = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(dstFile.fd, buffer);
      fs.closeSync(dstFile);
      // 清理临时文件
      this.cleanup(workDir, zipPath);
      console.info('备份已保存到: ' + uri);
      return uri;
    } catch (err) {
      const e = err as BusinessError;
      console.error('saveBackupFile error: ' + e.code + ' ' + e.message);
      throw new Error('备份操作失败');
    }
  }

  // 复制音乐文件到备份工作目录 music/ 子目录
  private async copyMusicFiles(workDir: string): Promise<void> {
    try {
      const musicDir = this.context.filesDir + '/music';
      if (!this.exists(musicDir)) {
        return;
      }
      const destMusicDir = workDir + '/music';
      if (!this.exists(destMusicDir)) {
        fs.mkdirSync(destMusicDir);
      }
      const names = fs.listFileSync(musicDir);
      for (let i = 0; i < names.length; i++) {
        const srcPath = musicDir + '/' + names[i];
        if (!this.exists(srcPath)) {
          continue;
        }
        const stat = fs.statSync(srcPath);
        if (stat.isDirectory()) {
          continue;
        }
        const srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
        const dstFile = fs.openSync(destMusicDir + '/' + names[i],
          fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        const buffer = new ArrayBuffer(stat.size);
        fs.readSync(srcFile.fd, buffer);
        fs.writeSync(dstFile.fd, buffer);
        fs.closeSync(srcFile);
        fs.closeSync(dstFile);
      }
    } catch (err) {
      console.error('copyMusicFiles error:', JSON.stringify(err));
    }
  }

  // 从 zip 导入数据（清空后重建表 + 恢复音乐文件）
  async importZip(zipPath: string): Promise<void> {
    const rdbStore: relationalStore.RdbStore | null = this.dbHelper.getRdbStore();
    if (!rdbStore) {
      throw new Error('数据库未初始化');
    }

    // 解压到临时目录
    const cacheDir = this.context.cacheDir;
    const extractDir = cacheDir + '/backup_extract_' + String(Date.now());
    if (!this.exists(extractDir)) {
      fs.mkdirSync(extractDir);
    }
    const options: zlib.Options = { level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION };
    await zlib.decompressFile(zipPath, extractDir, options);

    // 读取 data.json
    const dataJsonPath = extractDir + '/data.json';
    if (!this.exists(dataJsonPath)) {
      throw new Error('备份文件缺少 data.json');
    }
    const dataFile = fs.openSync(dataJsonPath, fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(dataJsonPath);
    const buffer = new ArrayBuffer(stat.size);
    fs.readSync(dataFile.fd, buffer);
    fs.closeSync(dataFile);
    const decoder = util.TextDecoder.create('utf-8');
    const jsonData = decoder.decodeToString(new Uint8Array(buffer));

    // 恢复表数据
    await this.importData(jsonData);

    // 恢复音乐文件到沙箱 music/ 目录
    const srcMusicDir = extractDir + '/music';
    const destMusicDir = this.context.filesDir + '/music';
    if (this.exists(srcMusicDir)) {
      if (!this.exists(destMusicDir)) {
        fs.mkdirSync(destMusicDir);
      }
      const names = fs.listFileSync(srcMusicDir);
      for (let i = 0; i < names.length; i++) {
        const srcPath = srcMusicDir + '/' + names[i];
        const dstPath = destMusicDir + '/' + names[i];
        if (!this.exists(srcPath)) {
          continue;
        }
        try {
          const srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
          const sStat = fs.statSync(srcPath);
          const dstFile = fs.openSync(dstPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          const buf = new ArrayBuffer(sStat.size);
          fs.readSync(srcFile.fd, buf);
          fs.writeSync(dstFile.fd, buf);
          fs.closeSync(srcFile);
          fs.closeSync(dstFile);
        } catch (err) {
          console.error('restore music file error:', JSON.stringify(err));
        }
      }
    }

    // 清理临时目录
    try {
      fs.rmdirSync(extractDir);
    } catch (err) {
      console.error('cleanup extract dir error:', JSON.stringify(err));
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
        const predicates = new relationalStore.RdbPredicates(tableName);
        await rdbStore.delete(predicates);
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

  // 从文件读取备份数据（兼容旧的纯 JSON 文件）
  async readBackupFile(fileUriOrPath: string): Promise<string> {
    const file = fs.openSync(fileUriOrPath, fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(fileUriOrPath);
    const buffer = new ArrayBuffer(stat.size);
    fs.readSync(file.fd, buffer);
    fs.closeSync(file);

    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(buffer));
  }

  // 通过系统文件选择器选择备份文件（zip 或 json），并执行导入
  async pickAndRestore(): Promise<void> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await documentPicker.select(documentSelectOptions);
      if (uris.length === 0) {
        throw new Error('用户取消选择');
      }
      const uri: string = uris[0];
      const lower = uri.toLowerCase();
      if (lower.endsWith('.zip')) {
        await this.importZip(uri);
      } else {
        // 兼容旧版 JSON 备份
        const jsonData = await this.readBackupFile(uri);
        await this.importData(jsonData);
      }
    } catch (err) {
      const e = err as BusinessError;
      console.error('pickAndRestore error: ' + e.code + ' ' + e.message);
      throw new Error('备份操作失败');
    }
  }

  // 兼容旧调用：选择并读取（返回 JSON 内容）
  async pickAndReadBackupFile(): Promise<string> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await documentPicker.select(documentSelectOptions);
      if (uris.length === 0) {
        return '';
      }
      const uri: string = uris[0];
      const lower = uri.toLowerCase();
      if (lower.endsWith('.zip')) {
        // zip 备份：解压并导入，返回空串表示已由 zip 流程处理
        await this.importZip(uri);
        return '';
      }
      return await this.readBackupFile(uri);
    } catch (err) {
      const e = err as BusinessError;
      console.error('pickAndReadBackupFile error: ' + e.code + ' ' + e.message);
      throw new Error('备份操作失败');
    }
  }

  // 判断文件/目录是否存在（accessSync 不存在时抛异常，需捕获）
  private exists(path: string): boolean {
    try {
      fs.accessSync(path);
      return true;
    } catch (err) {
      return false;
    }
  }

  private cleanup(workDir: string, zipPath: string): void {
    try {
      fs.rmdirSync(workDir);
    } catch (err) {
      console.error('cleanup workDir error:', JSON.stringify(err));
    }
    try {
      fs.unlinkSync(zipPath);
    } catch (err) {
      console.error('cleanup zip error:', JSON.stringify(err));
    }
  }
}
