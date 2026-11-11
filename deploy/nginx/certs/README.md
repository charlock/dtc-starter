# 证书目录

这里放 Cloudflare Origin CA 证书，两个文件：

- `origin.pem` —— 证书
- `origin.key` —— 私钥

生成方法：Cloudflare 后台 > satank.cn > SSL/TLS > Origin Server > Create Certificate，
Hostnames 填 `shop.satank.cn` 和 `shop-admin.satank.cn`，RSA 2048，有效期 15 年。

**这两个文件绝不能提交进 git**（见 `deploy/.gitignore`），只放在 VPS 的
`/data/medusa/nginx/certs/`，私钥权限 600。
