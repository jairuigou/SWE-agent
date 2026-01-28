sweagent run \
	--config /Users/cuiwenbo/repo/SWE-agent/config/shadow_code_agent_dev.yaml \
	--env.repo.path=/Users/cuiwenbo/repo/github-issue-agent \
	--agent.model.name=zai/GLM-4.7 \
	--agent.model.per_instance_cost_limit=2.00 \
	--agent.model.per_instance_cost_limit=0 \
	--agent.model.total_cost_limit=0 \
	--problem_statement.github_url=https://github.com/jairuigou/shadow-code-agent/issues/1
