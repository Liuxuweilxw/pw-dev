# pw_dev

基于需求文档《三角洲行动陪玩拼单平台》的 Flutter 多端原型项目。

## 技术栈

- Flutter 3.41+
- Dart 3.11+
- 单代码仓支持 Web / iOS / Android / Windows / macOS / Linux

## 已实现的原型范围

当前版本聚焦前端原型与流程演示，已覆盖：

- 角色分流：老板端 / 陪玩端切换
- 认证闸门：未登录先进入登录/注册界面，认证成功后进入业务页
- 登录后关键状态：实名认证开关与创建房间拦截逻辑
- 房间大厅：搜索、筛选、房间卡片、创建/接单入口
- 房间详情：状态、成员、空位、聊天占位、邀请/完成/举报操作
- 我的钱包：资产卡片、充值档位、提现说明、资金明细
- 我的订单：订单列表、进度展示、标准化举报类型
- 个人中心：会员等级、积分规则
- 治理页：资金托管与结算、举报审核、消息通知说明
- 待确认需求清单：对产品文档里的未决项进行集中展示
- 数据状态处理：首屏加载、失败重试、顶部刷新按钮

## 当前目录结构

```text
lib/
	main.dart
	backend/
		pubspec.yaml
		bin/server.dart
	src/
		app.dart
		data/mock_data.dart
		models/app_models.dart
		services/api_exception.dart
		services/http_platform_api.dart
		services/platform_api_factory.dart
		services/platform_api.dart
		ui/auth_gate_page.dart
		ui/platform_shell.dart
```

说明：

- `services/platform_api.dart` 定义了后端接入的接口合同（鉴权、房间、钱包、订单、举报）
- `services/http_platform_api.dart` 为真实 HTTP 接入实现
- `services/platform_api_factory.dart` 默认连接本地后端 `http://127.0.0.1:8080`
- `ui/platform_shell.dart` 承载多端自适应壳层与主要页面交互

## 后端 API 接入

默认行为：未配置 `API_BASE_URL` 时连接本地后端 `http://127.0.0.1:8080`。

先启动后端：

```bash
cd backend
dart pub get
dart run bin/server.dart
```

后端端口配置文件：

- `backend/config/server.json`
- 示例：`{"host":"0.0.0.0","port":8080}`
- 优先级：环境变量 `HOST/PORT` 会覆盖配置文件

接入真实后端：

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://api.your-domain.com
```

可选：启动时注入 token（用于联调临时鉴权）

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://api.your-domain.com --dart-define=API_TOKEN=your_token
```

认证说明：

- 默认启用认证闸门，未登录不会请求受保护接口
- 登录/注册成功后，前端才会携带 token 调用业务接口

当前 HTTP 实现约定接口（可按后端实际路径调整）：

- `POST /auth/login/sms`
- `POST /auth/register/sms`
- `POST /auth/logout`
- `GET /rooms`
- `POST /rooms`
- `POST /rooms/{roomId}/complete`
- `GET /wallet/flows`
- `POST /wallet/recharge`
- `POST /wallet/withdraw`
- `GET /orders`
- `POST /reports/rooms`
- `POST /reports/orders`

字段规范（已对齐并收敛）：

- AuthSession: `access_token` `refresh_token` `user_id`
- RoomItem: `room_id` `title` `owner_name` `unit_price` `status` `seats_left` `contribution_ratio` `note` `commission` `tags`
- WalletFlowItem: `type` `amount` `status` `created_at`
- OrderItem: `order_id` `partner_name` `unit_price` `contribution_ratio` `status` `room_title`

说明：

- `fromJson` 已改为严格解析：缺失关键字段会抛出 `FormatException`
- 这样可以尽早暴露后端字段不一致问题，避免静默兜底带来的脏数据

## 运行方式

1. 安装依赖

```bash
flutter pub get
```

2. 启动后端服务（新终端）

```bash
cd backend
dart pub get
dart run bin/server.dart
```

3. 运行 Web

```bash
flutter run -d chrome
```

4. 运行 Windows 桌面

```bash
flutter run -d windows
```

5. 运行 Android（连接设备或模拟器）

```bash
flutter run -d android
```

6. 运行 iOS（仅 macOS）

```bash
flutter run -d ios
```

## 质量检查

```bash
flutter analyze
flutter test
```

## 下一步建议

- 对齐后端字段规范，收敛 `fromJson` 的兼容分支
- 用状态管理方案（Riverpod/Bloc）替换页面内状态
- 引入实时通信（WebSocket）完成聊天与房间状态同步
- 增加支付、实名认证上传、审核流的完整表单与接口
