# SWE-agent 自定义镜像和挂载卷配置指南

## 概述

本指南介绍如何在 SWE-agent 中使用自定义 Docker 镜像（包含特殊依赖项）并挂载宿主机目录（用于敏感文件等场景）。

## 核心概念

SWE-agent 支持完全自定义 Docker 容器的启动参数，包括：
- 自定义镜像
- 卷挂载（volume mounts）
- 环境变量
- 资源限制
- 网络配置
- 其他 Docker 运行时参数

## 配置方式

### 方式 1：使用 YAML 配置文件（推荐）

创建配置文件 `config/custom_image_with_volumes.yaml`：

```yaml
instances:
  deployment:
    type: docker
    image: your-registry/your-image:tag

    # 自定义 Docker 启动参数
    docker_args:
      - "-v"
      - "/host/path:/container/path"
      - "-v"
      - "/secrets:/workspace/secrets:ro"
      - "--memory=8g"
      - "--cpus=4"

  # 启动后执行的命令
  post_startup_commands:
    - "export CUSTOM_VAR=value"
    - "cd /workspace"
```

然后运行：

```bash
sweagent run \
  --problem_statement.path="path/to/issue.md" \
  --repo.path="/path/to/repo" \
  --config config/custom_image_with_volumes.yaml
```

### 方式 2：命令行参数

```bash
sweagent run \
  --problem_statement.path="path/to/issue.md" \
  --repo.path="/path/to/repo" \
  --instances.deployment.type=docker \
  --instances.deployment.image="your-registry/your-image:tag" \
  --instances.deployment.docker_args='["-v", "/host/path:/container/path"]'
```

### 方式 3：Python 代码

```python
from sweagent.environment.swe_env import EnvironmentConfig, SWEEnv
from sweagent.environment.repo import LocalRepoConfig
from swerex.deployment.config import DockerDeploymentConfig

env_config = EnvironmentConfig(
    repo=LocalRepoConfig(
        repo_name="test_bed",
        path="/path/to/local/repo",
    ),
    deployment=DockerDeploymentConfig(
        image="your-registry/your-image:tag",
        docker_args=[
            "-v", "/host/path:/container/path",
            "-v", "/secrets:/workspace/secrets:ro",
            "--memory=8g",
        ],
        python_standalone_dir="/root",
    ),
    post_startup_commands=[
        "export CUSTOM_VAR=value",
        "cd /workspace",
    ],
)

env = SWEEnv.from_config(env_config)
env.start()
```

## 完整示例

### 场景：使用自定义镜像并挂载敏感文件

假设你有一个包含特殊依赖的镜像，并且需要挂载包含密码的配置文件：

#### 1. 创建配置文件

`config/my_project.yaml`:

```yaml
instances:
  repo:
    type: local
    repo_name: test_bed
    path: ""  # 通过命令行传入

  deployment:
    type: docker
    image: my-registry/my-project-image:v1.0
    docker_args:
      # 挂载仓库代码
      - "-v"
      - "/path/to/project:/workspace/project"

      # 挂载敏感配置（只读）
      - "-v"
      - "/home/user/.secrets:/workspace/secrets:ro"

      # 挂载缓存
      - "-v"
      - "/tmp/build-cache:/workspace/cache"

      # 环境变量
      - "-e"
      - "ENVIRONMENT=development"

      # 资源限制
      - "--memory=16g"
      - "--cpus=8"

    python_standalone_dir: "/root"

  post_startup_commands:
    - "export PATH=/root/venv/bin:$PATH"
    - "export SECRETS_DIR=/workspace/secrets"
    - "cd /workspace/project"
    - "python -c 'import special_lib; print(\"Ready\")'"

agent:
  type: default
  templates:
    system_template: |-
      你是一个软件开发助手。
      工作目录：{{working_dir}}
      敏感文件位置：/workspace/secrets
      所有依赖已预装在镜像中。

  # ... 其他 agent 配置
```

#### 2. 运行

```bash
sweagent run \
  --problem_statement.path="issues/bug-123.md" \
  --repo.path="/home/user/my-project" \
  --config config/my_project.yaml
```

## 常用 Docker 参数

### 卷挂载

```yaml
docker_args:
  # 读写挂载
  - "-v"
  - "/host/path:/container/path"

  # 只读挂载（推荐用于敏感文件）
  - "-v"
  - "/host/secrets:/container/secrets:ro"
```

### 环境变量

```yaml
docker_args:
  - "-e"
  - "VAR_NAME=value"
  - "-e"
  - "ANOTHER_VAR=${HOST_VAR}"  # 使用宿主机环境变量
```

### 资源限制

```yaml
docker_args:
  - "--memory=8g"        # 内存限制
  - "--cpus=4"           # CPU 核心数
  - "--memory-swap=16g"  # 交换空间
```

### 网络配置

