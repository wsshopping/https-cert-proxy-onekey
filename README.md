# HTTPS Nginx 反向代理一键配置脚本

这个脚本可以快速配置 Nginx + Let's Encrypt SSL 证书 + 反向代理，适用于 Telegram Bot Webhook 等需要 HTTPS 的场景。

## 功能特点

- ✅ 自动安装 Nginx 和 Certbot
- ✅ 自动获取 Let's Encrypt SSL 证书
- ✅ 配置 HTTPS 反向代理
- ✅ 支持自定义端口
- ✅ 自动续期证书
- ✅ 添加安全头
- ✅ 支持 WebSocket

## 使用方法

```bash
sudo ./setup-https-nginx.sh <域名> <反向代理端口> [HTTPS端口]
```

### 参数说明
- `<域名>`: 你的域名（必须已解析到服务器IP）
- `<反向代理端口>`: 后端服务监听的端口
- `[HTTPS端口]`: 可选，HTTPS 监听端口，默认 5008

### 示例
```bash
# 基本用法
sudo ./setup-https-nginx.sh bot1.utcwin.com 50088

# 指定HTTPS端口
sudo ./setup-https-nginx.sh bot1.utcwin.com 50088 5008
```

## 配置步骤总结

### 1. 准备工作
- 确保域名已解析到服务器IP
- 确保服务器80端口未被占用（获取证书时需要）

### 2. 运行脚本
```bash
sudo ./setup-https-nginx.sh bot1.utcwin.com 50088 5008
```

### 3. 设置 Telegram Webhook
```bash
curl -F "url=https://bot1.utcwin.com:5008" https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook
```

### 4. 验证配置
```bash
# 测试HTTPS连接
curl -I https://bot1.utcwin.com:5008

# 查看证书信息
sudo certbot certificates

# 检查Webhook状态
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo
```

## 生成的文件

- Nginx 配置: `/etc/nginx/sites-available/<域名>`
- SSL 证书: `/etc/letsencrypt/live/<域名>/`
- 续期钩子: `/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh`

## 管理命令

```bash
# 重启Nginx
sudo systemctl restart nginx

# 测试Nginx配置
sudo nginx -t

# 查看证书状态
sudo certbot certificates

# 手动续期证书
sudo certbot renew --dry-run

# 查看自动续期任务
sudo systemctl status certbot.timer
```

## 故障排除

### 证书获取失败
- 检查域名是否已解析到服务器IP
- 确保80端口未被占用
- 检查防火墙是否放行80端口

### Nginx 启动失败
- 检查端口是否被占用：`sudo netstat -tlnp | grep :5008`
- 检查配置文件语法：`sudo nginx -t`

### 浏览器显示不安全
- 确认使用域名访问，不是IP地址
- 清除浏览器SSL缓存
- 检查系统时间是否正确

### Webhook 无法接收更新
- 检查后端服务是否运行在指定端口
- 确认能够处理POST请求
- 检查返回正确的HTTP状态码（200）

## 安全建议

1. 定期更新系统和软件包
2. 监控证书有效期（会自动续期）
3. 配置防火墙规则
4. 定期检查访问日志

## 卸载/清理

如果需要移除配置：
```bash
# 删除Nginx配置
sudo rm /etc/nginx/sites-available/<域名>
sudo rm /etc/nginx/sites-enabled/<域名>

# 删除证书
sudo certbot delete --cert-name <域名>

# 重启Nginx
sudo systemctl restart nginx
```