#!/bin/bash
ARGS="$@"
./sync.sh
(
  WSL_CORE="/srv/mediawiki/core";
  # Use Git for Windows git for the WIN10 path
  CHANGES=$(git.exe diff --name-only)
  if [ -n "${CHANGES}" ]; then
    echo "The following core file(s) have uncommitted changes in git:"
    echo "${CHANGES}"
    exit 1
  fi
  sudo -u www-data eatmydata php "${WSL_CORE}/tests/phpunit/phpunit.php" $ARGS 2>&1 | less -R
)
