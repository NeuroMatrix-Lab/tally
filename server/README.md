# Tally Server 部署指南

## 功能说明
实时同步记账应用的Rust后端

## 使用 Docker 部署

### 使用 Docker Compose（推荐）

`server/docker-compose.yml` 会启动 MySQL 和后端服务。首次部署前，建议在 `server` 目录创建 `.env`，至少修改数据库密码：

```bash
cd server
cat > .env <<'EOF'
DB_NAME=tally
DB_USER=tally_user
DB_PASSWORD=请替换为数据库密码
MYSQL_ROOT_PASSWORD=请替换为root密码
PORT=7378
# 可选：API 访问密码，留空则不启用鉴权
# API_PASSWORD=请替换为访问密码
EOF

docker compose up -d --build
docker compose logs -f server
```

这会启动两个容器：
- `tally-db` - MySQL数据库容器，暴露在 `3306` 端口
- `tally-server` - Rust后端服务，暴露在 `7378` 端口

检查服务：

```bash
curl http://127.0.0.1:7378/api/v1/health
```

停止服务但保留数据库数据：

```bash
docker compose down
```

如需连数据库数据一起删除，执行 `docker compose down -v`，这会永久删除 MySQL 数据。

### 使用单独构建并运行
1. 构建镜像：

```bash
cd server
docker build -t tally-server .
```

2. 运行容器：

```bash
docker run -d \
  --name tally-server \
  -p 7378:7378 \
  -e DB_HOST=宿主机或数据库服务器地址 \
  -e DB_PORT=3306 \
  -e DB_USER=tally_user \
  -e DB_PASSWORD=数据库密码 \
  -e DB_NAME=tally \
  tally-server
```

单独运行后端容器时，MySQL 必须已经运行，并且从容器网络可访问。使用 Compose 时不需要手动配置 `DB_HOST`，它会自动使用数据库服务名 `db`。

## 本地开发

首先需要安装 Rust 1.70+：

```bash
cd server
cargo run
```

需要设置数据库连接（也可直接改 `config.toml`）：

```bash
export DB_HOST=127.0.0.1
export DB_PORT=3306
export DB_USER=tally_user
export DB_PASSWORD=数据库密码
export DB_NAME=tally
export PORT=7378
# 可选：API 访问密码，留空则不启用鉴权
# export API_PASSWORD=your-password
```

### 访问密码（可选）

`config.toml` 的 `[server].password`，或环境变量 `API_PASSWORD`：

- 留空：不启用鉴权，行为与之前一致
- 设置后：除 `GET /api/v1/health` 外，所有接口都需要密码
  - HTTP：请求头 `X-Api-Password: <密码>`，或 `Authorization: Bearer <密码>`
  - WebSocket：连接串追加 `?password=<密码>`
  - 校验接口：`GET /api/v1/auth`（需带密码；返回 `{"authRequired":true/false,"status":"ok"}`）

客户端在「设置 → 后端服务模式 → 访问密码」中填写同一密码。

## Cloudflare 部署注意

通过 Cloudflare Tunnel / 反代时，同步相关建议：

1. **WebSocket 必须放行**（客户端会连 `wss://host/api/v1/ws`，并每 30 秒发一次心跳）
2. **不要缓存 API**：对该主机名关闭 Cache Everything / 对 `/api/*` 设 Bypass，否则 GET 可能拿到旧数据
3. **不要用 Cloudflare Access 挡住 API**（除非你只走浏览器）；App 密码用本服务的 `API_PASSWORD` 即可
4. 增量同步时间戳按 MySQL 秒级精度对齐，同一秒内的人员/账本变更也会带上

## 数据库初始化
程序会在首次运行时自动创建所需的表结构。

## 功能概述

### 主要功能
- RESTful API (v1)
- WebSocket 实时同步
- 增量同步API
- 记账记录管理
- 人员管理
- 账本管理
- 操作日志（仅本地存储）

### API 端点

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | /api/v1/health | 健康检查 |
| POST | /api/v1/sync | 增量同步 |
| GET | /api/v1/records | 获取所有记录 |
| POST | /api/v1/records | 创建记录 |
| WS | /api/v1/ws | WebSocket连接 |

## Flutter 前端

请确保您的 Flutter 应用在连接模式下连接。
