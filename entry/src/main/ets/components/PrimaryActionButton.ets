import {
  COLOR_ACCENT,
  COLOR_ACCENT_DIM,
  COLOR_TEXT_PRIMARY
} from '../constants/MediaConfig';

@Component
export struct PrimaryActionButton {
  @Prop label: string = '';
  @Prop glyph: string = '●';
  @Prop active: boolean = false;
  onTap: () => void = () => {};

  build() {
    Button() {
      Row({ space: 8 }) {
        Text(this.glyph)
          .fontSize(16)
          .fontColor(COLOR_TEXT_PRIMARY)
        Text(this.label)
          .fontSize(8)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT_PRIMARY)
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width(112)
    .height(54)
    .borderRadius(27)
    .backgroundColor(this.active ? COLOR_ACCENT : '#151A20')
    .border({
      width: 2,
      color: COLOR_ACCENT_DIM
    })
    .onClick(() => {
      this.onTap();
    })
  }
}
