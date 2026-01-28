#!/bin/bash
#
# SWE-agent 运行脚本 - Shadow Code Agent 开发环境
#
# 功能：
# 1. 使用自定义 Docker 镜像 shadow-code-agent:dev
# 2. 在本地 dev 分支上进行修改
# 3. 修复 GitHub issue 后自动创建 PR
#
# 使用方法：
#   ./run_shadow_agent.sh [issue_number]
#
# 示例：
#   ./run_shadow_agent.sh 1

set -e

# 配置变量
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$CONFIG_DIR/config/shadow_code_agent_dev.yaml"
LOCAL_REPO="/Users/cuiwenbo/repo/github-issue-agent"
GITHUB_REPO_URL="https://github.com/jairuigou/shadow-code-agent"
ISSUE_NUMBER="${1:-1}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."

    # 检查 sweagent 命令
    if ! command -v sweagent &> /dev/null; then
        print_error "sweagent 命令未找到"
        print_info "请确保 SWE-agent 已安装：pip3.11 install -e ."
        exit 1
    fi

    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    # 检查 Docker 镜像
    if ! docker images shadow-code-agent:dev --format "{{.Repository}}:{{.Tag}}" | grep -q "shadow-code-agent:dev"; then
        print_warning "Docker 镜像 shadow-code-agent:dev 不存在"
        print_info "请先构建镜像：docker build -t shadow-code-agent:dev ."
        exit 1
    fi

    # 检查本地仓库
    if [ ! -d "$LOCAL_REPO/.git" ]; then
        print_error "本地仓库不存在：$LOCAL_REPO"
        exit 1
    fi

    # 检查 GitHub CLI（用于 PR 创建）
    if ! command -v gh &> /dev/null; then
        print_warning "GitHub CLI 未安装，PR 创建可能失败"
        print_info "安装 GitHub CLI：brew install gh"
    fi

    # 检查 GITHUB_TOKEN
    if [ -z "$GITHUB_TOKEN" ]; then
        print_warning "GITHUB_TOKEN 未设置"
        if command -v gh &> /dev/null; then
            print_info "尝试使用 GitHub CLI 获取 token..."
            export GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
            if [ -z "$GITHUB_TOKEN" ]; then
                print_error "无法获取 GitHub token，请先登录：gh auth login"
                exit 1
            fi
        else
            print_error "请设置 GITHUB_TOKEN 环境变量"
            exit 1
        fi
    fi

    # 检查配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "配置文件不存在：$CONFIG_FILE"
        exit 1
    fi

    print_info "依赖检查完成"
}

# 检查并切换到 dev 分支
prepare_repo() {
    print_info "准备本地仓库..."

    cd "$LOCAL_REPO"

    # 检查当前分支
    CURRENT_BRANCH=$(git branch --show-current)
    print_info "当前分支：$CURRENT_BRANCH"

    # 如果不在 dev 分支，询问是否切换
    if [ "$CURRENT_BRANCH" != "dev" ]; then
        print_warning "当前不在 dev 分支"
        read -p "是否切换到 dev 分支？(y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout dev || git checkout -b dev
            print_info "已切换到 dev 分支"
        else
            print_warning "继续在 $CURRENT_BRANCH 分支上工作"
        fi
    fi

    # 拉取最新代码
    print_info "拉取最新代码..."
    git fetch origin || print_warning "无法拉取远程代码，继续使用本地代码"

    print_info "仓库准备完成"
}

# 获取 Issue 信息
get_issue_info() {
    print_info "获取 Issue #$ISSUE_NUMBER 信息..."

    ISSUE_URL="$GITHUB_REPO_URL/issues/$ISSUE_NUMBER"
    print_info "Issue URL: $ISSUE_URL"

    # 使用 gh CLI 获取 issue 标题（如果可用）
    if command -v gh &> /dev/null; then
        ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --repo "$GITHUB_REPO_URL" --json title -q .title 2>/dev/null || echo "")
        if [ -n "$ISSUE_TITLE" ]; then
            print_info "Issue 标题：$ISSUE_TITLE"
        fi
    fi
}

# 运行 SWE-agent
run_swe_agent() {
    print_info "开始运行 SWE-agent..."
    print_info "配置文件：$CONFIG_FILE"
    print_info "Issue URL: $ISSUE_URL"

    echo ""
    echo "=========================================="
    echo " SWE-agent 运行配置"
    echo "=========================================="
    echo "镜像：shadow-code-agent:dev"
    echo "本地仓库：$LOCAL_REPO"
    echo "Issue：$ISSUE_URL"
    echo "配置文件：$CONFIG_FILE"
    echo "=========================================="
    echo ""

    # 检查是否需要运行（dry-run 模式）
    if [ "$1" == "--dry-run" ]; then
        print_info "Dry-run 模式，跳过实际执行"
        print_info "执行命令："
        echo "sweagent run \\"
        echo "  --config \"$CONFIG_FILE\" \\"
        echo "  --agent.model.name=\"claude-sonnet-4-20250514\" \\"
        echo "  --env.repo.path=\"$LOCAL_REPO\" \\"
        echo "  --problem_statement.github_url=\"$ISSUE_URL\""
        return
    fi

    # 运行 SWE-agent
    cd "$CONFIG_DIR"

    sweagent run \
        --config "$CONFIG_FILE" \
        --env.repo.path="$LOCAL_REPO" \
        --agent.model.name=zai/GLM-4.7 \
        --agent.model.per_instance_cost_limit=2.00 \
        --agent.model.per_instance_cost_limit=0 \
        --agent.model.total_cost_limit=0 \
        --problem_statement.github_url="$ISSUE_URL"
}

# 清理函数
cleanup() {
    print_info "清理中..."
    # 可以添加清理逻辑
}

# 主函数
main() {
    print_info "Shadow Code Agent - SWE-agent 运行脚本"
    print_info "Issue #$ISSUE_NUMBER"
    echo ""

    # 检查 dry-run 模式
    if [ "$1" == "--dry-run" ]; then
        check_dependencies
        prepare_repo
        get_issue_info
        run_swe_agent --dry-run
        print_info "Dry-run 完成"
        exit 0
    fi

    # 设置清理陷阱
    trap cleanup EXIT

    # 执行流程
    check_dependencies
    prepare_repo
    get_issue_info
    run_swe_agent

    print_info "SWE-agent 执行完成"
    print_info "请检查本地仓库的更改"
}

# 显示帮助信息
show_help() {
    cat << EOF
SWE-agent 运行脚本 - Shadow Code Agent 开发环境

使用方法：
    $0 [options] [issue_number]

参数：
    issue_number    GitHub issue 编号（默认：1）

选项：
    --dry-run       仅显示将要执行的命令，不实际运行
    -h, --help      显示此帮助信息

环境变量：
    GITHUB_TOKEN    GitHub token（用于创建 PR）
                    可通过 'gh auth token' 获取

示例：
    # 运行 Issue #1
    $0 1

    # 运行 Issue #2
    $0 2

    # Dry-run 模式
    $0 --dry-run 1

配置文件：
    $CONFIG_FILE

本地仓库：
    $LOCAL_REPO

EOF
}

# 处理命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            ISSUE_NUMBER="$1"
            shift
            ;;
    esac
done

# 运行主函数
main "$@"
