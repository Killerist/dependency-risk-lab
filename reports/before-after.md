# Before / after

| Metric | Before | After |
|---|---:|---:|
| Components checked | 5 | 5 |
| Unique vulnerability IDs | 64 | 0 |
| Affected components | 5 | 0 |

## Result

The intentionally outdated baseline produced known-vulnerability findings. After updating the five pinned dependencies and regenerating the SBOM, the repeat audit reported no known vulnerabilities.

This result applies only to the pinned direct dependencies and the vulnerability database available at scan time. A production assessment must also include transitive dependencies, application context, runtime exposure and regression testing.
