#!/bin/bash

BASE_DIR=$(dirname $(realpath $0))

# Sync code
"${BASE_DIR}/sync.sh" core

# Create/cleanup temp directory
"${BASE_DIR}/make_tempfs.sh" /mw-temp

sudo TMPDIR="/mw-temp" -u www-data php "tests/phpunit/phpunit.php" "$@" 2>&1 | less -R
