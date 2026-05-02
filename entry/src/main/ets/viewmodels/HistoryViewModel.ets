import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DailyRecord } from '../models/Habit';
import { HistoryService } from '../services/HistoryService';

const TAG: string = 'HistoryViewModel';

export type RecordsChangedCallback = (records: DailyRecord[]) => void;

export type LoadingChangedCallback = (isLoading: boolean) => void;

interface RouterParams {
  habitId: string;
  habitName: string;
  habitIcon: string;
}

export class HistoryViewModel {
  public onRecordsChanged: RecordsChangedCallback | null = null;
  public onLoadingChanged: LoadingChangedCallback | null = null;
  private _records: DailyRecord[] = [];
  private _isLoading: boolean = true;
  private _habitId: string = '';
  private _habitName: string = '';
  private _habitIcon: string = '';
  private historyService: HistoryService | null = null;

  public get records(): DailyRecord[] {
    return this._records;
  }

  public get isLoading(): boolean {
    return this._isLoading;
  }

  public get habitName(): string {
    return this._habitName;
  }

  public get habitIcon(): string {
    return this._habitIcon;
  }

  public async init(rawParam: string = ''): Promise<void> {
    if (!rawParam) {
      hilog.error(0x0000, TAG, 'No nav param received');
      this.setLoading(false);
      return;
    }

    try {
      const params: RouterParams = JSON.parse(rawParam) as RouterParams;
      this._habitId = params.habitId;
      this._habitName = params.habitName;
      this._habitIcon = params.habitIcon;
    } catch (e) {
      hilog.error(0x0000, TAG, `JSON parse failed: ${e}`);
      this.setLoading(false);
      return;
    }

    this.historyService = AppStorage.get<HistoryService>('historyService') ?? null;
    if (this.historyService === null) {
      hilog.error(0x0000, TAG, 'HistoryService not found in AppStorage');
      this.setLoading(false);
      return;
    }

    await this.loadHistory();
  }

  public formatDuration(seconds: number): string {
    if (seconds < 60) {
      return `${seconds}s`;
    }
    const mins = Math.floor(seconds / 60);
    if (mins < 60) {
      return `${mins}m`;
    }
    const hours = Math.floor(mins / 60);
    const remainingMins = mins % 60;
    return `${hours}h ${remainingMins}m`;
  }

  public formatDate(dateStr: string): string {
    const parts = dateStr.split('-');
    if (parts.length !== 3) {
      return dateStr;
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const monthIndex = parseInt(parts[1], 10) - 1;
    const day = parseInt(parts[2], 10);
    const monthName = months[monthIndex] ?? '';
    return `${monthName} ${day}`;
  }

  public getBarPercent(duration: number): number {
    if (this._records.length === 0) {
      return 0;
    }
    const maxDuration = this._records.reduce((max, r) => Math.max(max, r.duration), 0);
    if (maxDuration === 0) {
      return 0;
    }
    return Math.round((duration / maxDuration) * 100);
  }

  private async loadHistory(): Promise<void> {
    if (this.historyService === null) {
      this.setLoading(false);
      return;
    }
    try {
      const loaded = await this.historyService.getLast7Days(this._habitId);
      this._records = loaded;
      hilog.info(0x0000, TAG, `Loaded ${this._records.length} records for ${this._habitId}`);
      if (this.onRecordsChanged) {
        this.onRecordsChanged(this._records);
      }
    } catch (error) {
      hilog.error(0x0000, TAG, `loadHistory failed: ${error}`);
    } finally {
      this.setLoading(false);
    }
  }

  private setLoading(value: boolean): void {
    this._isLoading = value;
    if (this.onLoadingChanged) {
      this.onLoadingChanged(value);
    }
  }
}
