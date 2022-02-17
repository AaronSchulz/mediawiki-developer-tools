<?php

use Wikimedia\Rdbms\DatabaseSqlite;

/**
 * Make an empty DB with the same schema as the reference DB
 *
 * @param string $liveDbPath
 * @param string $cloneDbPath
 */
function mwptInitSchemaClone( string $liveDbPath, string $cloneDbPath ) {
	if ( is_file( $cloneDbPath ) ) {
		if ( filesize( $cloneDbPath ) ) {
			#return;
		}
		unlink( $cloneDbPath );
	}

	$dbl = DatabaseSqlite::newStandaloneInstance( $liveDbPath, [ 'trxMode' => 'IMMEDIATE' ] );
	$dbc = DatabaseSqlite::newStandaloneInstance( $cloneDbPath, [ 'trxMode' => 'IMMEDIATE' ] );

	$sqls = $dbl->selectFieldValues(
		$dbl->addIdentifierQuotes( 'sqlite_master' ),
		'sql',
		[
			'type' => [ 'index', 'table' ],
			"name NOT " . $dbl->buildLike( 'sqlite_', $dbl->anyString() ),
			"name NOT " . $dbl->buildLike( 'searchindex_', $dbl->anyString() ),
			// @see MediaWikiIntegrationTestCase::DB_PREFIX
			"name NOT " . $dbl->buildLike( 'unittest_', $dbl->anyString() )
		]
	);
	foreach ( $sqls as $sql ) {
		$dbc->query( $sql, __METHOD__, $dbc::QUERY_CHANGE_SCHEMA );
	}
}

function mwptModifyDirectories() {
    global $wgTmpDirectory, $wgSQLiteDataDir, $wgUploadDirectory, $wgCacheDirectory;
    global $wgDBservers, $wgDBtype, $wgDBserver, $wgDBname, $wgDBuser, $wgDBpassword;
    global $wgLocalisationCacheConf;
    global $wgDirectoryMode;

    if ( getenv( 'TMPDIR' ) === false || getenv( 'TEST_TOKEN' ) === false ) {
        // Not an invocation from paratest runner
        return;
    }

    // Use the temp dir for the slot assigned by paratest
    $wgTmpDirectory = getenv( 'TMPDIR' ) . '/' . getenv( 'TEST_TOKEN' );
    // Make slot directory
    @mkdir( $wgTmpDirectory, $wgDirectoryMode );

    // Normalize $wgDBservers if not set
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
    // Make $wgDBservers use the assigned temp dir where applicable
    if ( is_array( $wgDBservers ) ) {
        foreach ( $wgDBservers as $i => $server ) {
            if ( $server['type'] !== 'sqlite' ) {
                continue;
            }
            // Create or reuse the empty test DB for the assigned slot
            $liveDbPath = ( $server['dbDirectory'] ?? $wgSQLiteDataDir ) . "/$wgDBname.sqlite";
            $cloneDbPath = "$wgTmpDirectory/$wgDBname.sqlite";
            mwptInitSchemaClone( $liveDbPath, $cloneDbPath );
            // Avoid sharing certain resources among concurrent threads
            $wgDBservers[$i]['dbDirectory'] = $wgTmpDirectory;
            // Use the test DB with relaxed settings
            $wgDBservers[$i]['variables']['temp_store'] = 'MEMORY';
            $wgDBservers[$i]['variables']['synchronous'] = 'OFF';
            $wgDBservers[$i]['variables']['journal_mode'] = 'MEMORY';
        }
    }

	// Make $wgLocalisationCacheConf use the assigned temp dir where applicable
	$wgLocalisationCacheConf['storeDirectory'] = $wgTmpDirectory;
	if ( isset( $wgLocalisationCacheConf['dbDirectory'], $wgLocalisationCacheConf['dbname'] ) ) {
		$dbName = $wgLocalisationCacheConf['dbname'];
		$liveDbPath = "{$wgLocalisationCacheConf['dbDirectory']}/$dbName";
		$cloneDbPath = "$wgTmpDirectory/$dbName.sqlite";
		mwptInitSchemaClone( $liveDbPath, $cloneDbPath );
		$wgLocalisationCacheConf['dbDirectory'] = $wgTmpDirectory;
	}

    // Avoid sharing certain resources among concurrent threads
    $wgUploadDirectory = $wgTmpDirectory;
    $wgCacheDirectory = $wgTmpDirectory;
    $wgSQLiteDataDir = $wgTmpDirectory;
}

mwptModifyDirectories();
