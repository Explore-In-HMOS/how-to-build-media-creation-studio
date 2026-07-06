import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import {
  COLOR_BG,
  COLOR_PANEL,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../constants/MediaConfig';
import { ThumbnailService } from '../services/ThumbnailService';

type LoadState = 'idle' | 'loading' | 'ready' | 'failed';

interface FrameItem {
  id: string;
  pixelMap: image.PixelMap;
}

@Builder
export function ThumbnailsPageBuilder() {
  ThumbnailsPage()
}

@Component
struct ThumbnailsPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State state: LoadState = 'idle';
  @State message: string = '';
  @State durationMs: number = 0;
  @State frames: FrameItem[] = [];
  private busy: boolean = false;
  private disposed: boolean = false;

  aboutToAppear(): void {
    void this.extract();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.releaseFrames();
  }

  build() {
    NavDestination() {
      Column({ space: 10 }) {
        Text('Thumbnails')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT_PRIMARY)
          .margin({ top: 12 })

        Text(this.subtitle())
          .fontSize(11)
          .fontColor(COLOR_TEXT_SECONDARY)

        this.FrameRow()

        Text(this.message)
          .fontSize(10)
          .fontColor(COLOR_TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16 })

        Button('Re-extract')
          .fontSize(12)
          .fontColor(COLOR_TEXT_PRIMARY)
          .backgroundColor(COLOR_PANEL)
          .height(32)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            void this.extract();
          })
      }
      .width('100%')
      .height('100%')
      .padding(12)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(COLOR_BG)
    }
    .hideTitleBar(true)
    .backgroundColor(COLOR_BG)
  }

  @Builder
  FrameRow() {
    if (this.frames.length === 0) {
      Row() {
        Text(this.state === 'loading' ? '...' : 'No frames')
          .fontSize(11)
          .fontColor(COLOR_TEXT_SECONDARY)
      }
      .height(48)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Row({ space: 6 }) {
        ForEach(this.frames, (frame: FrameItem) => {
          Image(frame.pixelMap)
            .width(44)
            .height(44)
            .borderRadius(6)
            .backgroundColor(COLOR_PANEL)
            .objectFit(ImageFit.Cover)
        }, (frame: FrameItem) => frame.id)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
  }

  private subtitle(): string {
    if (this.state === 'loading') {
      return 'Extracting frames…';
    }
    if (this.state === 'ready') {
      return `Sample · ${Math.round(this.durationMs / 100) / 10}s`;
    }
    if (this.state === 'failed') {
      return 'Extraction failed';
    }
    return 'Tap re-extract to begin';
  }

  private async extract(): Promise<void> {
    if (this.busy || this.disposed) {
      return;
    }
    this.busy = true;
    this.state = 'loading';
    this.message = '';
    this.releaseFrames();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const batch = await ThumbnailService.extractSampleFrames(context);
      if (this.disposed) {
        for (const frame of batch.frames) {
          void this.releasePixelMap(frame);
        }
        return;
      }
      const items: FrameItem[] = [];
      const limit = batch.frames.length;
      for (let i = 0; i < limit; i++) {
        items.push({
          id: `frame_${i}_${batch.durationMs}`,
          pixelMap: batch.frames[i]
        });
      }
      this.frames = items;
      this.durationMs = batch.durationMs;
      this.state = items.length > 0 ? 'ready' : 'failed';
      if (items.length === 0) {
        this.message = 'No frames decoded';
      }
    } catch (err) {
      if (!this.disposed) {
        this.state = 'failed';
        this.message = (err as Error).message;
      }
    } finally {
      this.busy = false;
    }
  }

  private releaseFrames(): void {
    const existing = this.frames;
    this.frames = [];
    for (const item of existing) {
      void this.releasePixelMap(item.pixelMap);
    }
  }

  private async releasePixelMap(pm: image.PixelMap): Promise<void> {
    try {
      await pm.release();
    } catch (err) {
      console.warn(`ThumbnailsPage.release failed: ${(err as Error).message}`);
    }
  }
}
