# SWE-agent 分支配置指南

## 指定开发分支

SWE-agent 支持通过 `base_commit` 参数指定分支、标签或具体的 commit。

## base_commit 支持的值

### 1. 分支名（最常用）

```yaml
instances:
  repo:
    type: preexisting
    repo_name: test_bed
    base_commit: "dev"  # 开发分支
    reset: false
```

**支持的分支名格式**：
- `dev` - 简单分支名
- `main` - 主分支
- `feature/new-feature` - 带斜杠的分支名
- `release/v1.0` - 发布分支
- `hotfix/bug-123` - 热修复分支

### 2. 标签名

```yaml
base_commit: "v0.1.0"  # 从标签开始
```

### 3. Commit Hash

```yaml
base_commit: "a4464baca1f"  # 具体的 commit
```

### 4. HEAD（当前最新提交）

```yaml
base_commit: "HEAD"  # 默认值
```

---

## 完整示例：使用 dev 分支

### 配置文件

```yaml
# config/dev_branch.yaml
instances:
  repo:
    type: preexisting
    repo_name: test_bed
    base_commit: "dev"  # 🔑 使用 dev 分支
    reset: false  # 不重置，保持本地修改

  deployment:
    type: docker
    image: your-custom-image:latest
    docker_args:
      - "-v"
      - "/path/to/local/repo:/test_bed"
      - "-w"
      - "/test_bed"
```

### 运行命令

```bash
# 方式 1：使用配置文件
sweagent run \
  --config config/dev_branch.yaml \
  --problem_statement.github_url="https://github.com/org/repo/issues/123"

# 方式 2：通过命令行参数覆盖
sweagent run \
  --config config/local_repo_auto_pr_fixed.yaml \
  --instances.repo.base_commit="dev" \
  --problem_statement.github_url="https://github.com/org/repo/issues/123"
```

---

## reset 参数的行为

### reset: true（默认）

```yaml
repo:
  type: preexisting
  repo_name: test_bed
  base_commit: "dev"
  reset: true  # 🔑 会执行 git reset
```

**行为**：
1. `git fetch`
2. `git restore .` (恢复所有修改)
3. `git reset --hard` (硬重置)
4. `git checkout dev` (切换到 dev 分支)
5. `git clean -fdq` (删除未追踪文件)

**适合**：
- 每次都从干净的 dev 分支开始
- 不保留之前的修改

---

### reset: false（推荐用于本地开发）

```yaml
repo:
  type: preexisting
  repo_name: test_bed
  base_commit: "dev"
  reset: false  # 🔑 不重置
```

**行为**：
- **不执行任何 git 操作**
- 保持当前分支和修改
- SWE-agent 直接在现有状态上工作

**适合**：
- 本地开发，保留未提交的修改
- 在现有工作基础上继续
- 不想被重置打断

---

## 实际场景示例

### 场景 1：在 dev 分支上开发

```yaml
# config/dev_environment.yaml
instances:
  repo:
    type: preexisting
    repo_name: test_bed
    base_commit: "dev"
    reset: false  # 保留本地修改

  deployment:
    type: docker
    image: my-dev-image:latest
    docker_args:
      - "-v"
      - "/Users/dev/project:/test_bed"

actions:
  open_pr: true  # 修复后创建 PR 到 dev 分支
```

**运行**：
```bash
# 1. 切换到 dev 分支
git checkout dev

# 2. 运行 SWE-agent
sweagent run \
  --config config/dev_environment.yaml \
  --problem_statement.github_url="https://github.com/org/repo/issues/123"
```

**结果**：
- SWE-agent 在 dev 分支上工作
- 修改直接保存到本地 dev 分支
- 创建 PR 时，目标分支通常是 main（可配置）

---

### 场景 2：从 feature 分支创建 PR

```yaml
instances:
  repo:
    type: preexisting
    repo_name: test_bed
    base_commit: "feature/new-api"
    reset: false

  deployment:
    type: docker
    image: my-dev-image:latest
    docker_args:
      - "-v"
      - "/Users/dev/project:/test_bed"

actions:
  open_pr: true
```

