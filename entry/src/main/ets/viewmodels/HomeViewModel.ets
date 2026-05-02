import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Habit, TimerState } from '../models/Habit';
import { HabitService } from '../services/HabitService';
import { HistoryService } from '../services/HistoryService';
import { NavigationService } from '../services/NavigationService';
import { PreferencesService } from '../services/PreferencesService';

const TAG: string = 'HomeViewModel';
const CROWN_THRESHOLD: number = 10.0;

export type HabitsChangedCallback = (habits: Habit[]) => void;

export type TimerChangedCallback = (isRunning: boolean, elapsedTime: number) => void;

export type NavigateHistoryCallback = (habitId: string, habitName: string, habitIcon: string) => void;

export type InitializedCallback = () => void;

export class HomeViewModel {
  public onHabitsChanged: HabitsChangedCallback | null = null;
  public onTimerChanged: TimerChangedCallback | null = null;
  public onNavigateHistory: NavigateHistoryCallback | null = null;
  public onInitialized: InitializedCallback | null = null;
  private _habits: Habit[] = [];
  private _selectedIndex: number = 0;
  private _isTimerRunning: boolean = false;
  private _currentElapsedTime: number = 0;
  private _isInitialized: boolean = false;
  private habitService: HabitService | null = null;
  private historyService: HistoryService | null = null;
  private preferencesService: PreferencesService | null = null;
  private context: common.UIAbilityContext | null = null;
  private timerUpdateInterval: number = -1;
  private crownAccumulator: number = 0;

  public get habits(): Habit[] {
    return this._habits;
  }

  public get selectedIndex(): number {
    return this._selectedIndex;
  }

  public get isTimerRunning(): boolean {
    return this._isTimerRunning;
  }

  public get currentElapsedTime(): number {
    return this._currentElapsedTime;
  }

  public get isInitialized(): boolean {
    return this._isInitialized;
  }

  public async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.context = context;

      this.preferencesService = new PreferencesService(this.context);
      await this.preferencesService.init();

      this.historyService = new HistoryService(this.context);
      await this.historyService.init();

      AppStorage.setOrCreate<HistoryService>('historyService', this.historyService);

      this.habitService = new HabitService(
        this.preferencesService,
        this.historyService,
        this.context
      );
      await this.habitService.init();

      this.habitService.setHabitUpdateCallback((habits: Habit[]) => {
        this._habits = this.deepCopyHabits(habits);
        if (this.onHabitsChanged) {
          this.onHabitsChanged(this._habits);
        }
      });

      this.habitService.setTimerUpdateCallback((timerState: TimerState) => {
        this._isTimerRunning = timerState.isRunning;
        if (this.onTimerChanged) {
          this.onTimerChanged(this._isTimerRunning, this._currentElapsedTime);
        }
      });

      this._habits = this.deepCopyHabits(this.habitService.getHabits());

      const timerState = this.habitService.getTimerState();
      this._isTimerRunning = timerState.isRunning;

      if (timerState.currentHabitId !== '') {
        const idx = this._habits.findIndex(h => h.id === timerState.currentHabitId);
        if (idx !== -1) {
          this._selectedIndex = idx;
        }
      }

      this._isInitialized = true;

      this.timerUpdateInterval = setInterval(() => {
        if (this.habitService !== null && this._isTimerRunning) {
          this._currentElapsedTime = this.habitService.getCurrentElapsedTime();
          if (this.onTimerChanged) {
            this.onTimerChanged(this._isTimerRunning, this._currentElapsedTime);
          }
        }
      }, 1000);

      if (this.onInitialized) {
        this.onInitialized();
      }

      hilog.info(0x0000, TAG, `Initialized. Habits: ${this._habits.length}`);
    } catch (error) {
      hilog.error(0x0000, TAG, `init failed: ${error}`);
    }
  }

  public destroy(): void {
    if (this.timerUpdateInterval !== -1) {
      clearInterval(this.timerUpdateInterval);
      this.timerUpdateInterval = -1;
    }
    if (this.habitService !== null) {
      this.habitService.destroy();
    }
    if (this.historyService !== null) {
      this.historyService.destroy();
    }
    hilog.info(0x0000, TAG, 'Destroyed');
  }

  public async startStop(): Promise<void> {
    if (this.habitService === null || this._habits.length === 0) {
      hilog.error(0x0000, TAG, 'Cannot start/stop — service null or no habits');
      return;
    }

    const currentHabit = this._habits[this._selectedIndex];

    if (this._isTimerRunning) {
      await this.habitService.stopTimer();
      this._isTimerRunning = false;
      this._habits = this.deepCopyHabits(this.habitService.getHabits());
      this._currentElapsedTime = 0;

      if (this.onHabitsChanged) {
        this.onHabitsChanged(this._habits);
      }
      if (this.onTimerChanged) {
        this.onTimerChanged(false, 0);
      }
      hilog.info(0x0000, TAG, 'Timer stopped');
    } else {
      await this.habitService.startTimer(currentHabit.id);
      this._isTimerRunning = true;
      this._currentElapsedTime = 0;

      if (this.onTimerChanged) {
        this.onTimerChanged(true, 0);
      }
      hilog.info(0x0000, TAG, `Timer started: ${currentHabit.id}`);
    }
  }

  public async reset(): Promise<void> {
    if (this.habitService === null) {
      return;
    }
    await this.habitService.resetTimer();
    this._isTimerRunning = false;
    this._currentElapsedTime = 0;

    if (this.onTimerChanged) {
      this.onTimerChanged(false, 0);
    }
    hilog.info(0x0000, TAG, 'Timer reset');
  }

  public navigateToHistory(): void {
    if (this._isTimerRunning || this._habits.length === 0) {
      return;
    }
    const habit = this._habits[this._selectedIndex];

    const param = JSON.stringify({
      habitId: habit.id,
      habitName: habit.name,
      habitIcon: habit.icon
    });

    NavigationService.getInstance().navigateToWithArgs('HistoryPage', param);
  }

  public handleCrownEvent(angularVelocity: number): number {
    if (this._isTimerRunning || this._habits.length === 0) {
      return -1;
    }

    this.crownAccumulator += angularVelocity;

    if (this.crownAccumulator >= CROWN_THRESHOLD) {
      this.crownAccumulator = 0;
      this._selectedIndex = (this._selectedIndex + 1) % this._habits.length;
      this._currentElapsedTime = 0;
      return this._selectedIndex;
    }

    if (this.crownAccumulator <= -CROWN_THRESHOLD) {
      this.crownAccumulator = 0;
      this._selectedIndex = (this._selectedIndex - 1 + this._habits.length) % this._habits.length;
      this._currentElapsedTime = 0;
      return this._selectedIndex;
    }

    return -1;
  }

  public onSwiperChanged(index: number): void {
    if (!this._isTimerRunning) {
      this._selectedIndex = index;
      this._currentElapsedTime = 0;
      hilog.info(0x0000, TAG, `Swiped to index: ${index}`);
    }
  }

  public formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
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

  private deepCopyHabits(habits: Habit[]): Habit[] {
    return habits.map(h => {
      const copy: Habit = {
        id: h.id,
        name: h.name,
        icon: h.icon,
        color: h.color,
        todayDuration: h.todayDuration,
        totalDuration: h.totalDuration,
        lastActive: h.lastActive
      };
      return copy;
    });
  }
}
