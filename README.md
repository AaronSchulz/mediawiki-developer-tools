# mediawiki-developer-tools
A collection of utilities for assisting basic MediaWiki development tasks

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

## Mediawiki extension utilities ##
A set of programs that can be run from an "extensions" directory that contains MediaWiki extension repos.
This is not same directory as the one that appears under the "core" repo.

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

## Other utilities ##
These programs can be enabled by creating symlinks within the "~/bin" folder, e.g.:

<code>
mkdir -p ~/bin
ln -s /path/to/mediawiki-developer-tools/utils/* ~/bin/
</code>

* sync-wsl-mediawiki: This is a fast git/rsync based script to syncronize the MediaWiki directory used for serving content
with the one used by your IDE(s) for development. This is mostly useful when the server runs inside
WSL (with native file system access) but the IDE runs as a Win32 app that needs to heavily watch, stat,
and read thousands of files (requiring native file system access).

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