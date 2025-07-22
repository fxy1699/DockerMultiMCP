# DyberPet 多MCP服务器部署系统

## 🏗️ 架构概览

这是一个可扩展的多MCP服务器部署系统，支持同时运行多个独立的MCP服务，通过API网关统一管理和路由。

```
客户端架构:
DyberPet Agent (本地) ←--HTTP/SSE--> API Gateway (Nginx) ←---> 多个MCP服务
                                           ↓
                                    xiaohongshu-mcp:8001
                                    template-mcp:8002
                                    your-service-mcp:8003+
                                           ↓
                                    Redis缓存 + Prometheus监控
```

## 📁 目录结构

```
docker/
├── mcp-servers/                    # MCP服务器目录
│   ├── xiaohongshu/               # 小红书MCP服务
│   │   ├── server.py              # 服务主文件
│   │   ├── Dockerfile             # Docker构建文件
│   │   └── requirements.txt       # Python依赖
│   ├── template/                  # 通用模板
│   │   ├── server.py              # 模板服务文件
│   │   ├── Dockerfile             # 模板Docker文件
│   │   ├── requirements.txt       # 基础依赖
│   │   └── README.md              # 使用说明
│   └── [your-service]/            # 你的新服务
├── nginx/                         # API网关配置
│   ├── nginx.conf                 # 主配置文件
│   ├── proxy_params               # 代理参数
│   └── ssl/                       # SSL证书
├── data/                          # 数据存储
│   ├── xiaohongshu/               # 小红书数据
│   └── template/                  # 模板数据
├── logs/                          # 日志文件
├── monitoring/                    # 监控配置
├── docker-compose.yml             # 服务编排配置
├── deploy.sh                      # 一键部署脚本
├── .env                          # 环境变量
└── README.md                      # 本文档
```

## 🚀 快速开始

### 1. 基础部署
```bash
# 部署默认服务 (小红书MCP + API网关)
./deploy.sh

# 或者显式指定
./deploy.sh deploy
```

### 2. 开发模式部署
```bash
# 包含模板服务的开发模式
./deploy.sh --dev

# 完整功能部署 (包含缓存和监控)
./deploy.sh --full
```

### 3. 自定义服务部署
```bash
# 只部署指定服务
./deploy.sh --services "xiaohongshu-mcp api-gateway"

# 使用特定profile
./deploy.sh --profile cache  # 包含Redis缓存
```

## 🔧 管理命令

### 服务管理
```bash
./deploy.sh start                    # 启动服务
./deploy.sh stop                     # 停止服务
./deploy.sh restart                  # 重启服务
./deploy.sh status                   # 查看状态
./deploy.sh ps                       # 查看容器
```

### 日志管理
```bash
./deploy.sh logs                     # 查看所有日志
./deploy.sh logs xiaohongshu-mcp     # 查看特定服务日志
```

### 服务发现
```bash
./deploy.sh list                     # 列出所有可用服务
./deploy.sh add-service              # 添加新MCP服务向导
```

### 数据管理
```bash
./deploy.sh clean                    # 清理所有数据 (慎用!)
```

## 🌐 服务访问

### API网关路由

| 服务 | 直接访问 | 网关路由 | 描述 |
|------|----------|-----------|------|
| 小红书MCP | `http://localhost:8001` | `/api/xiaohongshu/` | 小红书内容搜索分析 |
| 模板MCP | `http://localhost:8002` | `/api/template/` | 开发测试模板 |
| 你的服务 | `http://localhost:8003+` | `/api/your-service/` | 自定义MCP服务 |

### 网关端点
- **主网关**: `http://localhost:80` (HTTP), `https://localhost:443` (HTTPS)
- **开发端口**: `http://localhost:8080` (直接访问，无SSL)
- **服务状态**: `http://localhost/api/status`
- **健康检查**: `http://localhost/health`

### SSE连接
```javascript
// 连接小红书MCP的SSE流
const sse = new EventSource('http://localhost/api/xiaohongshu/mcp/sse');

// 或直接连接
const sse = new EventSource('http://localhost:8001/mcp/sse');
```

## 🔌 添加新MCP服务

### 方式1: 使用向导 (推荐)
```bash
./deploy.sh add-service
# 按提示输入服务名和端口
```

### 方式2: 手动创建
```bash
# 1. 复制模板
cp -r mcp-servers/template mcp-servers/your-service

# 2. 修改配置
cd mcp-servers/your-service
# 编辑 server.py, requirements.txt, Dockerfile

# 3. 更新docker-compose.yml
# 添加新服务配置

# 4. 部署
./deploy.sh --services "your-service-mcp"
```

