#!/bin/bash
ARGS="$@"
./sync.sh
(
  [ $(cd "${HOME}/OSS/core") ] || exit 1
  # Use Git for Windows git for the WIN10 path
  local CHANGES=$(git.exe diff --name-only)
  if [ -n "${CHANGES}" ]; then
    echo "The following core file(s) have uncommitted changes in git"
    echo "${CHANGES}"
    exit 1
  fi
  sudo -u www-data php "${HOME}/OSS/core/tests/phpunit/phpunit.php" $ARGS 2>&1 | less -R
)
