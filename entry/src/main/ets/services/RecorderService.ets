import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  CLIP_FILE_EXT,
  CLIP_FILE_PREFIX,
  CLIPS_DIR,
  MAX_RECORD_MS,
  RECORD_TICK_MS,
  RecorderProfileSpec
} from '../constants/MediaConfig';
import { ClipEntry } from '../model/ClipEntry';
import { secureRandomId } from '../utils/SecureRandom';

export type RecorderStatus =
  | 'idle'
  | 'preparing'
  | 'recording'
  | 'stopping'
  | 'saved'
  | 'failed'
  | 'interrupted';

export interface RecorderEvents {
  onStatus: (status: RecorderStatus, message?: string) => void;
  onTick: (elapsedMs: number) => void;
}

const MIN_EXPECTED_BYTES: number = 4096;

export class RecorderService {
  private recorder: media.AVRecorder | null = null;
  private fd: number = -1;
  private filePath: string = '';
  private startedAt: number = 0;
  private tickHandle: number = -1;
  private deviceChangeBound: boolean = false;
  private audioManager: audio.AudioManager | null = null;
  private stopping: boolean = false;
  private stoppedCleanly: boolean = false;

  async start(
    context: common.UIAbilityContext,
    profile: RecorderProfileSpec,
    events: RecorderEvents
  ): Promise<boolean> {
    if (this.recorder !== null) {
      events.onStatus('failed', 'Recorder busy');
      return false;
    }
    this.stopping = false;
    this.stoppedCleanly = false;
    events.onStatus('preparing');
    try {
      await this.ensureClipsDir(context);
      const id = secureRandomId();
      this.filePath = `${context.filesDir}/${CLIPS_DIR}/${CLIP_FILE_PREFIX}${id}${CLIP_FILE_EXT}`;
      const file = fileIo.openSync(
        this.filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE
      );
      this.fd = file.fd;

      const recorder = await media.createAVRecorder();
      this.recorder = recorder;
      this.attachListeners(events);
      this.attachDeviceChangeListener(events);

      await recorder.prepare(this.buildConfig(profile));
      await recorder.start();
      this.startedAt = Date.now();
      this.startTicker(events);
      events.onStatus('recording');
      return true;
    } catch (err) {
      const e = err as BusinessError;
      events.onStatus('failed', `start: ${e.code} ${e.message}`);
      await this.cleanup();
      return false;
    }
  }

