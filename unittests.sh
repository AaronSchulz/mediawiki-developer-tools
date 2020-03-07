#!/bin/bash

BASE_DIR=$(dirname $(realpath $0))

"${BASE_DIR}/make_tempfs.sh" &&
sudo -u www-data php "tests/phpunit/phpunit.php" "$@" 2>&1 | less -R
