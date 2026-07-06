export interface RecorderProfileSpec {
  key: string;
  label: string;
  audioBitrate: number;
  audioSampleRate: number;
  audioChannels: number;
}

export const PROFILE_NORMAL: RecorderProfileSpec = {
  key: 'normal',
  label: 'Normal',
  audioBitrate: 96000,
  audioSampleRate: 44100,
  audioChannels: 1
};

export const PROFILE_HIGH: RecorderProfileSpec = {
  key: 'high',
  label: 'High',
  audioBitrate: 128000,
  audioSampleRate: 44100,
  audioChannels: 1
};

export const PROFILES: RecorderProfileSpec[] = [PROFILE_NORMAL, PROFILE_HIGH];

export const CLIPS_DIR: string = 'clips';
export const CLIP_FILE_PREFIX: string = 'clip_';
export const CLIP_FILE_EXT: string = '.m4a';

export const SAMPLE_RAWFILE: string = 'sample.mp4';
export const SAMPLE_DISPLAY_NAME: string = 'Sample.mp4';
export const SAMPLE_MIME_TYPE: string = 'video/mp4';

export const THUMB_PCTS: number[] = [0.08, 0.36, 0.64, 0.9];
export const THUMB_WIDTH_PX: number = 96;
export const THUMB_HEIGHT_PX: number = 96;

export const RECORD_TICK_MS: number = 200;
export const MAX_RECORD_MS: number = 120 * 1000;

export const COLOR_BG: string = '#101418';
export const COLOR_PANEL: string = '#1A1F26';
export const COLOR_ACCENT: string = '#FF5555';
export const COLOR_ACCENT_DIM: string = '#552222';
export const COLOR_TEXT_PRIMARY: string = '#F5F7FA';
export const COLOR_TEXT_SECONDARY: string = '#AAB3BE';
export const COLOR_TEXT_MUTED: string = '#6B7280';
export const COLOR_PROGRESS_DOWNLOAD: string = '#5AA0FF';
export const COLOR_PROGRESS_PLAYBACK: string = '#7CDC8B';
