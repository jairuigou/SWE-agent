sweagent run \
  --agent.model.name=zai/GLM-4.7 \
  --agent.model.per_instance_cost_limit=2.00 \
  --agent.model.per_instance_cost_limit=0 \
  --agent.model.total_cost_limit=0 \
  --env.repo.github_url=https://github.com/SWE-agent/test-repo \
  --problem_statement.github_url=https://github.com/SWE-agent/test-repo/issues/1
