import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { wantAgent } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreferencesService } from './PreferencesService';
import { HistoryService } from './HistoryService';
import { DailyRecord, Habit, TimerState } from '../models/Habit';
import { StorageKeys } from '../constants/StorageKeys';
import { DEFAULT_HABITS } from '../models/DefaultHabits';

const TAG: string = 'HabitService';

export type HabitUpdateCallback = (habits: Habit[]) => void;

export type TimerUpdateCallback = (timerState: TimerState) => void;

export class HabitService {
  private habits: Habit[] = [];
  private timerState: TimerState = {
    isRunning: false,
    currentHabitId: '',
    startTime: 0,
    elapsedTime: 0
  };
  private timerInterval: number = -1;
  private readonly preferencesService: PreferencesService;
  private readonly historyService: HistoryService;
  private readonly context: common.UIAbilityContext;
  private habitUpdateCallback: HabitUpdateCallback | null = null;
  private timerUpdateCallback: TimerUpdateCallback | null = null;

  constructor(
    preferencesService: PreferencesService,
    historyService: HistoryService,
    context: common.UIAbilityContext
  ) {
    this.preferencesService = preferencesService;
    this.historyService = historyService;
    this.context = context;
  }

  public async init(): Promise<void> {
    try {
      const savedHabits = await this.preferencesService.getObject<Habit[]>(StorageKeys.HABITS, []);

      if (savedHabits.length > 0) {
        this.habits = savedHabits;
        hilog.info(0x0000, TAG, `Loaded ${savedHabits.length} habits from storage`);
      } else {
        this.habits = Array.from(DEFAULT_HABITS);
        await this.saveHabits();
        hilog.info(0x0000, TAG, 'Initialized with default habits');
      }

      await this.checkDailyReset();

      const savedTimerState = await this.preferencesService.getObject<TimerState>(
        StorageKeys.TIMER_STATE,
        this.timerState
      );

      if (savedTimerState.currentHabitId) {
        this.timerState = {
          isRunning: false,
          currentHabitId: savedTimerState.currentHabitId,
          startTime: savedTimerState.startTime,
          elapsedTime: savedTimerState.elapsedTime
        };
      }
    } catch (error) {
      hilog.error(0x0000, TAG, `init failed: ${error}`);
      this.habits = Array.from(DEFAULT_HABITS);
    }
  }

  public async onForeground(): Promise<void> {
    await this.checkDailyReset();
  }

  public getHabits(): Habit[] {
    return Array.from(this.habits);
  }

  public getHabitById(id: string): Habit | null {
    const habit = this.habits.find(h => h.id === id);
    if (!habit) {
      return null;
    }

    const copy: Habit = {
      id: habit.id,
      name: habit.name,
      icon: habit.icon,
      color: habit.color,
      todayDuration: habit.todayDuration,
      totalDuration: habit.totalDuration,
      lastActive: habit.lastActive
    };
    return copy;
  }

  public getTimerState(): TimerState {
    const copy: TimerState = {
      isRunning: this.timerState.isRunning,
      currentHabitId: this.timerState.currentHabitId,
      startTime: this.timerState.startTime,
      elapsedTime: this.timerState.elapsedTime
    };
    return copy;
  }

  public getCurrentElapsedTime(): number {
    if (!this.timerState.isRunning) {
      return this.timerState.elapsedTime;
    }
    const currentSessionTime = Math.floor((Date.now() - this.timerState.startTime) / 1000);
    return this.timerState.elapsedTime + currentSessionTime;
  }

