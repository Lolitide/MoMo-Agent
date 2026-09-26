# `entry/signatures` 本地材料说明

此目录中的文件不是已验收的 Momo 签名套件。

当前审计结果：

- `Momo.p12` 存在，但未获得密码和可信配对信息，不能确认它与应用证书匹配。
- `Momo.cer` 是 Huawei CBG Root CA 根证书，不是 AGC 为 `com.example.momo` 签发的应用证书。
- 缺少 AGC 签发的调试 Profile（`.p7b`）。

不要把这些文件接入 `build-profile.json5`，也不要提交新增的 `.p12`、密码或私钥。推荐按仓库根目录 [SIGNING_SETUP.md](../../SIGNING_SETUP.md) 使用 DevEco Studio 关联注册应用自动签名，并在本机完成验签、安装和启动验证。

如果改用手动签名，必须从 AGC 获取完整且相互匹配的四件套：本机私钥库 `.p12`、对应 CSR 获得的应用证书 `.cer`、绑定 `com.example.momo` 的 `.p7b` Profile，以及 Profile 中登记的调试设备。任何一个缺失都不能宣称签名链完成。
