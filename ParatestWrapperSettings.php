<?php

require __DIR__ . '/LocalSettings.php';

/**
 * Make an empty DB with the same schema as the reference DB
 *
 * @param string $liveDbPath
 * @param string $cloneDbPath
 */
function wfCloneSqliteSchemaForParatest( $liveDbPath, $cloneDbPath ) {
	$proc = popen(
		"echo '.schema main.*' | " .
		"sqlite3 " . escapeshellarg( $liveDbPath ) . " | " .
		"grep -v 'CREATE TABLE sqlite_sequence' | " .
		"sqlite3 " . escapeshellarg( $cloneDbPath ),
		'r'
	);
	stream_get_contents( $proc );
	pclose( $proc );
}

// Use the temp dir for the slot assigned by paratest
$wgTmpDirectory = wfTempDir() . '/' . getenv( 'TEST_TOKEN' );
wfMkdirParents( $wgTmpDirectory );

foreach ( $wgDBservers as $i => $server ) {
	if ( $server['type'] !== 'sqlite' ) {
		continue;
	}
	$liveDbPath = ( $server['dbDirectory'] ?? $wgSQLiteDataDir ) . "/$wgDBname.sqlite";
	$cloneDbPath = "$wgTmpDirectory/$wgDBname.sqlite";
	// Create or reuse the empty test DB for the assigned slot
	if ( !is_file( $cloneDbPath ) ) {
		wfCloneSqliteSchemaForParatest( $liveDbPath, $cloneDbPath );
	}
	$wgDBservers[$i]['dbDirectory'] = $wgTmpDirectory;
	$wgDBservers[$i]['variables']['temp_store'] = 'MEMORY';
}

// Avoid sharing certain resources among concurrent threads
$wgUploadDirectory = $wgTmpDirectory;
$wgCacheDirectory = $wgTmpDirectory;
$wgSQLiteDataDir = $wgTmpDirectory;
