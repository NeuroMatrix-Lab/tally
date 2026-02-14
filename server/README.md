# Tally Server - Python后端服务

## 部署说明

### 前置要求
- Python 3.8 或更高版本

### 快速启动

#### Windows:
```bash
cd server
start_python.bat
```

#### Linux/Mac:
```bash
cd server
chmod +x start_python.sh
./start_python.sh
```

### 手动启动

1. 进入server目录：
```bash
cd server
```

2. 创建虚拟环境（可选但推荐）：
```bash
python -m venv venv
```

3. 激活虚拟环境：
- Windows: `venv\Scripts\activate`
- Linux/Mac: `source venv/bin/activate`

4. 安装依赖：
```bash
pip install -r requirements.txt
```

5. 运行服务：
```bash
python main.py
```

服务将在7378端口启动。

### 配置

配置在 `main.py` 文件中：

```python
DATABASE_FILE = "./data/tally.db"  # 数据库文件路径
```

### API接口

#### 获取最近N个月的记录
```
GET /api/records/recent?months=3
```

#### 搜索记录
```
GET /api/records/search?startDate=2024-01-01T00:00:00&endDate=2024-12-31T23:59:59&category=类别&ledger=账本
```

#### 获取最近的类别
```
GET /api/records/categories?months=3
```

#### 获取最近的工作内容
```
GET /api/records/work-contents?months=3
```

#### 获取所有账本
```
GET /api/records/ledgers
```

#### 创建记录
```
POST /api/records
Content-Type: application/json

{
  "recordId": "1234567890",
  "date": "2024-01-01T10:00:00",
  "category": "类别",
  "workContent": "工作内容",
  "amount": 100.0,
  "ledger": "默认账本"
}
```

#### 更新记录
```
PUT /api/records/{recordId}
Content-Type: application/json

{
  "recordId": "1234567890",
  "date": "2024-01-01T10:00:00",
  "category": "类别",
  "workContent": "工作内容",
  "amount": 100.0,
  "ledger": "默认账本"
}
```

#### 删除记录
```
DELETE /api/records/{recordId}
```

### 数据库

服务使用SQLite数据库，数据文件存储在 `data/tally.db`。

### 技术栈

- **FastAPI**: 现代化的Python Web框架
- **Uvicorn**: ASGI服务器
- **SQLite**: 轻量级数据库
- **Pydantic**: 数据验证

### 优势

相比Java版本，Python版本具有以下优势：

1. **部署简单**: 只需Python，无需Maven
2. **启动快速**: 无需编译，直接运行
3. **资源占用少**: 内存和CPU占用更低
4. **易于维护**: 代码简洁，易于理解和修改
5. **跨平台**: 在Windows、Linux、Mac上都能轻松运行

### 测试API

启动服务后，可以访问：
- API文档: `http://localhost:7378/docs`
- 交互式API文档: `http://localhost:7378/redoc`

### 常见问题

1. **端口被占用**: 修改 `main.py` 中的端口号
2. **数据库错误**: 删除 `data/tally.db` 文件重启服务
3. **依赖安装失败**: 尝试使用 `pip install --upgrade pip` 升级pip

### 生产部署

建议使用以下方式部署到生产环境：

1. **使用systemd (Linux)**:
```bash
sudo nano /etc/systemd/system/tally.service
```

添加以下内容：
```ini
[Unit]
Description=Tally Server
After=network.target

[Service]
Type=simple
User=your_user
WorkingDirectory=/path/to/server
Environment="PATH=/path/to/server/venv/bin"
ExecStart=/path/to/server/venv/bin/python main.py
Restart=always

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl enable tally
sudo systemctl start tally
```

2. **使用nohup (简单部署)**:
```bash
nohup python main.py > server.log 2>&1 &
```

3. **使用screen**:
```bash
screen -S tally
python main.py
# Ctrl+A+D 退出screen
```