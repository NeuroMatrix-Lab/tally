# Tally

轻量级跨平台记账应用

`Tally` 是一个 Flutter + Rust 全栈记账系统，支持多设备同步。

- **Flutter 前端** — Android / Windows / macOS / Linux / iOS
- **Rust 后端** — Axum + SQLx + MySQL，支持 WebSocket 实时同步
- **三种连接模式** — 本地模式（SQLite）、后端服务模式（HTTP API）、数据库直通模式（MySQL 直连）


## 功能

- 记录增删改查，支持图片附件
- 账本管理、人员管理
- 操作日志记录
- 统计视图与日期范围筛选
- Excel 导出
- 回收站恢复
- 深色/亮色主题
- 后端 WebSocket 实时同步


## 快速开始

### Flutter 前端

```bash
git clone https://github.com/NeuroMatrix-Lab/tally.git
cd tally
flutter pub get
flutter run
```

### Rust 后端

```bash
export DB_HOST=127.0.0.1
export DB_PORT=3306
export DB_USER=your_user
export DB_PASSWORD=your_password
export DB_NAME=your_db

cd server
cargo run
```

默认监听 `http://0.0.0.0:7378`。

健康检查: `GET /api/v1/health`


## Docker 部署

```bash
cd server
docker build -t tally-server .

docker run -d \
  --name tally-server \
  --network your-network \
  -p 127.0.0.1:7378:7378 \
  -e DB_HOST=mariadb \
  -e DB_PORT=3306 \
  -e DB_USER=tally_user \
  -e DB_PASSWORD=your_password \
  -e DB_NAME=tally_db \
  tally-server
```


## 连接模式

### 1. 本地模式

- `设置` → `本地模式`
- 使用 SQLite 存储，离线可用

### 2. 后端服务模式

- `设置` → `后端服务模式`，填入服务器地址和端口
- 通过 HTTP API 与 Rust 后端通信
- 支持 WebSocket 实时同步

### 3. 数据库直通模式

- `设置` → `数据库直通模式`，填入 MySQL 连接信息
- Flutter 直连数据库，无需后端
- 需要先运行后端初始化表结构


## API 接口

所有接口前缀 `/api/v1`：

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查 |
| GET | `/records` | 获取所有记录 |
| GET | `/records/recent?months=N` | 获取最近 N 月记录 |
| POST | `/records` | 创建记录 |
| PUT | `/records/:id` | 更新记录 |
| DELETE | `/records/:id` | 软删除记录 |
| POST | `/records/search` | 按日期范围搜索 |
| GET | `/records/deleted` | 获取已删除记录 |
| POST | `/records/:id/restore` | 恢复记录 |
| DELETE | `/records/:id/permanent` | 永久删除 |
| GET | `/ledgers` | 获取账本列表 |
| POST | `/ledgers` | 创建账本 |
| PUT | `/ledgers/:name` | 重命名账本 |
| DELETE | `/ledgers/:name` | 删除账本 |
| GET | `/staff` | 获取人员列表 |
| POST | `/staff` | 添加人员 |
| PUT | `/staff/:id` | 更新人员 |
| DELETE | `/staff/:id` | 删除人员 |
| GET | `/work-contents` | 获取工作内容列表 |
| GET | `/categories` | 获取类别列表 |


## CI / 发布

- 触发方式：tag `v*.*.*` 或 workflow_dispatch
- 构建产物：Android APK/AAB、Windows ZIP
- 自动创建 GitHub Release 并上传产物


## 目录结构

```
├── lib/
│   ├── main.dart              # 应用入口
│   ├── models/                # 数据模型（Record、Staff、OperationLog）
│   ├── pages/                 # 页面（记账、查账、设置、操作日志等）
│   ├── services/              # 数据服务（ApiService、DatabaseService）
│   └── widgets/               # 组件
├── server/
│   ├── src/main.rs            # Rust 后端（Axum + SQLx）
│   ├── Cargo.toml
│   └── Dockerfile
├── .github/workflows/
│   ├── build-release.yml      # Flutter 构建发布
│   └── server-ci.yml          # 后端 CI
└── test/                      # 测试用例
```


## 许可

MIT
