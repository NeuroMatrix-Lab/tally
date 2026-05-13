# Tally Server 部署指南

## 功能说明
实时同步记账应用的Rust后端

## 使用 Docker 部署

### 使用 Docker Compose（推荐）

最简单的部署方式是使用 Docker Compose：

```bash
cd server
docker-compose up -d
```

这会启动两个容器：
- `tally-db` - MySQL数据库容器，暴露在 `3306` 端口
- `tally-server` - Rust后端服务，暴露在 `7378` 端口

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
  -e DATABASE_URL=mysql://user:pass@host:3306/tally_db \
  tally-server
```

## 本地开发

首先需要安装 Rust 1.70+：

```bash
cd server
cargo run
```

需要设置数据库连接：

```bash
export DATABASE_URL=mysql://user:pass@host:3306/tally_db
export PORT=7378
```

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
