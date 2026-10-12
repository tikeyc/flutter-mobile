# 登录页面设计方案

**日期**: 2026-10-10  
**范围**: 手机号验证码登录 + 账号密码登录 + 滑块验证  
**设计稿**: MasterGo (fileId: 168002790860920)

---

## 一、需求概述

实现 intuly-mobile Flutter 应用的登录模块,支持:
1. 手机号 + 验证码登录
2. 账号 + 密码登录
3. 滑块验证码(发短信和账号登录前必经步骤)
4. 用户协议勾选
5. 登录成功后跳转首页占位页

**不包含**:
- 微信登录(后续版本)
- 忘记密码(后续版本)
- 绑定手机号(后续版本)

---

## 二、技术栈

| 类别 | 技术选型 | 版本 |
|------|----------|------|
| 状态管理 | flutter_riverpod + riverpod_annotation | ^2.5.0 / ^2.3.0 |
| 网络请求 | dio | ^5.4.0 |
| 路由 | go_router | ^13.0.0 |
| Token 存储 | flutter_secure_storage | 实施时解析 |
| SVG 渲染 | flutter_svg | 实施时解析 |

版本号说明：当前 Flutter 为 3.47 / Dart ^3.13，上表版本仅作参考。实施时用 `flutter pub add` 解析与 SDK 兼容的最新稳定版，再在 pubspec.yaml 中锁定为精确版本。

Token 改用 flutter_secure_storage（Android Keystore / iOS Keychain），不放 shared_preferences 明文存储。

---

## 三、项目结构

```
lib/
├── main.dart
├── config/
│   └── env_config.dart              # 环境配置
├── core/
│   ├── network/
│   │   ├── dio_client.dart          # Dio 实例 + 拦截器
│   │   └── api_response.dart        # 统一响应封装
│   └── storage/
│       └── token_storage.dart       # Token 持久化
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── models/              # DTO: LoginRequest, SlideResponse, etc.
│   │   │   ├── repositories/        # AuthRepository
│   │   │   └── providers/           # Riverpod StateNotifier
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── login_page.dart  # 登录页主入口
│   │       └── widgets/
│   │           ├── phone_login_form.dart
│   │           ├── account_login_form.dart
│   │           └── slide_captcha_dialog.dart
│   └── home/
│       └── presentation/
│           └── pages/
│               └── home_page.dart   # 首页占位
└── router/
    └── app_router.dart              # 路由配置
```

---

## 四、环境配置

**所有环境共用值** (`config/env_config.dart`):
```dart
class EnvConfig {
  static const String baseURL = 'https://www.intuly.com/api';
  static const String clientId = '101409740478767510';
  static const String apiVersion = 'v1.0.0';
}
```

---

## 五、UI 设计

### 5.1 整体布局

```
┌──────────────────────────────────┐
│  AppBar: "登录/注册" [← 关闭]      │
├──────────────────────────────────┤
│  TabBar: [手机号登录] [账号登录]  │
├──────────────────────────────────┤
│                                  │
│  TabBarView:                     │
│  - PhoneLoginForm                │
│  - AccountLoginForm              │
│                                  │
│  ┌────────────────────────────┐ │
│  │      立即登录               │ │  ← 与表单间距 40px
│  └────────────────────────────┘ │
│  [ ] 我已阅读并同意《用户服务协议》│  ← 按钮下方 12px,居中
│      和《隐私政策》               │
└──────────────────────────────────┘
```

**与设计稿的差异**: 设计稿中手机号登录和账号登录是两张独立页面(导航栏标题分别为"登录/注册"和"账号登录"),稿中没有画切换入口。本方案按已确认的方案用 TabBar 切换,导航栏标题统一为"登录/注册"。

### 5.2 手机号登录表单

