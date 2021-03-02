# YubiKey
export OPENSC='/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so'
function yubiadd() {
	ssh-add -s $OPENSC
}
function yubidel() {
	ssh-add -e $OPENSC
}
function yubireset() {
	yubidel
	yubiadd
}

# git
alias fast_git='~/bin/git'
alias glog='fast_git log --dirstat --decorate --color=always'
alias gstatus='fast_git status'
alias gdiffunstaged='fast_git diff -U20 --color=always'
alias gvdiffunstaged='fast_git difftool -yd --color=always'
alias gdiffstaged='fast_git diff -U20 --cached --color=always'
alias gvdiffstaged='fast_git difftool --cached -yd --color=always'
alias gdiffhead='fast_git diff -U20 --color=always HEAD^1..HEAD'
alias gvdiffhead='fast_git difftool -yd --color=always HEAD^1..HEAD'
alias gshow='fast_git show -U20 --color=always'
alias gremoteupdate='fast_git fetch --all'
alias grebasemaster='fast_git rebase origin/master'
alias grebaseoriginmaster='fast_git fetch --all && fast_git rebase origin/master'
alias grebasecontinue='fast_git rebase --continue'
alias grebaseabort='fast_git rebase --abort'
alias gsyncmaster='fast_git remote update && fast_git reset --hard origin/master'
alias gsyncprod='fast_git remote update && fast_git reset --hard origin/production'
alias gadd='fast_git add --interactive'
alias gcommit='fast_git commit'
alias gamend='fast_git commit -a --amend'

# git-review
alias smart_git-review='~/bin/git-review'
alias grpush='smart_git-review -fR'
alias grpushmaster='smart_git-review -R; if [ "$?" -eq 0 ]; then git reset --hard origin/master; fi'
alias grpushprod='smart_git-review -R; if [ "$?" -eq 0 ]; then git reset --hard origin/production; fi'
alias grdownload='smart_git-review -d $1'

# git/svn convenience
alias grep='grep --exclude-dir=".git" --exclude-dir=".svn"'

# git-based convenience
alias gphpcs='fast_git diff --name-only --oneline origin/master..HEAD | xargs -d '\n' phpcs -p -s'

# Win32 command locator (useful if ugly W10/WSL $PATH sharing is disable)
alias winwhere="/mnt/c/Windows/System32/where.exe"

# Fast OPCache-based PHP scripts
alias wphp='sudo -u www-data php -d opcache.file_cache=/opcache/php7 -d opcache.file_cache_only=1'

# Convenience wrapper to synchronize /srv/mediawiki with PhpStormProjects/mediawiki
alias syncsrvmediawiki="sudo -u www-data --preserve-env=DEV_MW_DIR,SRV_MW_DIR ${HOME}/bin/sync-srv-mediawiki"

# Convenience launchers for common editors
function pnotepad {
	WSLPATH=$(wslpath -w "$1")
	/mnt/c/Program\ Files\ \(x86\)/Programmer\'s\ Notepad/pn.exe "$WSLPATH"
}
function komodoedit {
	WSLPATH=$(wslpath -w "$1")
	/mnt/c/Program\ Files\ \(x86\)/ActiveState\ Komodo\ Edit\ 12/komodo.exe "$WSLPATH"
}
function notepadpp {
	WSLPATH=$(wslpath -w "$1")
	/mnt/c/Program\ Files\ \(x86\)/Notepad++/notepad++.exe "$WSLPATH"
}
