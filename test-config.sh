#!/bin/bash
#
# 测试HTTPS配置脚本
#

DOMAIN="bot1.utcwin.com"
HTTPS_PORT="5008"

echo "=== HTTPS 配置测试 ==="
echo "域名: $DOMAIN"
echo "端口: $HTTPS_PORT"
echo

# 测试1: 检查Nginx状态
echo "1. 检查Nginx状态:"
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx 正在运行"
else
    echo "❌ Nginx 未运行"
fi
echo

# 测试2: 检查端口监听
echo "2. 检查端口监听:"
if netstat -tlnp | grep -q ":$HTTPS_PORT"; then
    echo "✅ 端口 $HTTPS_PORT 正在监听"
    netstat -tlnp | grep ":$HTTPS_PORT"
else
    echo "❌ 端口 $HTTPS_PORT 未监听"
fi
echo

# 测试3: 检查证书有效期
echo "3. 检查证书有效期:"
if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
    echo "✅ 证书文件存在"
    openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -dates
else
    echo "❌ 证书文件不存在"
fi
echo

# 测试4: 测试HTTPS连接
echo "4. 测试HTTPS连接:"
if curl -k -I "https://$DOMAIN:$HTTPS_PORT" 2>/dev/null | grep -q "200"; then
    echo "✅ HTTPS 连接正常"
    curl -k -I "https://$DOMAIN:$HTTPS_PORT" 2>/dev/null | head -n 3
else
    echo "❌ HTTPS 连接失败"
fi
echo

# 测试5: 检查证书链
echo "5. 检查证书链:"
openssl_result=$(echo | openssl s_client -connect $DOMAIN:$HTTPS_PORT -servername $DOMAIN 2>/dev/null | grep "Verify return code" | awk '{print $4}')
if [ "$openssl_result" = "0" ]; then
    echo "✅ 证书链验证通过"
else
    echo "❌ 证书链验证失败: $openssl_result"
fi
echo

# 测试6: 检查反向代理
echo "6. 检查反向代理:"
proxy_port=$(grep -r "proxy_pass" /etc/nginx/sites-available/ | grep $DOMAIN | awk -F: '{print $3}' | tr -d ';')
if [ -n "$proxy_port" ]; then
    echo "✅ 反向代理配置: 127.0.0.1:$proxy_port"
else
    echo "❌ 未找到反向代理配置"
fi
echo

echo "=== 测试完成 ==="