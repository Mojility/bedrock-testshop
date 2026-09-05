#!/bin/sh
# Container entrypoint: run pending migrations, then boot the app.
# A migration failure aborts startup so systemd surfaces the problem
# instead of serving traffic against a stale schema.
set -eu

cd -P -- "$(dirname -- "$0")"

./shop eval 'Shop.Release.migrate()'

PHX_SERVER=true exec ./shop start