```yaml
docker_args:
  - "--network=host"           # 使用宿主机网络
  - "-p 8080:8080"            # 端口映射
  - "--add-host=host:192.168.1.1"  # 添加 hosts
```

### 权限和安全

```yaml
docker_args:
  - "--cap-add=SYS_PTRACE"              # 添加权限
  - "--security-opt seccomp=unconfined" # 安全配置
  - "--user=1000:1000"                  # 指定用户
```

### 工作目录

```yaml
docker_args:
  - "-w"
  - "/workspace"
```

## 仓库配置选项

### GitHub 仓库

```yaml
repo:
  type: github
  url: "https://github.com/user/repo"
  base_commit: "abc123"
  repo_name: test_bed
```

### 本地仓库

```yaml
repo:
  type: local
  path: "/path/to/local/repo"
  repo_name: test_bed
  base_commit: "HEAD"  # 或具体 commit hash
```

### 预存在仓库（已挂载）

```yaml
repo:
  type: pre_existing
  repo_name: repo  # 容器内的目录名
  reset: false     # 是否重置到 base commit
```

## 启动后命令

`post_startup_commands` 用于在容器启动后执行初始化命令：

```yaml
post_startup_commands:
  # 设置环境变量
  - "export PATH=/opt/conda/bin:$PATH"

  # 激活虚拟环境
  - "source /root/venv/bin/activate"

  # 验证依赖
  - "python -c 'import torch; print(torch.__version__)'"

  # 下载必要文件
  - "wget -O /tmp/model.bin https://example.com/model.bin"

  # 设置权限
  - "chmod +x /workspace/scripts/*.sh"
```

## 最佳实践

### 1. 敏感文件管理

```yaml
docker_args:
  # 使用只读挂载保护敏感文件
  - "-v"
  - "/path/to/.env:/workspace/.env:ro"

  # 挂载整个配置目录
  - "-v"
  - "/path/to/config:/workspace/config:ro"
```

### 2. 缓存优化

```yaml
docker_args:
  # 挂载构建缓存
  - "-v"
  - "/tmp/cache:/workspace/.cache"

  # 挂载 pip 缓存
  - "-v"
  - "/tmp/pip-cache:/root/.cache/pip"
```

### 3. 资源管理

```yaml
deployment:
  startup_timeout: 300.0  # 给镜像足够的启动时间
  pull: "missing"         # 只在本地不存在时拉取

  docker_args:
    - "--memory=16g"      # 根据需要调整
    - "--cpus=8"
    - "--shm-size=2g"     # 共享内存（用于某些框架）
```

### 4. 调试配置

```yaml
docker_args:
  # 挂载源代码（开发时使用）
  - "-v"
  - "/path/to/swe-agent:/app/swe-agent:ro"

  # 启用调试端口
  - "-p"
  - "5678:5678"

  # 保持容器运行（调试用）
  - "--entrypoint=/bin/bash"
```

## 故障排查

### 问题 1：容器无法启动

**解决方案**：
- 检查镜像是否存在：`docker images | grep your-image`
- 增加启动超时：`startup_timeout: 300.0`
- 查看容器日志：`docker logs <container-id>`

### 问题 2：挂载的目录不可访问

**解决方案**：
```yaml
docker_args:
  # 添加权限
  - "--user=root"
  # 或指定 UID/GID
  - "--user=1000:1000"
```

### 问题 3：环境变量未生效

**解决方案**：
- 在 `docker_args` 中设置：`-e VAR=value`
- 在 `post_startup_commands` 中设置：`export VAR=value`
- 在 `tools.env_variables` 中设置

### 问题 4：依赖项缺失

**解决方案**：
```yaml
post_startup_commands:
  # 验证关键依赖
  - "python -c 'import critical_lib; print(\"OK\")' || pip install critical_lib"
```

## 自动创建 Pull Request

SWE-agent 支持在修复 issue 后自动创建 PR。当你使用 `gh` CLI 配置并有适当权限时，可以完全自动化这个流程。

### 前置条件

1. **GitHub Token**
   ```bash
   # 设置环境变量（必需）
   export GITHUB_TOKEN=$(gh auth token)

   # 或使用 Personal Access Token
   export GITHUB_TOKEN=ghp_your_token_here
   ```

2. **Token 权限要求**：
   - `repo` (完整仓库访问权限)
   - `pull_requests` (创建 PR)
   - `issues` (读取 issue)

3. **仓库权限**：
   - 必须有目标仓库的写权限
   - 支持私有仓库

### 配置方法

#### 方式 1：命令行参数

```bash
sweagent run \
  --config config/custom_image_with_volumes.yaml \
  --problem_statement.github_url="https://github.com/your-org/your-repo/issues/123" \
  --env.repo.github_url="https://github.com/your-org/your-repo" \
  --actions.open_pr=true
```

#### 方式 2：配置文件

