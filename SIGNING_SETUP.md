# Momo 签名与可安装性说明

更新时间：2026-09-26。

## 已核实的当前状态

| 检查项 | 结果 |
| --- | --- |
| 应用包名 | `AppScope/app.json5` 为 `com.example.momo` |
| AGC 当前客户端 | `agconnect-services.json` 顶层 `client.package_name` 与 `app_info.package_name` 均为 `com.example.momo` |
| AGC 历史条目 | `appInfos` 还包含旧应用；不得手改密钥或删除条目。只有从 AGC 重新下载当前应用配置才能替换此文件 |
| 仓库签名配置 | `build-profile.json5` 的 `signingConfigs` 为空，仓库不会保存密码、私钥或本机绝对路径 |
| 当前构建产物 | `entry-default-unsigned.hap`，构建日志明确提示 `No signingConfig found for product default` |
| 当前设备验证 | unsigned HAP 可安装到已连接的 Pura X View 模拟器并启动 `EntryAbility`，设备报告 `appSignType: none` |

当前验证只证明工程可构建、模拟器接受 unsigned 调试包并能启动，不证明签名包、真机安装、Account Kit 指纹校验或 AGC 云服务已通过。

本轮 15:47 的构建成功并生成上述 unsigned HAP；15:53 再次复测时，并行工作区新出现的 `Garden3DDemo_Standalone.ets` 产生 ArkTS 编译错误，导致最新全量构建失败。该文件不在 T4 写入范围，需由对应功能负责人修复后再做签名候选复测；旧 unsigned HAP 不能代表当前工作区最新源码。

## 为什么现有材料不能用于可信签名

- `entry/signatures/` 中没有 `.p7b` 调试 Profile。
- `entry/signatures/Momo.cer` 实际是 Huawei CBG Root CA 根证书，不是为本应用签发的开发者应用证书。
- `sign/` 中的证书是本地自建 CA/自签材料，且只有未签名的 Profile JSON；它们不能替代 AGC 签发并绑定包名、证书和设备的 Profile。
- 未知来源或无法确认密码/配对关系的 `.p12` 不应写入 `build-profile.json5` 试错。

因此，当前签名可安装性仍受 AGC 签名材料阻塞。

## 安全且可复现的本地签名方式

推荐使用 DevEco Studio 的关联注册应用自动签名：

1. 连接目标真机/模拟器。当前已检测到设备，且能读取设备 UDID。
2. 打开 `File > Project Structure... > Project > Signing Configs`。
3. 新建或选择 `default`，类型选择 `HarmonyOS`。
4. 勾选 `Automatically generate signature` 与 `Associate with registered application`。
5. 选择拥有 `com.example.momo` AGC 应用的团队。确认 IDE 查询到的 Bundle name 正是 `com.example.momo`。
6. 让 DevEco 生成本机 `.p12`、`.csr`、`.cer` 和 `.p7b`；确认 Provisioning Profile 显示的 Bundle name 为 `com.example.momo`，并包含本次调试设备。
7. 将 product `default` 绑定到该签名配置，然后构建 debug HAP。

不要把以下内容提交到 Git：

- `.p12`、私钥、密码；
- DevEco 写入的真实 `storePassword` / `keyPassword`；
- 个人目录绝对路径；
- 完整 `agconnect-services.json` 内容或其密钥字段。

当前仓库已经追踪了 `sign/` 中的历史 `.p12`，而 `entry/signatures/` 也未被忽略。不要继续添加或提交签名材料；忽略规则、历史泄露检查和密钥轮换由 T7 在单独授权后处理。

## 签名完成后的验收命令

构建命令需要显式使用 DevEco 自带的 JDK、SDK 和 Hvigor：

```bash
JAVA_HOME="/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home" \
DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk" \
PATH="/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
"/Applications/DevEco-Studio.app/Contents/tools/node/bin/node" \
"/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js" \
--mode module -p product=default -p module=entry@default -p buildMode=debug \
assembleHap --no-daemon
```

验收时必须同时满足：

1. 构建日志不再出现 `No signingConfig found`。
2. 输出目录出现 signed HAP，而不只是 `entry-default-unsigned.hap`。
3. `hap-sign-tool.jar verify-app` 能导出证书链和 Profile，Profile 中的 Bundle name 为 `com.example.momo`。
4. 使用 `hdc install` 安装该 signed HAP 成功。
5. `hdc shell aa start -a EntryAbility -b com.example.momo -m entry` 启动成功。
6. `hdc shell bm dump -n com.example.momo` 的 `appSignType` 不再是 `none`。
7. 在真机或具备真实华为账号环境的设备上验证 Account Kit；模拟器 unsigned 启动不能替代此项。

## AGC 配置文件规则

当前文件选中的客户端与目标包名一致，因此本轮没有改写 `agconnect-services.json`。如果 AGC 控制台中的当前应用、App ID 或云服务配置已变化，只能在 AGC 选择 `com.example.momo` 后重新下载完整文件并整体替换；禁止手工复制、删除或改写其中的密钥字段。
