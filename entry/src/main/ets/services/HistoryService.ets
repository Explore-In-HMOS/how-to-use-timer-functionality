import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DbConstants } from '../constants/DbConstants';
import { DailyRecord } from '../models/Habit';

const TAG: string = 'HistoryService';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DbConstants.DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
};

export class HistoryService {
  private store: relationalStore.RdbStore | null = null;
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  public async init(): Promise<void> {
    try {
      this.store = await relationalStore.getRdbStore(this.context, STORE_CONFIG);
      await this.store.executeSql(DbConstants.CREATE_TABLE);
      hilog.info(0x0000, TAG, 'HistoryService initialized');
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(0x0000, TAG, `init failed: ${businessError.message}`);
    }
  }

  public async insertRecord(record: DailyRecord): Promise<void> {
    if (!this.store) {
      hilog.error(0x0000, TAG, 'Store not initialized');
      return;
    }
    if (record.duration <= 0) {
      return;
    }
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        habit_id: record.habitId,
        date: record.date,
        duration: record.duration
      };
      await this.store.insert(DbConstants.TABLE_DAILY_RECORD, valueBucket);
      hilog.info(0x0000, TAG, `Inserted record: ${record.habitId} ${record.date} ${record.duration}s`);
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(0x0000, TAG, `insertRecord failed: ${businessError.message}`);
    }
  }

  public async getLast7Days(habitId: string): Promise<DailyRecord[]> {
    if (!this.store) {
      hilog.error(0x0000, TAG, 'Store not initialized');
      return [];
    }
    try {
      const cutoffDate = this.getDateString(7);
      const predicates = new relationalStore.RdbPredicates(DbConstants.TABLE_DAILY_RECORD);
      predicates
        .equalTo(DbConstants.COL_HABIT_ID, habitId)
        .and()
        .greaterThanOrEqualTo(DbConstants.COL_DATE, cutoffDate)
        .orderByDesc(DbConstants.COL_DATE);

      const resultSet = await this.store.query(predicates, [
        DbConstants.COL_ID,
        DbConstants.COL_HABIT_ID,
        DbConstants.COL_DATE,
        DbConstants.COL_DURATION
      ]);

      const records: DailyRecord[] = [];
      const dayMap: Map<string, number> = new Map();

      while (resultSet.goToNextRow()) {
        const date = resultSet.getString(resultSet.getColumnIndex(DbConstants.COL_DATE));
        const duration = resultSet.getLong(resultSet.getColumnIndex(DbConstants.COL_DURATION));
        const existing = dayMap.get(date) ?? 0;
        dayMap.set(date, existing + duration);
      }
      resultSet.close();

      dayMap.forEach((duration, date) => {
        records.push({ habitId, date, duration });
      });

      records.sort((a, b) => b.date.localeCompare(a.date));

      return records;
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(0x0000, TAG, `getLast7Days failed: ${businessError.message}`);
      return [];
    }
  }

  private getDateString(daysAgo: number): string {
    const date = new Date();
    date.setDate(date.getDate() - daysAgo);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  public destroy(): void {
    this.store = null;
    hilog.info(0x0000, TAG, 'HistoryService destroyed');
  }
}
