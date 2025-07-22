#!/bin/bash
set -e

echo "🚀 DyberPet MCP多服务器部署脚本 v2.0"
echo "========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 配置
DEFAULT_SERVICES="xiaohongshu-mcp api-gateway"
AVAILABLE_SERVICES=(
    "xiaohongshu-mcp:小红书MCP服务"
    "template-mcp:模板MCP服务(开发)"
    "api-gateway:API网关"
    "redis-cache:Redis缓存"
    "prometheus:监控服务"
)

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  deploy      - 部署服务 (默认)"
    echo "  start       - 启动服务"
    echo "  stop        - 停止服务"
    echo "  restart     - 重启服务"
    echo "  logs        - 查看日志"
    echo "  status      - 查看状态"
    echo "  ps          - 查看容器"
    echo "  clean       - 清理数据"
    echo "  list        - 列出可用服务"
    echo "  add-service - 添加新MCP服务"
    echo ""
    echo "选项:"
    echo "  --services \"service1 service2\"  - 指定启动的服务"
    echo "  --profile profile_name         - 使用指定profile"
    echo "  --dev                         - 开发模式 (包含template-mcp)"
    echo "  --full                        - 完整模式 (所有服务)"
    echo "  --no-cache                    - 不使用缓存构建"
    echo ""
    echo "可用服务:"
    for service in "${AVAILABLE_SERVICES[@]}"; do
        name=$(echo $service | cut -d: -f1)
        desc=$(echo $service | cut -d: -f2)
        echo "  - $name: $desc"
    done
    echo ""
    echo "示例:"
    echo "  $0                            # 部署默认服务"
    echo "  $0 --dev                      # 开发模式部署"
    echo "  $0 --full                     # 完整部署"
    echo "  $0 start --services \"xiaohongshu-mcp\"  # 只启动小红书服务"
    echo "  $0 logs xiaohongshu-mcp       # 查看小红书服务日志"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! docker compose version &> /dev/null; then
        missing_deps+=("docker compose")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖后重试"
        exit 1
    fi
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker守护进程未运行，请启动Docker"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 创建必要目录
create_directories() {
    log_info "创建项目目录结构..."
    
    local dirs=(
        "data/xiaohongshu"
        "data/template"
        "logs/xiaohongshu"
        "logs/template"
        "logs/nginx"
        "nginx/ssl"
        "monitoring"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_debug "创建目录: $dir"
        fi
    done
    
    log_success "目录结构创建完成"
}

# 生成SSL证书
generate_ssl_cert() {
    log_info "检查SSL证书..."
    
    if [ ! -f "nginx/ssl/cert.pem" ] || [ ! -f "nginx/ssl/key.pem" ]; then
        log_info "生成自签名SSL证书..."
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout nginx/ssl/key.pem \
            -out nginx/ssl/cert.pem \
            -subj "/C=CN/ST=Beijing/L=Beijing/O=DyberPet/CN=localhost" \
            2>/dev/null
        
        log_success "SSL证书生成完成"
    else
        log_info "SSL证书已存在，跳过生成"
    fi
}

# 设置环境变量
setup_environment() {
    log_info "配置环境变量..."
    
    if [ ! -f ".env" ]; then
        log_info "创建环境变量文件..."
        cat > .env << EOF
# MCP服务器配置
MCP_AUTH_TOKEN=$(openssl rand -hex 32)

# 小红书MCP
XIAOHONGSHU_ENABLED=true
XIAOHONGSHU_MCP_TOKEN=$(openssl rand -hex 16)

# 模板MCP (开发用)
TEMPLATE_ENABLED=false
TEMPLATE_MCP_TOKEN=$(openssl rand -hex 16)

# 数据库配置
REDIS_PASSWORD=$(openssl rand -hex 16)

# 网关配置
GATEWAY_DOMAIN=localhost
GATEWAY_DEBUG=false

# 调试模式
DEBUG=false
LOG_LEVEL=info

# 监控配置
MONITORING_ENABLED=false
PROMETHEUS_RETENTION=15d
EOF
        log_success "环境变量文件创建完成"
    else
        log_info "环境变量文件已存在"
    fi
}

# 选择要部署的服务
select_services() {
    local profile=""
    local services=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --services)
                services="$2"
                shift 2
                ;;
            --profile)
                profile="$2"
                shift 2
                ;;
            --dev)
                profile="dev"
                shift
                ;;
            --full)
                profile="dev,cache,monitoring"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 如果指定了服务，直接使用
    if [ -n "$services" ]; then
        echo "$services"
        return
    fi
    
    # 根据profile选择服务
    case "$profile" in
        "dev")
            echo "xiaohongshu-mcp template-mcp api-gateway"
            ;;
        "cache")
            echo "$DEFAULT_SERVICES redis-cache"
            ;;
        "monitoring")
            echo "$DEFAULT_SERVICES prometheus"
            ;;
        "dev,cache,monitoring"|"full")
            echo "xiaohongshu-mcp template-mcp api-gateway redis-cache prometheus"
            ;;
        *)
            echo "$DEFAULT_SERVICES"
            ;;
    esac
}

