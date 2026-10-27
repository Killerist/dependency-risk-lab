# Validation record

- Date: 2026-10-27
- Docker Compose syntax: passed (`docker compose config --quiet`)
- CycloneDX SBOM files: generated and parsed as valid JSON
- Baseline: 5 pinned direct dependencies, 64 unique vulnerability identifiers, 5 affected components
- Repeat check: 5 updated direct dependencies, 0 known vulnerability identifiers reported
- Shell scripts: syntax checked with `bash -n`
- Python scripts: bytecode compilation passed
- GitHub Actions workflow: YAML parsed successfully
- Trivy server configuration: Docker Compose and shell syntax validated
- Trivy SBOM generation and Dependency-Track API upload: prepared, not executed in this validation run

The 64 baseline records are unique vulnerability identifiers (CVE, GHSA and PYSEC), not 64 distinct CVEs. The results reflect direct pinned dependencies and the vulnerability data available at scan time. They do not replace production testing or application-context analysis.
