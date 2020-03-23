#!/bin/bash

ARGS="$@"
WSL_CORE="/srv/mediawiki/core"
GIT_BIN="git"
BASE_DIR=$(dirname $(realpath $0))

# Use Git for Windows git for the WIN10 path
CHANGES=$($GIT_BIN diff --name-only)
if [ -n "${CHANGES}" ]; then
  echo "The following core file(s) have uncommitted changes in git:"
  echo "${CHANGES}"
  exit 1
fi

# Sync code
"${BASE_DIR}/sync.sh" core

# Create/cleanup temp directory
"${BASE_DIR}/make_tempfs.sh" /mw-temp

(
  cd "${WSL_CORE}" &&
  sudo TMPDIR="/mw-temp" -u www-data php "${WSL_CORE}/tests/phpunit/phpunit.php" $ARGS 2>&1 | less -R
)
