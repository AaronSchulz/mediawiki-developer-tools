<?php

use Wikimedia\Rdbms\DatabaseFactory;

/**
 * Make an empty DB with the same schema as the reference DB
 *
 * @param string $liveDbPath
 * @param string $cloneDbPath
 */
function mwptInitSchemaClone( string $liveDbPath, string $cloneDbPath ) {
	$fh = fopen( $cloneDbPath, 'c' );
	if ( !flock( $fh, LOCK_EX ) ) {
		throw new RuntimeException( "Failed to lock '$cloneDbPath'" );
	}

	$stat = fstat( $fh );
	// Rebuild the temp "slot" DB unless it already existed and is expected to match the schema
	if ( !$stat['size'] || ( time() - $stat['mtime'] ) > 15 ) {
		ftruncate( $fh, 0 );

        $dbl = mwptSqliteHandle( $liveDbPath );
		$dbc = mwptSqliteHandle( $cloneDbPath );

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

	flock( $fh, LOCK_UN );
	fclose( $fh );
    
    if ( headers_sent() ) moo();
}

function mwptSqliteHandle( $filename ) {
    $p['dbFilePath'] = $filename;
    $p['schema'] = null;
    $p['tablePrefix'] = '';
    $p['trxMode'] = 'IMMEDIATE';

    return ( new DatabaseFactory() )->create( 'sqlite', $p );
}

function mwptModifyDirectories() {
    global $wgTmpDirectory, $wgSQLiteDataDir, $wgUploadDirectory, $wgCacheDirectory;
    global $wgDBservers, $wgDBtype, $wgDBserver, $wgDBname, $wgDBuser, $wgDBpassword;
    global $wgLocalisationCacheConf;
    global $wgDirectoryMode;

	$envTmpDir = getenv( 'TMPDIR' );
	$envTestToken = getenv( 'TEST_TOKEN' );
	$envTestRunNo = getenv( 'TEST_RUN_NO' );
    if ( in_array( false, [ $envTmpDir, $envTestToken, $envTestRunNo ], true ) ) {
        // Not an invocation from paratest runner
        return;
    }

    // Use the temp dir for the slot assigned by paratest
    $wgTmpDirectory = "${envTmpDir}/${envTestToken}";
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