  async stop(events: RecorderEvents): Promise<ClipEntry | null> {
    if (this.stopping) {
      return null;
    }
    const recorder = this.recorder;
    if (recorder === null) {
      events.onStatus('idle');
      return null;
    }
    this.stopping = true;
    events.onStatus('stopping');
    this.stopTicker();
    let entry: ClipEntry | null = null;
    try {
      await recorder.stop();
      this.stoppedCleanly = true;
      const durationMs = Date.now() - this.startedAt;
      const path = this.filePath;
      const id = this.extractIdFromPath(path);
      let sizeBytes = 0;
      try {
        sizeBytes = fileIo.statSync(path).size;
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`RecorderService.stat failed: ${e.code} ${e.message}`);
      }
      entry = {
        id,
        name: `Clip ${id.slice(0, 6)}`,
        uri: path,
        kind: 'audio',
        source: 'sandbox',
        createdAt: Date.now(),
        sizeBytes
      };
      console.info(`RecorderService.saved ${durationMs}ms ${sizeBytes} bytes ${path}`);
      if (durationMs >= 1000 && sizeBytes < MIN_EXPECTED_BYTES) {
        console.warn(`RecorderService.emptyAudioSuspected duration=${durationMs} size=${sizeBytes}`);
        events.onStatus('saved', `${Math.round(durationMs / 100) / 10}s · empty audio`);
      } else {
        events.onStatus('saved', `${Math.round(durationMs / 100) / 10}s · ${this.formatSize(sizeBytes)}`);
      }
    } catch (err) {
      const e = err as BusinessError;
      events.onStatus('failed', `stop: ${e.code} ${e.message}`);
    } finally {
      await this.cleanup();
      this.stopping = false;
    }
    return entry;
  }

  async release(): Promise<void> {
    if (this.stopping) {
      return;
    }
    this.stopTicker();
    await this.cleanup();
  }

  isRecording(): boolean {
    return this.recorder !== null;
  }

  private attachListeners(events: RecorderEvents): void {
    const recorder = this.recorder;
    if (recorder === null) {
      return;
    }
    try {
      recorder.on('stateChange', (
        state: media.AVRecorderState,
        reason: media.StateChangeReason
      ) => {
        console.info(`AVRecorder state: ${state}, reason: ${reason}`);
        if (state === 'stopped' && !this.stopping && this.recorder !== null) {
          events.onStatus('interrupted', 'Recorder stopped by system');
          this.stopTicker();
          void this.cleanup();
        }
      });
      recorder.on('error', (err: BusinessError) => {
        events.onStatus('failed', `runtime: ${err.code} ${err.message}`);
        if (this.stopping) {
          return;
        }
        this.stopTicker();
        void this.cleanup();
      });
      recorder.on('audioCapturerChange', (info: audio.AudioCapturerChangeInfo) => {
        console.info(`AVRecorder audio capturer changed: ${JSON.stringify(info)}`);
        const stoppedBySystem = info.capturerState === audio.AudioState.STATE_STOPPED ||
          info.capturerState === audio.AudioState.STATE_PAUSED;
        if (stoppedBySystem && !this.stopping && this.recorder !== null) {
          events.onStatus('interrupted', 'Audio capturer interrupted');
          void this.stop(events);
        }
      });
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`RecorderService.attachListeners failed: ${e.code} ${e.message}`);
    }
  }

  private buildConfig(profile: RecorderProfileSpec): media.AVRecorderConfig {
    return {
      audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
      profile: {
        audioBitrate: profile.audioBitrate,
        audioChannels: profile.audioChannels,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: profile.audioSampleRate,
        fileFormat: media.ContainerFormatType.CFT_MPEG_4A
      },
      url: `fd://${this.fd}`
    };
  }

  private formatSize(sizeBytes: number): string {
    const kb = Math.max(1, Math.round(sizeBytes / 1024));
    return `${kb} KB`;
  }

  private attachDeviceChangeListener(events: RecorderEvents): void {
    try {
      this.audioManager = audio.getAudioManager();
      const routing = this.audioManager.getRoutingManager();
      routing.on('deviceChange', audio.DeviceFlag.INPUT_DEVICES_FLAG,
        (action: audio.DeviceChangeAction) => {
          console.info(`Recorder input device changed: ${action.type}`);
          const disconnected = action.type === audio.DeviceChangeType.DISCONNECT;
          if (disconnected && !this.stopping && this.recorder !== null) {
            events.onStatus('interrupted', 'Input device disconnected');
            void this.stop(events);
          }
        });
      this.deviceChangeBound = true;
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`RecorderService.deviceListener failed: ${e.code} ${e.message}`);
      this.deviceChangeBound = false;
    }
  }

  private detachDeviceChangeListener(): void {
    if (!this.deviceChangeBound || this.audioManager === null) {
      return;
    }
    try {
      this.audioManager.getRoutingManager().off('deviceChange');
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`RecorderService.detach failed: ${e.code} ${e.message}`);
    }
    this.deviceChangeBound = false;
  }

  private startTicker(events: RecorderEvents): void {
    const startedAt = this.startedAt;
    this.tickHandle = setInterval(() => {
      const elapsed = Date.now() - startedAt;
      events.onTick(elapsed);
      if (elapsed >= MAX_RECORD_MS && this.recorder !== null) {
        events.onStatus('stopping', 'Max duration reached');
        void this.stop(events);
      }
    }, RECORD_TICK_MS);
  }

  private stopTicker(): void {
    if (this.tickHandle !== -1) {
      clearInterval(this.tickHandle);
      this.tickHandle = -1;
    }
  }

  private async cleanup(): Promise<void> {
    const recorder = this.recorder;
    this.recorder = null;
    this.stopTicker();
    this.detachDeviceChangeListener();
    if (recorder !== null) {
      try {
        if (!this.stoppedCleanly) {
          await recorder.stop();
        }
      } catch (err) {
        const e = err as BusinessError;
        console.info(`RecorderService.stopOnCleanup skipped: ${e.code} ${e.message}`);
      }
      try {
        await recorder.release();
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`RecorderService.release failed: ${e.code} ${e.message}`);
      }
    }
    if (this.fd !== -1) {
      try {
        fileIo.closeSync(this.fd);
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`RecorderService.closeFd failed: ${e.code} ${e.message}`);
      }
      this.fd = -1;
    }
    this.stoppedCleanly = false;
  }

  private async ensureClipsDir(context: common.UIAbilityContext): Promise<void> {
    const dir = `${context.filesDir}/${CLIPS_DIR}`;
    let exists = false;
    try {
      exists = fileIo.accessSync(dir);
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`RecorderService.access failed: ${e.code} ${e.message}`);
    }
    if (!exists) {
      try {
        fileIo.mkdirSync(dir);
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`RecorderService.mkdir failed: ${e.code} ${e.message}`);
      }
    }
  }

  private extractIdFromPath(path: string): string {
    const slash = path.lastIndexOf('/');
    const file = slash >= 0 ? path.slice(slash + 1) : path;
    const withoutExt = file.endsWith(CLIP_FILE_EXT)
      ? file.slice(0, file.length - CLIP_FILE_EXT.length)
      : file;
    return withoutExt.startsWith(CLIP_FILE_PREFIX)
      ? withoutExt.slice(CLIP_FILE_PREFIX.length)
      : withoutExt;
  }
}