# 构建和启动服务
deploy_services() {
    local services=$(select_services "$@")
    local no_cache_flag=""
    local profiles=""
    
    # 检查是否使用缓存
    for arg in "$@"; do
        if [ "$arg" = "--no-cache" ]; then
            no_cache_flag="--no-cache"
            break
        fi
    done
    
    # 构建profile参数
    if [[ "$services" == *"template-mcp"* ]]; then
        profiles="$profiles --profile dev"
    fi
    if [[ "$services" == *"redis-cache"* ]]; then
        profiles="$profiles --profile cache"
    fi
    if [[ "$services" == *"prometheus"* ]]; then
        profiles="$profiles --profile monitoring"
    fi
    
    log_info "部署服务: $services"
    log_debug "Profile参数: $profiles"
    
    # 停止现有服务
    log_info "停止现有服务..."
    docker compose $profiles down --remove-orphans 2>/dev/null || true
    
    # 构建镜像
    log_info "构建服务镜像..."
    if [ -n "$no_cache_flag" ]; then
        docker compose $profiles build --no-cache
    else
        docker compose $profiles build
    fi
    
    # 启动服务
    log_info "启动服务..."
    docker compose $profiles up -d $services
    
    log_success "服务部署完成"
}

# 等待服务就绪
wait_for_services() {
    local services="$1"
    local max_attempts=60
    local attempt=0
    
    log_info "等待服务就绪..."
    
    # 定义健康检查端点
    declare -A health_endpoints=(
        ["xiaohongshu-mcp"]="http://localhost:8001/health"
        ["template-mcp"]="http://localhost:8002/health"
        ["api-gateway"]="http://localhost:80/health"
    )
    
    for service in $services; do
        if [[ -n "${health_endpoints[$service]}" ]]; then
            local endpoint="${health_endpoints[$service]}"
            local service_ready=false
            local service_attempt=0
            
            log_info "检查 $service 服务状态..."
            
            while [ $service_attempt -lt $max_attempts ] && [ "$service_ready" = false ]; do
                if curl -s --max-time 3 "$endpoint" > /dev/null 2>&1; then
                    log_success "$service 服务已就绪"
                    service_ready=true
                else
                    echo -n "."
                    sleep 2
                    service_attempt=$((service_attempt + 1))
                fi
            done
            
            if [ "$service_ready" = false ]; then
                log_warning "$service 服务启动超时，请检查日志"
            fi
        fi
    done
    
    echo ""
}

# 显示部署信息
show_deployment_info() {
    local services="$1"
    
    echo ""
    echo "🎉 部署完成！"
    echo "========================================="
    echo ""
    echo "🌐 服务访问地址:"
    
    if [[ "$services" == *"api-gateway"* ]]; then
        echo "  📡 API网关:"
        echo "    - HTTP:  http://localhost:80"
        echo "    - HTTPS: https://localhost:443"
        echo "    - 开发:  http://localhost:8080"
    fi
    
    if [[ "$services" == *"xiaohongshu-mcp"* ]]; then
        echo "  📚 小红书MCP:"
        echo "    - 直接访问: http://localhost:8001"
        echo "    - 网关路由: http://localhost/api/xiaohongshu/"
    fi
    
    if [[ "$services" == *"template-mcp"* ]]; then
        echo "  🔧 模板MCP (开发):"
        echo "    - 直接访问: http://localhost:8002"
        echo "    - 网关路由: http://localhost/api/template/"
    fi
    
    if [[ "$services" == *"redis-cache"* ]]; then
        echo "  🗄️ Redis缓存: localhost:6379"
    fi
    
    if [[ "$services" == *"prometheus"* ]]; then
        echo "  📊 Prometheus监控: http://localhost:9090"
    fi
    
    echo ""
    echo "📊 管理命令:"
    echo "  - 查看状态: ./deploy.sh status"
    echo "  - 查看日志: ./deploy.sh logs [service]"
    echo "  - 重启服务: ./deploy.sh restart"
    echo "  - 停止服务: ./deploy.sh stop"
    echo ""
    echo "🔒 认证信息:"
    if [ -f ".env" ]; then
        echo "  $(grep MCP_AUTH_TOKEN .env | head -1)"
    fi
    echo ""
    echo "📝 配置文件:"
    echo "  - 环境变量: .env"
    echo "  - Docker配置: docker-compose.yml"
    echo "  - Nginx配置: nginx/nginx.conf"
    echo ""
}

