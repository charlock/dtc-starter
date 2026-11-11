# 创建地区（待管理员密码提交后执行）

## 接口（Medusa 2.21，Admin API）
- 登录：POST https://shop-admin.satank.cn/auth/user/emailpass
  Body: {"email": "shop-admin@satank.cn", "password": "<vault 提交的密码，浏览器登录代理使用，不从对话里取>"}
  返回 token，用作 Bearer。
- 创建地区：POST https://shop-admin.satank.cn/admin/regions
  Header: Authorization: Bearer <token>
  Body US: {"name": "United States", "currency_code": "usd", "countries": ["us"]}
  Body CN: {"name": "China", "currency_code": "cny", "countries": ["cn"]}
- 验收：GET https://shop-admin.satank.cn/store/regions（publishable key）
  应返回 3 个地区：Europe/EUR、United States/USD、China/CNY
  商城 https://shop.satank.cn/us/store 应 200（不再 307 跳到 dk），
  https://shop.satank.cn/cn/store 应 200。

## 注意
- 密码只进 Secure Vault，不记录、不复述、不写文件。
- 如果接口登录失败（密码不对），先在 Admin 页面确认能登录，再重试，不要反复试密码。
- 如果浏览器登录代理已用保存的登录登进 Admin，也可直接走 Admin UI 创建，效果相同。
