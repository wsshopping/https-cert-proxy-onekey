#!/bin/bash
#
# 一键配置Nginx + HTTPS + 反向代理脚本
# 适用于Telegram Bot Webhook等场景
#
# 使用方法:
#   sudo ./setup-https-nginx.sh <域名> <反向代理端口> [HTTPS端口]
#
# 示例:
#   sudo ./setup-https-nginx.sh bot1.utcwin.com 50088 5008
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 检查参数
if [ $# -lt 2 ]; then
    echo "用法: $0 <域名> <反向代理端口> [HTTPS端口(默认5008)]"
    echo "示例: $0 bot1.utcwin.com 50088 5008"
    exit 1
fi

DOMAIN=$1
PROXY_PORT=$2
HTTPS_PORT=${3:-5008}

log_info "开始配置 HTTPS Nginx 反向代理..."
log_info "域名: $DOMAIN"
log_info "反向代理端口: $PROXY_PORT"
log_info "HTTPS端口: $HTTPS_PORT"

# 检查是否root权限
if [ "$EUID" -ne 0 ]; then
    log_error "请以root权限运行此脚本"
    exit 1
fi

# 更新系统
log_info "更新系统包..."
apt update -y

# 安装Nginx（如果未安装）
if ! command -v nginx &> /dev/null; then
    log_info "安装Nginx..."
    apt install -y nginx
else
    log_info "Nginx已安装"
fi

# 安装Certbot
if ! command -v certbot &> /dev/null; then
    log_info "安装Certbot..."
    apt install -y certbot python3-certbot-nginx
else
    log_info "Certbot已安装"
fi

# 创建Nginx配置
log_info "创建Nginx配置文件..."
cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen $HTTPS_PORT ssl;
    server_name $DOMAIN;

    # SSL配置
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;

    location / {
        proxy_pass http://127.0.0.1:$PROXY_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Port \$server_port;

        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# 启用站点
mkdir -p /etc/nginx/sites-enabled
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# 获取Let's Encrypt证书
log_info "获取Let's Encrypt证书..."
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    log_warn "证书已存在，跳过获取"
else
    # 临时停止Nginx以使用standalone模式
    systemctl stop nginx

    # 获取证书
    certbot certonly --standalone \
        -d $DOMAIN \
        --email admin@$DOMAIN \
        --agree-tos \
        --non-interactive \
        --keep-until-expiring

    # 重新启动Nginx
    systemctl start nginx
fi

# 测试Nginx配置
log_info "测试Nginx配置..."
if nginx -t; then
    log_info "Nginx配置测试通过"
else
    log_error "Nginx配置测试失败"
    exit 1
fi

# 重启Nginx
log_info "重启Nginx服务..."
systemctl restart nginx

# 开放防火墙端口
if command -v ufw &> /dev/null; then
    log_info "配置防火墙..."
    ufw allow $HTTPS_PORT/tcp
fi

# 创建续期钩子脚本
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/bin/bash
systemctl reload nginx
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# 输出结果
log_info "配置完成！"
echo "========================================"
echo -e "${GREEN}✓${NC} 域名: https://$DOMAIN:$HTTPS_PORT"
echo -e "${GREEN}✓${NC} 反向代理到: 127.0.0.1:$PROXY_PORT"
echo -e "${GREEN}✓${NC} 证书有效期: $(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -enddate | cut -d= -f2)"
echo "========================================"
echo
echo "Telegram Webhook设置命令:"
echo -e "${YELLOW}curl -F \"url=https://$DOMAIN:$HTTPS_PORT\" https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook${NC}"
echo
echo "测试命令:"
echo -e "${YELLOW}curl -I https://$DOMAIN:$HTTPS_PORT${NC}"
echo
echo "查看证书状态:"
echo -e "${YELLOW}sudo certbot certificates${NC}"