  public async startTimer(habitId: string): Promise<void> {
    if (this.timerState.isRunning) {
      hilog.warn(0x0000, TAG, 'Timer already running');
      return;
    }

    const habit = this.habits.find(h => h.id === habitId);
    if (!habit) {
      hilog.error(0x0000, TAG, `Habit not found: ${habitId}`);
      return;
    }

    this.timerState = {
      isRunning: true,
      currentHabitId: habitId,
      startTime: Date.now(),
      elapsedTime: 0
    };

    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: this.context.abilityInfo.bundleName,
            abilityName: 'EntryAbility'
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(wantAgentInfo);
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
        agent
      );
      hilog.info(0x0000, TAG, 'Background task registered');
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.warn(0x0000, TAG, `Background task registration failed: ${businessError.message}`);
    }

    this.timerInterval = setInterval(() => {
      this.onTimerTick();
    }, 1000);

    await this.saveTimerState();
    this.notifyTimerUpdate();

    hilog.info(0x0000, TAG, `Timer started for habit: ${habitId}`);
  }

  public async pauseTimer(): Promise<void> {
    if (!this.timerState.isRunning) {
      hilog.warn(0x0000, TAG, 'Timer is not running');
      return;
    }

    const sessionDuration = this.stopInterval();
    await this.commitSession(sessionDuration, false);

    hilog.info(0x0000, TAG, `Timer paused. Session: ${sessionDuration}s`);
  }

  public async stopTimer(): Promise<void> {
    if (!this.timerState.isRunning) {
      hilog.warn(0x0000, TAG, 'Timer is not running');
      return;
    }

    const sessionDuration = this.stopInterval();
    await this.commitSession(sessionDuration, true);

    hilog.info(0x0000, TAG, `Timer stopped. Session: ${sessionDuration}s`);
  }

  public async resetTimer(): Promise<void> {
    if (this.timerInterval !== -1) {
      clearInterval(this.timerInterval);
      this.timerInterval = -1;
    }

    this.stopBackgroundTask().catch((err: Error) => {
      hilog.warn(0x0000, TAG, `stopBackgroundTask in reset failed: ${err.message}`);
    });

    this.timerState = {
      isRunning: false,
      currentHabitId: '',
      startTime: 0,
      elapsedTime: 0
    };

    this.notifyTimerUpdate();

    await this.saveTimerState();

    hilog.info(0x0000, TAG, 'Timer discarded (reset)');
  }

  public setHabitUpdateCallback(callback: HabitUpdateCallback): void {
    this.habitUpdateCallback = callback;
  }

  public setTimerUpdateCallback(callback: TimerUpdateCallback): void {
    this.timerUpdateCallback = callback;
  }

  public destroy(): void {
    if (this.timerInterval !== -1) {
      clearInterval(this.timerInterval);
      this.timerInterval = -1;
    }
    hilog.info(0x0000, TAG, 'HabitService destroyed');
  }

  private stopInterval(): number {
    const sessionDuration = Math.floor((Date.now() - this.timerState.startTime) / 1000);

    if (this.timerInterval !== -1) {
      clearInterval(this.timerInterval);
      this.timerInterval = -1;
    }

    this.timerState.isRunning = false;
    return sessionDuration;
  }

  private async commitSession(sessionDuration: number, fireNotification: boolean): Promise<void> {
    const habit = this.habits.find(h => h.id === this.timerState.currentHabitId);
    if (habit) {
      habit.todayDuration += sessionDuration;
      habit.totalDuration += sessionDuration;
      habit.lastActive = Date.now();
      await this.saveHabits();
      this.notifyHabitUpdate();

      const record: DailyRecord = {
        habitId: habit.id,
        date: this.getTodayDateString(),
        duration: sessionDuration
      };
      await this.historyService.insertRecord(record);
    }

    this.timerState.elapsedTime += sessionDuration;
    await this.saveTimerState();
    this.notifyTimerUpdate();

    await this.stopBackgroundTask();

    if (fireNotification && habit && sessionDuration > 0) {
      await this.publishSessionEndNotification(habit.name, habit.icon, sessionDuration);
    }
  }

  private onTimerTick(): void {
    if (!this.timerState.isRunning) {
      return;
    }
    this.notifyTimerUpdate();

    const totalElapsed = this.getCurrentElapsedTime();
    if (totalElapsed > 0 && totalElapsed % 30 === 0) {
      this.autoSaveProgress();
    }
  }

  private autoSaveProgress(): void {
    const habit = this.habits.find(h => h.id === this.timerState.currentHabitId);
    if (!habit) {
      return;
    }
    const currentSessionTime = Math.floor((Date.now() - this.timerState.startTime) / 1000);
    hilog.info(0x0000, TAG, `Auto-save: ${habit.name} — ${currentSessionTime}s this session`);
    this.saveTimerState();
  }

  private async stopBackgroundTask(): Promise<void> {
    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      hilog.info(0x0000, TAG, 'Background task stopped');
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.warn(0x0000, TAG, `stopBackgroundRunning failed: ${businessError.message}`);
    }
  }

  private async publishSessionEndNotification(
    habitName: string,
    habitIcon: string,
    durationSeconds: number
  ): Promise<void> {
    try {
      const durationText = this.formatDuration(durationSeconds);
      const request: notificationManager.NotificationRequest = {
        id: 1001,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: `${habitIcon} ${habitName} complete`,
            text: `Session saved — ${durationText} logged today`
          }
        },
        deliveryTime: Date.now(),
        showDeliveryTime: false
      };
      await notificationManager.publish(request);
      hilog.info(0x0000, TAG, `Session-end notification published for ${habitName}`);
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.warn(0x0000, TAG, `Notification publish failed: ${businessError.message}`);
    }
  }

  private async checkDailyReset(): Promise<void> {
    const today = this.getTodayDateString();
    const lastDate = await this.preferencesService.getString(StorageKeys.LAST_DATE, '');

    if (lastDate !== today) {
      hilog.info(0x0000, TAG, `New day detected — resetting daily stats. Last: ${lastDate}, Today: ${today}`);
      this.habits.forEach(habit => {
        habit.todayDuration = 0;
      });
      await this.preferencesService.putString(StorageKeys.LAST_DATE, today);
      await this.saveHabits();
    }
  }

  private getTodayDateString(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private async saveHabits(): Promise<void> {
    try {
      await this.preferencesService.putObject(StorageKeys.HABITS, this.habits);
    } catch (error) {
      hilog.error(0x0000, TAG, `saveHabits failed: ${error}`);
    }
  }

  private async saveTimerState(): Promise<void> {
    try {
      await this.preferencesService.putObject(StorageKeys.TIMER_STATE, this.timerState);
    } catch (error) {
      hilog.error(0x0000, TAG, `saveTimerState failed: ${error}`);
    }
  }

  private notifyHabitUpdate(): void {
    if (this.habitUpdateCallback) {
      this.habitUpdateCallback(Array.from(this.habits));
    }
  }

  private notifyTimerUpdate(): void {
    if (this.timerUpdateCallback) {
      const copy: TimerState = {
        isRunning: this.timerState.isRunning,
        currentHabitId: this.timerState.currentHabitId,
        startTime: this.timerState.startTime,
        elapsedTime: this.timerState.elapsedTime
      };
      this.timerUpdateCallback(copy);
    }
  }

  private formatDuration(seconds: number): string {
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
}
