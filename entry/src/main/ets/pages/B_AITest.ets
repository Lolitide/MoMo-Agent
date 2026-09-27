/*
 * ============================================================================
 * 文件名：pages/B_AITest.ets
 * ============================================================================
 * 【用途】AI服务测试页面，用于验证LLM接入和各项AI能力
 * 【功能】
 *   - 显示当前提供商状态
 *   - 测试每日总结生成
 *   - 测试漫画脚本生成
 *   - 测试记忆纠正
 * ============================================================================
 */
import { AIService } from '../service/ai/AIService';
import { EventItem } from '../model/Models';
import { Logger } from '../utils/Logger';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct B_AITest {
  @State providerName: string = '初始化中...';
  @State isOffline: boolean = true;
  @State testResult: string = '';
  @State isLoading: boolean = false;

  async aboutToAppear() {
    await this.initializeAI();
  }

  async initializeAI() {
    try {
      const aiService = AIService.get();
      await aiService.initialize();
      this.providerName = aiService.getProviderName();
      this.isOffline = aiService.isOfflineMode();
      Logger.info('B_AITest', `AI服务初始化完成: ${this.providerName}`);
    } catch (error) {
      Logger.error('B_AITest', `初始化失败: ${error}`);
      this.providerName = 'Mock (离线模式)';
      this.isOffline = true;
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
      Logger.info('B_AITest', '每日总结测试成功');
    } catch (error) {
      this.testResult = `❌ 生成失败\n\n${error}`;
      Logger.error('B_AITest', `每日总结测试失败: ${error}`);
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
      Logger.info('B_AITest', '漫画脚本测试成功');
    } catch (error) {
      this.testResult = `❌ 生成失败\n\n${error}`;
      Logger.error('B_AITest', `漫画脚本测试失败: ${error}`);
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
      Logger.info('B_AITest', '记忆纠正测试成功');
    } catch (error) {
      this.testResult = `❌ 处理失败\n\n${error}`;
      Logger.error('B_AITest', `记忆纠正测试失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('AI能力测试')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.Center)

      Scroll() {
        Column({ space: 16 }) {
          // 状态卡片
          Column({ space: 8 }) {
            Row() {
              Text('当前提供商')
                .fontSize(14)
                .fontColor('#999999')
              Blank()
              Text(this.providerName)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isOffline ? '#FF6B6B' : '#52C41A')
            }
            .width('100%')

            Row() {
              Text('运行模式')
                .fontSize(14)
                .fontColor('#999999')
              Blank()
              Text(this.isOffline ? '离线模式 (Mock)' : '在线模式')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F5F5F5')
          .borderRadius(12)

          // 测试按钮组
          Column({ space: 12 }) {
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
                .fontSize(14)
                .fontColor('#333333')
                .lineHeight(22)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: '#E0E0E0' })
          }

          // 说明文本
          Text('说明：\n' +
            '1. 默认使用Mock模式，可以测试基本流程\n' +
            '2. 配置DeepSeek API Key后可使用真实AI能力\n' +
            '3. 配置文件：entry/src/main/resources/rawfile/ai_config.json')
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
