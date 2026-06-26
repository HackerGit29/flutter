# Versioning — aricie

This document defines the versioning strategy for the aricie project.

## Current Version

**1.3.0+1** (as defined in `pubspec.yaml`)

## Versioning Scheme

This project follows **[Semantic Versioning 2.0.0](https://semver.org/)**:

```
MAJOR.MINOR.PATCH+BUILD
```

- **MAJOR** — Incompatible API changes or significant architectural rewrites
- **MINOR** — New features added in a backward-compatible manner
- **PATCH** — Bug fixes, performance improvements, security patches
- **BUILD** — Internal build number (incremented automatically per release)

## Version File

The canonical version is stored in `pubspec.yaml` under the `version` field:

```yaml
version: 1.3.0+1
```

## Release Process

1. Determine the new version based on changes since the last release
2. Update `pubspec.yaml` version field
3. Update `CHANGELOG.md` with the release notes
4. Commit with message: `chore(release): bump version to X.Y.Z+build`
5. Tag the commit: `git tag vX.Y.Z`
6. Push tags: `git push --tags`

## Changelog

The `CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/) format:

- **Added** — New features
- **Changed** — Changes in existing functionality
- **Deprecated** — Soon-to-be removed features
- **Removed** — Removed features
- **Fixed** — Bug fixes
- **Security** — Security fixes

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.3.0+1 | 2026-06-26 | Admin provisioning, pipeline stats, refonte UI appareils, nettoyage secrets |
| 1.2.0+1 | 2026-06-26 | CI/CD release pipeline |
| 1.1.0+1 | 2026-06-25 | Agent RAG, subscription tiers, device_commands |
| 1.0.0+1 | 2026-06-21 | Initial release |
