#!/bin/bash

# Config
repoBasePath='mediawiki/extensions/'
fakeBasePath='$IP/extensions/'
threads=8
operation=$1
summary=$2

# Sanity check the working directory to avoid making git checkout spam
# Note: this handles the case where the bash script is a symlink to the git repo version
REALPATH=$(pwd -P)
DIRECTORY=$(basename "$REALPATH")
if [ "$DIRECTORY" != "extensions" ]; then
	echo "pull-extensions must be run from 'extensions' directory"
	exit 1
fi

if [ -z "$operation" ]; then
	echo "Missing operation argument (pull, fetch)"
	exit 1
fi

rem_trailing_slash() {
    echo $1 | sed 's/\/*$//g'
}

pull_ext_repo() {
	PROJECT=$1
	if [ ! -d "${PROJECT}" ]; then
	    timeout 60 \
		git clone "ssh://gerrit.wikimedia.org:29418/${repoBasePath}${PROJECT}" && \
		cd "${PROJECT}" && \
		git checkout master && git pull && git submodule update && git config core.fileMode false
	else
		cd "${PROJECT}" && \
		git checkout master 2>/dev/null && git reset --hard master && \
		timeout 30 git pull && timeout 30 git submodule update
	fi
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
	    cd "${PROJECT}" && timeout 60 git remote update && git push -f && git reset --hard origin/master
	fi
}

reset_ext_repo() {
	PROJECT=$1
	if [ -d "${PROJECT}" ]; then
	    cd "${PROJECT}" && timeout 60 git reset --hard && git checkout master
	fi
}

clean_ext_repo() {
	PROJECT=$1
	if [ -d "${PROJECT}" ]; then
	    cd "${PROJECT}" && timeout 60 git reset --hard && git clean -xf
	fi
}

# Script to clone any missing extensions and updates the others
echo -n "Retrieving Wikimedia-deployed MediaWiki extension list..."
MODULES=($(curl -sL "https://raw.githubusercontent.com/wikimedia/operations-mediawiki-config/master/wmf-config/extension-list" | \
grep "${fakeBasePath}" | \
sed "s,${fakeBasePath},," | \
sed "s,/.*$,,"))
echo "done"

subprocs=0
for PROJECT in "${MODULES[@]}"; do
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
        info=$(reset_ext_repo "${PROJECT}")
    elif [ "$operation" == "clean" ]; then
        info=$(clean_ext_repo "${PROJECT}")
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
