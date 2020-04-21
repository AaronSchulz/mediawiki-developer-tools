#!/bin/bash

BASE_DIR=$(dirname $(realpath $0))

# Create/cleanup temp directory
"${BASE_DIR}/make_tempfs.sh" /mw-temp || exit 1

sudo TMPDIR="/mw-temp" -u www-data php "tests/phpunit/phpunit.php" "$@" 2>&1 | less -R
