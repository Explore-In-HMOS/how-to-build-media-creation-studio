import { ClipEntry } from '../model/ClipEntry';

export class ClipSelectionService {
  private static selected: ClipEntry | null = null;

  static set(entry: ClipEntry): void {
    ClipSelectionService.selected = entry;
  }

  static get(): ClipEntry | null {
    return ClipSelectionService.selected;
  }
}
