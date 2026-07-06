import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';
import { resourceManager } from '@kit.LocalizationKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SAMPLE_RAWFILE, THUMB_HEIGHT_PX, THUMB_PCTS, THUMB_WIDTH_PX } from '../constants/MediaConfig';

export interface ThumbnailBatch {
  durationMs: number;
  frames: image.PixelMap[];
}

export class ThumbnailService {
  static async extractSampleFrames(context: common.UIAbilityContext): Promise<ThumbnailBatch> {
    const durationUs = await ThumbnailService.readDurationUs(context);
    const timestamps = ThumbnailService.buildTimestamps(durationUs);
    const frames = await ThumbnailService.readFrames(context, timestamps);
    return { durationMs: Math.round(durationUs / 1000), frames };
  }

  private static async readDurationUs(context: common.UIAbilityContext): Promise<number> {
    let fd: resourceManager.RawFileDescriptor;
    try {
      fd = await context.resourceManager.getRawFd(SAMPLE_RAWFILE);
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`ThumbnailService.getRawFd (metadata) failed: ${e.code} ${e.message}`);
      return 12_000_000;
    }
    let durationUs = 0;
    let extractor: media.AVMetadataExtractor | null = null;
    try {
      extractor = await media.createAVMetadataExtractor();
      extractor.fdSrc = { fd: fd.fd, offset: fd.offset, length: fd.length };
      const metadata = await extractor.fetchMetadata();
      if (metadata.duration !== undefined) {
        const parsed = Number.parseInt(metadata.duration, 10);
        if (!Number.isNaN(parsed) && parsed > 0) {
          durationUs = parsed * 1000;
        }
      }
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`ThumbnailService.duration failed: ${e.code} ${e.message}`);
    } finally {
      if (extractor !== null) {
        try {
          await extractor.release();
        } catch (err) {
          const e = err as BusinessError;
          console.warn(`ThumbnailService.extractor.release failed: ${e.code} ${e.message}`);
        }
      }
      try {
        await context.resourceManager.closeRawFd(SAMPLE_RAWFILE);
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`ThumbnailService.closeRawFd (metadata) failed: ${e.code} ${e.message}`);
      }
    }
    if (durationUs <= 0) {
      durationUs = 12_000_000;
    }
    return durationUs;
  }

  private static buildTimestamps(durationUs: number): number[] {
    const out: number[] = [];
    for (const pct of THUMB_PCTS) {
      out.push(Math.max(0, Math.floor(durationUs * pct)));
    }
    return out;
  }

  private static async readFrames(
    context: common.UIAbilityContext,
    timestamps: number[]
  ): Promise<image.PixelMap[]> {
    let fd: resourceManager.RawFileDescriptor;
    try {
      fd = await context.resourceManager.getRawFd(SAMPLE_RAWFILE);
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`ThumbnailService.getRawFd (frames) failed: ${e.code} ${e.message}`);
      return [];
    }
    let gen: media.AVImageGenerator | null = null;
    const frames: image.PixelMap[] = [];
    try {
      gen = await media.createAVImageGenerator();
      gen.fdSrc = { fd: fd.fd, offset: fd.offset, length: fd.length };
      const params: media.PixelMapParams = {
        width: THUMB_WIDTH_PX,
        height: THUMB_HEIGHT_PX
      };
      for (const tsUs of timestamps) {
        try {
          const pm: image.PixelMap = await gen.fetchFrameByTime(
            tsUs,
            media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST,
            params
          );
          const info = await pm.getImageInfo();
          console.info(`Thumbnail at ${tsUs}us: ${info.size.width}x${info.size.height}`);
          frames.push(pm);
        } catch (err) {
          const e = err as BusinessError;
          console.warn(`ThumbnailService.frame at ${tsUs}us failed: ${e.code} ${e.message}`);
        }
      }
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`ThumbnailService.frames failed: ${e.code} ${e.message}`);
    } finally {
      if (gen !== null) {
        try {
          await gen.release();
        } catch (err) {
          const e = err as BusinessError;
          console.warn(`ThumbnailService.gen.release failed: ${e.code} ${e.message}`);
        }
      }
      try {
        await context.resourceManager.closeRawFd(SAMPLE_RAWFILE);
      } catch (err) {
        const e = err as BusinessError;
        console.warn(`ThumbnailService.closeRawFd (frames) failed: ${e.code} ${e.message}`);
      }
    }
    return frames;
  }
}
