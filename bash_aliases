#!/bin/bash
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
alias glog='~/bin/git log --dirstat --decorate --topo-order --no-merges --color=always'
alias gstatus='~/bin/git status'
alias gdiff,iw='~/bin/git diff -U20 --color=always --stat'
alias gvdiff,iw='~/bin/git difftool --color=always -yd'
alias gdiff,hi='~/bin/git diff -U20 --color=always --stat --cached'
alias gvdiff,hi='~/bin/git difftool --color=always --cached -yd'
alias gdiff,oh='~/bin/git diff -U20 --color=always --stat origin/HEAD..HEAD'
alias gvdiff,oh='~/bin/git difftool --color=always -yd origin/HEAD..HEAD'
alias gdiff,h='~/bin/git diff -U20 --color=always --stat HEAD^1..HEAD'
alias gvdiff,h='~/bin/git difftool --color=always -yd HEAD^1..HEAD'
alias gshow='~/bin/git show -U20 --color=always --stat'
alias gremoteupdate='~/bin/git fetch --all'
alias grebasemaster='~/bin/git fetch --all && ~/bin/git rebase origin/master'
alias grebasecontinue='~/bin/git rebase --continue'
alias grebaseabort='~/bin/git rebase --abort'
alias gsyncmaster='~/bin/git diff --exit-code --stat && ~/bin/git remote update && [[ "$(~/bin/git branch --show-current)" == 'master' ]] && ~/bin/git reset --hard origin/master'
alias gsyncprod='~/bin/git remote update origin && [[ "$(~/bin/git branch --show-current)" == 'production' ]] && ~/bin/git reset --hard origin/production'
alias gadd='~/bin/git add --interactive'
alias gcommit='~/bin/git add --interactive && git commit'
alias gamend='~/bin/git commit -a --amend'
alias greflog='~/bin/git reflog --pretty=short --date=iso'

# git-review
alias grpush='~/bin/git-review -fR'
alias grpushmaster='~/bin/git-review -R; if [ "$?" -eq 0 ]; then git reset --hard origin/master; fi'
alias grpushprod='~/bin/git-review -R; if [ "$?" -eq 0 ]; then git reset --hard origin/production; fi'
alias grdownload='~/bin/git-review -d $1'

# git/svn convenience
alias grep='grep --exclude-dir=".git" --exclude-dir=".svn"'

# git-based convenience (check for errors on local changes)
alias gphpcs='mapfile -t FLIST < <(~/bin/git log origin..HEAD -p --name-only --format= --diff-filter=d); if [ -n "${FLIST}" ]; then vendor/bin/phpcs -s -p --parallel=8 "${FLIST[@]}"; fi'
alias gphan='FLIST=$(~/bin/git log origin..HEAD -p --name-only --format= --diff-filter=d | sed -z "s/\n/,/g;s/,$/\n/"); if [ -n "${FLIST}" ]; then vendor/bin/phan -I "${FLIST}" -j8; fi'

# Convenience launcher for code quality
alias vphpcs='if [ ! -x vendor/bin/phpcs ]; then composer update; fi; vendor/bin/phpcs -p -s'
alias vphan='if [ ! -x vendor/bin/phan ]; then composer update; fi; vendor/bin/phan -j8'

# Win32 command locator (useful if ugly W10/WSL $PATH sharing is disable)
alias winwhere="/mnt/c/Windows/System32/where.exe"

# Fast OPCache-based PHP scripts
alias wphp='sudo -u www-data php'

# Convenience launcher for MediaWiki maintenance scripts
alias mwscript='sudo -u www-data --preserve-env=MW_DB php "${DEV_MW_DIR}/core/maintenance/run.php"'

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
