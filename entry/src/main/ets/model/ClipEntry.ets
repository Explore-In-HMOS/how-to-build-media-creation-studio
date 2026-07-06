export type ClipKind = 'audio' | 'video';

export type ClipSource = 'sandbox' | 'rawfile';

export interface ClipEntry {
  id: string;
  name: string;
  uri: string;
  kind: ClipKind;
  source: ClipSource;
  createdAt: number;
  sizeBytes: number;
}
