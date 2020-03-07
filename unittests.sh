#!/bin/bash

# Use fast RAM-disk for Sqlite
if ! grep -qs '/tmp/mw-temp-sql ' /proc/mounts; then
  sudo mount -t tmpfs -o size=512m tmpfs /tmp/mw-temp-sql
fi

sudo -u www-data php "tests/phpunit/phpunit.php" "$@" 2>&1 | less -R
