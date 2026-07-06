import { AudioClipPageBuilder } from './AudioClipPage';
import { GalleryPageBuilder } from './GalleryPage';
import { RecordPageBuilder } from './RecordPage';
import { StreamPageBuilder } from './StreamPage';
import { ThumbnailsPageBuilder } from './ThumbnailsPage';
import {
  COLOR_BG,
  COLOR_PANEL,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../constants/MediaConfig';

@Builder
function homePageBuilder() {
  HomePage()
}

@Component
struct HomePage {
  @Consume('pathStack') pathStack: NavPathStack;

  build() {
    Column({ space: 8 }) {
      Text('Media Studio')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT_PRIMARY)
        .margin({ top: 12, bottom: 2 })

      Text('Record, preview, stream')
        .fontSize(10)
        .fontColor(COLOR_TEXT_SECONDARY)
        .margin({ bottom: 6 })

      this.HomeButton('Record', '●', () => {
        this.pathStack.pushPathByName('RecordPage', null);
      })
      this.HomeButton('Gallery', '▦', () => {
        this.pathStack.pushPathByName('GalleryPage', null);
      })
      this.HomeButton('Stream', '▶', () => {
        this.pathStack.pushPathByName('StreamPage', null);
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: 14 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .backgroundColor(COLOR_BG)
  }

  @Builder
  HomeButton(label: string, glyph: string, action: () => void) {
    Button() {
      Row({ space: 10 }) {
        Text(glyph)
          .fontSize(14)
          .fontColor(COLOR_TEXT_PRIMARY)
        Text(label)
          .fontSize(12)
          .fontColor(COLOR_TEXT_PRIMARY)
      }
    }
    .width('76%')
    .height(34)
    .borderRadius(17)
    .backgroundColor(COLOR_PANEL)
    .onClick(() => {
      action();
    })
  }
}

@Entry
@Component
struct Index {
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();

  @Builder
  PagesMap(name: string) {
    if (name === 'RecordPage') {
      RecordPageBuilder()
    } else if (name === 'GalleryPage') {
      GalleryPageBuilder()
    } else if (name === 'AudioClipPage') {
      AudioClipPageBuilder()
    } else if (name === 'ThumbnailsPage') {
      ThumbnailsPageBuilder()
    } else if (name === 'StreamPage') {
      StreamPageBuilder()
    }
  }

  build() {
    Navigation(this.pathStack) {
      homePageBuilder()
    }
    .navDestination(this.PagesMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }
}
