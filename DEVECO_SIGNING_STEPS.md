# DevEco Studio 自动签名步骤

请以 [SIGNING_SETUP.md](SIGNING_SETUP.md) 为唯一签名操作与验收说明。

当前工程已确认可生成、安装并启动 unsigned HAP，但还没有 AGC 签发且绑定 `com.example.momo` 与调试设备的 `.p7b` Profile；因此尚不能把当前产物称为已验证签名包。

最短操作路径：

1. `File > Project Structure... > Project > Signing Configs`。
2. 选择 `HarmonyOS`，启用 `Automatically generate signature` 与 `Associate with registered application`。
3. 选择拥有 `com.example.momo` 的团队，并核对 Provisioning Profile 的 Bundle name。
4. 生成本地签名材料后，按 `SIGNING_SETUP.md` 的命令重建、验签、安装和启动。

不要把密码、私钥、真实密钥字段或个人绝对路径提交到仓库。