**字段**:
1. 标题: "手机号登录" (14sp Medium, #1D2129)
2. 提示: "未注册手机号将自动注册" (12sp Regular, #868F9C)
3. 手机号输入框:
   - 左侧固定文本: "+86"
   - 占位符: "请输入手机号"
   - 背景色: #F9F9FA, 圆角 4px
4. 验证码输入框:
   - 标题: "验证码" (14sp Medium, #FFFFFF)
   - 占位符: "请输入验证码"
   - 右侧按钮: "获取验证码" (次要按钮,禁用时灰色)
   - 倒计时: "60s" → "0s" 后恢复可点击

**交互**:
1. 手机号输入完成(11 位数字) → "获取验证码"按钮可点击
2. 点击"获取验证码" → 弹出滑块验证弹窗
3. 滑块验证成功 → 调 `/login/ai/sendSms` → 按钮进入 60s 倒计时
4. 验证码 + 手机号输入完成 → "立即登录"按钮变亮
5. 协议未勾选 → 点击"立即登录"时弹 Toast 提示"请先同意用户协议"

### 5.3 账号登录表单

**字段**:
1. 标题: "账号登录" (14sp Medium, #1D2129)
2. 账号输入框:
   - 占位符: "请输入账号"
   - 背景色: #F9F9FA, 圆角 4px
3. 密码输入框:
   - 标题: "密码" (14sp Medium, #FFFFFF)
   - 占位符: "请输入密码"
   - 右侧图标: 眼睛 icon (切换明文/密文)
4. 忘记密码链接:
   - 文本: "忘记密码" (12sp Regular, #0057FF)
   - 点击: 暂不实现,后续版本

**交互**:
1. 账号 + 密码输入完成 → "立即登录"按钮变亮
2. 协议未勾选 → 点击时弹 Toast 提示"请先同意用户协议"
3. 点击"立即登录" → 弹出滑块验证弹窗
4. 滑块验证成功 → 调 `/login/ai/pass` → 登录

### 5.4 滑块验证弹窗

**布局**:
```
半透明黑色蒙层 (rgba(0,0,0,0.6))
┌─────────────────────────────────┐
│  ┌───────────────────────────┐  │
│  │  [拼图背景图 297x178]      │  │
│  │    [滑块小图 32x32] 🔄     │  │  ← 右上角刷新按钮
│  └───────────────────────────┘  │
│  ┌─────────────────────────┬─┐  │
│  │ 请拖动滑块完成拼图       │►│  │  ← 滑块轨道(#DEDFE0)
│  └─────────────────────────┴─┘  │
└─────────────────────────────────┘
```

**数据源**:
- 背景图: `/login/ai/slide` 返回的 `image` (base64)
- 滑块小图: `/login/ai/slide` 返回的 `slide` (base64)
- 滑块宽高: `slideWidth`, `slideHeight`
- 校验 ID: `imgCaptchaId`

**交互**:
1. 用户水平拖动滑块按钮
2. 记录 `moveWidth` (拖动距离,单位 px)
3. 松手后调 `/login/ai/checkSlide`,传 `moveWidth`
4. `checkResult: true` → 返回 `loginSlide` → 关闭弹窗
5. `checkResult: false` → 提示"未对准,请重试" → 重置滑块
6. `errorCnt >= 3` → 自动刷新滑块图片

**注意**: `moveWidth` 是拖动距离的 **逻辑像素值**(device-independent pixels)。如果滑块图片渲染尺寸与原始像素尺寸不一致,需按比例换算回原始像素坐标再传给后端。

---

## 六、数据流

### 6.1 API 接口

**基础配置**:
- baseURL: `https://www.intuly.com/api`
- 公共 Header:
  - `AI-Api-ClientId`: `101409740478767510`
  - `AI-Api-Version`: `v1.0.0`
  - `Authorization`: `Bearer <token>` (登录后自动添加)

**接口列表**:

| 接口 | 方法 | 参数 | 说明 |
|------|------|------|------|
| `/login/ai/slide` | POST | `loginUser`, `smsType` | 获取滑块验证码 |
| `/login/ai/checkSlide` | POST | `loginUser`, `imgCaptchaId`, `moveWidth`, `smsType` | 校验滑块位置 |
| `/login/ai/sendSms` | POST | `phone`, `loginSlide`, `smsType` | 发送短信验证码 |
| `/login/ai/phone` | POST | `loginUser`, `loginCode`, `loginSlide`, `loginType` | 手机号登录 |
| `/login/ai/pass` | POST | `loginUser`, `loginPass`, `loginSlide`, `loginType` | 账号密码登录 |

**参数说明**:
- `smsType`: 1=登录短信, 2=忘记密码, 3=绑定手机号
- `loginType`: `'1'`=Web 端, `'2'`=移动端

### 6.2 状态管理

**AuthRepository** (`auth/data/repositories/auth_repository.dart`):
```dart
class AuthRepository {
  final Dio _dio;
  
  Future<SlideResponse> getSlide(String loginUser, int smsType);
  Future<SlideCheckResponse> checkSlide({...});
  Future<void> sendSms({...});
  Future<LoginResponse> loginWithPhone({...});
  Future<LoginResponse> loginWithPassword({...});
}
```

**SlideCaptchaNotifier** (滑块状态):
```dart
@riverpod
class SlideCaptchaNotifier extends _$SlideCaptchaNotifier {
  AsyncValue<SlideCaptchaState> build();
  Future<void> loadSlide(String loginUser, int smsType);
  Future<String?> checkSlide(double moveWidth);
  Future<void> refresh();
}

class SlideCaptchaState {
  final String? imgCaptchaId;
  final String? backgroundImageBase64;
  final String? slideImageBase64;
  final int? slideWidth;
  final int? slideHeight;
  final int errorCount;
}
```

**AuthNotifier** (登录状态):
```dart
@riverpod
class AuthNotifier extends _$AuthNotifier {
  AsyncValue<AuthState> build();
  Future<void> getPhoneCode(String phone);
  Future<void> loginWithPhone(String phone, String code);
  Future<void> loginWithPassword(String account, String password);
  Future<void> logout();
}

class AuthState {
  final String? token;
  final UserInfo? userInfo;
  final bool isLoading;
  bool get isAuthenticated => token != null;
}
```

### 6.3 关键流程

**获取验证码**:
```
1. 用户输入手机号(11 位) → "获取验证码"可点击
2. 点击按钮 → 调 getSlide(phone, 1) → 显示滑块弹窗
3. 用户拖动滑块 → 调 checkSlide(moveWidth) → 返回 loginSlide
4. 调 sendSms(phone, loginSlide, 1) → 短信发送成功
5. 按钮进入 60s 倒计时
```

**手机号登录**:
```
1. 用户输入手机号 + 验证码 + 勾选协议
2. 点击"立即登录" → 调 loginWithPhone(phone, code)
   - loginSlide 复用获取验证码时的值
3. 后端返回 { status: 200, data: "<token>" }
4. 保存 token 到 flutter_secure_storage
5. 保存登录账号(手机号)到本地,用于首页展示
6. 跳转 /home
```

**账号密码登录**:
```
1. 用户输入账号 + 密码 + 勾选协议
2. 点击"立即登录" → 弹出滑块弹窗
3. 滑块验证成功 → 调 loginWithPassword(account, password, loginSlide)
4. 后端返回 { status: 200, data: "<token>" }
5. 保存 token 到 flutter_secure_storage
6. 保存登录账号到本地,用于首页展示
7. 跳转 /home
```

---

## 七、错误处理

### 7.1 业务状态码 (响应 body 中的 status 字段)

| 状态码 | 处理方式 |
|--------|----------|
| 200 | 正常响应 |
| 401/405/409 | 清除 token,跳转登录页 |
| 403 | "账号或密码错误",输入框标红 |
| 301/302/303 | 显示账号封禁/冻结/违规弹窗(占位文案) |
| 其他 | 显示 SnackBar 提示 `response.message` |

**注**: 以上均为响应 JSON 的 `status` 字段,不是 HTTP 状态码。HTTP 层由 Dio 拦截器统一处理网络异常。

### 7.2 表单校验

| 字段 | 规则 |
|------|------|
| 手机号 | 正则 `^1[3-9]\d{9}$` |
| 验证码 | 非空 + 纯数字 |
| 账号 | 非空 |
| 密码 | 非空 |

### 7.3 滑块验证失败

- `checkResult: false` → 提示"未对准,请重试",重置滑块位置
- `errorCnt >= 3` → 自动调用 `refresh()` 刷新滑块图片

---

## 八、边界情况

1. **重复点击**: 登录按钮点击后立即禁用,显示 Loading
2. **Token 过期**: 401 响应 → 清除本地 token → Toast 提示 → 回登录页
3. **滑块弹窗关闭**: 用户点击蒙层/返回键 → 视为取消操作
4. **协议链接**: 第一版用 InkWell 包裹,点击跳转外部浏览器(后续实现 WebView)
5. **网络异常**: Dio 拦截器统一捕获,显示 SnackBar

---

## 九、路由守卫

使用 `go_router` 的 `redirect` 回调:
- 未登录 + 访问 `/home` → 重定向到 `/login`
- 已登录 + 访问 `/login` → 重定向到 `/home`

---

## 十、首页占位

**功能**:
1. 显示登录账号(手机号或账号,从本地读取)
2. 显示 token 前 10 位(脱敏)
3. "登出"按钮:
   - 点击 → 清除 token 和登录账号 → 跳转 `/login`

---

## 十一、设计还原

### 11.1 颜色 Token

| Token | 值 | 用途 |
|-------|-----|------|
| `color-bg-1` | `#FFFFFF` | 白色背景 |
| `color-bg-2` | `#F9F9FA` | 输入框背景 |
| `color-text-1` | `#1D2129` | 强调文字 |
| `color-text-2` | `#4D5562` | 次强调文字 |
| `color-text-3` | `#868F9C` | 辅助文字 |
| `color-text-4` | `#CACCD0` | 置灰信息 |
| `primary-base` | `#0057FF` | 主色(按钮/链接) |
| `color-border-3` | `#E5E6EB` | 描边 |
| `color-border-4` | `#F2F3F5` | 浅描边 |

### 11.2 字体

| Token | 配置 |
|-------|------|
| `title-16-CN` | HarmonyOS Sans SC, 16sp, Medium, line-height 24 |
| `title-14-CN` | HarmonyOS Sans SC, 14sp, Medium, line-height 20 |
| `body-14-CN` | HarmonyOS Sans SC, 14sp, Regular, line-height 20 |
| `body-12-CN` | HarmonyOS Sans SC, 12sp, Regular, line-height 16 |

**Fallback**: 如果 HarmonyOS Sans SC 不可用,使用系统默认字体。

### 11.3 间距

- Tab 与表单: `gap: 40px`
- 表单内字段: `gap: 12px`
- 输入框内 padding: `15px`
- 按钮 padding: `8px 12px`
- 弹窗 padding: `12px`

---

## 十二、工作量估算

| 任务 | 预估时间 |
|------|----------|
| 项目结构搭建 + 环境配置 | 1-2h |
| Dio 封装 + Repository 层 | 2-3h |
| 登录页 UI(手机号+账号表单) | 3-4h |
| 滑块弹窗 UI + 拖动逻辑 | 2-3h |
| 状态管理 + 业务逻辑 | 3-4h |
| 首页占位 + 路由守卫 | 1h |
| 测试 + 调试 | 2-3h |
| **总计** | **14-20h** |

---

## 十三、验收标准

1. ✅ 手机号登录流程完整可用(含滑块验证)
2. ✅ 账号密码登录流程完整可用(含滑块验证)
3. ✅ 滑块验证弹窗交互正常,拖动校验准确
4. ✅ 协议勾选控制按钮可用性
5. ✅ 登录成功后跳转首页,显示用户信息
6. ✅ 登出功能正常
7. ✅ 错误提示准确(网络错误、表单校验、业务错误码)
8. ✅ 视觉对比设计稿验证:颜色、字体、间距、圆角无明显偏差

---

## 十四、后续版本规划

1. 微信登录
2. 忘记密码
3. 绑定手机号
4. 用户协议详情页(WebView)
5. 账号封禁/冻结/违规详情弹窗
