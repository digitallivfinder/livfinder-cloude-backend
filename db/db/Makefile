# Liv Finder — database
#
# Pure SQL. There is no generator, no build step and no language runtime: the
# schema is db/migrations/*.sql and the data is db/seeds/*.sql, applied in
# filename order.
#
# Connection settings come from the environment; see .env.example.
#
#   make fresh            drop, recreate, migrate, seed and verify
#   make migrate          apply migrations
#   make seed             apply seeds
#   make verify           re-run the seed assertions
#   make integrity        run the nightly consistency suite
#   make mysql8           apply the MySQL-8-only optimisations (0015)
#   make shell            open a mysql shell on the database
#   make counts           row counts for the main tables
#   make schema-dump      write a single-file schema snapshot to build/schema.sql

SHELL := /usr/bin/env bash
DB_NAME ?= livfinder
export DB_NAME

.PHONY: help fresh migrate seed verify mysql8 shell counts schema-dump \
        integrity clean

help:
	@sed -n '2,20p' Makefile | sed 's/^# \{0,1\}//'

fresh:
	tools/load.sh all --fresh

migrate:
	tools/load.sh migrate

seed:
	tools/load.sh seed

verify:
	tools/load.sh verify

mysql8:
	tools/load.sh migrate --with-mysql8

shell:
	mysql $(DB_NAME)

counts:
	@mysql --table $(DB_NAME) -e "\
	  SELECT table_name AS tbl, FORMAT(table_rows, 0) AS approx_rows \
	    FROM information_schema.tables \
	   WHERE table_schema = '$(DB_NAME)' AND table_type = 'BASE TABLE' \
	   ORDER BY table_rows DESC LIMIT 40;"

# Orphan and consistency checks the schema's foreign keys cannot express — the
# polymorphic subject columns, derived denormalisation, counters and money
# invariants. Every check must report 0. Exits non-zero on any failure, so this
# is safe to run from cron or CI.
#
# This runs through tools/load.sh so it resolves the connection the same way
# every other target does. It used to invoke `mysql $(DB_NAME)` directly with no
# host, port, user or password and pipe into awk with no `pipefail`: against a
# server on a non-default port, or one that wants a password, the client failed,
# awk read an empty stream, and the target printed "0 check(s) failed" and exited
# 0. A connection error was indistinguishable from a clean run.
integrity:
	tools/load.sh integrity

schema-dump:
	@mkdir -p build
	mysqldump --no-data --routines --triggers --skip-add-drop-table \
	          --skip-comments $(DB_NAME) > build/schema.sql
	@echo "wrote build/schema.sql"

clean:
	rm -rf build
