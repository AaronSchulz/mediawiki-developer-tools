# mediawiki-developer-tools
A collection of utilities for assisting basic MediaWiki development tasks

## Environmental variable setup ##

These tools assume that there is a "mediawki" directory (DEV_MW_DIR), used directly by an IDE,
for making changes and that this directory contains the following subdirectories:
* core: git checkout of mediawiki/core
* skins: directory of git checkouts of mediawiki/skin/*
* extensions: directory of git checkouts of mediawiki/extensions/*

These tools assume that there is another "mediawki" directory (SRV_MW_DIR), used by a webserver,
for testing changes made in the IDE. This directory must be synchronized prior to each attempt to
test functionality or run unit tests against it. 

Set DEV_MW_DIR and SRV_MW_DIR in ~/.bashrc (or similar).

<code>
export DEV_MW_DIR=/home/aaron/PhpstormProjects/mediawiki
export SRV_MW_DIR=/srv/mediawiki
</code>

## Win32/Linux command wrappers ##
A set of programs useful for making WSL faster by avoiding 9P file system I/O. They work by deciding 
which binary to use based on the current working directory. They do not carefully inspect the program
arguments to see what files are targeted. To avoid slowdown, avoid running them while the working 
directory is within an ntfs mount (e.g. /mnt/c/) when they need to operate on files inside a non-9P
mount (e.g. an "ext4" mount in the WSL VM).

Some of the wrappers always uses the Linux version if an argument starts with /proc, /run, ect...
The grep wrapper always uses the Linux version if the input is from a pipe (within WSL, launching
an exe is slower than a Linux program).

* composer: uses the Win32 exe if applicable and available, and the Linux version otherwise
* find: uses the "Git for Windows" exe if applicable and available, and the Linux version otherwise
* git: uses the "Git for Windows" exe if applicable and available, and the Linux version otherwise
* git-review: uses the PIP3 Win32 exe if applicable and available, and the Linux version otherwise
* grep: uses the "Git for Windows" version if applicable and available, and the Linux version otherwise

These programs can be enabled by creating symlinks within your "~/bin" folder, e.g.:

<code>
mkdir -p ~/bin
ln -s /path/to/mediawiki-developer-tools/smart_utils/* ~/bin/
</code>

## Mediawiki core utilities ##
A set of programs that can be run from the "core" MediaWiki repo directory.

* mediawiki-phpunit: runs phpunit.php (directly or via paratest)
* dev_phpunit: wrapper; runs phpunit in the "development" directory
* dev_paratest: wrapper; runs paratest in the "development" directory
* srv_phpunit: wrapper; runs phpunit in the "server" directory
* srv_paratest: wrapper; runs paratest on the "server" directory

These programs can be enabled by creating symlinks within the "core" repo folder, e.g.:

<code>
cd /path/to/mediawiki/core
ln -s /path/to/mediawiki-developer-tools/core_utils/* .
</code>

The test runners depends on paratest, which can be installed via:
<code>
git clone https://github.com/paratestphp/paratest.git
cd paratest
git checkout 5.0.4
sed -i.bak 's/"php": "^/"php": ">=/' composer.json
sed -i.bak 's/phpstan-banned-code": "^/phpstan-banned-code": ">=/' composer.json
composer.phar update
ln -s bin/paratest ~/bin/paratest
</code>

## Mediawiki extension utilities ##
A set of programs that can be run from either an "extensions" directory containing MediaWiki
extension repos, or, a "skins" containing MediaWiki skin repos. These directories should not be 
the same directories as the ones that appears under the "core" repo. The proper place for these
directories is under the "mediawiki" directory.

These programs can be enabled by creating symlinks within this extension folder, e.g.:

<code>
cd /path/to/mediawiki/extensions
ln -s /path/to/mediawiki-developer-tools/extension_utils/* .
</code>

### Syncing/pushing git repos ###
Some git/git-review utilities are included for doing mass operations.

* git-all: use this to clone, pull, or git-review the master branch of all gerrit-hosted extensions into the current folder
* git-wmf: use this to clone, pull, or git-review the master branch of all Wikimedia deployed, gerrit-hosted, extensions into the current folder 

Note:
At least when using Windows, it's best to set SSH connection keep-alive to avoid TCP connection spam in TIME_WAIT that can lead to exhaustion. E.g.:

<code>
Host gerrit.wikimedia.org
   KeepAlive yes
   ServerAliveInterval 60
</code>

Alternatively, using pageant and setting git to use plink.exe via core.sshCommand also works for sharing TCP connections.
Hardcoding the username in core.sshCommand means that SSH repo origin URLs do not need your username in them.
Note that GitHub SSH URLs require the username "git", so be careful when setting core.sshCommand with --global. 

<code>
git config core.sshCommand = "plink.exe -ssh -l YOUR_SSH_USERNAME -share -agent"
</code>

### Grepping git repos ###
Some grep wrappers are included for searching MediaWiki extension repos, of which there are 1000+.
The must be run in a folder called "extensions" that contains the extension repos.

* grep-all: searches all extension repos and groups output by repo
* grep-wmf: searches only extensions enabled on Wikimedia productions sites and groups output by repo 

## SystemD multi-instance MariaDB helpers ##
A set of scripts are included for quickly setting up replication on a single machine using mariadb.

* setup_multi_mariadb: setup db1, db2, db3, db4 instances using the mariadb@ SystemD template
* enable_replicated_multi_mariadb: make the db2,db3,db4 instances replicate from db1
* import_stock_mariadb: import stock mariadb instance data into the db1 instance

These scripts can be found in the /maria subdirectory.

## Other utilities ##
A set of programs that can be run from anywhere.

* sync-srv-mediawiki: This is a fast git/rsync based script to syncronize the MediaWiki directory used for serving content
with the one used by your IDE(s) for development. This is mostly useful when the server runs inside
WSL (with native file system access) but the IDE runs as a Win32 app that needs to heavily watch, stat,
and read thousands of files (requiring native file system access).
* mmariadb: Run mariadb, with the first argument passed as the --defaults-group-suffix option

These programs can be enabled by creating symlinks within the "~/bin" folder, e.g.:

<code>
mkdir -p ~/bin
ln -s /path/to/mediawiki-developer-tools/utils/* ~/bin/
</code>

## Convenience aliases for Bash ##
The bash_aliases script contains convenient shell terminal aliases for running common commands, e.g:
* YubiKey operations
* Git operations
* git-review operations
* Synchronizing the MediaWiki "server" directory to match the "development" directory

They can be enabled by editing ~/.bashrc, e.g.:

<code>
source /path/to/mediawiki-developer-tools/bash_aliases
</code>
