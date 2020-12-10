<?php

if ( getenv( 'TMPDIR' ) === false ) {
    echo( "TMPDIR was not set by paratest wrapper" );
    die( 1 );
} elseif ( getenv( 'TEST_TOKEN' ) === false ) {
    echo( "TEST_TOKEN was not set by paratest wrapper" );
    die( 1 );
}

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
$wgTmpDirectory = getenv( 'TMPDIR' ) . '/' . getenv( 'TEST_TOKEN' );
// Make sure the slot dir exists (entrypoint script should clear them)
wfMkdirParents( $wgTmpDirectory );

if ( $wgDBtype === 'sqlite' && !is_array( $wgDBservers ) ) {
	$wgDBservers = [ [
		'host' => $wgDBserver,
		'dbname' => $wgDBname,
		'user' => $wgDBuser,
		'password' => $wgDBpassword,
		'dbDirectory' => $wgSQLiteDataDir,
		'type' => $wgDBtype
	] ];
}
if ( is_array( $wgDBservers ) ) {
	foreach ( $wgDBservers as $i => $server ) {
		if ( $server['type'] !== 'sqlite' ) {
			continue;
		}
		// Create or reuse the empty test DB for the assigned slot
		$liveDbPath = ( $server['dbDirectory'] ?? $wgSQLiteDataDir ) . "/$wgDBname.sqlite";
		$cloneDbPath = "$wgTmpDirectory/$wgDBname.sqlite";
		if ( !is_file( $cloneDbPath ) ) {
			wfCloneSqliteSchemaForParatest( $liveDbPath, $cloneDbPath );
		}
		// Use the test DB with relaxed settings
		$wgDBservers[$i]['dbDirectory'] = $wgTmpDirectory;
		$wgDBservers[$i]['variables']['temp_store'] = 'MEMORY';
		$wgDBservers[$i]['variables']['synchronous'] = 'OFF';
		$wgDBservers[$i]['variables']['journal_mode'] = 'MEMORY';
	}
}

// Avoid sharing certain resources among concurrent threads
$wgUploadDirectory = $wgTmpDirectory;
$wgCacheDirectory = $wgTmpDirectory;
$wgSQLiteDataDir = $wgTmpDirectory;