```yaml
instances:
  repo:
    type: github
    url: ""  # 或通过命令行传入
    base_commit: ""

  deployment:
    type: docker
    image: your-registry/your-image:latest
    docker_args:
      - "-v"
      - "/path/to/host/repo:/workspace/repo"

# Agent 配置
agent:
  type: default
  # ... 其他配置

# Actions 配置
actions:
  open_pr: true
  pr_config:
    # 如果已有提交引用该 issue，则跳过 PR 创建（推荐）
    skip_if_commits_reference_issue: true
```

#### 方式 3：使用 Hooks

```yaml
hooks:
  - type: open_pr
    skip_if_commits_reference_issue: true
```

### 工作流程

当 SWE-agent 成功修复 issue 后，`OpenPRHook` 会自动执行：

1. **验证条件**：
   - ✅ Agent 成功提交 (exit_status == "submitted")
   - ✅ Issue 处于 open 状态
   - ✅ Issue 未被分配
   - ✅ Issue 未被锁定
   - ✅ 没有已有关联的 commit（可选检查）

2. **创建分支**：
   ```bash
   git checkout -b swe-agent-fix-#123-abc123de
   ```

3. **提交更改**：
   ```bash
   git add .
   git commit -m "Fix: Issue title" -m "Closes #123"
   ```

4. **推送到远程**：
   ```bash
   git push origin swe-agent-fix-#123-abc123de
   ```

5. **创建 Draft PR**：
   - 标题：`SWE-agent[bot] PR to fix: {issue_title}`
   - 包含完整的修复过程（trajectory）
   - Draft 状态，需要人工审查

### 完整示例：自定义镜像 + 自动 PR

```yaml
instances:
  repo:
    type: github
    url: ""  # 通过命令行传入
    base_commit: ""

  deployment:
    type: docker
    image: your-registry/your-project-image:latest
    docker_args:
      # 挂载本地仓库（开发调试用）
      - "-v"
      - "/path/to/local/repo:/workspace/repo:ro"

      # 挂载敏感配置（只读）
      - "-v"
      - "/path/to/.env:/workspace/.env:ro"

    python_standalone_dir: "/root"
    startup_timeout: 300.0

  post_startup_commands:
    - "export PYTHONPATH=/workspace/repo:$PYTHONPATH"
    - "cd /workspace/repo"
    - "python -c 'import special_lib; print(\"Ready\")'"

agent:
  type: default
  templates:
    system_template: |-
      你是一个软件开发助手，修复 GitHub issues。
      所有依赖已预装在镜像中。

  tools:
    bundles:
      - path: tools/registry
      - path: tools/edit_anthropic
      - path: tools/review_on_submit_m

    enable_bash_tool: true
    parse_function:
      type: function_calling

  history_processors:
    - type: cache_control
      last_n_messages: 2

  model:
    name: "claude-sonnet-4-20250514"
    api_key: $CLAUDE_API_KEY
    temperature: 0.0

# Actions 配置
actions:
  open_pr: true
  pr_config:
    skip_if_commits_reference_issue: true
```

**运行命令**：

```bash
# 1. 设置 token
export GITHUB_TOKEN=$(gh auth token)

# 2. 运行
sweagent run \
  --config config/auto_pr_custom_image.yaml \
  --problem_statement.github_url="https://github.com/your-org/your-repo/issues/456" \
  --env.repo.github_url="https://github.com/your-org/your-repo"
```

### 配置选项

- **`actions.open_pr`**: 是否启用自动 PR 创建（默认：false）
- **`actions.pr_config.skip_if_commits_reference_issue`**: 如果已有提交引用该 issue，是否跳过（默认：true，推荐）

### 安全特性

- ✅ 创建 **Draft PR**，需要手动审查
- ✅ 多重安全检查，避免误操作
- ✅ 完整记录修复过程在 PR 描述中
- ✅ 支持私有仓库

### 故障排查

**问题：PR 未创建**
- 检查 `GITHUB_TOKEN` 是否设置
- 验证 token 权限：`gh auth status`
- 确认 issue 状态：`gh issue view 123`
- 查看日志中的 exit_status

**问题：推送失败**
- 验证仓库写权限：`gh repo view your-org/your-repo`
- 确认 token 有 push 权限

## 完整配置参考

参见示例配置文件：
- `config/custom_image_with_volumes.yaml` - 自定义镜像完整示例
- `config/benchmarks/250522_anthropic_filemap_simple_review.yaml` - 使用 `docker_args` 的实际案例
- `sweagent/run/run_shell.py:127-134` - Python 代码示例
- `sweagent/run/hooks/open_pr.py` - PR 创建实现代码

## 相关文档

- [Docker DeploymentConfig 文档](https://github.com/princeton-nlp/SWE-rex/blob/main/README.md)
- [SWE-agent 配置指南](../README.md)
- [Volume Mounts 最佳实践](https://docs.docker.com/storage/volumes/)
- [SWE-agent OpenPR Hook](../sweagent/run/hooks/open_pr.py) - 自动 PR 创建功能
