import { common } from '@kit.AbilityKit';
import {
  COLOR_BG,
  COLOR_PANEL,
  COLOR_PROGRESS_DOWNLOAD,
  COLOR_PROGRESS_PLAYBACK,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../constants/MediaConfig';
import { StreamSourceService } from '../services/StreamSourceService';

@Builder
export function StreamPageBuilder() {
  StreamPage()
}

@Component
struct StreamPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State status: string = 'idle';
  @State message: string = '';
  @State downloadPct: number = 0;
  @State playbackPct: number = 0;
  @State durationMs: number = 0;
  @State ready: boolean = false;
  @State playing: boolean = false;
  private service: StreamSourceService = new StreamSourceService();
  private disposed: boolean = false;

  aboutToAppear(): void {
    void this.load();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    void this.service.release();
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Text('Stream')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT_PRIMARY)
          .margin({ top: 12 })

        Text(this.subtitle())
          .fontSize(11)
          .fontColor(COLOR_TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16 })

        this.ProgressBar('Download', this.downloadPct, COLOR_PROGRESS_DOWNLOAD)
        this.ProgressBar('Playback', this.playbackPct, COLOR_PROGRESS_PLAYBACK)

        Button(this.playing ? 'Pause' : 'Play')
          .fontSize(13)
          .fontColor(COLOR_TEXT_PRIMARY)
          .backgroundColor(COLOR_PANEL)
          .height(44)
          .width(100)
          .borderRadius(22)
          .enabled(this.ready)
          .onClick(() => {
            void this.toggle();
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
  ProgressBar(label: string, value: number, color: string) {
    Column({ space: 4 }) {
      Row() {
        Text(label)
          .fontSize(10)
          .fontColor(COLOR_TEXT_SECONDARY)
          .layoutWeight(1)
        Text(`${value}%`)
          .fontSize(10)
          .fontColor(COLOR_TEXT_SECONDARY)
      }
      .width('80%')
      Progress({ value: value, total: 100, type: ProgressType.Linear })
        .width('80%')
        .height(6)
        .color(color)
        .backgroundColor(COLOR_PANEL)
    }
  }

  private subtitle(): string {
    if (this.message.length > 0) {
      return `${this.status} · ${this.message}`;
    }
    if (this.durationMs > 0) {
      return `${this.status} · ${Math.round(this.durationMs / 100) / 10}s`;
    }
    return this.status;
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await this.service.load(context, {
      onStatus: (s, m) => this.onStatus(s, m),
      onDownload: (p) => {
        if (!this.disposed) {
          this.downloadPct = p;
        }
      },
      onPlayback: (p) => {
        if (!this.disposed) {
          this.playbackPct = p;
        }
      },
      onDuration: (d) => {
        if (!this.disposed) {
          this.durationMs = d;
        }
      }
    });
    if (this.disposed) {
      void this.service.release();
    }
  }

  private async toggle(): Promise<void> {
    if (this.playing) {
      await this.service.pause();
      if (!this.disposed) {
        this.playing = false;
      }
    } else {
      await this.service.play();
      if (!this.disposed) {
        this.playing = true;
      }
    }
  }

  private onStatus(status: string, message?: string): void {
    if (this.disposed) {
      return;
    }
    this.status = status;
    this.message = message ?? '';
    if (status === 'ready' || status === 'playing' || status === 'paused') {
      this.ready = true;
    }
    if (status === 'completed') {
      this.playing = false;
    }
    if (status === 'failed') {
      this.playing = false;
    }
  }
}
