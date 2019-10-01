#!/bin/bash
ARGS="$@"
./sync.sh
sudo -u www-data php "${HOME}/OSS/core/tests/phpunit/phpunit.php" $ARGS
