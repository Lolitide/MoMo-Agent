/*
 * ============================================================================
 * 文件名：pages/B_AITest_V2.ets
 * ============================================================================
 * 【用途】AI服务测试页面（云服务架构版本）
 * 【测试内容】
 *   - 认证服务（设备ID登录）
 *   - Token管理
 *   - LLM服务（Mock模式）
 *   - 文生图服务（Mock模式）
 * ============================================================================
 */
import { AIService } from '../service/ai/AIService';
import { AuthService } from '../service/auth/AuthService';
import { CloudBackendService } from '../service/backend/CloudBackendService';
import { EventItem } from '../model/Models';
import { Logger } from '../utils/Logger';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct B_AITest_V2 {
  @State authStatus: string = '未初始化';
  @State userId: string = '';
  @State tokenStatus: string = '';
  @State aiStatus: string = '未初始化';
  @State runningMode: string = '';
  @State testResult: string = '';
  @State isLoading: boolean = false;

  async aboutToAppear() {
    await this.initializeServices();
  }

  async initializeServices() {
    try {
      // 1. 初始化认证服务
      this.authStatus = '初始化中...';
      const authService = AuthService.get();
      await authService.initialize();

      const user = await authService.getCurrentUser();
      this.userId = user?.userId || '未知';
      this.authStatus = `已登录 (${authService.getProviderName()})`;

      // 2. 检查Token状态
      const token = await authService.getAccessToken();
      this.tokenStatus = `Token: ${token.substring(0, 20)}...`;

      // 3. 初始化AI服务
      this.aiStatus = '初始化中...';
      const aiService = AIService.get();
      await aiService.initialize();

      this.runningMode = aiService.getProviderName();
      this.aiStatus = '已初始化';

      Logger.info('B_AITest_V2', '所有服务初始化完成');
    } catch (error) {
      Logger.error('B_AITest_V2', `初始化失败: ${error}`);
      this.authStatus = `初始化失败: ${error}`;
    }
  }

  async testDailySummary() {
    this.isLoading = true;
    this.testResult = '生成中...';

    try {
      const mockEvents: EventItem[] = [
        new EventItem('e1', '起床后散步20分钟', '07:20', 'life', '在公园里看到晨练的老人'),
        new EventItem('e2', '专注写设计方案', '09:30', 'work', '完成了HDS视觉规范初稿'),
        new EventItem('e3', '与设计同学评审', '14:00', 'work', '团队讨论很有收获'),
        new EventItem('e4', '晚饭后看漫画', '19:40', 'interest', '重温了喜欢的作品'),
        new EventItem('e5', '记录今天的感受', '22:10', 'life', '写下三个小确幸')
      ];

      const aiService = AIService.get();
      const result = await aiService.generateDailySummary(mockEvents);

      this.testResult = `✅ 每日总结生成成功\n\n${result}`;
      Logger.info('B_AITest_V2', '每日总结测试成功');
    } catch (error) {
      this.testResult = `❌ 生成失败\n\n${error}`;
      Logger.error('B_AITest_V2', `每日总结测试失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  async testComicScript() {
    this.isLoading = true;
    this.testResult = '生成中...';

    try {
      const mockSummary = '今天是充实的一天。上午专注完成了设计方案，下午与团队评审交流，晚上看了会儿漫画放松心情。';
      const mockEvents: EventItem[] = [
        new EventItem('e1', '晨间散步', '07:20', 'life', ''),
        new EventItem('e2', '专注工作', '09:30', 'work', ''),
        new EventItem('e3', '团队评审', '14:00', 'work', ''),
        new EventItem('e4', '看漫画', '19:40', 'interest', ''),
        new EventItem('e5', '记录感受', '22:10', 'life', '')
      ];

      const aiService = AIService.get();
      const result = await aiService.generateComicScript(mockSummary, mockEvents);

      this.testResult = `✅ 漫画脚本生成成功\n\n${result}`;
      Logger.info('B_AITest_V2', '漫画脚本测试成功');
    } catch (error) {
      this.testResult = `❌ 生成失败\n\n${error}`;
      Logger.error('B_AITest_V2', `漫画脚本测试失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  async testMemoryCorrection() {
    this.isLoading = true;
    this.testResult = '处理中...';

    try {
      const memoryContent = `标题：完成HDS设计规范初稿
日期：2026-10-22
类型：学习
重要度：4
标签：设计、文档、成长`;

      const userFeedback = '这个成果对我来说很重要，应该是5星，而且这是一个里程碑';

      const aiService = AIService.get();
      const result = await aiService.processMemoryCorrection('m2', memoryContent, userFeedback);

      this.testResult = `✅ 记忆纠正处理成功\n\n${result}`;
      Logger.info('B_AITest_V2', '记忆纠正测试成功');
    } catch (error) {
      this.testResult = `❌ 处理失败\n\n${error}`;
      Logger.error('B_AITest_V2', `记忆纠正测试失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  async testImageGen() {
    this.isLoading = true;
    this.testResult = '生成中...';

    try {
      const aiService = AIService.get();
      const imageUrl = await aiService.generateImage(
        '一只可爱的AI桌宠，坐在窗台上，卡通风格，温暖色调',
        'cartoon'
      );

      this.testResult = `✅ 图像生成成功\n\n图像URL: ${imageUrl}\n\n注意：当前为Mock模式，返回的是占位图资源路径`;
      Logger.info('B_AITest_V2', '图像生成测试成功');
    } catch (error) {
      this.testResult = `❌ 生成失败\n\n${error}`;
      Logger.error('B_AITest_V2', `图像生成测试失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  async testLogout() {
    try {
      const authService = AuthService.get();
      await authService.logout();

      promptAction.showToast({ message: '已登出，请重启应用重新登录' });
      this.authStatus = '已登出';
      this.userId = '';
      this.tokenStatus = '';
    } catch (error) {
      promptAction.showToast({ message: `登出失败: ${error}` });
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('AI服务测试 (云服务架构)')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.Center)

      Scroll() {
        Column({ space: 16 }) {
          // 认证状态卡片
          Column({ space: 8 }) {
            Text('认证服务')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')

            Row() {
              Text('状态')
                .fontSize(14)
                .fontColor('#999999')
              Blank()
              Text(this.authStatus)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')

            Row() {
              Text('用户ID')
                .fontSize(14)
                .fontColor('#999999')
              Blank()
              Text(this.userId || '无')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')

            Row() {
              Text('Token')
                .fontSize(14)
                .fontColor('#999999')
              Blank()
              Text(this.tokenStatus || '无')
                .fontSize(10)
            }
            .width('100%')

            Button('登出测试')
              .fontSize(14)
              .height(36)
              .width('100%')
              .type(ButtonType.Normal)
              .borderRadius(8)
              .onClick(() => this.testLogout())
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F5F5F5')
          .borderRadius(12)

          // AI服务状态卡片
          Column({ space: 8 }) {
            Text('AI服务')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')

            Row() {
              Text('状态')
                .fontSize(14)
                .fontColor('#999999')
              Blank()
              Text(this.aiStatus)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')

            Row() {
              Text('运行模式')
                .fontSize(14)
                .fontColor('#999999')
              Blank()
              Text(this.runningMode)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FF6B6B')
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F5F5F5')
          .borderRadius(12)

          // 测试按钮组
          Column({ space: 12 }) {
            Text('功能测试')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')

            Button('测试每日总结生成')
              .width('100%')
              .height(48)
              .fontSize(16)
              .enabled(!this.isLoading)
              .onClick(() => this.testDailySummary())

            Button('测试漫画脚本生成')
              .width('100%')
              .height(48)
              .fontSize(16)
              .enabled(!this.isLoading)
              .onClick(() => this.testComicScript())

            Button('测试记忆纠正')
              .width('100%')
              .height(48)
              .fontSize(16)
              .enabled(!this.isLoading)
              .onClick(() => this.testMemoryCorrection())

            Button('测试图像生成')
              .width('100%')
              .height(48)
              .fontSize(16)
              .enabled(!this.isLoading)
              .onClick(() => this.testImageGen())
          }
          .width('100%')

          // 结果显示
          if (this.testResult) {
            Column() {
              Text('测试结果')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 8 })

              Text(this.testResult)
                .fontSize(12)
                .fontColor('#333333')
                .lineHeight(20)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: '#E0E0E0' })
          }

          // 说明文本
          Text('当前状态说明：\n' +
            '✅ 设备ID自动登录已实现\n' +
            '✅ Token自动管理已实现\n' +
            '✅ Mock模式完全可用\n' +
            '⚠️ 华为账号登录未实现\n' +
            '⚠️ 云服务模式需要后端支持')
            .fontSize(12)
            .fontColor('#999999')
            .lineHeight(20)
            .width('100%')
            .padding(16)
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAFAFA')
  }
}
