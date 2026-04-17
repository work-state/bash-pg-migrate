# pgmigrate

A lightweight, zero-dependency PostgreSQL migration runner written in pure Bash. It manages schema changes through plain SQL files, tracks applied migrations in the database itself, and snapshots your live schema after every change — no Node, Python, or Docker required.

---

## Table of Contents

- [What it is](#what-it-is)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Migration Files](#migration-files)
- [Commands](#commands)
  - [up](#up)
  - [down](#down)
  - [status](#status)
  - [create](#create)
  - [snapshot](#snapshot)
  - [help](#help)
- [Schema Snapshots](#schema-snapshots)
- [Checksum Protection](#checksum-protection)
- [Directory Structure](#directory-structure)
- [Running Tests](#running-tests)
- [Author](#author)

---

## What it is

`pgmigrate` is a single-entry-point Bash script that wraps `psql` to give you:

- **Ordered, atomic migrations** — each migration runs inside a `BEGIN/COMMIT` block; if any statement fails the whole migration rolls back.
- **Tamper detection** — a SHA-256 checksum of every applied migration's UP block is stored in the database; re-running `up` will abort if a file was modified after it was applied.
- **Schema snapshots** — after every `up` or `down` run, the live schema of each table in the configured schema (`DB_SCHEMA`, defaults to `public`) is dumped via `pg_dump` into a `schemas/` directory, giving you an always-up-to-date reference.
- **No external runtime** — the only dependencies are `psql`, `pg_dump`, and standard POSIX utilities (`sed`, `awk`, `sha256sum`/`shasum`).

---

## Prerequisites

| Dependency    | Purpose                          | Minimum version |
|---------------|----------------------------------|-----------------|
| `bash`        | Script runtime                   | 4.0+            |
| `psql`        | Run SQL against PostgreSQL       | any             |
| `pg_dump`     | Generate schema snapshots        | any             |
| `sha256sum` or `shasum` | Compute migration checksums | any        |

On macOS, `psql` and `pg_dump` are included with a standard PostgreSQL installation:

```sh
brew install postgresql
```

On Debian/Ubuntu:

```sh
apt-get install postgresql-client
```

---

## Installation

### Supported platforms

| Platform | Support |
|---|---|
| macOS | Supported — Bash 4+ recommended (installer will warn if below) |
| Linux (Ubuntu, Debian, CentOS, Arch...) | Supported |
| WSL (Windows Subsystem for Linux) | Supported — detected automatically, treated as Linux |
| Windows native | Not supported — use WSL |

### Global install (recommended)

Install `pgmigrate` once on your machine and run it from any project directory.

```sh
git clone https://github.com/work-state/bash-pg-migrate.git
cd bash-pg-migrate
./install.sh
```

The installer will:
- Detect your operating system and run the appropriate setup
- Print your Bash version, `psql` version, and `pg_dump` version
- Show exactly where files are being installed
- Warn about any missing dependencies with OS-specific install instructions
- Warn if the install bin directory is not in your `PATH`

If writing to `/usr/local/bin` requires elevated privileges:

```sh
sudo ./install.sh
```

The installer never self-escalates — you stay in control.

**Custom install prefix** (e.g. for a user-local install without `sudo`):

```sh
./install.sh --prefix ~/.local
```

**Uninstall:**

```sh
pgmigrate uninstall
```

No need to keep the cloned repo around — the launcher handles its own removal.

---

### Local (project-scoped) install

If you prefer to keep the tool inside a single project rather than installing it globally:

```sh
git clone https://github.com/work-state/bash-pg-migrate.git
cd bash-pg-migrate
chmod +x migrate.sh
```

Then invoke it directly:

```sh
./migrate.sh help
```

---

### After installing

Copy the example environment file into your project and fill in your database credentials:

```sh
cp .env.example .env
```

Verify the connection:

```sh
pgmigrate status   # global install
# or
./migrate.sh status  # local install
```

---

## Configuration

All database credentials and optional path overrides are read from a `.env` file in the same directory as `migrate.sh`. The `.env` file is never committed (it is listed in `.gitignore`).

**Required variables:**

```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp
DB_USER=postgres
DB_PASSWORD=secret
```

**Optional overrides:**

```dotenv
# PostgreSQL schema to manage (default: public)
# DB_SCHEMA=public

# Override where migration files are stored (default: <project-root>/migrations)
# MIGRATIONS_DIR=/absolute/path/to/migrations

# Override where schema snapshots are written (default: <project-root>/schemas)
# SCHEMAS_DIR=/absolute/path/to/schemas
```

Copy `.env.example` to `.env` and adjust to match your environment. The script validates that all five required variables are present before connecting.

`DB_SCHEMA` controls three things at once:
- The schema where the `_migrations` tracking table is created
- The `search_path` used for every query, so unqualified table names in your migration SQL resolve to the right schema
- The schema captured by the snapshot command

---

## Migration Files

Each migration is a single `.sql` file split into two clearly-marked sections:

```sql
-- UP

CREATE TABLE users (
  id         SERIAL PRIMARY KEY,
  email      VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- DOWN

DROP TABLE users;
```

**Rules:**

- The `-- UP` marker must appear on its own line (no trailing text).
- The `-- DOWN` marker must appear on its own line below the UP block.
- Everything between `-- UP` and `-- DOWN` is the forward migration.
- Everything after `-- DOWN` is the rollback.
- Both sections are required. A file with a missing section will cause `up` or `down` to abort with an error.

**Naming convention:**

Migration files are named with a `YYYYMMDDHHMMSS` timestamp prefix so they sort and apply in chronological order:

```
20240101120000_create_users_table.sql
20240102090000_add_avatar_to_users.sql
20240103150000_create_posts_table.sql
```

Use `./migrate.sh create <name>` to scaffold a correctly-named file automatically.

---

## Commands

### up

```sh
./migrate.sh up
```

Applies all pending migrations in filename order (ascending). For each file:

1. Checks whether the migration is already recorded in `_migrations`.
2. If already applied, verifies the stored checksum matches the file — aborts if it does not.
3. If pending, extracts the UP block, wraps it in `BEGIN/COMMIT`, runs it against the database, and records the filename + checksum in `_migrations`.

After all pending migrations are applied, schema snapshots are regenerated automatically.

**Example output:**

```
[INFO]  Connecting to postgres@localhost:5432/myapp...
[OK]    Connected to localhost:5432/myapp
[INFO]  Applying: 20240101120000_create_users_table.sql
[OK]    Applied: 20240101120000_create_users_table.sql
[INFO]  Applying: 20240102090000_add_avatar_to_users.sql
[OK]    Applied: 20240102090000_add_avatar_to_users.sql
[OK]    Applied 2 migration(s).
[OK]    Snapshot: ./schemas/users.sql
```

If there is nothing to apply:

```
[INFO]  No pending migrations.
```

---

### down

```sh
./migrate.sh down
```

Rolls back the **last applied** migration (determined by descending filename order from `_migrations`). The DOWN block is extracted from the migration file, wrapped in `BEGIN/COMMIT`, and executed. The record is removed from `_migrations` on success.

Schema snapshots are regenerated after a successful rollback.

**Example output:**

```
[INFO]  Connecting to postgres@localhost:5432/myapp...
[OK]    Connected to localhost:5432/myapp
[INFO]  Rolling back: 20240102090000_add_avatar_to_users.sql
[OK]    Rolled back: 20240102090000_add_avatar_to_users.sql
```

> `down` rolls back one migration at a time. Run it repeatedly to go further back.

---

### status

```sh
./migrate.sh status
```

Prints every `.sql` file found in `MIGRATIONS_DIR` alongside its current state.

```
Migration Status
================

  ✓  20240101120000_create_users_table.sql
  ✓  20240102090000_add_avatar_to_users.sql
  ○  20240103150000_create_posts_table.sql  (pending)
```

- `✓` (green) — migration has been applied.
- `○` (yellow) — migration is pending.

---

### create

```sh
./migrate.sh create <name>
```

Scaffolds a new migration file in `MIGRATIONS_DIR` with the current timestamp as a prefix and an empty UP/DOWN template.

```sh
./migrate.sh create add_index_to_users_email
# Created: ./migrations/20240103153000_add_index_to_users_email.sql
```

The generated file:

```sql
-- UP


-- DOWN

```

Open the file, fill in your SQL, and run `./migrate.sh up`.

---

### snapshot

```sh
./migrate.sh snapshot
```

Manually regenerates schema snapshots for all tables in the configured schema (excluding the internal `_migrations` table) without running any migrations. Useful when you want to refresh `schemas/` after making changes directly in the database during development.

```
[INFO]  Generating schema snapshots...
[OK]    Snapshot: ./schemas/users.sql
[OK]    Snapshot: ./schemas/posts.sql
[OK]    Schema snapshots updated in ./schemas
```

---

### help

```sh
./migrate.sh help
# or simply
./migrate.sh
```

Prints a summary of all available commands. This is the only command that does not require a `.env` file to be present.

```
PostgreSQL migration runner

Usage:
  ./migrate.sh [OPTION]...

General options:
  ./migrate.sh up               Apply all pending migrations
  ./migrate.sh down             Rollback last migration
  ./migrate.sh status           Show migration status
  ./migrate.sh create <name>    Create a new migration file
  ./migrate.sh snapshot         Regenerate schema snapshots
```

---

## Schema Snapshots

After every `up` and `down` run, `pgmigrate` generates one snapshot file per table under `schemas/`. Each file:

- Is a **read-only reference** — it should never be executed directly.
- Captures that table's columns, sequences, indexes, constraints, and outgoing foreign key references.
- Can be committed to version control — each table has its own file, so a migration touching `orders` only modifies `schemas/orders.sql`, keeping diffs isolated and avoiding merge conflicts in team workflows.

> **Note:** FK constraints defined on *other* tables that point *to* this table are not included — those belong to the other table's snapshot. This limitation is documented in each file's header.

Example `schemas/orders.sql`:

```sql
-- Table: public.orders
-- Database: myapp
-- Auto-generated snapshot (2024-01-03 15:30:00)
-- DO NOT EXECUTE — this is a reference file only.
--
-- Includes: columns, sequences, indexes, constraints, and outgoing FK references.
-- Excludes: FK constraints from other tables pointing to this one.
-- The migrations/ directory is the source of truth for schema changes.

CREATE TABLE public.orders (
    id integer NOT NULL,
    user_id integer NOT NULL,
    total numeric(10,2) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);
CREATE SEQUENCE public.orders_id_seq ...
ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);
```

The snapshot strips `SET` statements, `SELECT` statements, `\connect` directives, and blank lines produced by `pg_dump` to keep the output clean.

---

## Checksum Protection

Every time a migration is applied, a SHA-256 checksum of its UP block is stored in `_migrations.checksum`. On every subsequent `up` run, the stored checksum is compared against the current file content.

If they differ, `up` aborts immediately:

```
[ERROR] Checksum mismatch: 20240101120000_create_users_table.sql was modified after being applied.
[ERROR]   stored:  a3f1c9...
[ERROR]   current: 7e82b4...
```

This prevents silent schema drift caused by editing a migration file after it has already been applied to a shared or production database.

> If you intentionally need to amend an already-applied migration during local development, rollback with `./migrate.sh down`, edit the file, and re-apply with `./migrate.sh up`.

---

## Directory Structure

```
pgmigrate/
├── migrate.sh              # Entry point — load libs, dispatch commands
├── install.sh              # OS-aware installer
├── .env                    # Your local credentials (git-ignored)
├── .env.example            # Template to copy from
├── .gitignore
│
├── bin/
│   └── pgmigrate           # Launcher — copied to <prefix>/bin/ on install
│
├── lib/
│   └── helpers/
│       ├── constants.sh    # Terminal color codes, ENV_FILE path
│       ├── helpers.sh      # Logging, load_env, checksum, UP/DOWN extraction
│       ├── db.sh           # run_sql, check_connection, ensure_migrations_table
│       └── snapshot.sh     # generate_schema_snapshot (pg_dump per table)
│
├── cmd/
│   ├── help/               # cmd_help
│   │   └── help.sh
│   ├── up/                 # cmd_up
│   │   └── up.sh
│   ├── down/               # cmd_down
│   │   └── down.sh
│   ├── status/             # cmd_status
│   │   └── status.sh
│   ├── create/             # cmd_create
│   │   └── create.sh
│   └── snapshot/           # cmd_snapshot
│       └── snapshot.sh
│
├── migrations/             # Your .sql migration files (git-ignored by default)
│   └── .gitkeep
│
└── schemas/                # Auto-generated schema snapshots (git-ignored by default)
    └── .gitkeep
```

The `migrations/` and `schemas/` directories are excluded from version control by default. If you want to track migrations in git (common practice), remove the `migrations/*` line from `.gitignore`.

---

## Running Tests

Tests use [bats-core](https://github.com/bats-core/bats-core) and require no real database — all PostgreSQL calls are intercepted by mock binaries in `test/mocks/`.

### Setup

Install bats-core once on your machine:

```sh
# macOS
brew install bats-core

# Debian / Ubuntu
sudo apt-get install bats

# npm (any platform)
npm install -g bats
```

### Running

```sh
./migrate_tests   # tests for migrate.sh
./install_tests   # tests for install.sh
```

### What is covered

**`migrate_tests`** — `migrate.sh`

`test/env.bats`, `test/connection.bats`, `test/up.bats`, `test/down.bats`, `test/status.bats`, `test/create.bats`, `test/snapshot.bats`

**`install_tests`** — `install.sh` and `bin/pgmigrate`

`test/install.bats`

Each install test controls the simulated OS via:

```sh
MOCK_OS="macos"       # default
MOCK_OS="linux"
MOCK_OS="windows"     # triggers the unsupported-platform exit
MOCK_OS="unsupported"
```

All test operations are isolated inside a temporary directory created by `mktemp -d` and deleted after each test. The repo is never written to.

---

## Author

[Ilyass Mabrouk](https://github.com/work-state)

Built to manage PostgreSQL schema migrations without introducing a heavy framework dependency.
