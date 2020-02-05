#!/bin/bash

ARGS="$@"
WSL_CORE="/srv/mediawiki/core"

# Use Git for Windows git for the WIN10 path
CHANGES=$(git.exe diff --name-only)
if [ -n "${CHANGES}" ]; then
  echo "The following core file(s) have uncommitted changes in git:"
  echo "${CHANGES}"
  exit 1
fi

# Use fast RAM-disk for Sqlite
if [ ! -d "/tmp/mw-temp-sql" ]; then
  sudo mount -t tmpfs -o size=512m tmpfs /tmp/mw-temp-sql
fi

sudo ./sync.sh &&
sudo -u www-data php "${WSL_CORE}/tests/phpunit/phpunit.php" $ARGS 2>&1 | less -R
