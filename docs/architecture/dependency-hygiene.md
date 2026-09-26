# Dependency hygiene

FunKey uses controlled weekly Dependabot updates for GitHub Actions, Python,
Node/media, Flutter/Dart, Go realtime and Terraform.

Minor/patch updates are grouped to reduce PR noise. Major-version updates are
explicitly excluded from automatic grouping and require architecture/compatibility
review, targeted tests and release notes. Dependency automation never bypasses
lockfiles, CodeQL, Trivy, gitleaks, architecture guards or production
certification.

A dependency should be removed when source reachability is zero and its owning
build still passes without it. A dependency must not be upgraded solely to make
a scanner green if the upgrade changes a protocol/runtime contract without the
matching migration plan.
