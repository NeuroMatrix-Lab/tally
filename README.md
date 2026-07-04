# Tally 💰

> 一个给...自己做的记账 app

Flutter 前端 + Rust 后端，支持多设备同步。


## 它能干嘛

- 记一笔账（金额、类别、工作内容、关联人员）
- 图片附件（自动压缩）
- 账本管理（比如"日常"、"项目A"分开记）
- Excel 导出
- 操作日志（谁改了什么一目了然）
- 回收站（删错了能救回来）
- 深色模式
- WebSocket 实时同步（多设备同时在线）


## 跑起来

### 前端

```bash
git clone https://github.com/NeuroMatrix-Lab/tally.git
cd tally
flutter pub get
flutter run
```

### 后端

```bash
export DB_HOST=127.0.0.1
export DB_PORT=3306
export DB_USER=你的用户名
export DB_PASSWORD=你的密码
export DB_NAME=你的数据库名

cd server && cargo run
```

跑在 `http://0.0.0.0:7378`，健康检查：`GET /api/v1/health`


## Docker 部署

```bash
cd server
docker build -t tally-server .

docker run -d \
  --name tally-server \
  --network 你的网络 \
  -p 127.0.0.1:7378:7378 \
  -e DB_HOST=mariadb \
  -e DB_PORT=3306 \
  -e DB_USER=tally_user \
  -e DB_PASSWORD=你的密码 \
  -e DB_NAME=tally_db \
  tally-server
```


## 三种模式

| 模式 | 说明 | 适合场景 |
|------|------|----------|
| 本地 | SQLite，不需要服务器 | 一个人用，离线 |
| 后端服务 | HTTP API + WebSocket | 多设备同步 |
| 数据库直通 | Flutter 直连 MySQL | 不想跑后端 |


## API

所有接口前缀 `/api/v1`

```
GET    /health                    健康检查
GET    /records                   所有记录
GET    /records/recent?months=N   最近 N 月
POST   /records                   新建记录
PUT    /records/:id               更新记录
DELETE /records/:id               删除记录
POST   /records/search            按日期搜索
GET    /records/deleted           已删除的
POST   /records/:id/restore       恢复
DELETE /records/:id/permanent     永久删除

GET    /ledgers                   账本列表
POST   /ledgers                   新建账本
PUT    /ledgers/:name             改名
DELETE /ledgers/:name             删除

GET    /staff                     人员列表
POST   /staff                     添加
PUT    /staff/:id                 更新
DELETE /staff/:id                 删除

GET    /work-contents             工作内容
GET    /categories                类别
```


## CI

推 tag `v*.*.*` 或手动触发，自动构建 Android + Windows，发 GitHub Release。


## 项目结构

```
lib/                  Flutter 前端
  main.dart           入口
  models/             数据模型
  pages/              页面
  services/           API 服务
  widgets/            组件

server/               Rust 后端
  src/main.rs         主逻辑
  Dockerfile          Docker 构建

.github/workflows/    CI 配置
test/                 测试
```


## 许可

MIT
