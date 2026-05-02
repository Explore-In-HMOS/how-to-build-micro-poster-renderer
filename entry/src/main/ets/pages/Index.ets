
import { displaySync, uiEffect } from '@kit.ArkGraphics2D';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { POSTER_SIZE_PX, PosterNodeController } from '../poster/PosterRenderer';

const TAG: string = 'MicroPoster';
const HOME_DESTINATION: string = 'PosterHome';

@Entry
@Component
struct Index {
  @Provide('posterPathStack') pathStack: NavPathStack = new NavPathStack();

  @Builder
  destinationMap(name: string, _param: object) {
    if (name === HOME_DESTINATION) {
      PosterDestination()
    }
  }

  build() {
    Navigation(this.pathStack) {
      PosterDestination()
    }
    .hideTitleBar(true)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.destinationMap)
    .width('100%')
    .height('100%')
  }
}

@Component
struct PosterDestination {
  // ---------------------------------------------------------------------------
  // RenderNode plumbing
  // ---------------------------------------------------------------------------
  private readonly controller: PosterNodeController = new PosterNodeController();

  // ---------------------------------------------------------------------------
  // Animation state
  // ---------------------------------------------------------------------------
   message: string = 'Micro-Poster';
  @State frameCounter: number = 0;
  private dashPhase: number = 0;
  private rotationDeg: number = 0;
  private sync: displaySync.DisplaySync | null = null;

  private readonly hostFilter: uiEffect.Filter = uiEffect.createFilter().blur(0.6);

  aboutToAppear(): void {
    const sync: displaySync.DisplaySync = displaySync.create();
    sync.setExpectedFrameRateRange({ min: 24, max: 60, expected: 30 });
    sync.on('frame', (_info: displaySync.IntervalInfo) => {
      this.dashPhase = (this.dashPhase + 0.5) % 7;
      this.rotationDeg = (this.rotationDeg + 1.5) % 360;
      this.frameCounter += 1;
      this.controller.tick(this.dashPhase, this.rotationDeg, this.frameCounter);
    });
    sync.start();
    this.sync = sync;
    hilog.info(0x0000, TAG, 'displaySync started');
  }

  aboutToDisappear(): void {
    if (this.sync !== null) {
      this.sync.stop();
      this.sync = null;
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          Text(`${this.message}  •  f${this.frameCounter}`)
            .fontSize(12)
            .fontColor('#FFFFFFCC')
            .margin({ top: 16 })
            .padding({ bottom: 16 })
          NodeContainer(this.controller)
            .width(POSTER_SIZE_PX)
            .height(POSTER_SIZE_PX)
            .align(Alignment.Center)
            .alignSelf(ItemAlign.Center)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#000000')
      }
      .width('100%')
      .height('100%')
      .compositingFilter(this.hostFilter)
    }
    .hideTitleBar(true)
  }
}
