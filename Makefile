.PHONY: dev down test lint integration-test load-test-smoke

dev down test lint integration-test load-test-smoke:
	pwsh -NoProfile -File scripts/task.ps1 $@
