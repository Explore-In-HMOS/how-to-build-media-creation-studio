import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  CLIP_FILE_EXT,
  CLIP_FILE_PREFIX,
  CLIPS_DIR,
  SAMPLE_DISPLAY_NAME,
  SAMPLE_RAWFILE
} from '../constants/MediaConfig';
import { ClipEntry } from '../model/ClipEntry';

export class ClipRepository {
  static list(context: common.UIAbilityContext): ClipEntry[] {
    const out: ClipEntry[] = [ClipRepository.buildSampleEntry()];
    const dir = `${context.filesDir}/${CLIPS_DIR}`;
    let dirExists = false;
    try {
      dirExists = fileIo.accessSync(dir);
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`ClipRepository.access failed: ${e.code} ${e.message}`);
    }
    if (!dirExists) {
      return out;
    }
    let names: string[] = [];
    try {
      names = fileIo.listFileSync(dir);
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`ClipRepository.list failed: ${e.code} ${e.message}`);
      return out;
    }
    const recorded: ClipEntry[] = [];
    for (const name of names) {
      const entry = ClipRepository.buildSandboxEntry(dir, name);
      if (entry !== null) {
        recorded.push(entry);
      }
    }
    recorded.sort((a, b) => b.createdAt - a.createdAt);
    for (const entry of recorded) {
      out.push(entry);
    }
    return out;
  }

  static delete(entry: ClipEntry): boolean {
    if (entry.source !== 'sandbox') {
      return false;
    }
    try {
      fileIo.unlinkSync(entry.uri);
      return true;
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`ClipRepository.delete failed: ${e.code} ${e.message}`);
      return false;
    }
  }

  private static buildSampleEntry(): ClipEntry {
    return {
      id: 'sample',
      name: SAMPLE_DISPLAY_NAME,
      uri: SAMPLE_RAWFILE,
      kind: 'video',
      source: 'rawfile',
      createdAt: 0,
      sizeBytes: 0
    };
  }

  private static buildSandboxEntry(dir: string, name: string): ClipEntry | null {
    if (!name.startsWith(CLIP_FILE_PREFIX) || !name.endsWith(CLIP_FILE_EXT)) {
      return null;
    }
    const path = `${dir}/${name}`;
    let sizeBytes = 0;
    let createdAt = Date.now();
    try {
      const stat = fileIo.statSync(path);
      sizeBytes = stat.size;
      createdAt = stat.mtime;
    } catch (err) {
      const e = err as BusinessError;
      console.warn(`ClipRepository.stat failed: ${e.code} ${e.message}`);
    }
    const id = name.slice(CLIP_FILE_PREFIX.length, name.length - CLIP_FILE_EXT.length);
    return {
      id,
      name: `Clip ${id.slice(0, 6)}`,
      uri: path,
      kind: 'audio',
      source: 'sandbox',
      createdAt,
      sizeBytes
    };
  }
}
