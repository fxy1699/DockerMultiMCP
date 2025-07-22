#!/usr/bin/env python3
"""
通用MCP服务器模板
用于快速创建新的MCP服务
"""

import asyncio
import json
import logging
import os
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
import uvicorn

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 服务配置 - 请根据具体MCP服务修改
SERVICE_NAME = "template"  # 修改为实际服务名
SERVICE_PORT = 8002        # 修改为专用端口
SERVICE_VERSION = "1.0.0"

app = FastAPI(
    title=f"{SERVICE_NAME.title()} MCP Server",
    description=f"{SERVICE_NAME} MCP Server for DyberPet AI Agent",
    version=SERVICE_VERSION
)

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class BaseMCPService:
    """MCP服务基础类"""
    
    def __init__(self, service_name: str):
        self.service_name = service_name
        self.version = SERVICE_VERSION
        self.mcp_instance = None
        self._initialize_service()
    
    def _initialize_service(self):
        """初始化MCP服务实例 - 子类重写此方法"""
        try:
            # 在这里导入和初始化实际的MCP包
            # from your_mcp_package import YourMCPClass
            # self.mcp_instance = YourMCPClass()
            
            # 临时使用模拟实现
            self.mcp_instance = MockMCPImplementation()
            logger.info(f"✅ {self.service_name} MCP服务初始化成功")
        
        except ImportError as e:
            logger.warning(f"⚠️ 无法导入{self.service_name} MCP包: {e}")
            self.mcp_instance = MockMCPImplementation()
        except Exception as e:
            logger.error(f"❌ {self.service_name} MCP初始化失败: {e}")
            raise
    
    async def handle_request(self, action: str, **kwargs) -> Dict[str, Any]:
        """处理MCP请求的通用方法"""
        try:
            if hasattr(self.mcp_instance, action):
                method = getattr(self.mcp_instance, action)
                
                # 支持同步和异步方法
                if asyncio.iscoroutinefunction(method):
                    result = await method(**kwargs)
                else:
                    result = method(**kwargs)
                
                return {
                    "status": "success",
                    "service": self.service_name,
                    "action": action,
                    "data": result
                }
            else:
                raise AttributeError(f"方法 {action} 不存在")
                
        except Exception as e:
            logger.error(f"{action} 请求失败: {e}")
            return {
                "status": "error",
                "service": self.service_name,
                "action": action,
                "error": str(e)
            }


class MockMCPImplementation:
    """模拟MCP实现 (开发测试用)"""
    
    def test_function(self, message: str = "Hello"):
        """测试功能"""
        return {
            "message": f"Mock response: {message}",
            "timestamp": asyncio.get_event_loop().time()
        }
    
    async def async_test_function(self, data: str = "Test"):
        """异步测试功能"""
        await asyncio.sleep(0.1)  # 模拟异步操作
        return {
            "data": f"Async mock response: {data}",
            "processed": True
        }


# 全局服务实例
mcp_service = BaseMCPService(SERVICE_NAME)

@app.get("/")
async def root():
    """服务状态检查"""
    return {
        "service": f"{SERVICE_NAME}-mcp",
        "status": "running",
        "version": mcp_service.version,
        "endpoints": [
            "/test",
            "/async-test",
            "/health",
            "/mcp/sse"
        ]
    }

@app.get("/health")
async def health_check():
    """健康检查端点"""
    return {
        "status": "healthy",
        "service": f"{SERVICE_NAME}-mcp",
        "timestamp": asyncio.get_event_loop().time()
    }

@app.get("/mcp/sse")
async def mcp_sse_stream():
    """MCP SSE流端点"""
    async def event_stream():
        try:
            # 发送初始连接确认
            yield f"data: {json.dumps({'type': 'connected', 'service': f'{SERVICE_NAME}-mcp'})}\n\n"
            
            while True:
                # 发送心跳
                heartbeat = {
                    'type': 'heartbeat', 
                    'service': f'{SERVICE_NAME}-mcp',
                    'timestamp': asyncio.get_event_loop().time()
                }
                yield f"data: {json.dumps(heartbeat)}\n\n"
                await asyncio.sleep(30)  # 30秒心跳
                
        except asyncio.CancelledError:
            logger.info(f"{SERVICE_NAME} MCP SSE连接断开")
    
    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
        }
    )

# 示例端点 - 根据实际MCP服务修改
@app.post("/test")
async def test_endpoint(payload: Dict[str, Any]):
    """测试端点"""
    message = payload.get('message', 'Hello')
    return await mcp_service.handle_request('test_function', message=message)

@app.post("/async-test")
async def async_test_endpoint(payload: Dict[str, Any]):
    """异步测试端点"""
    data = payload.get('data', 'Test')
    return await mcp_service.handle_request('async_test_function', data=data)

@app.on_event("startup")
async def startup_event():
    """启动事件"""
    logger.info(f"🚀 {SERVICE_NAME} MCP服务器启动成功")

@app.on_event("shutdown")
async def shutdown_event():
    """关闭事件"""
    logger.info(f"💤 {SERVICE_NAME} MCP服务器关闭")

if __name__ == "__main__":
    # 从环境变量获取配置
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", SERVICE_PORT))
    debug = os.getenv("DEBUG", "false").lower() == "true"
    
    uvicorn.run(
        app,
        host=host,
        port=port,
        debug=debug,
        log_level="info"
    ) 