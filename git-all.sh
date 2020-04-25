#!/bin/bash

# Config
GERRIT_EXT_DIR="mediawiki/extensions/"
GERRIT_SSH_URL="ssh://gerrit.wikimedia.org:29418"
ALL_EXTS_URL="https://gerrit.wikimedia.org/r/projects/?format=text&b=master&p=mediawiki%2Fextensions%2F"
WMF_EXTS_URL="https://raw.githubusercontent.com/wikimedia/OPERATIONs-mediawiki-config/master/wmf-config/extension-list"
GITTILES_URL="https://gerrit.wikimedia.org/r/plugins/gitiles"
OPERATION=$1
SUMMARY=$2

# Sanity check the working directory to avoid making Git checkout spam
# Note: this handles the case where the bash script is a symlink to the Git repo version
REALPATH=$(pwd -P)
DIRECTORY=$(basename "$REALPATH")
if [ "$DIRECTORY" != "extensions" ]; then
	echo "pull-extensions must be run from 'extensions' directory"
	exit 1
fi

declare SCRIPT_BASENAME
SCRIPT_BASENAME=$(basename "$(realpath "$0")")
if [ -z "${OPERATION}" ]; then
	echo "Usage: ${SCRIPT_BASENAME} <pull|commit|push|reset|review|reset> [message]"
	exit 1
fi

function cmd_update_remote() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2

	if [ ! -d "./${REPO}/.git" ]; then
		repo_init_update_remote "${REPO}" "${REMOTE_ORIGIN_SHA1}"
	else
		repo_update_remote "${REPO}" "${REMOTE_ORIGIN_SHA1}"
	fi
}

function repo_init_update_remote() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	(
		set -e
		local BYPASSED

		BYPASSED=$(repo_bypass_creation_if_archived "${REPO}")
		[[ -z "${BYPASSED}" ]] || exit 0

		echo "Initializing ${REPO} to ${REMOTE_ORIGIN_SHA1}"

		mkdir -p "${REPO}"
		cd "./${REPO}"
		git init -q
		git config core.fileMode false
		git remote add origin "${GERRIT_SSH_URL}/${GERRIT_EXT_DIR}${REPO}"
		git remote update
		git checkout master -fq
		timeout 120 git submodule update --recursive --remote
	)
}

function repo_update_remote() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	(
		set -e
		local INDEX_SYNCED SALTED

		INDEX_SYNCED=$(head_matches_upstream_origin "${REPO}" "${REMOTE_ORIGIN_SHA1}")
		[[ -z "${INDEX_SYNCED}" ]] || exit 0

		SALTED=$(repo_salt_if_archived "${REPO}")
		[[ -z "${SALTED}" ]] || exit 0

		echo "Updating ${REPO} to ${REMOTE_ORIGIN_SHA1}"

		mkdir -p "${REPO}"
		cd "./${REPO}"
		git remote update
	)
}

function cmd_sync_origin_master() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2

	if [ ! -d "./${REPO}" ]; then
		repo_clone_checkout_master "${REPO}" "${REMOTE_ORIGIN_SHA1}"
	else
		repo_update_reset_origin_master "${REPO}" "${REMOTE_ORIGIN_SHA1}"
	fi
}

function repo_clone_checkout_master() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	(
		set -e
		local BYPASSED

		BYPASSED=$(repo_bypass_creation_if_archived "${REPO}")
		[[ -z "${BYPASSED}" ]] || exit 0

		timeout 120 git clone "${GERRIT_SSH_URL}/${GERRIT_EXT_DIR}${REPO}"

		cd "./${REPO}"
		git config core.fileMode false
		git checkout master -qf
		timeout 120 git submodule update --recursive --remote
	)
}

