import { Constants } from '../common/Constants';

@Component
export struct AccountTab {
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop isLoggedIn: boolean = false;
  @Prop userName: string = '';
  onNavigate: (page: string) => void = () => {};

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('账号').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
        }
        .width('100%').padding({ left: 20, right: 20, top: 16 + this.statusBarHeight, bottom: 16 })

        Row() {
          Stack() {
            Circle().width(56).height(56).fill(this.isLoggedIn ? '#CF0A2C' : '#555555')
            if (this.isLoggedIn && this.userName.length > 0) {
              Text(this.userName.charAt(0)).fontSize(26).fontColor(Color.White)
            } else {
              Text('👤').fontSize(24)
            }
          }
          Column() {
            Text(this.isLoggedIn && this.userName.length > 0 ? this.userName : '未登录')
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
            Text(this.isLoggedIn ? 'HUAWEI 账号已绑定' : '登录后同步数据到云端')
              .fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start).margin({ left: 12 })
          Blank()
        }
        .width('100%').padding(16).backgroundColor(this.cardColor).borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 10 })
        .onClick(() => { this.onNavigate(Constants.PAGE_LOGIN); })

        this.accountMenuItem('👤', '个人信息', '身高、体重、性别设置', () => { this.onNavigate(Constants.PAGE_PROFILE); })
        this.accountMenuItem('⚙️', '设置', '通知、目标、主题、关于', () => { this.onNavigate(Constants.PAGE_SETTINGS); })
        this.accountMenuItem('📊', '健康报告', '查看周报月报', () => { this.onNavigate(Constants.PAGE_REPORT); })

        Divider().opacity(0).height(24)
      }
      .width('100%')
    }
  }

  @Builder accountMenuItem(icon: string, title: string, desc: string, action: () => void) {
    Row() {
      Text(icon).fontSize(22)
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
        Text(desc).fontSize(11).fontColor(this.subTextColor).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.subTextColor)
    }
    .width('100%').padding(14).backgroundColor(this.cardColor).borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 8 })
    .onClick(() => { action(); })
  }
}
