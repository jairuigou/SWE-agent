# SWE-agent 仓库配置完全指南

## 核心概念

SWE-agent 有三种仓库配置类型，理解它们的区别至关重要：

### 1. `github` - 从 GitHub 克隆

```yaml
repo:
  type: github
  url: "https://github.com/user/repo"
  base_commit: "abc123"
```

**行为**：
- ✅ 使用 `git clone --depth 1` 从 GitHub 拉取代码
- ✅ 只拉取指定的 commit
- ✅ 适合处理公开或私有仓库的 issues
- ❌ **不会使用本地文件**
- ❌ **不会修改本地仓库**

**使用场景**：
- 处理 GitHub issues
- 不需要保留修改在本地
- 标准的 SWE-bench 评测

---

### 2. `local` - 上传本地仓库到容器

```yaml
repo:
  type: local
  path: "/path/to/local/repo"
  base_commit: "HEAD"
```

**行为**：
- ✅ 使用 SWE-ReX 的 `upload()` 功能上传本地文件
- ✅ 文件被复制到容器内的 `/test_bed` 目录
- ✅ 容器内的修改**不会**影响本地文件（隔离的）
- ✅ 可以使用 `--actions.apply_patch_locally=true` 将修改应用回本地

**使用场景**：
- 本地有仓库，但不需要实时修改
- 想在隔离环境中测试
- 可以选择性应用修改

**工作流程**：
```
本地文件 → [upload] → 容器 /test_bed → Agent 修改 → patch → [应用] → 本地
```

---

### 3. `preexisting` - 使用已存在的仓库（重要！）

```yaml
repo:
  type: preexisting
  repo_name: "test_bed"  # 容器内的目录名
  base_commit: "HEAD"
  reset: false  # 是否重置到 base_commit
```

**行为**：
- ✅ **假设仓库已经存在**（通过 volume mount 或其他方式）
- ✅ **不会克隆、不会上传**
- ✅ 直接使用容器内的目录
- ✅ 容器修改**直接反映**到挂载的本地文件系统
- ✅ 适合与 Docker volume mount 配合使用

**使用场景**：
- **使用 Docker volume mount 挂载本地仓库**
- 需要实时修改本地文件
- 使用自定义开发镜像
- 敏感文件通过只读 volume 挂载

**工作流程**：
```
本地仓库 → [docker volume mount] → 容器 /test_bed → Agent 修改 → 直接保存到本地
```

---

## 关键区别对比表

| 特性 | `github` | `local` | `preexisting` |
|------|----------|---------|---------------|
| **数据来源** | GitHub 远程仓库 | 本地上传 | Docker volume |
| **copy() 方法** | `git clone` | `upload()` | `pass` (无操作) |
| **容器修改是否影响本地** | ❌ 否 | ❌ 否 | ✅ **是** |
| **需要 Docker volume** | ❌ 否 | ❌ 否 | ✅ **是** |
| **适合场景** | GitHub issues | 隔离测试 | **本地开发** |

---

## 配置优先级

### 命令行参数 > 配置文件

```bash
# ❌ 错误示例：这会覆盖配置文件中的 type: local
sweagent run \
  --config config/local_repo_auto_pr.yaml \
  --env.repo.github_url="https://github.com/user/repo" \  # 🔴 这会覆盖！
  --problem_statement.github_url="https://github.com/user/repo/issues/123"
```

**结果**：
- 配置文件中 `type: local` 被忽略
- 实际使用 `GithubRepoConfig`
- 从 GitHub 拉取代码，而不是使用本地文件

### ✅ 正确的做法

```bash
# ✅ 正确：只指定 issue URL，不指定 repo URL
sweagent run \
  --config config/local_repo_auto_pr_fixed.yaml \
  --problem_statement.github_url="https://github.com/user/repo/issues/123"
  # 不指定 --env.repo.github_url！
```

**结果**：
- 使用配置文件中的 `type: preexisting`
- 通过 Docker volume mount 使用本地仓库
- 修改直接保存到本地

---

## 实际配置示例

### 场景 1：标准 GitHub Issue（最常见）