function repo_update_reset_origin_master() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	(
		set -e
		local INDEX_SYNCED SALTED

		INDEX_SYNCED=$(head_matches_upstream_origin "${REPO}" "${REMOTE_ORIGIN_SHA1}")
		[[ -z "${INDEX_SYNCED}" ]] || exit 0

		SALTED=$(repo_salt_if_archived "${REPO}")
		[[ -z "${SALTED}" ]] || exit 0

		echo "Updating ${REPO} to ${REMOTE_ORIGIN_SHA1}"

		cd "./${REPO}"
		CHANGES=$(git status -s --ignore-submodules --untracked-files=no | wc -l)
		[ "$CHANGES" -ge 0 ] || git stash
		timeout 60 git remote update
		git checkout master -qf
		git reset --hard origin/master
		timeout 60 git submodule update --init
	)
}

function cmd_commit() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	local SUMMARY=$3
	(
		set -e
		local CHANGES

		cd "./${REPO}"
		CHANGES=$(git status -s --ignore-submodules --untracked-files=no)
		if [ -n "${CHANGES}" ]; then
			git commit -a -m "${SUMMARY}"
		fi
	)
}

function cmd_push_and_reset_origin_master() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	(
		set -e
		local INDEX_SYNCED CHANGES

		INDEX_SYNCED=$(head_matches_upstream_origin "${REPO}" "${REMOTE_ORIGIN_SHA1}")
		[[ -z "${INDEX_SYNCED}" ]] || exit 0

		cd "./${REPO}"
		CHANGES=$(git log --oneline origin/master..HEAD)
		if [ -n "${CHANGES}" ]; then
			timeout 60 git remote update
			timeout 60 git push -f
			git reset --hard origin/master
		fi
	)
}

function cmd_review_and_reset_origin_master() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	(
		set -e
		local INDEX_SYNCED CHANGES

		INDEX_SYNCED=$(head_matches_upstream_origin "${REPO}" "${REMOTE_ORIGIN_SHA1}")
		[[ -z "${INDEX_SYNCED}" ]] || exit 0

		cd "./${REPO}"
		CHANGES=$(git log --oneline origin/master..HEAD | wc -l)
		if [ "${CHANGES}" -eq 1 ]; then
			timeout 60 git remote update
			timeout 60 git-review
			git reset --hard origin/master
		fi
	)
}

function cmd_reset_origin_master() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	(
		set -e
		local SALTED INDEX_SYNCED CHANGES VALID_GIT_REPO

		SALTED=$(repo_salt_if_archived "${REPO}")
		[[ -z "${SALTED}" ]] || exit 0

		# Note that REMOTE_ORIGIN_SHA1 might be higher than what is known in .git
		INDEX_SYNCED=$(head_matches_upstream_origin "${REPO}" "${REMOTE_ORIGIN_SHA1}")
		if [ -z "${INDEX_SYNCED}" ]; then
			# Check if the repo is in working condition
			echo -n "Checking integrity of ${REPO}..."
			VALID_GIT_REPO=$(check_git_repo_is_valid "${REPO}")
			echo "done"
			# Rebuild the entire Git repo if it got hosed somehow
			if [ -z "$VALID_GIT_REPO" ]; then
				echo -n "Repo ${REPO} is corrupt; removing..."
				rm -rf "./${REPO}/.git"
				echo 'done'
				repo_init_update_remote "${REPO}" "${REMOTE_ORIGIN_SHA1}"
				exit 0
			fi
		fi

		cd "./${REPO}"
		# Stash any working copy changes checkout/reset master
		CHANGES=$(git status -s --ignore-submodule --untracked-file=no | wc -l)
		[ "$CHANGES" -ge 0 ] || git stash
		if [ -z "${INDEX_SYNCED}" ]; then
			echo "Resetting ${REPO} to origin/master"
			git checkout master -qf
			git reset --hard origin/master
		fi
		timeout 15 git submodule foreach --recursive git clean -x -f -d
		timeout 15 git submodule foreach git reset --hard
	)
}

