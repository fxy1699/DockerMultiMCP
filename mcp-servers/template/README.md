# MCP 服务器模板

这是一个用于快速创建新MCP服务器的通用模板。

## 🚀 快速开始

### 1. 复制模板
```bash
cp -r template your-new-service
cd your-new-service
```

### 2. 修改配置
编辑 `server.py` 中的服务配置：
```python
SERVICE_NAME = "your-service"  # 修改为你的服务名
SERVICE_PORT = 8003           # 选择一个未使用的端口
```

### 3. 实现你的MCP服务
在 `BaseMCPService._initialize_service()` 方法中：
```python
def _initialize_service(self):
    try:
        from your_mcp_package import YourMCPClass
        self.mcp_instance = YourMCPClass()
        logger.info(f"✅ {self.service_name} MCP服务初始化成功")
    except ImportError as e:
        # 处理导入失败
        pass
```

### 4. 添加API端点
根据你的MCP服务功能，添加相应的API端点：
```python
@app.post("/your-endpoint")
async def your_endpoint(payload: Dict[str, Any]):
    # 处理请求
    return await mcp_service.handle_request('your_method', **payload)
```

### 5. 更新依赖
编辑 `requirements.txt`，添加你的MCP服务所需的依赖。

### 6. 更新Dockerfile
如果需要额外的系统依赖，修改 `Dockerfile`。

## 📁 文件说明

- `server.py` - 主服务器文件
- `Dockerfile` - Docker构建配置
- `requirements.txt` - Python依赖
- `README.md` - 使用说明

## 🔧 开发建议

1. **端口分配**：每个MCP服务使用独立端口
   - 小红书：8001
   - 模板：8002
   - 你的服务：8003+

2. **服务命名**：使用有意义的服务名，如 `weibo`, `douyin`, `github` 等

3. **错误处理**：确保所有API端点都有适当的错误处理

4. **日志记录**：使用统一的日志格式，便于调试和监控

5. **健康检查**：实现 `/health` 端点，用于服务监控

## 📊 集成到Docker Compose

在 `docker-compose.yml` 中添加你的服务：
```yaml
services:
  your-service-mcp:
    build:
      context: ./mcp-servers/your-service
    ports:
      - "8003:8003"
    environment:
      - HOST=0.0.0.0
      - PORT=8003
      - DEBUG=false
      - YOUR_SERVICE_ENABLED=true
```

## 🌐 客户端集成

在DyberPet的 `config.json` 中添加：
```json
{
  "your_service_mcp": {
    "enabled": true,
    "url": "http://your-server.com:8003/mcp/sse",
    "api_key": "",
    "timeout": 30
  }
}
``` 