from __future__ import annotations


class _DummyEnv:
    def __init__(self):
        self.commands: list[str] = []

    def communicate(self, input: str, **kwargs) -> str:  # noqa: A002
        self.commands.append(input)
        return ""


class _DummyIssue:
    def __init__(self, number: int, title: str):
        self.number = number
        self.title = title


class _DummyRepos:
    def __init__(self, default_branch: str):
        self._default_branch = default_branch

    def get(self, owner: str, repo: str):
        return type("_Repo", (), {"default_branch": self._default_branch})()


class _DummyPulls:
    def __init__(self):
        self.last_create_kwargs: dict | None = None

    def create(self, **kwargs):
        self.last_create_kwargs = kwargs
        return type("_PR", (), {"html_url": "https://example.com/pr/1"})()


class _DummyGhApi:
    def __init__(self, token: str):
        self.token = token
        self.repos = _DummyRepos(default_branch="main")
        self.pulls = _DummyPulls()


def test_open_pr_uses_configured_base_branch(monkeypatch):
    from sweagent.run.hooks import open_pr as open_pr_mod

    monkeypatch.setattr(open_pr_mod, "_get_gh_issue_data", lambda *_args, **_kwargs: _DummyIssue(12, "T"))
    monkeypatch.setattr(open_pr_mod, "_parse_gh_issue_url", lambda *_args, **_kwargs: ("o", "r", 12))

    api = _DummyGhApi(token="t")
    monkeypatch.setattr(open_pr_mod, "GhApi", lambda token: api)

    open_pr_mod.open_pr(
        logger=type("_L", (), {"info": lambda *_a, **_k: None, "debug": lambda *_a, **_k: None})(),
        token="t",
        env=_DummyEnv(),
        github_url="https://github.com/o/r/issues/12",
        trajectory=[],
        base_branch="dev",
    )

    assert api.pulls.last_create_kwargs is not None
    assert api.pulls.last_create_kwargs["base"] == "dev"


def test_open_pr_defaults_to_repo_default_branch(monkeypatch):
    from sweagent.run.hooks import open_pr as open_pr_mod

    monkeypatch.setattr(open_pr_mod, "_get_gh_issue_data", lambda *_args, **_kwargs: _DummyIssue(12, "T"))
    monkeypatch.setattr(open_pr_mod, "_parse_gh_issue_url", lambda *_args, **_kwargs: ("o", "r", 12))

    api = _DummyGhApi(token="t")
    monkeypatch.setattr(open_pr_mod, "GhApi", lambda token: api)

    open_pr_mod.open_pr(
        logger=type("_L", (), {"info": lambda *_a, **_k: None, "debug": lambda *_a, **_k: None})(),
        token="t",
        env=_DummyEnv(),
        github_url="https://github.com/o/r/issues/12",
        trajectory=[],
        base_branch=None,
    )

    assert api.pulls.last_create_kwargs is not None
    assert api.pulls.last_create_kwargs["base"] == "main"