**运行**：
```bash
# 1. 切换到 feature 分支
git checkout feature/new-api

# 2. 运行
sweagent run \
  --config config/feature_branch.yaml \
  --instances.repo.base_commit="feature/new-api" \
  --problem_statement.github_url="https://github.com/org/repo/issues/123"
```

---

### 场景 3：从特定 commit 开始

```yaml
instances:
  repo:
    type: preexisting
    repo_name: test_bed
    base_commit: "a4464baca1f"  # 具体commit
    reset: true  # 清理到这个commit

  deployment:
    type: docker
    image: python:3.11
    docker_args:
      - "-v"
      - "/path/to/repo:/test_bed"
```

---

## 命令行覆盖配置

你可以通过命令行参数覆盖配置文件中的 `base_commit`：

```bash
# 配置文件中 base_commit: "dev"
sweagent run \
  --config config/dev_branch.yaml \
  --instances.repo.base_commit="feature/xxx" \  # 🔑 覆盖为 feature/xxx
  --problem_statement.github_url="https://github.com/org/repo/issues/123"
```

---

## PR 创建时的分支处理

当使用 `actions.open_pr: true` 时，SWE-agent 会：

1. **在当前分支**（如 `dev`）上进行修改
2. **创建新分支**：`swe-agent-fix-#123-random`
3. **从 dev 分支**创建 commit
4. **推送到远程**
5. **创建 PR**：
   - base（目标分支）：通常是 main（可通过 GitHub API 获取）
   - head（源分支）：`swe-agent-fix-#123-random`

### 示例流程

```bash
# 本地状态
git branch  # 当前在 dev 分支

# SWE-agent 执行
1. 在 dev 分支上修改文件
2. git checkout -b swe-agent-fix-#123-abc123
3. git add .
4. git commit -m "Fix: issue title"
5. git push origin swe-agent-fix-#123-abc123
6. 创建 PR: swe-agent-fix-#123-abc123 -> main
```

---

## 最佳实践

### 1. 本地开发使用 reset: false

```yaml
repo:
  type: preexisting
  base_commit: "dev"
  reset: false  # 保留你的工作
```

**原因**：
- 不会丢失未提交的修改
- 不会切换分支
- 在现有状态上继续工作

### 2. 测试/CI 使用 reset: true

```yaml
repo:
  type: github
  url: "https://github.com/org/repo"
  base_commit: "dev"
  # reset: true 是默认值
```

**原因**：
- 每次从干净状态开始
- 可重复测试
- 不受之前运行影响

### 3. 明确指定分支名

```yaml
# ✅ 好
base_commit: "dev"

# ⚠️ 可能有问题
base_commit: "HEAD"  # 取决于当前所在分支
```

---

## 常见问题

### Q1: 如果本地不在 dev 分支会怎样？

**A**: 如果 `reset: false`，SWE-agent 会在当前分支上工作，不会切换。如果 `reset: true`，会先 `git checkout dev`。

### Q2: 如何在 PR 时指定目标分支？

**A**: 目前 SWE-agent 会通过 GitHub API 获取仓库的默认分支作为目标。如需自定义，需要修改 `sweagent/run/hooks/open_pr.py`。

### Q3: 分支名中有特殊字符怎么办？

**A**: 使用引号包裹：
```yaml
base_commit: "feature/new-api-v2"
base_commit: "release/v1.0.0"
```

### Q4: 如果 dev 分支不存在会怎样？

**A**: SWE-agent 会在执行 git 操作时报错。确保分支存在：
```bash
git branch -a | grep dev
```

---

## 总结

| 场景 | base_commit | reset | 用途 |
|------|-------------|-------|------|
| 本地开发 | `"dev"` | `false` | 在现有基础上工作 |
| 清理测试 | `"dev"` | `true` | 每次从干净状态开始 |
| 特定版本 | `"v0.1.0"` | `true` | 从特定标签开始 |
| Bug 修复 | `commit_hash` | `true` | 回到具体 commit |

记住：对于本地开发场景，推荐使用 **`base_commit: "dev"` + `reset: false`**！
