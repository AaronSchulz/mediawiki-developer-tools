#!/bin/bash
ARGS="$@"
./sync.sh
(
  cd "${HOME}/OSS/core" &&
  sudo -u www-data php "${HOME}/OSS/core/tests/phpunit/phpunit.php" $ARGS 2>&1 | less -R
)
