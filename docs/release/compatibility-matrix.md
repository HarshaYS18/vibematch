# Release compatibility matrix

The machine-readable source is
`contracts/compatibility/version-matrix-v1.json`.

| Contract | Current | Compatibility rule |
|---|---:|---|
| REST | v1 | Preserve supported v1 routes/payloads until versioned replacement and deprecation window complete. |
| Realtime envelope | 1 | Client/server must reject unsupported envelope versions explicitly and resync safely. |
| Domain events | 1 | Consumers support versioned schemas; breaking changes require new version and staged producer/consumer rollout. |
| Persisted GraphQL operations | 1 | Registry/client IDs remain compatible across the supported mobile skew window. |
| Game bridge | 1 | Remote games negotiate only supported bridge versions; bearer tokens never cross the bridge. |
| Asset manifest | 1 | CDN game/media manifests must remain integrity-verifiable and versioned. |

The generated release manifest snapshots these values together with the mobile
version, migration head, feature flags and image digests so an operator can
answer exactly what was deployed.
