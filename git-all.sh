#!/bin/bash

# Config
basePath="mediawiki/extensions/"
scriptPath=$(readlink -f "$0")
scriptDir=$(dirname ${scriptPath})
curDir=$(readlink -f "$PWD")
threads=8
operation=$1
summary=$2

if [ "$scriptDir" != "$curDir" ]; then
	echo "pull-extensions must be run from $scriptDir; not $curDir"
	exit 1
fi

if [ -z "$operation" ]; then
	echo "Missing operation argument"
	exit 1
fi

rem_trailing_slash() {
    echo $1 | sed 's/\/*$//g'
}

pull_ext_repo() {
	PROJECT=$1
	if [ ! -d "${PROJECT}" ]; then
	    timeout 60 \
		git clone "https://gerrit.wikimedia.org/r/p/${basePath}${PROJECT}.git" "${PROJECT}" && \
		cd "${PROJECT}" \
		git remote set-url gerrit "ssh://gerrit.wikimedia.org:29418/${basePath}${PROJECT}" && \
		git checkout master && git pull && git submodule update
	else
		cd "${PROJECT}" && \
		git checkout master 2>/dev/null && git reset --hard master && \
		timeout 30 git pull && timeout 30 git submodule update
	fi
    git config core.filemode false
    git config core.fsCache true
    git config core.core.preloadindex true
}

commit_ext_repo() {
	PROJECT=$1
	SUMMARY=$2
	if [ -d "${PROJECT}" ]; then
	    cd "${PROJECT}"
		if [ -n $(git diff) ]; then
		    git commit -a -m "$SUMMARY"
        fi
	fi
}

push_ext_repo() {
	PROJECT=$1
	if [ -d "${PROJECT}" ]; then
	    cd "${PROJECT}"
		timeout 60 git remote update && git push -f && git reset --hard origin/master
	fi
}

reset_ext_repo() {
    BASEPATH=$1
	PROJECT=$2
	if [ -d "${PROJECT}" ]; then
	    cd "${PROJECT}"
	    git remote set-url origin "https://gerrit.wikimedia.org/r/p/${BASEPATH}${PROJECT}.git"
	    git remote set-url gerrit "ssh://gerrit.wikimedia.org:29418/${BASEPATH}${PROJECT}.git"
		timeout 60 git remote update && git checkout master
	fi
}

subprocs=0
# Script to clone any missing extensions and updates the others
curl -s "https://gerrit.wikimedia.org/r/projects/?format=text" | \
grep "^${basePath}" | \
sed "s,${basePath},," | \
while read PROJECT; do
    (
    PROJECT=$(rem_trailing_slash "${PROJECT}")

    if [ -f "${PROJECT}/IGNORE" ]; then
        echo "Skipping ${PROJECT}"
        continue
    fi

    if [ "$operation" == "pull" ]; then
        info=$(pull_ext_repo "${PROJECT}")
    elif [ "$operation" == "commit" ]; then
        info=$(commit_ext_repo "${PROJECT}" "${summary}")
    elif [ "$operation" == "push" ]; then
        info=$(push_ext_repo "${PROJECT}")
    elif [ "$operation" == "reset" ]; then
        echo "${basePath}" "${PROJECT}"
        info=$(reset_ext_repo "${basePath}" "${PROJECT}")
    else
        echo "Invalid operation: $operation."
        exit 1
    fi

	if [ $? -eq 0 ]; then
		echo "${PROJECT}: OK"
	else
		echo "${PROJECT}: FAILED ($?): $info"
	fi
	) &

    subprocs=$((subprocs + 1));
    if [ ${subprocs} -ge ${threads} ]; then
        wait
        subprocs=0
    fi
done
wait
