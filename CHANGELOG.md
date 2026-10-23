# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[Unreleased]: https://github.com/work-state/bash-pg-migrate/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/work-state/bash-pg-migrate/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/work-state/bash-pg-migrate/releases/tag/v1.0.0
