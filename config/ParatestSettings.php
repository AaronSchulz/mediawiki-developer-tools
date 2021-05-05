<?php

/**
 * Make an empty DB with the same schema as the reference DB
 *
 * @param string $liveDbPath
 * @param string $cloneDbPath
 */
function wfCloneSqliteSchemaForParatest( string $liveDbPath, string $cloneDbPath ) {
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

function wfModifyConfigForParatest() {
    global $wgTmpDirectory, $wgSQLiteDataDir, $wgUploadDirectory, $wgCacheDirectory;
    global $wgDBservers, $wgDBtype, $wgDBserver, $wgDBname, $wgDBuser, $wgDBpassword;
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
            if ( !is_file( $cloneDbPath ) || !filesize( $cloneDbPath ) ) {
                wfCloneSqliteSchemaForParatest( $liveDbPath, $cloneDbPath );
            }
            // Avoid sharing certain resources among concurrent threads
            $wgDBservers[$i]['dbDirectory'] = $wgTmpDirectory;
            // Use the test DB with relaxed settings
            $wgDBservers[$i]['variables']['temp_store'] = 'MEMORY';
            $wgDBservers[$i]['variables']['synchronous'] = 'OFF';
            $wgDBservers[$i]['variables']['journal_mode'] = 'MEMORY';
        }
    }

    // Avoid sharing certain resources among concurrent threads
    $wgUploadDirectory = $wgTmpDirectory;
    $wgCacheDirectory = $wgTmpDirectory;
    $wgSQLiteDataDir = $wgTmpDirectory;
}

wfModifyConfigForParatest();
