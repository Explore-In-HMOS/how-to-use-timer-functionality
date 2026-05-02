import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Habit } from '../models/Habit';
import { HomeViewModel } from '../viewmodels/HomeViewModel';

const TAG: string = 'IndexPage';

@Component
export struct HomePage {
  @State habits: Habit[] = [];
  @State selectedIndex: number = 0;
  @State isTimerRunning: boolean = false;
  @State currentElapsedTime: number = 0;
  @State isInitialized: boolean = false;
  private viewModel: HomeViewModel = new HomeViewModel();
  private swiperController: SwiperController = new SwiperController();

  async aboutToAppear() {
    this.viewModel.onHabitsChanged = (habits: Habit[]) => {
      this.habits = habits;
    };

    this.viewModel.onTimerChanged = (isRunning: boolean, elapsedTime: number) => {
      this.isTimerRunning = isRunning;
      this.currentElapsedTime = elapsedTime;
    };

    this.viewModel.onInitialized = () => {
      this.habits = this.viewModel.habits;
      this.selectedIndex = this.viewModel.selectedIndex;
      this.isTimerRunning = this.viewModel.isTimerRunning;
      this.currentElapsedTime = this.viewModel.currentElapsedTime;
      this.isInitialized = true;
    };

    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.viewModel.init(context);
    } catch (error) {
      hilog.error(0x0000, TAG, `Failed to initialize ViewModel: ${error}`);
    }
  }

  aboutToDisappear() {
    this.viewModel.destroy();
  }

  onBackPress(): boolean | void {
    if (this.isTimerRunning) {
      return true;
    }
    return false;
  }

  build() {
    Column() {
      if (!this.isInitialized) {
        this.LoadingView();
      } else {
        this.MainView();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onDigitalCrown((event: CrownEvent) => {
      event.stopPropagation();
      const newIndex = this.viewModel.handleCrownEvent(event.degree);
      if (newIndex === -1) {
        return;
      }
      this.selectedIndex = newIndex;
      this.currentElapsedTime = 0;

      const prev = this.viewModel.selectedIndex;
      const len = this.habits.length;
      const forward = ((newIndex - prev + len) % len) <= Math.floor(len / 2);
      if (forward) {
        this.swiperController.showNext();
      } else {
        this.swiperController.showPrevious();
      }
    })
  }

  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#00D4AA')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  MainView() {
    List() {
      ListItem() {
        Column({ space: 0 }) {
          Swiper(this.swiperController) {
            ForEach(this.habits, (habit: Habit) => {
              this.HabitSlide(habit);
            }, (habit: Habit) => habit.id)
          }
          .index(this.selectedIndex)
          .loop(true)
          .indicator(
            new DotIndicator()
              .color('#333333')
              .selectedColor('#00D4AA')
              .itemWidth(6)
              .itemHeight(6)
              .selectedItemWidth(10)
              .selectedItemHeight(10)
          )
          .onChange((index: number) => {
            this.viewModel.onSwiperChanged(index);
            this.selectedIndex = this.viewModel.selectedIndex;
            this.currentElapsedTime = 0;
          })
          .width('100%')
          .height(110)
          .disableSwipe(this.isTimerRunning)

          Column({ space: 4 }) {
            Text(this.viewModel.formatTime(this.currentElapsedTime))
              .fontSize(52)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isTimerRunning ? '#00D4AA' : '#FFA500')
              .fontFamily('monospace')

            if (this.isTimerRunning || this.currentElapsedTime > 0) {
              Text(this.isTimerRunning ? 'Running' : 'Stopped')
                .fontSize(13)
                .fontColor(this.isTimerRunning ? '#00D4AA' : '#FFA500')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 6, bottom: 8 })

          if (this.habits.length > 0) {
            Row({ space: 20 }) {
              Column({ space: 2 }) {
                Text(this.viewModel.formatDuration(this.habits[this.selectedIndex].todayDuration))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                Text('Today')
                  .fontSize(11)
                  .fontColor('#888888')
              }

              Row()
                .width(1)
                .height(22)
                .backgroundColor('#333333')

              Column({ space: 2 }) {
                Text(this.viewModel.formatDuration(this.habits[this.selectedIndex].totalDuration))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                Text('Total')
                  .fontSize(11)
                  .fontColor('#888888')
              }
            }
            .margin({ bottom: 12 })
          }

          Column({ space: 10 }) {
            Button(this.isTimerRunning ? 'Stop' : 'Start')
              .width('72%')
              .height(48)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.isTimerRunning ? '#FFA500' : '#00D4AA')
              .fontColor(Color.Black)
              .borderRadius(24)
              .onClick(() => {
                this.viewModel.startStop();
              })

            Row({ space: 10 }) {
              Button('Reset')
                .width('34%')
                .height(40)
                .fontSize(14)
                .backgroundColor('#222222')
                .fontColor('#CCCCCC')
                .borderRadius(20)
                .onClick(() => {
                  this.viewModel.reset();
                })

              Button('History')
                .width('34%')
                .height(40)
                .fontSize(14)
                .backgroundColor('#222222')
                .fontColor(this.isTimerRunning ? '#555555' : '#CCCCCC')
                .borderRadius(20)
                .enabled(!this.isTimerRunning)
                .onClick(() => {
                  this.viewModel.navigateToHistory();
                })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 6, bottom: 32 })
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  HabitSlide(habit: Habit) {
    Column({ space: 4 }) {
      Text(habit.icon)
        .fontSize(34)

      Text(habit.name)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
    }
    .width('100%')
    .height(110)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 10 })
    .border({
      width: { bottom: 2 },
      color: { bottom: habit.color }
    })
  }
}
