export interface Habit {
  id: string;
  name: string;
  icon: string;
  color: string;
  todayDuration: number;
  totalDuration: number;
  lastActive: number;
}

export interface TimerState {
  isRunning: boolean;
  currentHabitId: string;
  startTime: number;
  elapsedTime: number;
}

export interface DailyRecord {
  id?: number;
  habitId: string;
  date: string;
  duration: number;
}
