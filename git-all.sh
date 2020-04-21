#!/bin/bash

# Config
base_dir="mediawiki/extensions/"
gitiles_url="https://gerrit.wikimedia.org/r/plugins/gitiles"
threads=4
operation=$1
summary=$2
# Support ~/git exe that uses /usr/bin/git or git.exe based on path
if [ -x ~/git ]; then
  git_bin=~/git
else
  git_bin=git
fi
# Sanity check the working directory to avoid making git checkout spam
# Note: this handles the case where the bash script is a symlink to the git repo version
REALPATH=$(pwd -P)
DIRECTORY=$(basename "$REALPATH")
if [ "$DIRECTORY" != "extensions" ]; then
	echo "pull-extensions must be run from 'extensions' directory"
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
	local PROJECT=$1
	if [ ! -d "${PROJECT}" ]; then
	  if \
	    wget -q --method=HEAD "${gitiles_url}/${base_dir}${PROJECT}/+/master/OBSOLETE" || \
	    wget -q --method=HEAD "${gitiles_url}/${base_dir}${PROJECT}/+/master/OBSOLETE.txt"
	  then
	    echo "Marking ${PROJECT} as ignored"
	    mkdir "${PROJECT}" && echo -n > "${PROJECT}/IGNORE"
	    exit 0
    fi

		timeout 60 $git_bin clone "ssh://gerrit.wikimedia.org:29418/${base_dir}${PROJECT}" && \
		cd "${PROJECT}" && \
		$git_bin config core.fileMode false && \
		$git_bin checkout master && \
		timeout 60 $git_bin submodule update --init --recursive
	else
		cd "${PROJECT}" && \
		timeout 30 $git_bin remote update && \
		$git_bin checkout master 2>/dev/null && \
		$git_bin reset --hard origin/master && \
		timeout 30 $git_bin submodule update --recursive
	fi
}

commit_ext_repo() {
	local PROJECT=$1
	local SUMMARY=$2
	if [ -d "${PROJECT}" ] && cd "${PROJECT}"; then
		if [ -n "$($git_bin status --porcelain)" ]; then
		  $git_bin commit -a -m "$SUMMARY"
    fi
	fi
}

push_ext_repo() {
	local PROJECT=$1
	if [ -d "${PROJECT}" ] && cd "${PROJECT}"; then
    local CHANGES=$($git_bin log origin/master..HEAD)
    if [ -n "${CHANGES}" ]; then
      echo $CHANGES
      timeout 60 $git_bin remote update && \
      timeout 60 $git_bin push -f && \
      $git_bin reset --hard origin/master
		fi
	fi
}

review_ext_repo() {
	local PROJECT=$1
	if [ -d "${PROJECT}" ] && cd "${PROJECT}"; then
    local CHANGES=$($git_bin log origin/master..HEAD)
    if [ -n "${CHANGES}" ]; then
      echo $CHANGES
      timeout 60 $git_bin remote update && \
      timeout 60 git-review && \
      $git_bin reset --hard origin/master
		fi
	fi
}

reset_ext_repo() {
	local PROJECT=$1
	if [ -d "${PROJECT}" ] && cd "${PROJECT}"; then
		$git_bin config core.fileMode false && \
    $git_bin remote set-url origin "ssh://gerrit.wikimedia.org:29418/${base_dir}${PROJECT}" && \
		$git_bin reset --hard && \
		$git_bin checkout master 2>/dev/null

		if [ -f "./OBSOLETE" ] || [ -f "./OBSOLETE.txt" ]; then
	    echo "Marking ${PROJECT} as ignored"
	    rm -rf ./* && echo -n > "./IGNORE"
    fi
	fi
}

# Script to clone any missing extensions and updates the others
if [ -n "${GIT_ALL_WMF_ONLY}" ]; then
  fakebase_dir='$IP/extensions/'
  echo -n "Retrieving Wikimedia-deployed MediaWiki extension list..."
  MODULES=($(curl -sL "https://raw.githubusercontent.com/wikimedia/operations-mediawiki-config/master/wmf-config/extension-list" | \
  grep "${fakebase_dir}" | \
  sed "s,${fakebase_dir},," | \
  sed "s,/.*$,,"))
  echo "done"
else
  echo -n "Retrieving known MediaWiki extension list..."
  MODULES=($(curl -s "https://gerrit.wikimedia.org/r/projects/?format=text" | \
  grep "^${base_dir}" | \
  sed "s,${base_dir},,"))
  echo "done"
fi

subprocs=0
for PROJECT in "${MODULES[@]}"; do
    PROJECT=$(rem_trailing_slash "${PROJECT}")
    if [ -f "${PROJECT}/IGNORE" ]; then
      echo "Skipping ${PROJECT}"
      continue
    fi

    (
    if [ "$operation" == "pull" ]; then
      info=$(pull_ext_repo "${PROJECT}")
    elif [ "$operation" == "commit" ]; then
      info=$(commit_ext_repo "${PROJECT}" "${summary}")
    elif [ "$operation" == "push" ]; then
      info=$(push_ext_repo "${PROJECT}")
    elif [ "$operation" == "review" ]; then
      info=$(review_ext_repo "${PROJECT}")
    elif [ "$operation" == "reset" ]; then
      info=$(reset_ext_repo "${PROJECT}")
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
