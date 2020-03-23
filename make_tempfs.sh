#!/bin/bash

# Useful when paired with code like this in LocalSettings.php:
# if ( defined( 'MW_PHPUNIT_TEST' ) ) {
#	  $tmpSqlDir = '/tmp/mw-temp';
#	  @unlink( "$tmpSqlDir/$wgDBname.sqlite" );
#	  @copy( "$wgSQLiteDataDir/$wgDBname.sqlite", "$tmpSqlDir/$wgDBname.sqlite" );
#	  $wgDBservers[0]['dbDirectory'] = $tmpSqlDir;
#	  $wgDBservers[0]['variables']['synchronous'] = 'OFF';
#}

TEMP_RAM_DIR=$1

if [ -z "${TEMP_RAM_DIR}" ]; then
  echo "Missing temp directory mount path"
  exit 1
fi

# Use fast RAM-disk for Sqlite
if [ -d "${TEMP_RAM_DIR}" ]; then
  if grep -qs " ${TEMP_RAM_DIR} " /proc/mounts; then
    echo "Clearing tmpfs mount at '${TEMP_RAM_DIR}'"
    sudo -u www-data rm -rf "${TEMP_RAM_DIR}"/*
  else
    echo "Mounting tmpfs at '${TEMP_RAM_DIR}'"
    sudo mount -t tmpfs -o size=512m tmpfs "${TEMP_RAM_DIR}"
    sudo chown www-data:www-data "${TEMP_RAM_DIR}"
  fi
fi
