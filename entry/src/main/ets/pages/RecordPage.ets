import { common } from '@kit.AbilityKit';
import { PrimaryActionButton } from '../components/PrimaryActionButton';
import {
  COLOR_BG,
  COLOR_PANEL,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY,
  PROFILES,
  PROFILE_NORMAL,
  RecorderProfileSpec
} from '../constants/MediaConfig';
import { PermissionService } from '../services/PermissionService';
import { RecorderService, RecorderStatus } from '../services/RecorderService';

@Builder
export function RecordPageBuilder() {
  RecordPage()
}

@Component
struct RecordPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State status: RecorderStatus = 'idle';
  @State statusMessage: string = '';
  @State elapsedMs: number = 0;
  @State profileIndex: number = 0;
  private busy: boolean = false;
  private recorder: RecorderService = new RecorderService();
  private disposed: boolean = false;

  aboutToDisappear(): void {
    this.disposed = true;
    void this.recorder.release();
  }

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        Text('Record')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT_PRIMARY)
          .margin({ top: 8 })

        this.ProfilePill()

        Text(this.formatElapsed(this.elapsedMs))
          .fontSize(28)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT_PRIMARY)

        PrimaryActionButton({
          label: this.status === 'recording' ? 'STOP' : 'RECORD',
          glyph: this.status === 'recording' ? '■' : '●',
          active: this.status === 'recording',
          onTap: () => {
            void this.handlePrimaryAction();
          }
        })

        if (this.shouldShowStatus()) {
          Text(this.formatStatus())
            .fontSize(11)
            .fontColor(COLOR_TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .padding({ left: 16, right: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start)
      .backgroundColor(COLOR_BG)
    }
    .hideTitleBar(true)
    .backgroundColor(COLOR_BG)
  }

  @Builder
  ProfilePill() {
    Row({ space: 8 }) {
      ForEach(PROFILES, (profile: RecorderProfileSpec) => {
        Text(profile.label)
          .fontSize(11)
          .fontColor(profile.key === this.activeProfile().key
            ? COLOR_TEXT_PRIMARY
            : COLOR_TEXT_SECONDARY)
          .backgroundColor(profile.key === this.activeProfile().key
            ? COLOR_PANEL
            : '#00000000')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .onClick(() => {
            this.selectProfile(profile.key);
          })
      }, (profile: RecorderProfileSpec) => profile.key)
    }
    .padding(4)
    .borderRadius(16)
    .backgroundColor('#1F252D')
  }

  private activeProfile(): RecorderProfileSpec {
    const fallback = PROFILE_NORMAL;
    if (this.profileIndex < 0 || this.profileIndex >= PROFILES.length) {
      return fallback;
    }
    return PROFILES[this.profileIndex];
  }

  private selectProfile(key: string): void {
    if (this.status === 'recording' || this.busy) {
      return;
    }
    let nextIndex = -1;
    for (let i = 0; i < PROFILES.length; i++) {
      if (PROFILES[i].key === key) {
        nextIndex = i;
        break;
      }
    }
    if (nextIndex >= 0) {
      this.profileIndex = nextIndex;
    }
  }

  private async handlePrimaryAction(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      if (this.status === 'recording') {
        await this.recorder.stop({
          onStatus: (s, m) => this.onStatus(s, m),
          onTick: (ms) => this.onTick(ms)
        });
      } else {
        await this.startRecording();
      }
    } catch (err) {
      this.status = 'failed';
      this.statusMessage = this.formatActionError(err);
    } finally {
      this.busy = false;
    }
  }

  private async startRecording(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const granted = await PermissionService.ensureMic(context);
    if (!granted) {
      this.status = 'failed';
      this.statusMessage = 'Microphone denied';
      return;
    }
    this.elapsedMs = 0;
    await this.recorder.start(context, this.activeProfile(), {
      onStatus: (s, m) => this.onStatus(s, m),
      onTick: (ms) => this.onTick(ms)
    });
  }

  private onStatus(status: RecorderStatus, message?: string): void {
    if (this.disposed) {
      return;
    }
    this.status = status;
    this.statusMessage = message ?? '';
  }

  private onTick(elapsedMs: number): void {
    if (this.disposed) {
      return;
    }
    this.elapsedMs = elapsedMs;
  }

  private formatElapsed(ms: number): string {
    const seconds = Math.floor(ms / 1000);
    const mm = Math.floor(seconds / 60).toString().padStart(2, '0');
    const ss = (seconds % 60).toString().padStart(2, '0');
    return `${mm}:${ss}`;
  }

  private formatStatus(): string {
    if (this.status === 'idle') {
      return '';
    }
    if (this.statusMessage.length > 0) {
      return `${this.status} · ${this.statusMessage}`;
    }
    return this.status;
  }

  private shouldShowStatus(): boolean {
    return this.status !== 'idle' || this.statusMessage.length > 0;
  }

  private formatActionError(err: Object): string {
    const e = err as Error;
    if (e.message !== undefined && e.message.length > 0) {
      return e.message;
    }
    return 'Action failed';
  }
}
