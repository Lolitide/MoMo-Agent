# 公开仓库配置说明

仓库中的源码、资源、测试和云函数实现可以复用。你可以让安装者共用同一套已部署后端，但必须把“发布应用”和“自行编译源码”分开处理。

## 1. 只运行本地/Mock 版本

1. 用 DevEco Studio 打开项目。
2. 保持 `build-profile.json5` 中 `signingConfigs` 为空，先运行本地检查或 Mock 功能。
3. 应用启动失败的云服务会自动降级到本地数据和 Mock 能力；这不代表云端功能已配置。

## 2. 让安装者共用你的华为云项目

1. 你的 AGC 应用、Cloud Functions、CloudDB、Cloud Storage 和 Account Kit 必须持续运行。
2. 正式发布时，用你自己的签名构建并分发 HAP/应用包。安装者会直接使用你的应用配置和后端，不需要拿到你的私钥。
3. 如果一定要让别人从源码构建，把与你的 AGC 应用匹配的 `agconnect-services.json` 放到 `entry/src/main/resources/rawfile/`。它只是客户端项目配置，不包含 DeepSeek/Ark 的服务端密钥，但会让调用消耗你的项目配额。
4. 在 AGC 为应用配置调用配额、访问控制、CloudDB Creator ACL 和 Storage 权限，确保每个登录用户只能访问自己的数据。

`agconnect-services.json` 中的 `appId`、`client_secret`、`api_key`、OAuth 配置和存储桶会指向你的项目。可以随应用分发，但不应把它当作服务器密钥，也不能因此开放管理员权限。

如果你不想公开自己的项目配置，就不要把该文件提交到公开仓库；改为只发布已签名应用，或让使用者换成自己的 AGC 配置。

## 3. 配置自己的云函数

云函数代码在 `cloud-functions/`，密钥只设置在云函数的环境变量中：

- `DEEPSEEK_API_KEY`
- `ARK_API_KEY`
- `ARK_IMAGE_MODEL`
- `ARK_IMAGE_URL_HOST_SUFFIXES`
- `IMAGE_TASK_SECRET`（至少 32 个字符；两个图片函数必须一致）

不要把这些值写进 JavaScript、ArkTS、JSON 或 GitHub Actions 日志。角色配置从模板开始：

```bash
cp cloud-functions/character-config.template.json cloud-functions/character-config.json
```

然后按自己的角色和参考图修改 `character-config.json`，部署时把它和对应云函数一起上传。该文件已被 `.gitignore` 忽略。

## 4. 华为账号登录能否共用

可以共用你的正式应用登录入口，但前提是包名、AGC 应用和签名证书匹配。安装你签名好的应用时，用户登录的是自己的华为账号，数据应由云端按该账号隔离。

别人从源码自行签名时，证书指纹会变化。你必须把对方证书加入同一个 AGC 应用并重新下载配置，或者让对方使用自己的 AGC 应用；不能把你的 `.p12` 和密码发给别人。

## 5. 签名能否共用

签名私钥不能安全共用，也不应上传 GitHub。你可以：

- 发布你自己签名的应用包，让所有人安装；
- 在 AGC 给协作者登记各自的证书，让他们各自签名；
- 为协作者单独创建团队权限和测试签名。

不要共享 `sign/*.p12`、`.p7b`、密码或 DevEco 的签名目录。详见 `SIGNING_SETUP.md`。

## 6. 共享后端前必须完成

- 云函数环境变量只配置在云端：`DEEPSEEK_API_KEY`、`ARK_API_KEY`、`IMAGE_TASK_SECRET` 等；
- 云端校验真实登录身份，不信任客户端自传的 `userId`；
- CloudDB 和 Storage 使用用户级 ACL，禁止跨用户读写；
- 设置每日调用次数、费用上限、日志脱敏和告警；
- 如果旧 Git 历史已经公开过 API Key 或签名私钥，先撤销/轮换，再公开新版本。删除当前文件或添加 `.gitignore` 不会清除旧历史。
