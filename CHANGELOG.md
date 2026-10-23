# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-10-24

### Fixed

- Snapshots now cover every schema-level object, not only tables
- One file per view and materialized view
- Table files include triggers, rules, policies, extended statistics and comments
- `_extensions.sql` lists every installed extension except `plpgsql`
- `_types.sql` holds enums, composite types, range types and domains
- `_sequences.sql` holds standalone sequences; owned sequences stay in their table's file
- `_functions.sql` holds functions, procedures and aggregates
- `_collations.sql` holds custom collations
- `_text_search.sql` holds text search configurations, dictionaries, parsers and templates
- Files of dropped or renamed tables and views are removed
- `_*.sql` files are removed when the last object of that kind is dropped
- Only files with pgmigrate's own header are removed; other files in `schemas/` are kept
- A failed table listing warns and removes nothing
- A failed `pg_dump` warns that object files were not updated
- SQL inside function and view bodies is no longer stripped from snapshots
- Foreign tables are skipped with a warning instead of silently
- `migrate_tests` runs `test/mapping.bats`

### Added

- `pg_restore` dependency, checked by `install.sh` and `snapshot`
- `install.sh` prints the `pg_restore` version and warns when it is missing
- `pg_restore` mocks for the migrate and install tests
- Snapshot tests for views, object files, stale file removal and failures
- Install test: missing `pg_restore` shows a warning

### Changed

- README lists `pg_restore` in the prerequisites and dependencies
- README documents every snapshot file and what is not snapshotted
- README explains how dropped objects are removed from `schemas/`

## [1.1.0] - 2026-10-24

### Added

- `--version` and `-v` print the current version, e.g. `pgmigrate 1.1.0`
- The version is read from the first row of the "Released versions" table in `VERSION.md`
- `--version` works without a `.env` file
- `--version` exits with `1` when `VERSION.md` is missing or has no version row
- `install.sh` copies `VERSION.md` and `cmd/version/` into `<prefix>/lib/pgmigrate/`
- `help` lists the `--version, -v` option
- Version tests in `test/version.bats`, run by `migrate_tests`
- Install test: `VERSION.md` is copied to `LIB_DIR`
- Launcher test: `pgmigrate --version` prints the installed version

### Changed

- README documents the `version` command
- README adds `VERSION.md`, `CHANGELOG.md` and `cmd/version/` to the directory structure
- README lists `test/version.bats` in the test suites

## [1.0.1] - 2026-10-23

### Fixed

- `pgmigrate uninstall` checks write access to `LIB_DIR`, `BIN_FILE` and `bin/` before removing anything
- `pgmigrate uninstall` prints an error to stderr and exits with `1` when a check or an `rm` fails
- The success message only prints when everything was removed

### Added

- Launcher test: unwritable `LIB_DIR` shows an error and removes nothing
- Launcher test: unwritable `bin/` shows an error with a `sudo` hint
- Launcher test: failed `rm -rf` shows an error and no success message

### Changed

- README notes that a global install doesn't copy `.env.example` into your project
- README documents `PGMIGRATE_PROJECT_DIR` and `./install.sh --uninstall [--prefix]`
- README adds a `sudo pgmigrate uninstall` note
- README says `pgmigrate` replaces `./migrate.sh` in the Commands examples

## [1.0.0] - 2026-06-11

First release.

### Added

- Five commands: `up`, `down`, `status`, `create`, `snapshot`, plus `help`
- Each migration runs atomically inside `BEGIN`/`COMMIT`
- SHA-256 checksums catch migration files edited after they were applied
- `pg_dump` saves a schema snapshot after every `up`/`down`
- Custom schema through `DB_SCHEMA` (defaults to `public`)
- Finds `.env`, `.env.local`, `.env.development` and other `.env.*` files automatically
- A `.pgmigrate` file maps your own variable names (e.g. `PGHOST`) to the expected ones
- `install.sh` detects the OS, checks dependencies and supports `--prefix` and `--uninstall`
- The global `pgmigrate` launcher removes itself with `pgmigrate uninstall`
- Supports macOS, Linux and WSL
- Bats test suite; MIT license

[Unreleased]: https://github.com/work-state/bash-pg-migrate/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/work-state/bash-pg-migrate/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/work-state/bash-pg-migrate/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/work-state/bash-pg-migrate/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/work-state/bash-pg-migrate/releases/tag/v1.0.0
