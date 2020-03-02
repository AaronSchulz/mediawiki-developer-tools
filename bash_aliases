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
alias gdiff='fast_git diff -U20 --color=always'
alias gshow='fast_git show -U20 --color=always'
alias gstatus='fast_git status'
alias glog='fast_git log --dirstat --decorate --color=always'
alias gremoteupdate='fast_git remote update'
alias grebasemaster='fast_git rebase origin/master'
alias grebasecontinue='fast_git rebase --continue'
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

alias grep='grep --exclude-dir=".git"'

alias wphp='sudo -u www-data php'