function cmd_gc() {
	local REPO=$1
	(
		set -e
		local SALTED INDEX_SYNCED CHANGES VALID_GIT_REPO

		SALTED=$(repo_salt_if_archived "${REPO}")
		[[ -z "${SALTED}" ]] || exit 0

		cd "./${REPO}"
		git gc
	)
}

function check_git_repo_is_valid() {
	local REPO=$1
	(
		set +e

		cd "./${REPO}" || exit $?
		git rev-parse HEAD 1>/dev/null || exit 0
		echo 1
	) 2>/dev/null

	exit 0
}

function head_matches_upstream_origin() {
	local REPO=$1
	local REMOTE_ORIGIN_SHA1=$2
	local LOCAL_ORIGIN_HEAD_FILE="${REPO}/.git/ORIG_HEAD"
	local LOCAL_HEAD_FILE="${REPO}/.git/HEAD"
	(
		set +e
		local LOCAL_ORIGIN_SHA1 LOCAL_HEAD

		[ -n "${REMOTE_ORIGIN_SHA1}" ] || exit 128

		# https://stackoverflow.com/a/46163991
		IFS= read -r -d '' LOCAL_HEAD <"$LOCAL_HEAD_FILE"
		[ "${LOCAL_HEAD//$'\n'/}" == 'ref: refs/heads/master' ] || exit 0

		# https://stackoverflow.com/a/46163991
		IFS= read -r -d '' LOCAL_ORIGIN_SHA1 <"$LOCAL_ORIGIN_HEAD_FILE"
		[ "${LOCAL_ORIGIN_SHA1//$'\n'/}" == "${REMOTE_ORIGIN_SHA1}" ] || exit 0

		echo 1
	) 2>/dev/null

	exit 0
}

function repo_salt_if_archived() {
	local REPO=$1
	(
		set +e

		if
			[ -f "./${REPO}/ARCHIVED" ] ||
			[ -f "./${REPO}/OBSOLETE" ] ||
			[ -f "./${REPO}/OBSOLETE.txt" ];
		then
			echo "Marked ${REPO} as ignored" >/dev/stderr
			rm -rf "./${REPO}/*"
			echo -n >"./${REPO}/IGNORE"
			echo 1
		fi
	)

	exit 0
}

function repo_bypass_creation_if_archived() {
	local REPO=$1
	local PREFIX="${GITTILES_URL}/${GERRIT_EXT_DIR}${REPO}/+/master/"
	(
		set +e

		declare -i COUNT
		COUNT=$(
			wget --method=HEAD --spider -S -nv \
				"${PREFIX}/ARCHIVED" \
				"${PREFIX}/OBSOLETE" \
				"${PREFIX}/OBSOLETE.txt" \
				2>&1 | grep -Pc '^\s*HTTP/\d(\.\d)?\s2\d\d\s'
		)
		if [ "$COUNT" -ge 1 ]; then
			echo "Marked ${REPO} as ignored" >/dev/stderr
			mkdir -p "${REPO}"
			echo -n >"./${REPO}/IGNORE"
			echo 1
		fi
	)

	exit 0
}

function get_upstream_extensions_wmf() {
	# Exclude nested repositories for directory layout sanity
	# shellcheck disable=SC2016
	curl -sL "${WMF_EXTS_URL}" |
		grep -P '^\$IP/extensions/[^/]+/[^/]+$' |
		awk -F/ '{print $3}'
}

function get_upstream_extensions_all() {
	# Exclude nested repositories for directory layout sanity
	curl -sL "${ALL_EXTS_URL}" |
		grep -P '^[a-f0-9]{40} mediawiki/extensions/[^/]+$' |
		awk -F'[/ ]' '{print $1 "|" $4}'
}

