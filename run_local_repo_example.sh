#!/bin/bash
# 本地仓库 + 自定义镜像 + 自动 PR 运行脚本
#
# 使用前请确保：
# 1. 已安装并配置 sweagent
# 2. 已设置 GITHUB_TOKEN 环境变量
# 3. 本地仓库与 GitHub 远程仓库同步
# 4. 有适当的仓库写权限

set -e

# ============================================
# 配置区域 - 请根据你的实际情况修改
# ============================================

# GitHub Token（必需）
# 方式 1: 使用 gh CLI 获取 token（推荐）
# export GITHUB_TOKEN=$(gh auth token)

# 方式 2: 手动设置 token
# export GITHUB_TOKEN=ghp_your_token_here

# 本地仓库路径（必需）
LOCAL_REPO_PATH="/path/to/your/local/repo"

# GitHub 仓库 URL（必需）
GITHUB_REPO_URL="https://github.com/your-org/your-repo"

# GitHub Issue URL（必需）
ISSUE_URL="https://github.com/your-org/your-repo/issues/123"

# 自定义镜像名称（必需）
CUSTOM_IMAGE="your-registry/your-custom-image:latest"

# 敏感文件路径（可选）
# SECRETS_PATH="/home/user/.secrets"

# ============================================
# 检查前置条件
# ============================================

echo "🔍 检查前置条件..."

# 检查 GITHUB_TOKEN
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ 错误: GITHUB_TOKEN 环境变量未设置"
    echo "请运行: export GITHUB_TOKEN=$(gh auth token)"
    exit 1
fi
echo "✅ GITHUB_TOKEN 已设置"

# 检查本地仓库路径
if [ ! -d "$LOCAL_REPO_PATH" ]; then
    echo "❌ 错误: 本地仓库路径不存在: $LOCAL_REPO_PATH"
    exit 1
fi
echo "✅ 本地仓库路径存在: $LOCAL_REPO_PATH"

# 检查是否是 git 仓库
if [ ! -d "$LOCAL_REPO_PATH/.git" ]; then
    echo "❌ 错误: 该目录不是 git 仓库: $LOCAL_REPO_PATH"
    exit 1
fi
echo "✅ 是有效的 git 仓库"

# 检查远程仓库连接
cd "$LOCAL_REPO_PATH"
if ! git remote get-url origin &>/dev/null; then
    echo "❌ 错误: 没有 origin 远程仓库"
    exit 1
fi
echo "✅ 远程仓库配置正常"

# 检查 Docker 镜像
if ! docker images | grep -q "$CUSTOM_IMAGE"; then
    echo "⚠️  警告: Docker 镜像可能不存在: $CUSTOM_IMAGE"
    echo "请确保镜像已构建或拉取: docker pull $CUSTOM_IMAGE"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Docker 镜像存在"
fi

# 检查仓库状态
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️  警告: 本地仓库有未提交的修改"
    git status --short
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ 本地仓库干净"
fi

# ============================================
# 运行 SWE-agent
# ============================================

echo ""
echo "🚀 启动 SWE-agent..."
echo "仓库: $LOCAL_REPO_PATH"
echo "Issue: $ISSUE_URL"
echo "镜像: $CUSTOM_IMAGE"
echo ""

# 临时修改配置文件，替换路径和镜像
CONFIG_FILE="config/local_repo_auto_pr.yaml"
TEMP_CONFIG=$(mktemp)

# 复制配置文件
cp "$CONFIG_FILE" "$TEMP_CONFIG"

# 替换配置中的占位符
sed -i.bak "s|/path/to/your/local/repo|$LOCAL_REPO_PATH|g" "$TEMP_CONFIG"
sed -i.bak "s|your-registry/your-custom-image:latest|$CUSTOM_IMAGE|g" "$TEMP_CONFIG"

# 如果有敏感文件，取消注释并修改
# if [ -n "$SECRETS_PATH" ]; then
#     sed -i.bak "s|# - \"-v\"\n# - \"/home/user/.secrets:/workspace/secrets:ro\"|- \"-v\"\n  - \"$SECRETS_PATH:/workspace/secrets:ro\"|g" "$TEMP_CONFIG"
# fi

# 运行 SWE-agent
# 注意：
# - 不指定 --env.repo.github_url，避免触发 GithubRepoConfig（从远程拉取）
# - github_url 仅用于 PR 创建，通过 problem_statement.github_url 提供
# - repo 使用 preexisting 类型，通过 docker_args 挂载本地目录
sweagent run \
  --config "$TEMP_CONFIG" \
  --problem_statement.github_url="$ISSUE_URL"

# 清理临时文件
rm -f "$TEMP_CONFIG" "${TEMP_CONFIG}.bak"

echo ""
echo "✅ SWE-agent 运行完成"
echo ""
echo "后续步骤："
echo "1. 检查本地仓库的修改: cd $LOCAL_REPO_PATH && git status"
echo "2. 查看创建的 PR: gh pr list"
echo "3. 如果创建了 PR，审查后标记为 Ready for Review"
