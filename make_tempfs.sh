#!/bin/bash

# Useful when paired with code like this in LocalSettings.php:
# if ( defined( 'MW_PHPUNIT_TEST' ) ) {
#	  $tmpSqlDir = '/tmp/mw-temp';
#	  @unlink( "$tmpSqlDir/$wgDBname.sqlite" );
#	  @copy( "$wgSQLiteDataDir/$wgDBname.sqlite", "$tmpSqlDir/$wgDBname.sqlite" );
#	  $wgDBservers[0]['dbDirectory'] = $tmpSqlDir;
#	  $wgDBservers[0]['variables']['synchronous'] = 'OFF';
#}

# Use fast RAM-disk for Sqlite
if ! grep -qs '/tmp/mw-temp ' /proc/mounts; then
  if [ ! -d /tmp/mw-temp ]; then
    sudo -u www-data mkdir '/tmp/mw-temp' -m 744
  fi
  sudo mount -t tmpfs -o size=512m tmpfs /tmp/mw-temp
fi
