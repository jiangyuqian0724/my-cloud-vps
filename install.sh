#!/usr/bin/env bash
set -Eeuo pipefail

PANEL_PORT=10000
SWAP_URL="https://raw.githubusercontent.com/zhucaidan/swap.sh/main/swap.sh"
XUI_URL="https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh"
BBR_URL="https://raw.githubusercontent.com/byJoey/Actions-bbr-v3/main/install.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info(){ echo -e "${GREEN}[+]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
die(){ echo -e "${RED}[-]${NC} $*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "请使用 root 运行此脚本"

install_deps() {
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y curl wget jq ca-certificates openssl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl wget jq ca-certificates openssl
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl wget jq ca-certificates openssl
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl wget jq ca-certificates openssl bash
  else
    die "不支持的包管理器，请先安装 curl wget jq ca-certificates openssl"
  fi
}

cf_api() {
  local method="$1" url="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -fsS -X "$method" "$url" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "$data"
  else
    curl -fsS -X "$method" "$url" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json"
  fi
}

find_zone() {
  local name="$1" zone resp zid
  while [[ "$name" == *.* ]]; do
    zone="$name"
    resp=$(cf_api GET "https://api.cloudflare.com/client/v4/zones?name=${zone}") || true
    zid=$(jq -r '.result[0].id // empty' <<<"$resp" 2>/dev/null || true)
    if [[ -n "$zid" ]]; then
      ZONE_NAME="$zone"
      ZONE_ID="$zid"
      return 0
    fi
    name="${name#*.}"
  done
  return 1
}

upsert_dns() {
  local type="$1" ip="$2" rid payload resp
  [[ -n "$ip" ]] || return 0
  rid=$(cf_api GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=${type}&name=${DOMAIN}" | jq -r '.result[0].id // empty')
  payload=$(jq -nc --arg t "$type" --arg n "$DOMAIN" --arg c "$ip" '{type:$t,name:$n,content:$c,ttl:1,proxied:false}')
  if [[ -n "$rid" ]]; then
    resp=$(cf_api PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${rid}" "$payload")
  else
    resp=$(cf_api POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" "$payload")
  fi
  [[ $(jq -r '.success' <<<"$resp") == "true" ]] || { jq . <<<"$resp"; die "Cloudflare ${type} 记录配置失败"; }
  info "Cloudflare ${type} -> ${ip} 配置成功（DNS only）"
}

install_deps

echo
read -rp "域名: " DOMAIN
DOMAIN="${DOMAIN,,}"
[[ "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]] || die "域名格式无效"

if [[ -z "${CF_API_TOKEN:-}" ]]; then
  read -rsp "Cloudflare API Token: " CF_API_TOKEN
  echo
fi
[[ -n "$CF_API_TOKEN" ]] || die "Cloudflare API Token 不能为空"

info "检测公网 IP..."
V4=$(curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)
V6=$(curl -6fsS --max-time 8 https://api64.ipify.org 2>/dev/null || true)
[[ -n "$V4" || -n "$V6" ]] || die "无法获取公网 IPv4/IPv6"
[[ -n "$V4" ]] && info "IPv4: $V4"
[[ -n "$V6" ]] && info "IPv6: $V6"

find_zone "$DOMAIN" || die "Cloudflare 中找不到该域名对应的 Zone，请检查 Token 的 Zone:Read / DNS:Edit 权限"
info "Cloudflare Zone: $ZONE_NAME"
upsert_dns A "$V4"
upsert_dns AAAA "$V6"

# 给 Cloudflare DNS 少量传播时间，避免紧接着申请 HTTP-01 证书时解析仍是旧地址。
info "等待 DNS 记录传播..."
sleep 8

echo
read -rp "请输入需要创建的 Swap 大小（MB，例如 2048）: " SWAP_MB
[[ "$SWAP_MB" =~ ^[1-9][0-9]*$ ]] || die "Swap 大小必须是正整数 MB"
info "调用原 swap.sh 创建 ${SWAP_MB}MB Swap..."
printf '1\n%s\n' "$SWAP_MB" | bash <(curl -fsSL "$SWAP_URL")

info "安装 3x-ui，面板端口固定为 ${PANEL_PORT}，SSL 域名为 ${DOMAIN}..."
XUI_NONINTERACTIVE=1 \
XUI_PANEL_PORT="$PANEL_PORT" \
XUI_SSL_MODE=domain \
XUI_DOMAIN="$DOMAIN" \
XUI_DB_TYPE=sqlite \
bash <(curl -fsSL "$XUI_URL")

RESULT_FILE="/etc/x-ui/install-result.env"
[[ -r "$RESULT_FILE" ]] || die "3x-ui 已执行，但未找到安装结果文件 $RESULT_FILE"
# shellcheck disable=SC1090
source "$RESULT_FILE"

SUMMARY_FILE="/root/vps-bootstrap-result.txt"
umask 077
cat > "$SUMMARY_FILE" <<EOF
3x-ui 安装信息
==============================
域名: $DOMAIN
后台地址: ${XUI_ACCESS_URL:-https://${DOMAIN}:${PANEL_PORT}/}
用户名: ${XUI_USERNAME:-未知}
密码: ${XUI_PASSWORD:-未知}
API Token: ${XUI_API_TOKEN:-未知}
端口: ${XUI_PANEL_PORT:-$PANEL_PORT}
WebBasePath: ${XUI_WEB_BASE_PATH:-未知}
证书: /root/cert/${DOMAIN}/fullchain.pem
私钥: /root/cert/${DOMAIN}/privkey.pem
==============================
EOF
chmod 600 "$SUMMARY_FILE"

echo
info "3x-ui 安装完成"
echo "后台地址: ${XUI_ACCESS_URL:-https://${DOMAIN}:${PANEL_PORT}/}"
echo "用户名: ${XUI_USERNAME:-未知}"
echo "密码: ${XUI_PASSWORD:-未知}"
echo "API Token: ${XUI_API_TOKEN:-未知}"
echo "安装信息已保存到: $SUMMARY_FILE (600 权限)"
echo

info "安装最新版 BBR v3 标准版；安装成功后按上游脚本要求立即重启..."
# 上游菜单：1=安装/更新最新版，1=标准版，y=立即重启。
printf '1\n1\ny\n' | bash <(curl -fsSL "$BBR_URL")
