import { audio } from '@kit.AudioKit';
import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ClipEntry } from '../model/ClipEntry';

export interface AudioClipEvents {
  onStatus: (status: string, message?: string) => void;
  onDuration: (durationMs: number) => void;
  onProgress: (pct: number) => void;
}

export class AudioClipPlayerService {
  private player: media.AVPlayer | null = null;
  private fd: number = -1;
  private events: AudioClipEvents | null = null;
  private playbackConfigured: boolean = false;

  async load(clip: ClipEntry, events: AudioClipEvents): Promise<boolean> {
    this.events = events;
    try {
      const file = fileIo.openSync(clip.uri, fileIo.OpenMode.READ_ONLY);
      this.fd = file.fd;
      const player = await media.createAVPlayer();
      this.player = player;
      this.playbackConfigured = false;
      this.attachListeners(events);
      const source: media.AVFileDescriptor = { fd: this.fd, offset: 0 };
      if (clip.sizeBytes > 0) {
        source.length = clip.sizeBytes;
      }
      player.fdSrc = source;
      events.onStatus('loading');
      return true;
    } catch (err) {
      const e = err as BusinessError;
      events.onStatus('failed', `${e.code} ${e.message}`);
      await this.release();
      return false;
    }
  }

  async play(): Promise<void> {
    const player = this.player;
    if (player === null) {
      return;
    }
    try {
      this.configurePlayback();
      await player.play();
      if (this.events !== null) {
        this.events.onStatus('playing');
      }
    } catch (err) {
      const e = err as BusinessError;
      if (this.events !== null) {
        this.events.onStatus('failed', `play: ${e.code} ${e.message}`);
      }
    }
  }

  async pause(): Promise<void> {
    const player = this.player;
    if (player === null) {
      return;
    }
    try {
      await player.pause();
      if (this.events !== null) {
        this.events.onStatus('paused');
      }
    } catch (err) {
      const e = err as BusinessError;
      if (this.events !== null) {
        this.events.onStatus('failed', `pause: ${e.code} ${e.message}`);
      }
    }
  }

  async release(): Promise<void> {
    const player = this.player;
    const fd = this.fd;
    this.player = null;
    this.events = null;
    this.fd = -1;
    this.playbackConfigured = false;
    if (player !== null) {
      try {
        await player.release();
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`AudioClipPlayer.release failed: ${e.code} ${e.message}`);
      }
    }
    if (fd !== -1) {
      try {
        fileIo.closeSync(fd);
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`AudioClipPlayer.closeFd failed: ${e.code} ${e.message}`);
      }
    }
  }

  private attachListeners(events: AudioClipEvents): void {
    const player = this.player;
    if (player === null) {
      return;
    }
    player.on('stateChange', (state: string) => {
      console.info(`AudioClipPlayer state: ${state}`);
      if (state === 'initialized') {
        void this.prepare();
      } else if (state === 'completed') {
        events.onProgress(100);
        events.onStatus('completed');
      }
    });
    player.on('durationUpdate', (durationMs: number) => {
      events.onDuration(durationMs);
    });
    player.on('timeUpdate', (positionMs: number) => {
      const current = this.player;
      if (current === null || current.duration <= 0) {
        return;
      }
      const pct = Math.min(100, Math.round((positionMs / current.duration) * 100));
      events.onProgress(pct);
    });
    player.on('error', (err: BusinessError) => {
      events.onStatus('failed', `player: ${err.code} ${err.message}`);
    });
    player.on('audioInterrupt', (event: audio.InterruptEvent) => {
      const shouldPause = event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
        event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP;
      if (shouldPause) {
        events.onStatus('paused', 'Interrupted');
        void this.pause();
      }
    });
    player.on('audioOutputDeviceChangeWithInfo', () => {
      events.onStatus('paused', 'Output device changed');
      void this.pause();
    });
  }

  private async prepare(): Promise<void> {
    const player = this.player;
    if (player === null) {
      return;
    }
    try {
      player.audioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };
      await player.prepare();
      this.configurePlayback();
      if (this.events !== null) {
        this.events.onStatus('ready');
      }
    } catch (err) {
      const e = err as BusinessError;
      if (this.events !== null) {
        this.events.onStatus('failed', `prepare: ${e.code} ${e.message}`);
      }
    }
  }

  private configurePlayback(): void {
    const player = this.player;
    if (player === null || this.playbackConfigured) {
      return;
    }
    try {
      player.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
      player.setVolume(1.0);
      this.playbackConfigured = true;
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`AudioClipPlayer.configure failed: ${e.code} ${e.message}`);
    }
  }
}
