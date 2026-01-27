# SWE-agent 优化配置指南

本指南解决了三个常见问题：
1. 减少过度检查和验证步骤
2. 自动清理 Docker 容器
3. 自动提交 PR 到 GitHub

## 问题 1：减少过度检查和验证

### 症状
- 模型完成修复后不断检查文件
- 反复执行相同的测试
- 步骤数明显多于正常流程

### 解决方案

#### 方案 A：使用优化配置文件（推荐）

我已经创建了 `config/optimized_glms.yaml`，包含以下优化：

```bash
sweagent run --config config/optimized_glms.yaml \
  --problem_statement.path="path/to/issue.md" \
  --repo_path="path/to/repo"
```

#### 方案 B：在命令行中指定参数

```bash
sweagent run \
  --agent.model.per_instance_call_limit=50 \
  --agent.history_processors=[{"type":"last_n_observations","n":10}] \
  --agent.retry_loop.max_attempts=2 \
  --problem_statement.path="path/to/issue.md" \
  --repo_path="path/to/repo"
```

#### 关键配置项说明

1. **限制 API 调用次数**
   ```yaml
   agent:
     model:
       per_instance_call_limit: 50  # 默认无限制
   ```

2. **简化提交审查流程**
   ```yaml
   tools:
     # 移除 tools/review_on_submit_m 以减少额外检查
     bundles:
       - path: tools/registry
       - path: tools/edit_anthropic
       # - path: tools/review_on_submit_m  # 注释掉这个
   ```

3. **优化提示词**
   ```yaml
   templates:
     system_template: |-
       IMPORTANT WORKFLOW GUIDELINES:
       1. Be efficient and direct
       2. Only run necessary tests
       3. Submit when confident - don't second-guess
   ```

4. **限制历史长度**
   ```yaml
   history_processors:
     - type: last_n_observations
       n: 10  # 只保留最近 10 个观察
   ```

5. **减少重试次数**
   ```yaml
   retry_loop:
     max_attempts: 2  # 默认是 3 次
   ```

## 问题 2：自动清理 Docker 容器

### 症状
任务完成后留下 Docker 容器

### 解决方案

#### 方案 A：自动清理（推荐）

在配置文件中添加：

```yaml
env:
  auto_remove: true  # 容器停止后自动删除
```

#### 方案 B：手动清理

```bash
# 查看所有容器
docker ps -a

# 删除特定容器
docker rm <container_id>

# 删除所有停止的容器
docker container prune

# 删除 SWE-agent 相关的所有容器
docker ps -a | grep swe | awk '{print $1}' | xargs docker rm
```

#### 方案 C：使用环境钩子

创建一个 Python 脚本 `cleanup_hooks.py`：

```python
from sweagent.environment.hooks.abstract import EnvHook
from sweagent.utils.log import get_logger

class CleanupHook(EnvHook):
    def __init__(self):
        self.logger = get_logger("cleanup", emoji="🧹")

    def on_close(self):
        """在环境关闭时清理容器"""
        self.logger.info("Cleaning up Docker containers...")
        import subprocess
        try:
            # 删除所有停止的 swe-* 容器
            subprocess.run(
                ["docker", "container", "prune", "-f"],
                check=True,
                capture_output=True
            )
            self.logger.info("Docker containers cleaned up successfully")
        except Exception as e:
            self.logger.warning(f"Failed to cleanup containers: {e}")
```

然后在配置中使用：

```yaml
env:
  hooks:
    - type: cleanup_hooks.CleanupHook
```

## 问题 3：自动提交 PR 到 GitHub

### 前提条件

1. 设置 GitHub Token：
   ```bash
   export GITHUB_TOKEN=your_github_token
   ```

2. 确保问题来自 GitHub URL（例如：`https://github.com/owner/repo/issues/123`）

### 解决方案

#### 方案 A：使用 OpenPR Hook（推荐）

在配置文件中添加：

```yaml
hooks:
  - type: open_pr
    skip_if_commits_reference_issue: true
```

完整示例：

```yaml
# config/auto_pr.yaml
agent:
  model:
    model_name: "zai/glm-4.7"
  templates:
    system_template: "You are a helpful assistant..."
    # ... 其他配置

hooks:
  - type: open_pr
    skip_if_commits_reference_issue: true
```

运行：

```bash
sweagent run --config config/auto_pr.yaml \
  --problem_statement.path="path/to/github_issue.md" \
  --repo_path="path/to/repo"
```

#### 方案 B：命令行参数

