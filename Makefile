.PHONY: dev down test lint integration-test load-test-smoke bootstrap seed scaffold-service

dev down test lint integration-test load-test-smoke bootstrap seed:
	pwsh -NoProfile -File scripts/task.ps1 $@

scaffold-service:
	@if [ -z "$(NAME)" ]; then echo "Usage: make scaffold-service NAME=my-service"; exit 1; fi
	pwsh -NoProfile -File scripts/task.ps1 scaffold-service -Name "$(NAME)"
