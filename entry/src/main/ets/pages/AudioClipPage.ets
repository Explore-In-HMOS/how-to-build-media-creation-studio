import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  COLOR_BG,
  COLOR_PANEL,
  COLOR_PROGRESS_PLAYBACK,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../constants/MediaConfig';
import { AudioClipPlayerService } from '../services/AudioClipPlayerService';
import { ClipSelectionService } from '../services/ClipSelectionService';

@Builder
export function AudioClipPageBuilder() {
  AudioClipPage()
}

@Component
struct AudioClipPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State status: string = 'idle';
  @State message: string = '';
  @State clipName: string = 'Clip';
  @State clipSizeBytes: number = 0;
  volumeText: string = '';
  @State durationMs: number = 0;
  @State progressPct: number = 0;
  @State ready: boolean = false;
  @State playing: boolean = false;
  private service: AudioClipPlayerService = new AudioClipPlayerService();
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
        Text(this.clipName)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT_PRIMARY)
          .margin({ top: 12 })

        Text(this.subtitle())
          .fontSize(11)
          .fontColor(COLOR_TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16 })

        Progress({ value: this.progressPct, total: 100, type: ProgressType.Linear })
          .width('80%')
          .color(COLOR_PROGRESS_PLAYBACK)
          .backgroundColor(COLOR_PANEL)

        Text(`${this.progressPct}%`)
          .fontSize(10)
          .fontColor(COLOR_TEXT_SECONDARY)

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

  private async load(): Promise<void> {
    const clip = ClipSelectionService.get();
    if (clip === null || clip.kind !== 'audio') {
      this.status = 'failed';
      this.message = 'No audio clip selected';
      return;
    }
    this.clipName = clip.name;
    this.clipSizeBytes = clip.sizeBytes;
    this.volumeText = this.readVolumeText();
    await this.service.load(clip, {
      onStatus: (s, m) => this.onStatus(s, m),
      onDuration: (d) => {
        if (!this.disposed) {
          this.durationMs = d;
        }
      },
      onProgress: (p) => {
        if (!this.disposed) {
          this.progressPct = p;
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
    if (status === 'completed' || status === 'failed') {
      this.playing = false;
    }
  }

  private subtitle(): string {
    if (this.message.length > 0) {
      return `${this.status} · ${this.message}`;
    }
    if (this.durationMs > 0) {
      const seconds = Math.round(this.durationMs / 100) / 10;
      return `${this.status} · ${seconds}s · ${this.formatSize()}${this.volumeText}`;
    }
    if (this.clipSizeBytes > 0) {
      return `${this.status} · ${this.formatSize()}${this.volumeText}`;
    }
    return this.status;
  }

  private formatSize(): string {
    const kb = Math.max(1, Math.round(this.clipSizeBytes / 1024));
    return `${kb} KB`;
  }

  private readVolumeText(): string {
    try {
      const volumeManager = audio.getAudioManager().getVolumeManager();
      const volume = volumeManager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MUSIC);
      const muted = volumeManager.isSystemMutedForStream(audio.StreamUsage.STREAM_USAGE_MUSIC);
      return muted ? ` · muted · vol ${volume}` : ` · vol ${volume}`;
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`AudioClipPage.volume failed: ${e.code} ${e.message}`);
      return '';
    }
  }
}
