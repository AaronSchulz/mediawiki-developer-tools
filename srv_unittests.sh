#!/bin/bash

ARGS="$@"
WSL_CORE="/srv/mediawiki/core"
GIT_BIN="~/bin/git"

# Use Git for Windows git for the WIN10 path
CHANGES=$($GIT_BIN diff --name-only)
if [ -n "${CHANGES}" ]; then
  echo "The following core file(s) have uncommitted changes in git:"
  echo "${CHANGES}"
  exit 1
else
  ./sync.sh wmf
fi

# Use fast RAM-disk for Sqlite
if ! grep -qs '/tmp/mw-temp-sql ' /proc/mounts; then
  sudo mount -t tmpfs -o size=512m tmpfs /tmp/mw-temp-sql
fi

sudo -u www-data php "${WSL_CORE}/tests/phpunit/phpunit.php" $ARGS 2>&1 | less -R