# 添加新MCP服务向导
add_new_service() {
    local service_name
    local service_port
    
    echo "🔧 添加新MCP服务向导"
    echo "===================="
    
    read -p "请输入服务名称 (如: weibo, douyin): " service_name
    if [ -z "$service_name" ]; then
        log_error "服务名称不能为空"
        exit 1
    fi
    
    read -p "请输入服务端口 (推荐8003+): " service_port
    if [ -z "$service_port" ]; then
        service_port=$((8002 + $(ls mcp-servers/ | wc -l)))
    fi
    
    local service_dir="mcp-servers/$service_name"
    
    if [ -d "$service_dir" ]; then
        log_error "服务目录已存在: $service_dir"
        exit 1
    fi
    
    log_info "创建服务目录: $service_dir"
    mkdir -p "$service_dir"
    
    # 复制模板文件
    log_info "从模板创建服务文件..."
    cp mcp-servers/template/* "$service_dir/"
    
    # 替换模板中的占位符
    sed -i.bak "s/template/$service_name/g" "$service_dir/server.py"
    sed -i.bak "s/8002/$service_port/g" "$service_dir/server.py"
    sed -i.bak "s/8002/$service_port/g" "$service_dir/Dockerfile"
    rm "$service_dir"/*.bak
    
    log_success "新MCP服务创建完成: $service_name"
    log_info "请编辑以下文件来实现你的服务:"
    echo "  - $service_dir/server.py"
    echo "  - $service_dir/requirements.txt"
    echo "  - docker-compose.yml (添加服务配置)"
    echo ""
    log_info "然后运行: ./deploy.sh deploy --services \"$service_name-mcp\""
}

# 列出可用服务
list_services() {
    echo "📋 可用MCP服务:"
    echo "==============="
    
    for service_dir in mcp-servers/*/; do
        if [ -d "$service_dir" ]; then
            local name=$(basename "$service_dir")
            local status="❌ 未运行"
            
            # 检查服务是否运行
            if docker compose ps "$name-mcp" 2>/dev/null | grep -q "Up"; then
                status="✅ 运行中"
            fi
            
            echo "  - $name ($status)"
        fi
    done
    
    echo ""
    echo "📊 Docker Compose状态:"
    docker compose ps
}

# 主函数
main() {
    echo "开始部署 DyberPet MCP多服务器系统..."
    
    check_dependencies
    create_directories
    generate_ssl_cert
    setup_environment
    deploy_services "$@"
    
    local services=$(select_services "$@")
    wait_for_services "$services"
    show_deployment_info "$services"
    
    log_success "多服务器部署完成！🎉"
}

# 参数处理
case "${1:-}" in
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    "deploy"|"")
        shift
        main "$@"
        ;;
    "start")
        shift
        log_info "启动服务..."
        services=$(select_services "$@")
        docker compose up -d $services
        log_success "服务已启动"
        ;;
    "stop")
        log_info "停止所有服务..."
        docker compose --profile dev --profile cache --profile monitoring down
        log_success "服务已停止"
        ;;
    "restart")
        shift
        log_info "重启服务..."
        services=$(select_services "$@")
        docker compose restart $services
        log_success "服务已重启"
        ;;
    "logs")
        shift
        service_name="${1:-}"
        if [ -n "$service_name" ]; then
            docker compose logs -f "$service_name"
        else
            docker compose logs -f
        fi
        ;;
    "status")
        echo "📊 服务状态:"
        docker compose ps
        echo ""
        echo "📈 系统资源:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        ;;
    "ps")
        docker compose ps
        ;;
    "clean")
        log_warning "清理所有数据 (不可恢复)..."
        read -p "确认继续? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            docker compose --profile dev --profile cache --profile monitoring down -v --remove-orphans
            docker system prune -f
            rm -rf data/* logs/* nginx/ssl/*
            log_success "清理完成"
        else
            log_info "取消清理"
        fi
        ;;
    "list")
        list_services
        ;;
    "add-service")
        add_new_service
        ;;
    *)
        log_error "未知命令: $1"
        echo ""
        show_help
        exit 1
        ;;
esac 