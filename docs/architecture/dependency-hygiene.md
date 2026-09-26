# Dependency hygiene

FunKey uses controlled weekly Dependabot updates for GitHub Actions, Python
backend and standalone Python services, Node/media, Flutter/Dart, Go realtime
and Terraform.

Every repository directory with its own direct dependency manifest is covered,
including Inbox and Worker service requirements.

Minor/patch updates are grouped to reduce PR noise. Major-version updates are
explicitly excluded from automatic grouping and require architecture/
compatibility review, targeted tests and release notes. Dependency automation
never bypasses lockfiles, CodeQL, Trivy, gitleaks, architecture guards or
production certification.

A dependency should be removed when source reachability is zero and its owning
build still passes without it. The obsolete direct Flutter `package:http`
dependency was removed after feature traffic converged on the canonical Dio
transport and no Dart source imported `package:http/http.dart`.

A dependency must not be upgraded solely to make a scanner green if the upgrade
changes a protocol/runtime contract without the matching migration plan.
