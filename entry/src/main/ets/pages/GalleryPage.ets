import { common } from '@kit.AbilityKit';
import {
  COLOR_BG,
  COLOR_PANEL,
  COLOR_TEXT_MUTED,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../constants/MediaConfig';
import { ClipEntry } from '../model/ClipEntry';
import { ClipRepository } from '../services/ClipRepository';
import { ClipSelectionService } from '../services/ClipSelectionService';

@Builder
export function GalleryPageBuilder() {
  GalleryPage()
}

@Component
struct GalleryPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State clips: ClipEntry[] = [];

  aboutToAppear(): void {
    this.refresh();
  }

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        Text('Gallery')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT_PRIMARY)
          .margin({ top: 10, bottom: 8 })

        List({ space: 6 }) {
          ForEach(this.clips, (clip: ClipEntry) => {
            ListItem() {
              this.ClipRow(clip)
            }
          }, (clip: ClipEntry) => clip.id)
        }
        .width('78%')
        .layoutWeight(1)
        .padding({ top: 4, bottom: 28 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLOR_BG)
    }
    .hideTitleBar(true)
    .backgroundColor(COLOR_BG)
    .onShown(() => {
      this.refresh();
    })
  }

  @Builder
  ClipRow(clip: ClipEntry) {
    Row({ space: 6 }) {
      Text(clip.kind === 'video' ? '▷' : '♪')
        .fontSize(14)
        .fontColor(COLOR_TEXT_PRIMARY)
        .width(18)
        .textAlign(TextAlign.Center)
      Column({ space: 2 }) {
        Text(clip.name)
          .fontSize(10)
          .fontColor(COLOR_TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subtitle(clip))
          .fontSize(8)
          .fontColor(COLOR_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (clip.source === 'sandbox') {
        Text('×')
          .fontSize(14)
          .fontColor(COLOR_TEXT_MUTED)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.removeClip(clip);
          })
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: 7, right: 6 })
    .borderRadius(8)
    .backgroundColor(COLOR_PANEL)
    .onClick(() => {
      this.openClip(clip);
    })
  }

  private subtitle(clip: ClipEntry): string {
    if (clip.source === 'rawfile') {
      return 'Bundled · tap for thumbnails';
    }
    const kb = Math.max(1, Math.round(clip.sizeBytes / 1024));
    return `${kb} KB · tap to play`;
  }

  private refresh(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.clips = ClipRepository.list(context);
  }

  private removeClip(clip: ClipEntry): void {
    if (ClipRepository.delete(clip)) {
      this.refresh();
    }
  }

  private openClip(clip: ClipEntry): void {
    if (clip.kind === 'video') {
      this.pathStack.pushPathByName('ThumbnailsPage', null);
      return;
    }
    ClipSelectionService.set(clip);
    this.pathStack.pushPathByName('AudioClipPage', null);
  }
}
