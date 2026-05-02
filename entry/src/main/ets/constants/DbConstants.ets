export class DbConstants {
  static readonly DB_NAME: string = 'habit_timer.db';
  static readonly TABLE_DAILY_RECORD: string = 'daily_record';
  static readonly COL_ID: string = 'id';
  static readonly COL_HABIT_ID: string = 'habit_id';
  static readonly COL_DATE: string = 'date';
  static readonly COL_DURATION: string = 'duration';
  static readonly CREATE_TABLE: string =
    `CREATE TABLE IF NOT EXISTS ${DbConstants.TABLE_DAILY_RECORD} (` +
      `${DbConstants.COL_ID} INTEGER PRIMARY KEY AUTOINCREMENT, ` +
      `${DbConstants.COL_HABIT_ID} TEXT NOT NULL, ` +
      `${DbConstants.COL_DATE} TEXT NOT NULL, ` +
      `${DbConstants.COL_DURATION} INTEGER NOT NULL)`;
}
