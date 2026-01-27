# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
```bash
# Run all tests
python3 -m pytest tests/

# Run specific test file
python3 -m pytest tests/path/to/test_file.py

# Run tests without slow tests
python3 -m pytest -m "not slow" tests/

# Run tests in parallel
python3 -m pytest -n auto tests/

# Run with coverage
python3 -m pytest --cov=sweagent tests/
```

### Code Quality
```bash
# Run linting and formatting
ruff check .
ruff format .

# Run pre-commit hooks
pre-commit run --all-files

# Install pre-commit hooks
pre-commit install
```

### Running SWE-agent
```bash
# Run on a single problem
sweagent run --problem_statement.path="path/to/issue.md" --repo_path="path/to/repo"

# Run on batch (benchmarking)
sweagent run-batch --config config/default.yaml

# View trajectory in web interface
sweagent inspector trajectories/

# Inspect single trajectory in terminal
sweagent inspect trajectories/path/to/traj.json
```

## Architecture Overview

SWE-agent is an autonomous software engineering agent system that uses language models to fix GitHub issues and solve coding problems.

### Core Components

**Entry Points** (`sweagent/run/`)
- `run_single.py`: Main execution for single problem solving
- `run_batch.py`: Batch execution for benchmarking (e.g., SWE-bench)
- `run.py`: CLI dispatcher for all subcommands

**Agent System** (`sweagent/agent/`)
- `agents.py`: Main `Agent` class that orchestrates problem-solving loop
- `models.py`: Model interfaces and configurations (LiteLLM integration)
- `action_sampler.py`: Sampling strategies for agent actions
- `problem_statement.py`: Problem statement processing and formatting

**Environment** (`sweagent/environment/`)
- `swe_env.py`: `SWEEnv` class that interfaces with SWE-ReX for Docker container management
- `hooks/`: Event hooks for environment lifecycle events
- Containerized execution environment where agent actions are performed

**Tools System** (`tools/` and `sweagent/tools/`)
- Tools are organized in bundles (e.g., `tools/registry/`, `tools/edit_anthropic/`)
- Bundles are copied to container and made available in `$PATH`
- `sweagent/tools/tools.py`: Tool parsing and execution logic
- `sweagent/tools/bundle.py`: Bundle management

**Configuration** (`config/`)
- YAML-based agent configuration
- Defines templates, tools, history processors, and retry loops
- `default.yaml`: Standard configuration with function calling

**Inspector** (`sweagent/inspector/`)
- `server.py`: Web-based trajectory viewer
- `inspector_cli.py`: Terminal-based trajectory viewer

### Execution Flow

1. Initialization: Agent class loads config and initializes SWEEnv with Docker container
2. Problem presentation: Problem statement formatted and presented to model
3. Action loop: Model proposes actions → executed in container → results returned
4. Submission: Agent submits changes when confident
5. Hooks: Throughout execution, hooks can intercept and modify behavior

### Key Design Patterns

- **YAML Configuration**: Agent behavior entirely configurable via YAML files
- **Hook System**: Extensible hooks at agent and environment levels
- **Tool Bundles**: Modular tool organization for container deployment
- **History Processing**: Configurable message processing for context management

## Development Guidelines

- Target Python 3.11+
- Use type annotations
- Use `pathlib` instead of `os.path`
- Use `Path.read_text()` over `with ...open()`
- Use `argparse` for CLI interfaces
- Run tests before committing
- Pre-commit hooks enforce code quality (ruff, typos, etc.)
- Don't modify test files when fixing issues (agents should only modify source code)
