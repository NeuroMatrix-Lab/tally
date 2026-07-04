# tally

轻量级跨平台记账应用

`tally` 是一个 Flutter 应用，支持以下模式：

- 本地模式（SQLite）
- 后端服务模式（HTTP API，`server/src/main.rs`）
- 数据库直通模式（MySQL 直连）
- Android / iOS / macOS / Windows / Linux


## 目录结构

- `lib/`
  - `main.dart`：应用入口
  - `models/`：数据模型（Record、Staff、OperationLog）
  - `pages/`：页面视图（记账、查账、设置、操作日志等）
  - `services/`：数据服务（ApiService、DatabaseService）
  - `widgets/`：组件
- `server/src/main.rs`：后端服务API（Axum + SQLx + MySQL）
- `.github/workflows/build-release.yml`：自动构建与发布流程
- `test/`：测试用例（数据库连接）


## 快速开始

### 环境要求

- Flutter SDK（建议 3.41.5）
- （可选）MySQL
- （可选）Rust + Cargo（后端服务）

### 安装依赖

```bash
git clone <repo_url>
cd tally
flutter pub get
```

### 启动 App

```bash
flutter run
```

### 启动后端（可选）

```bash
export DATABASE_URL="mysql://YOUR_USER:YOUR_PASSWORD@localhost:3306/YOUR_DB"
cd server
cargo run
```

默认后端监听 `http://0.0.0.0:7378`。

健康检查:
- `GET /health`


## 模式说明

### 1. 本地模式

- 在 `设置` 中选 `本地模式`
- 使用 SQLite 存储（`sqflite`）
- 离线可用，适合单机场景

### 2. 后端服务模式

- 选 `后端服务模式` 并配置 `backendIp`、`backendPort`
- API 接口（与 `server/src/main.rs` 对应）
  - `GET /api/records`
  - `GET /api/records/recent?months=...`
  - `POST /api/records`
  - `PUT /api/records/:id`
  - `DELETE /api/records/:id`
  - `GET /api/records/deleted`
  - `POST /api/records/:id/restore`
  - `DELETE /api/records/:id/permanent`
  - `GET /api/ledgers`
  - `POST /api/ledgers`
  - `PUT /api/ledgers/:name`
  - `DELETE /api/ledgers/:name`
  - `GET /api/staff`
  - `POST /api/staff`
  - `PUT /api/staff/:id`
  - `DELETE /api/staff/:id`
  - `GET /api/work-contents`
  - `GET /api/categories`

### 3. 数据库直通模式

- 选 `数据库直通模式` 并填 MySQL 配置
- 直接使用 `mysql1` 访问数据库
- 需要事先建立数据库表结构（server 会自动创建）


## 主要功能

- 记录增删改查
- 账本管理、人员管理
- 操作记录
- 统计视图
- 过滤与日期范围查询
- 回收站恢复
- 深色/亮色主题适配


## 已修复改动

### 深色模式适配

- `lib/pages/operation_log_page.dart` 使用 `ColorScheme` 替代硬编码
- CHIP、TextField、日期选择等均支持暗色模式

### 后端构建发布修复

- `.github/workflows/build-release.yml`
  - Android artifact rename 使用通配方式查找
  - Release 上传路径 `builds/**`
  - 输出 log 和文件检查

### 模式校验与连接优化

- `lib/pages/settings_page.dart`:
  - 保存前检查输入合法
  - 测试连接显示明确错误（超时/网络/格式）
- `lib/services/api_service.dart`:
  - 后端/数据库 URL/端口校验
  - HTTP 请求统一超时（12 秒）
  - 本地 SQLite migration 版本及 onUpgrade


## CI / 发布

- 触发方式：tag `v*.*.*` 或 workflow_dispatch
- 产物：Android APK/AAB，Windows ZIP，macOS DMG
- release 阶段合并 artifacts 并发布 GitHub Release


## 本地调试（不依赖后端/数据库）

- 直接切到本地模式，运行 app，进行 CRUD
- 设置页面可切换模式，未配置后端/数据库不会崩溃（会弹错误提示）


## 贡献

- 欢迎 issue / PR
- 推荐改进
  - `ConnectionMode` 枚举统一定义
  - 后端鉴权、令牌机制
  - 数据库直连 SSL/TLS
  - 增加单测与集成测试


## 许可

MIT / Apache

