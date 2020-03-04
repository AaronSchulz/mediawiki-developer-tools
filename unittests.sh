#!/bin/bash

# Use fast RAM-disk for Sqlite
if [ ! -d "/tmp/mw-temp-sql" ]; then
  sudo mount -t tmpfs -o size=512m tmpfs /tmp/mw-temp-sql
fi

sudo -u www-data php "tests/phpunit/phpunit.php" "$@" 2>&1 | less -R
