# my-cloud-vps

VPS 初始化总脚本。

## 功能

1. 输入域名和 Cloudflare API Token，自动把域名的 A/AAAA 记录更新为当前 VPS 公网 IPv4/IPv6，并关闭 Cloudflare 代理。
2. 询问 Swap 大小，调用 `zhucaidan/swap.sh` 创建 Swap。
3. 调用 `mhsanaei/3x-ui` 官方安装脚本，固定面板端口为 `10000`，使用第一步输入的域名申请 Let's Encrypt SSL。
4. 显示并保存 3x-ui 后台地址、用户名、密码和 API Token。
5. 调用 `byJoey/Actions-bbr-v3` 安装最新版 BBR v3 标准版，并在成功后立即重启。

## 安全

Cloudflare API Token **不会写入仓库，也不会保存到脚本文件**。

运行脚本时会在终端中要求输入：

```text
Cloudflare API Token:
```

输入过程使用隐藏输入方式，不会在终端回显。

也可以预先通过环境变量 `CF_API_TOKEN` 提供，但不建议把真实 Token 写进 shell 历史、脚本、README 或任何公开文件。

建议 Cloudflare Token 只授权目标 Zone，并仅授予：

- `Zone:Read`
- `DNS:Edit`

## 一键运行

仓库公开后可直接执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jiangyuqian0724/my-cloud-vps/main/install.sh)
```

或者：

```bash
curl -fsSL https://raw.githubusercontent.com/jiangyuqian0724/my-cloud-vps/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

## 安装结果

3x-ui 安装完成后会显示：

- 后台地址
- 用户名
- 密码
- API Token
- 面板端口
- WebBasePath

同时保存到：

```text
/root/vps-bootstrap-result.txt
```

重启后可以运行：

```bash
cat /root/vps-bootstrap-result.txt
```

## 注意

脚本需要 `root` 权限运行。域名必须已经托管在输入 Token 可以访问的 Cloudflare Zone 中。
