import { hilog } from '@kit.PerformanceAnalysisKit';
import { DailyRecord } from '../models/Habit';
import { HistoryViewModel } from '../viewmodels/HistoryViewModel';

const TAG: string = 'HistoryPage';

@Component
export struct HistoryPage {
  @State records: DailyRecord[] = [];
  @State isLoading: boolean = true;
  @State habitTitle: string = '';
  private viewModel: HistoryViewModel = new HistoryViewModel();

  async aboutToAppear() {
    this.viewModel.onRecordsChanged = (records: DailyRecord[]) => {
      this.records = records;
    };

    this.viewModel.onLoadingChanged = (isLoading: boolean) => {
      this.isLoading = isLoading;
    };

    const destInfo = this.queryNavDestinationInfo();
    const rawParam = destInfo?.param as string ?? '';

    await this.viewModel.init(rawParam);

    this.habitTitle = `${this.viewModel.habitIcon} ${this.viewModel.habitName}`;

    hilog.info(0x0000, TAG, 'HistoryPage initialized');
  }

  build() {
    Column() {
      Row() {
        Text(this.habitTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row()
          .width(36)
          .height(36)
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 20,
        bottom: 12
      })
      .alignItems(VerticalAlign.Center)

      Text($r('app.string.history_subtitle'))
        .fontSize(12)
        .fontColor($r('app.color.color_text_hint'))
        .margin({ bottom: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color($r('app.color.color_accent'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.records.length === 0) {
        Column({ space: 8 }) {
          Text($r('app.string.history_empty_title'))
            .fontSize(16)
            .fontColor($r('app.color.color_text_secondary'))
          Text($r('app.string.history_empty_body'))
            .fontSize(13)
            .fontColor($r('app.color.color_text_disabled'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.records, (record: DailyRecord) => {
            ListItem() {
              this.RecordRow(record);
            }
          }, (record: DailyRecord) => record.date)
        }
        .padding({ left: 16, right: 16, bottom: 20 })
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg_page'))
  }

  @Builder
  RecordRow(record: DailyRecord) {
    Column({ space: 6 }) {
      Row() {
        Text(this.viewModel.formatDate(record.date))
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .width(52)

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(8)
            .backgroundColor($r('app.color.color_bg_card_secondary'))
            .borderRadius(4)

          Row()
            .width(`${this.viewModel.getBarPercent(record.duration)}%`)
            .height(8)
            .backgroundColor($r('app.color.color_accent'))
            .borderRadius(4)
        }
        .layoutWeight(1)
        .margin({ left: 10, right: 10 })

        Text(this.viewModel.formatDuration(record.duration))
          .fontSize(13)
          .fontColor($r('app.color.color_text_primary'))
          .fontWeight(FontWeight.Medium)
          .width(48)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      top: 10,
      bottom: 10,
      left: 12,
      right: 12
    })
    .backgroundColor($r('app.color.color_bg_card'))
    .borderRadius(10)
  }
}