function git_command_all() {
	# Cannot exceed the server-side connection limits
	declare -i PROCESSORS=4

	declare -A REMOTE_SHA1_BY_REPO
	echo -n "Retrieving known MediaWiki extension list..."
	# shellcheck disable=SC2162
	while IFS='|' read -r sha1 name; do
		#echo "Found upstream repo '$name'"
		if [[ -v REMOTE_SHA1_BY_REPO[$name] ]]; then
			echo "Duplicate REMOTE_SHA1_BY_REPO entry '$name' (hazard)!"
			exit 1
		fi
		REMOTE_SHA1_BY_REPO[$name]="$sha1"
	done <<<"$(get_upstream_extensions_all)"
	echo "done"

	# Figure out which repos this command will actually affect
	declare -A REMOTE_SHA1_BY_TARGET_REPO
	if [ -n "${GIT_ALL_WMF_ONLY}" ]; then
		declare -a WMF_DEPLOYED_REPOS
		echo -n "Retrieving WMF-deployed MediaWiki extension list..."
		mapfile -t WMF_DEPLOYED_REPOS < <(get_upstream_extensions_wmf)
		for name in "${WMF_DEPLOYED_REPOS[@]}"; do
			if [[ ! -v REMOTE_SHA1_BY_REPO[$name] ]]; then
				echo "Missing REMOTE_SHA1_BY_REPO entry for '$name'!" >>/dev/stderr
				exit 1
			elif [[ -v REMOTE_SHA1_BY_TARGET_REPO[$name] ]]; then
				echo "Duplicate WMF_DEPLOYED_REPOS entry '$name'!" >>/dev/stderr
				exit 1
			fi
			#echo "Using repo '$name'"
			REMOTE_SHA1_BY_TARGET_REPO[$name]=${REMOTE_SHA1_BY_REPO[$name]}
		done
		echo "done"
	else
		for name in "${!REMOTE_SHA1_BY_REPO[@]}"; do
			REMOTE_SHA1_BY_TARGET_REPO[$name]=${REMOTE_SHA1_BY_REPO[$name]}
		done
	fi

	declare COMMAND
	case $OPERATION in
	"update")
		COMMAND='cmd_update_remote'
		;;
	"pull")
		COMMAND='cmd_sync_origin_master'
		;;
	"commit")
		COMMAND='cmd_commit'
		;;
	"push")
		COMMAND='cmd_push_and_reset_origin_master'
		;;
	"review")
		COMMAND='cmd_review_and_reset_origin_master'
		;;
	"reset")
		COMMAND='cmd_reset_origin_master'
		;;
	"gc")
		COMMAND='cmd_gc'
		;;
	*)
		echo "Invalid command: ${OPERATION}"
		exit 127
		;;
	esac

	set -m
	declare -i CHILD_JOB_COUNT=0
	trap "wait && exit" INT
	for REPO in "${!REMOTE_SHA1_BY_TARGET_REPO[@]}"; do
		if [ -f "./${REPO}/IGNORE" ]; then
			#echo "Skipping ${REPO} (IGNORE file)"
			continue
		fi

		(
			declare REMOTE_ORIGIN_SHA1=${REMOTE_SHA1_BY_TARGET_REPO[$REPO]}

			declare OUT
			OUT=$($COMMAND "${REPO}" "${REMOTE_ORIGIN_SHA1}" "${SUMMARY}" 2>&1)
			declare -i CODE=$?

			if [ $CODE -ne 0 ]; then
				echo -e "[${REPO}] FAILED (${CODE}):\n${OUT}"
			elif [ -n "${OUT}" ]; then
				echo -e "[${REPO}] OK:\n${OUT}"
			fi

			exit $CODE
		) &

		# Move on to the wait loop only if there are no open job slots.
		# Otherwise, immediately move on to the next repo.
		CHILD_JOB_COUNT=$((CHILD_JOB_COUNT + 1))
		while [ "$CHILD_JOB_COUNT" -ge "$PROCESSORS" ]; do
			wait -n
			# Try to ropgate SIGINT upward
			[ $! -ne 130 ] || exit $!
			CHILD_JOB_COUNT=$(jobs -r | wc -l)
		done
	done
	wait
}

git_command_all
