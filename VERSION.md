# Versions

pgmigrate follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html): `MAJOR.MINOR.PATCH`.

- **MAJOR**: incompatible changes (commands, flags, env variables or migration file format).
- **MINOR**: new, backwards-compatible features.
- **PATCH**: backwards-compatible bug fixes.

Each release is tagged in git as `vX.Y.Z`. See [CHANGELOG.md](CHANGELOG.md) for full details.

## Released versions

| Version | Date       | Summary                                              | Details |
|---------|------------|------------------------------------------------------|---------|
| 1.1.1   | 2026-10-24 | Snapshots cover all schema-level objects and drop stale files | [Changelog](CHANGELOG.md#111---2026-10-24) |
| 1.1.0   | 2026-10-24 | `--version` / `-v` command                           | [Changelog](CHANGELOG.md#110---2026-10-24) |
| 1.0.1   | 2026-10-23 | Safer `pgmigrate uninstall` with permission checks and proper exit codes | [Changelog](CHANGELOG.md#101---2026-10-23) |
| 1.0.0   | 2026-06-11 | First release                                        | [Changelog](CHANGELOG.md#100---2026-06-11) |