```bash
sweagent run \
  --hooks.open_pr=true \
  --hooks.open_pr.skip_if_commits_reference_issue=true \
  --problem_statement.path="path/to/github_issue.md" \
  --repo_path="path/to/repo"
```

#### OpenPR Hook 的行为

1. **检查条件**：
   - ✅ 任务成功完成（exit_status = "submitted"）
   - ✅ 有有效的提交
   - ✅ Issue 仍然是 open 状态
   - ✅ Issue 没有被分配
   - ✅ Issue 没有被锁定
   - ✅ 没有其他提交关联到这个 Issue

2. **创建 PR**：
   - 创建新分支：`swe-agent-fix-#123-random`
   - 提交更改
   - 推送到远程
   - 创建 **Draft PR**（需要你手动审查后点击 "Ready for Review"）

3. **PR 内容**：
   - 标题：`SWE-agent[bot] PR to fix: <issue title>`
   - 包含完整的思考过程（trajectory）
   - 关联到原 Issue

#### 方案 C：只应用补丁（不提交 PR）

如果你只想应用补丁到本地，不想提交 PR：

```yaml
hooks:
  - type: apply_patch
    repo_type: github
```

这会：
- 生成 `.patch` 文件
- 应用补丁到本地仓库
- 但不会推送到 GitHub

## 完整使用示例

### 1. 基本使用（优化配置）

```bash
# 设置环境变量
export GITHUB_TOKEN=your_token
export ZHIPUAI_API_KEY=your_api_key

# 运行 SWE-agent
sweagent run \
  --config config/optimized_glms.yaml \
  --problem_statement.path="issues/issue_123.md" \
  --repo_path="repos/target_repo"
```

### 2. 批量运行（Benchmarking）

```bash
sweagent run-batch \
  --config config/optimized_glms.yaml \
  --instances.instances_path="data/swe_bench_like.jsonl" \
  --output_dir="results/optimized_run"
```

### 3. 调试模式（保留容器）

```bash
# 修改配置文件
env:
  auto_remove: false  # 保留容器用于调试

# 运行
sweagent run --config config/debug.yaml ...

# 完成后手动进入容器检查
docker exec -it <container_id> /bin/bash

# 调试完成后清理
docker rm -f <container_id>
```

## 常见问题

### Q1: 如何平衡速度和质量？

**A**: 使用以下配置平衡：
```yaml
agent:
  model:
    per_instance_call_limit: 50  # 限制调用次数
  retry_loop:
    max_attempts: 2  # 减少1次重试
  history_processors:
    - type: last_n_observations
      n: 15  # 保留足够的历史但不过多
```

### Q2: PR 被创建了但我想修改怎么办？

**A**:
1. PR 是以 Draft 形式创建的
2. 在 GitHub 上找到 PR
3. 手动推送额外的更改到 PR 分支
4. 点击 "Ready for Review" 当你满意时

### Q3: 容器清理失败怎么办？

**A**:
```bash
# 强制删除所有 swe-agent 容器
docker ps -a | grep swe-agent | awk '{print $1}' | xargs -r docker rm -f

# 或者使用 Docker 的自动清理
docker system prune -a
```

### Q4: 如何跳过某些检查但保留其他检查？

**A**: 自定义 SUBMIT_REVIEW_MESSAGES：
```yaml
tools:
  registry_variables:
    SUBMIT_REVIEW_MESSAGES:
      - |
        Quick review: Does this fix address the issue?
        <diff>{{diff}}</diff>
```

## 监控和调试

### 查看日志

```bash
# 实时查看日志
tail -f trajectories/latest/traj.log

# 查看完整轨迹
sweagent inspect trajectories/latest/latest.traj
```

### 统计信息

```bash
# 快速统计
sweagent quick-stats trajectories/

# 查看成本和步骤数
python3 << EOF
import json
with open('trajectories/latest/latest.traj') as f:
    data = json.load(f)
    print(f"Total steps: {len(data['trajectory'])}")
    print(f"Exit status: {data['info']['exit_status']}")
    print(f"API calls: {data['info']['model_stats']['api_calls']}")
EOF
```

## 总结

| 问题 | 解决方案 | 配置项 |
|-----|---------|--------|
| 过度检查 | 限制调用次数 + 简化流程 | `per_instance_call_limit`, `max_attempts` |
| 容器残留 | 自动清理 | `env.auto_remove: true` |
| 手动提交 PR | 使用 Hook | `hooks: [{type: open_pr}]` |

使用 `config/optimized_glms.yaml` 可以一次性解决所有问题！
