/*
 * ============================================================================
 * 文件名：components/SettingRows.ets
 * ============================================================================
 * 【用途】设置页通用行组件（两枚）：SettingSwitchRow（图标+标题+描述+开关，onChange）、
 *   SettingNavRow（图标+标题+描述+右侧箭头/自定义，onTap）；外观与隐私设置共用。
 * 【前置条件 / 假设】
 *   - 依赖：Theme；开关组件用系统 Toggle/自定义 Toggle 视觉；
 *   - 假设：行高 62-64；图标为 sys.symbol。
 * 【输入 / 输出（后置条件）】
 *   - 输入：开关变化、行点击；
 *   - 输出：onChange(on)/onTap() 回调。
 * 【关键类 / 算法】
 *   - 两组件均无内部业务状态，纯受控（props + 回调）。
 * 【参考源】
 *   - iBest-UI 设置列表样式；ArkUI Toggle 文档
 * ============================================================================
 */
import { Theme } from '../utils/Theme';

@Component
export struct SettingSwitchRow {
  @Prop icon: Resource = $r('sys.symbol.lock');
  @Prop iconStyle: string = '';
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop isOn: boolean = false;
  onChange: (on: boolean) => void = (on: boolean) => {};
  onTap: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Stack() {
        Column().width(38).height(38).borderRadius(999).backgroundColor(this.iconStyle === 'danger' ? '#FDECEC' : '#EDF6EF')
        SymbolGlyph(this.icon).fontSize(18)
          .fontColor([this.iconStyle === 'danger' ? Theme.DANGER : Theme.BRAND_DEEP])
      }
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.PRIMARY)
        Text(this.desc)
          .fontSize(11)
          .fontColor(Theme.TERTIARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(Theme.BRAND_DEEP)
        .onChange((on: boolean) => {
          this.onChange(on);
        })
    }
    .width('100%')
    .height(62)
    .padding({ left: 14, right: 14 })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct SettingNavRow {
  @Prop icon: Resource = $r('sys.symbol.leaf');
  @Prop iconStyle: string = '';
  @Prop title: string = '';
  @Prop desc: string = '';
  onTap: () => void = () => {};
  @Prop trailing: string = '';

  build() {
    Row({ space: 12 }) {
      Stack() {
        Column().width(38).height(38).borderRadius(999).backgroundColor(this.iconStyle === 'danger' ? '#FDECEC' : '#EDF6EF')
        SymbolGlyph(this.icon).fontSize(18)
          .fontColor([this.iconStyle === 'danger' ? Theme.DANGER : Theme.BRAND_DEEP])
      }
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.PRIMARY)
        Text(this.desc)
          .fontSize(11)
          .fontColor(Theme.TERTIARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.trailing !== '') {
        Text(this.trailing)
          .fontSize(12)
          .fontColor(Theme.BRAND_DEEP)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(14)
          .backgroundColor('#ECFBEF')
          .onClick(() => {
            this.onTap();
          })
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([Theme.TERTIARY])
      }
    }
    .width('100%')
    .height(62)
    .padding({ left: 14, right: 14 })
    .onClick(() => {
      this.onTap();
    })
  }
}