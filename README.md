# my-cloud-vps

私有 VPS 初始化总脚本。

## 功能

1. 输入域名和 Cloudflare API Token，自动把域名的 A/AAAA 记录更新为当前 VPS 公网 IPv4/IPv6，关闭 Cloudflare 代理。
2. 询问 Swap 大小，调用 `zhucaidan/swap.sh` 创建 Swap。
3. 调用 `mhsanaei/3x-ui` 官方安装脚本，固定面板端口为 `10000`，使用第一步输入的域名申请 Let's Encrypt SSL。
4. 显示并保存 3x-ui 后台地址、用户名、密码和 API Token。
5. 调用 `byJoey/Actions-bbr-v3` 安装最新版 BBR v3 标准版，并在成功后立即重启。

## 安全

Cloudflare API Token 不写入仓库。运行时交互输入，或预先设置环境变量 `CF_API_TOKEN`。

Token 建议仅授予对应 Zone 的 `Zone:Read` 和 `DNS:Edit` 权限。

## 运行

本仓库是 Private，不能像公开仓库一样匿名 `curl raw.githubusercontent.com/... | bash`。需要先给 GitHub API Token 设置环境变量，然后从 GitHub Contents API 拉取：

```bash
export GITHUB_TOKEN='你的GitHub访问令牌'
curl -fsSL \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw+json" \
  https://api.github.com/repos/jiangyuqian0724/my-cloud-vps/contents/install.sh | bash
```

也可以先 `git clone` 私有仓库后执行：

```bash
chmod +x install.sh
sudo ./install.sh
```

3x-ui 安装结果同时保存到 `/root/vps-bootstrap-result.txt`，重启后可运行：

```bash
cat /root/vps-bootstrap-result.txt
```
