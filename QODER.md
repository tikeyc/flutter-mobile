# QODER.md

Intuly 移动端（Flutter）——AI 创作社区 App。已完成：登录（手机号验证码 + 账号密码 + 滑块验证）、首页瀑布流；其余底部导航 Tab 为占位。

## 常用命令

Git Bash 下 Flutter SDK 不在 PATH（位于 `D:\flutter`），每条命令前需：

```bash
export PATH="/d/flutter/bin:$PATH"
```

| 操作 | 命令 |
|------|------|
| 安装依赖 | `flutter pub get` |
| 静态分析 | `dart analyze` |
| 全部测试 | `flutter test` |
| 单个测试 | `flutter test test/features/auth/data/auth_repository_test.dart` |
| 运行 | `flutter run`（常用模拟器 `emulator-5554`；adb 在 `C:\Users\WIN11\AppData\Local\Android\sdk\platform-tools`） |
| 构建 | `flutter build apk` |

**分析器注意**：项目启用了 riverpod_lint 3.1.x（Dart 原生 analyzer 插件，无 custom_lint）。其诊断只在 `dart analyze` 和 IDE 中出现，`flutter analyze` 不加载该插件。校验 lint 一律用 `dart analyze`。升级 flutter_riverpod 时需同步更新两处 riverpod_lint 约束（pubspec dev_dependencies + analysis_options `plugins:`）。

## 技术栈

- Flutter / Dart `^3.13.5`，Material 3，仅 Android/iOS（web 目录为模板残留）
- flutter_riverpod 3.4.3（**手动 Provider/Notifier API，未用 codegen 与 riverpod_annotation**）
- go_router 18（路由 + 守卫）、dio 5（网络）、flutter_secure_storage（会话）、flutter_svg（图标）、url_launcher（协议页）
- pubspec.yaml 主要依赖**锁定精确版本**；新增依赖同样锁精确版本

## 架构

feature-first 分层，每个 feature 内部 `data / application / presentation`：

```
lib/
├── main.dart                 # 启动前先读会话，override initialSessionProvider，首帧即定路由避免闪屏
├── config/env_config.dart    # baseUrl、clientId 等常量（目前所有环境共用）
├── core/
│   ├── network/              # createDio() + ApiException
│   └── theme/                # AppColors / AppTextStyles / AppIcons / AppTheme
├── features/<feature>/
│   ├── data/                 # Repository（抽象类 + Dio 实现）、models（手写 fromJson）
│   ├── application/          # Riverpod providers / Notifier
│   └── presentation/         # 页面与 widgets
└── router/app_router.dart    # GoRouter；resolveRedirect() 纯函数守卫 + refreshListenable
```

关键约定：

- **业务状态码在响应 body 的 `status` 字段**，不是 HTTP 状态码。Dio 拦截器统一处理：body.status 非 2xx 抛 `DioException`（error 为 `ApiException`）；401/405/409 触发 `onUnauthorized`（只触发一次，signOut 回登录页）。Repository 层把 `DioException` 转成 `ApiException` 再抛。
- **依赖注入**：provider 构造期不 watch 可能回调自己的 provider（如 dioProvider 内惰性 `read` authProvider 避免循环依赖）；可替换点抽成 Provider（`httpClientAdapterProvider`、`sessionStorageProvider`、`slideVerifierProvider`），测试时 override。
- **Token 只存 flutter_secure_storage**（Android Keystore / iOS Keychain），禁止明文存储。
- 私有构造 + 静态常量的 token 类（`AppColors._()` 等）承载设计常量；公共 API 写中文 `///` 文档注释。

## 测试

- 测试目录镜像 lib/：`test/features/...`、`test/core/...`；公共测试设施在 `test/helpers/`
- 网络测试：`FakeHttpAdapter().on(path, httpStatus: 200, body: {...})` 按路径路由并记录请求，经 `httpClientAdapterProvider` override 注入，不发真实网络请求
- widget 测试：`AuthTestHost` 注入 FakeAuthRepository + InMemorySessionStorage + 假滑块回调；表单单独测时套 Scaffold + 滚动（`scroll: true`）
- 改任何功能后运行 `dart analyze` + `flutter test` 再交付

## UI / 设计还原

- 设计稿在 MasterGo（fileId 见 docs/superpowers/specs/2026-10-10-login-design.md）
- 颜色、文字必须用 `AppColors` / `AppTextStyles` token（注释里标了 MasterGo token 名），禁止硬编码色值；图标用 `AppIcons` + flutter_svg，SVG 放 `assets/icons/`（pubspec 已声明）
- UI 文案为简体中文；代码注释、文档均为中文
- 字体按 HarmonyOS Sans SC 设计，不可用时回退系统默认

## 业务规则速查

- 手机号正则 `^1[3-9]\d{9}$`；短信/登录前必须过滑块验证；协议未勾选禁止提交
- 滑块 `moveWidth` 是**逻辑像素**，若渲染尺寸与原图不一致需按比例换算回原始像素再传后端
- 业务码含义：403 账号或密码错误；301/302/303 账号封禁/冻结/违规；其余展示 `message` SnackBar
- 接口清单与完整数据流见 `docs/superpowers/specs/2026-10-10-login-design.md`

## 工作流

- 提交信息用 Conventional Commits（`feat:` / `fix:` / ...）
- 方案文档放 `docs/superpowers/specs/`，实施计划放 `docs/superpowers/plans/`，命名 `YYYY-MM-DD-<topic>.md`

## 已知 TODO

- Android `applicationId` 仍是 `com.example.intuly` 占位；release 构建用 debug 签名
- 首页底部导航「长按中央按钮退出登录」为调试期临时方案（home_page.dart）
- 协议页暂用 url_launcher 跳外部浏览器（域名待确认），WebView 在后续版本