```yaml
# config/github_issue.yaml
instances:
  repo:
    type: github
    url: ""  # 通过 --env.repo.github_url 传入
    base_commit: ""

  deployment:
    type: docker
    image: "python:3.11"
```

```bash
sweagent run \
  --config config/github_issue.yaml \
  --env.repo.github_url="https://github.com/user/repo" \
  --problem_statement.github_url="https://github.com/user/repo/issues/123"
```

---

### 场景 2：本地仓库 + 自动 PR（你的需求）

```yaml
# config/local_repo_auto_pr_fixed.yaml
instances:
  repo:
    type: preexisting  # 🔑 关键
    repo_name: test_bed
    base_commit: "HEAD"
    reset: false

  deployment:
    type: docker
    image: your-custom-image:latest
    docker_args:
      - "-v"
      - "/path/to/local/repo:/test_bed"  # 🔑 挂载本地仓库

actions:
  open_pr: true  # 自动创建 PR
```

```bash
# ❌ 错误：不要指定 --env.repo.github_url
sweagent run \
  --config config/local_repo_auto_pr_fixed.yaml \
  --env.repo.github_url="https://github.com/user/repo" \  # 🔴 不要这样！
  --problem_statement.github_url="https://github.com/user/repo/issues/123"

# ✅ 正确：只指定 issue URL
sweagent run \
  --config config/local_repo_auto_pr_fixed.yaml \
  --problem_statement.github_url="https://github.com/user/repo/issues/123"
```

---

## 常见错误

### 错误 1：配置冲突

```bash
# 配置文件：
repo:
  type: preexisting
  ...

# 命令行：
--env.repo.github_url="https://..."  # 🔴 覆盖配置文件！
```

**结果**：从 GitHub 拉取，不使用本地文件

**解决**：不要指定 `--env.repo.github_url`

---

### 错误 2：忘记 volume mount

```yaml
# 配置文件：
repo:
  type: preexisting
  repo_name: test_bed

# 但没有 docker_args 挂载！
```

**结果**：容器内 `/test_bed` 目录不存在或为空

**解决**：必须通过 `docker_args` 挂载

---

### 错误 3：使用了 `local` 类型但期望实时修改

```yaml
repo:
  type: local  # 🔴 会上传文件，不是挂载
  path: "/path/to/repo"
```

**结果**：文件被上传到容器，修改不影响本地

**解决**：改用 `type: preexisting` + `docker_args` volume mount

---

## 完整示例：本地开发 + 自定义镜像 + 自动 PR

### 配置文件

```yaml
# config/dev_env.yaml
instances:
  repo:
    type: preexisting
    repo_name: test_bed
    base_commit: "HEAD"
    reset: false

  deployment:
    type: docker
    image: my-dev-image:latest
    docker_args:
      - "-v"
      - "/Users/dev/myproject:/test_bed"
      - "-v"
      - "/Users/dev/.secrets:/workspace/secrets:ro"
      - "--memory=16g"
      - "--cpus=8"

actions:
  open_pr: true
  pr_config:
    skip_if_commits_reference_issue: true
```

### 运行命令

```bash
# 1. 设置 token
export GITHUB_TOKEN=$(gh auth token)

# 2. 进入项目目录
cd /Users/dev/myproject

# 3. 确保仓库是干净的
git status

# 4. 运行 SWE-agent
sweagent run \
  --config config/dev_env.yaml \
  --problem_statement.github_url="https://github.com/org/repo/issues/123"

# 注意：
# - 不需要指定 --env.repo.github_url
# - 不需要指定 --instances.repo.path
# - 修改会直接保存到 /Users/dev/myproject
```

---

## 总结

| 你的需求 | 正确配置 |
|---------|---------|
| 本地仓库已存在 | `type: preexisting` |
| 使用自定义镜像 | `deployment.docker_args` 挂载 |
| 容器修改保存到本地 | `docker_args` volume mount (rw) |
| 自动创建 PR | `actions.open_pr: true` |
| **不要指定** | ❌ `--env.repo.github_url` |

记住：**`github_url` 只在 `problem_statement.github_url` 中提供，用于 PR 创建，不要在 `--env.repo.github_url` 中指定！**
