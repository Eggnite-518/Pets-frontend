# 宠托师 - Flutter 宠物寄养服务平台

这是一个使用 Flutter + Dart 重构的宠物寄养服务平台应用，原项目基于 Next.js + React + Tailwind CSS。

## 功能特性

### 宠物主人端
- 首页：服务入口、订单预览、推荐宠托师
- 创建订单：三步流程（选择宠物/宠托师 → 服务要求 → 费用确认）
- 订单详情：查看订单状态、联系宠托师
- 消息中心：与宠托师实时沟通
- 个人中心：宠物管理、订单统计、账户设置

### 宠托师端
- 工作台：订单统计、待处理订单、进行中服务
- 订单管理：接单/拒单、完成服务
- 消息中心：与客户沟通
- 个人中心：服务管理、收入明细、认证中心

## 技术栈

- **Flutter** 3.x
- **Dart** 3.x
- **Riverpod** - 状态管理
- **go_router** - 路由管理
- **lucide_icons** - 图标库
- **cached_network_image** - 网络图片缓存

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── core/
│   ├── theme/
│   │   ├── app_colors.dart      # 颜色系统
│   │   └── app_theme.dart       # 主题配置
│   ├── router/
│   │   └── app_router.dart      # 路由配置
│   ├── models/
│   │   └── models.dart          # 数据模型
│   ├── data/
│   │   └── mock_data.dart       # Mock 数据
│   └── providers/
│       └── providers.dart       # Riverpod Providers
├── shared/
│   └── widgets/                 # 共享组件
│       ├── main_shell.dart      # 主页面 Shell
│       ├── caretaker_shell.dart # 宠托师端 Shell
│       ├── app_card.dart        # 卡片组件
│       ├── app_button.dart      # 按钮组件
│       ├── app_header.dart      # 头部组件
│       └── order_status_badge.dart # 订单状态标签
└── features/
    ├── home/                    # 首页模块
    ├── order/                   # 订单模块
    ├── messages/                # 消息模块
    ├── profile/                 # 个人中心模块
    └── caretaker/               # 宠托师端模块
```

## 安装运行

1. 确保已安装 Flutter SDK (>= 3.2.0)

2. 克隆项目并进入目录
```bash
cd flutter_app
```

3. 获取依赖
```bash
flutter pub get
```

4. 运行应用
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## 颜色系统

应用使用与原 Next.js 项目一致的颜色系统：

| 颜色 | 用途 | 值 |
|------|------|-----|
| Primary | 主色调（橙色） | #F97316 |
| Background | 背景色 | #FAFAFA |
| Foreground | 前景文字 | #171717 |
| Card | 卡片背景 | #FFFFFF |
| Border | 边框 | #E5E5E5 |
| Muted | 次要文字 | #737373 |

## 状态管理

使用 Riverpod 进行状态管理，主要 Provider：

- `currentUserProvider` - 当前用户
- `caretakersProvider` - 宠托师列表
- `ordersProvider` - 订单列表
- `conversationsProvider` - 会话列表
- `createOrderProvider` - 创建订单状态

## 后续开发

- [ ] 接入真实后端 API
- [ ] 添加用户认证
- [ ] 集成支付功能
- [ ] 添加推送通知
- [ ] 实时聊天功能
- [ ] 图片上传功能