### 新服务清单
创建新服务时需要确定：
- [ ] 服务名称 (如: `weibo`, `douyin`, `github`)
- [ ] 端口号 (8003+)
- [ ] 特殊依赖 (Playwright, 特定Python包等)
- [ ] API端点设计
- [ ] 环境变量配置

## 📊 监控和运维

### 服务健康检查
```bash
# 检查所有服务状态
curl http://localhost/api/status

# 检查单个服务
curl http://localhost:8001/health     # 小红书MCP
curl http://localhost:8002/health     # 模板MCP
```

### 性能监控
```bash
# 启用Prometheus监控
./deploy.sh --profile monitoring

# 访问监控面板
open http://localhost:9090
```

### 日志分析
```bash
# 实时日志
docker-compose logs -f xiaohongshu-mcp

# 错误日志
docker-compose logs xiaohongshu-mcp | grep ERROR

# Nginx访问日志
tail -f logs/nginx/access.log
```

## 🔒 安全配置

### API认证
```bash
# 查看认证Token
grep MCP_AUTH_TOKEN .env

# 在请求中使用
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost/api/xiaohongshu/search
```

### SSL证书
```bash
# 开发环境 (自动生成自签名证书)
./deploy.sh  # 会自动生成

# 生产环境 (使用Let's Encrypt)
certbot --nginx -d your-domain.com
```

### 防火墙设置
```bash
# 只开放必要端口
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw deny 8001:8099/tcp # 隐藏直接访问
```

## 🎯 最佳实践

### 1. 服务设计
- **单一职责**: 每个MCP服务专注一个平台或功能
- **独立部署**: 服务间尽量避免直接依赖
- **统一接口**: 使用标准的健康检查和错误响应格式
- **优雅降级**: 服务故障时提供合理的fallback

### 2. 端口分配
- `8001`: 小红书MCP
- `8002`: 模板/开发服务
- `8003+`: 新增MCP服务
- `80/443`: API网关
- `6379`: Redis缓存
- `9090`: Prometheus监控

### 3. 环境管理
- **开发环境**: 使用`--dev`模式
- **测试环境**: 单独的`.env`配置
- **生产环境**: 使用外部SSL证书和域名

### 4. 容量规划
- **轻量服务**: 1核1G内存起
- **重度爬虫**: 2核4G内存 + SSD存储
- **高并发**: 配置Nginx负载均衡

## 🔧 故障排除

### 常见问题

#### 1. 服务启动失败
```bash
# 查看详细日志
./deploy.sh logs service-name

# 检查端口占用
netstat -tlnp | grep :8001

# 重新构建
./deploy.sh deploy --no-cache
```

#### 2. 网关路由问题
```bash
# 测试Nginx配置
docker exec mcp-api-gateway nginx -t

# 重载配置
docker exec mcp-api-gateway nginx -s reload
```

#### 3. 容器资源不足
```bash
# 查看资源使用
docker stats

# 清理无用容器
docker system prune -f
```

#### 4. SSL证书问题
```bash
# 重新生成证书
rm nginx/ssl/*
./deploy.sh deploy
```

### 调试技巧
```bash
# 进入容器调试
docker exec -it xiaohongshu-mcp-server bash

# 查看容器启动日志
docker logs xiaohongshu-mcp-server

# 检查网络连接
docker network ls
docker network inspect docker_mcp-network
```

## 📈 扩展方向

### 即将支持的功能
- [ ] 自动服务发现
- [ ] 动态负载均衡
- [ ] 服务限流和熔断
- [ ] 统一配置中心
- [ ] 链路追踪
- [ ] 自动化测试

### 潜在的MCP服务
- [ ] 微博MCP (Weibo)
- [ ] 抖音MCP (Douyin)
- [ ] GitHub MCP
- [ ] 知乎MCP (Zhihu)
- [ ] B站MCP (Bilibili)

## 🤝 贡献指南

### 添加新MCP服务
1. 使用`./deploy.sh add-service`创建基础结构
2. 实现MCP服务逻辑
3. 添加测试用例
4. 更新文档
5. 提交PR

### 代码规范
- 遵循PEP 8 Python代码规范
- 使用有意义的变量和函数名
- 添加必要的错误处理和日志
- 包含健康检查端点

---

> 💡 **提示**: 这个多MCP服务器系统设计为高度模块化和可扩展，你可以根据实际需求添加任意数量的MCP服务，每个服务都是独立运行的。 