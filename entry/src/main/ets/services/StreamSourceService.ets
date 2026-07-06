import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SAMPLE_MIME_TYPE, SAMPLE_RAWFILE } from '../constants/MediaConfig';

const STREAM_SCHEME: string = 'http';
const STREAM_HOST: string = 'memory.local';
const STREAM_PATH: string = 'sample.mp4';
const STREAM_KEY: string = `${STREAM_SCHEME}://${STREAM_HOST}/${STREAM_PATH}`;

export interface StreamEvents {
  onStatus: (status: string, message?: string) => void;
  onDownload: (pct: number) => void;
  onPlayback: (pct: number) => void;
  onDuration: (durationMs: number) => void;
}

export class StreamSourceService {
  private player: media.AVPlayer | null = null;
  private mediaSource: media.MediaSource | null = null;
  private buffer: Uint8Array | null = null;
  private totalLength: number = 0;
  private requests: Map<number, media.MediaSourceLoadingRequest> = new Map();
  private deliveredBytes: number = 0;
  private nextUuid: number = 1;
  private events: StreamEvents | null = null;
  private playerState: string = 'idle';
  private savedContext: common.UIAbilityContext | null = null;

  async load(context: common.UIAbilityContext, events: StreamEvents): Promise<boolean> {
    this.events = events;
    this.savedContext = context;
    try {
      await this.loadBuffer(context);
      const player: media.AVPlayer = await media.createAVPlayer();
      this.player = player;
      this.attachPlayerListeners(events);
      const source = this.createMediaSource();
      await player.setMediaSource(source);
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
    if (this.playerState === 'completed') {
      const ok = await this.reloadForReplay();
      if (!ok) {
        return;
      }
    }
    const player = this.player;
    if (player === null) {
      return;
    }
    try {
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

  private async reloadForReplay(): Promise<boolean> {
    const ctx = this.savedContext;
    const evs = this.events;
    if (ctx === null || evs === null) {
      return false;
    }
    await this.releaseInternal();
    const loaded = await this.load(ctx, evs);
    if (!loaded) {
      return false;
    }
    return await this.waitForPrepared();
  }

  private async releaseInternal(): Promise<void> {
    this.requests.clear();
    this.deliveredBytes = 0;
    const player = this.player;
    this.player = null;
    this.mediaSource = null;
    this.buffer = null;
    this.playerState = 'idle';
    if (player !== null) {
      try {
        await player.release();
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`StreamSource.releaseInternal failed: ${e.code} ${e.message}`);
      }
    }
  }

  private waitForPrepared(): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      if (this.playerState === 'prepared' || this.playerState === 'paused') {
        resolve(true);
        return;
      }
      const start = Date.now();
      const handle = setInterval(() => {
        const ready = this.playerState === 'prepared' || this.playerState === 'paused';
        const expired = Date.now() - start >= 3000;
        if (ready || expired) {
          clearInterval(handle);
          resolve(ready);
        }
      }, 50);
    });
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
    this.requests.clear();
    this.deliveredBytes = 0;
    const player = this.player;
    this.player = null;
    this.mediaSource = null;
    this.buffer = null;
    this.events = null;
    this.savedContext = null;
    this.playerState = 'idle';
    if (player !== null) {
      try {
        await player.release();
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`StreamSource.release failed: ${e.code} ${e.message}`);
      }
    }
  }

  private async loadBuffer(context: common.UIAbilityContext): Promise<void> {
    let data: Uint8Array;
    try {
      data = await context.resourceManager.getRawFileContent(SAMPLE_RAWFILE);
    } catch (err) {
      const e = err as BusinessError;
      throw new Error(`getRawFileContent failed: ${e.code} ${e.message}`);
    }
    this.buffer = data;
    this.totalLength = data.byteLength;
    this.deliveredBytes = 0;
  }

  private createMediaSource(): media.MediaSource {
    let source: media.MediaSource;
    try {
      source = media.createMediaSourceWithUrl(STREAM_KEY, {
        'Content-Type': SAMPLE_MIME_TYPE
      });
    } catch (err) {
      const e = err as BusinessError;
      throw new Error(`createMediaSourceWithUrl failed: ${e.code} ${e.message}`);
    }
    source.setMediaResourceLoaderDelegate(this.buildLoader());
    this.mediaSource = source;
    return source;
  }

  private buildLoader(): media.MediaSourceLoader {
    const owner = this;
    const open = (request: media.MediaSourceLoadingRequest): number => {
      return owner.onLoaderOpen(request);
    };
    const read = (uuid: number, offset: number, length: number): void => {
      owner.onLoaderRead(uuid, offset, length);
    };
    const close = (uuid: number): void => {
      owner.onLoaderClose(uuid);
    };
    return { open, read, close } as media.MediaSourceLoader;
  }

  onLoaderOpen(request: media.MediaSourceLoadingRequest): number {
    const uuid = this.nextUuid++;
    this.requests.set(uuid, request);
    this.respondHeader(uuid, request);
    return uuid;
  }

  onLoaderRead(uuid: number, offset: number, length: number): void {
    const request = this.requests.get(uuid);
    const buffer = this.buffer;
    if (request === undefined || buffer === null) {
      return;
    }
    const total = this.totalLength;
    if (offset >= total) {
      this.finishRequest(uuid, request);
      return;
    }
    const end = total;
    try {
      const data = StreamSourceService.sliceToArrayBuffer(buffer, offset, end);
      const written = request.respondData(uuid, offset, data);
      if (written < 0) {
        return;
      }
      const newFrontier = end;
      if (newFrontier > this.deliveredBytes) {
        this.deliveredBytes = Math.min(total, newFrontier);
      }
      this.notifyDownload();
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`StreamSource.respondData failed: ${e.code} ${e.message}`);
    }
  }

  onLoaderClose(uuid: number): void {
    this.requests.delete(uuid);
  }

  private respondHeader(uuid: number, request: media.MediaSourceLoadingRequest): void {
    try {
      request.respondHeader(uuid, {
        'Content-Type': SAMPLE_MIME_TYPE,
        'Content-Length': `${this.totalLength}`,
        'Accept-Ranges': 'bytes'
      });
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`StreamSource.respondHeader failed: ${e.code} ${e.message}`);
    }
  }

  private notifyDownload(): void {
    const events = this.events;
    const total = this.totalLength;
    if (events === null || total === 0) {
      return;
    }
    const pct = Math.min(100, Math.round((this.deliveredBytes / total) * 100));
    events.onDownload(pct);
  }

  private finishRequest(uuid: number, request: media.MediaSourceLoadingRequest): void {
    try {
      request.finishLoading(uuid, media.LoadingRequestError.LOADING_ERROR_SUCCESS);
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`StreamSource.finishLoading failed: ${e.code} ${e.message}`);
    }
  }

  private static sliceToArrayBuffer(source: Uint8Array, start: number, end: number): ArrayBuffer {
    const view = source.subarray(start, end);
    const out = new ArrayBuffer(view.byteLength);
    new Uint8Array(out).set(view);
    return out;
  }

  private attachPlayerListeners(events: StreamEvents): void {
    const player = this.player;
    if (player === null) {
      return;
    }
    player.on('stateChange', (state: string) => {
      console.info(`AVPlayer state: ${state}`);
      this.playerState = state;
      if (state === 'initialized') {
        void this.preparePlayer();
      } else if (state === 'completed') {
        events.onPlayback(100);
        events.onStatus('completed');
      }
    });
    player.on('durationUpdate', (durationMs: number) => {
      events.onDuration(durationMs);
    });
    player.on('timeUpdate', (positionMs: number) => {
      const current = this.player;
      if (current === null) {
        return;
      }
      const dur = current.duration;
      if (dur > 0) {
        const pct = Math.min(100, Math.round((positionMs / dur) * 100));
        events.onPlayback(pct);
      }
    });
    player.on('error', (err: BusinessError) => {
      events.onStatus('failed', `player: ${err.code} ${err.message}`);
    });
    player.on('audioInterrupt', (event: audio.InterruptEvent) => {
      this.handleAudioInterrupt(event, events);
    });
    player.on('audioOutputDeviceChangeWithInfo', () => {
      events.onStatus('paused', 'Output device changed');
      void this.pause();
    });
  }

  private handleAudioInterrupt(event: audio.InterruptEvent, events: StreamEvents): void {
    const force = event.forceType === audio.InterruptForceType.INTERRUPT_FORCE;
    const shouldPause = event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
      event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP;
    if (shouldPause) {
      events.onStatus('paused', force ? 'Interrupted' : 'Interrupt hint');
      void this.pause();
    }
  }

  private async preparePlayer(): Promise<void> {
    const player = this.player;
    if (player === null) {
      return;
    }
    try {
      await player.prepare();
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
}
