#!/bin/bash

W10_USER=$(/mnt/c/WINDOWS/system32/whoami.exe | grep -Po '[^\\]+$' | tr -d '\r')
WWW_USER="www-data"

W10_FIND_BIN="/mnt/c/Program Files/Git/usr/bin/find.exe"

W10_MEDIAWIKI="/mnt/c/Users/${W10_USER}/PhpstormProjects/mediawiki"
WSL_MEDIAWIKI="/srv/mediawiki"
W10_CORE="${W10_MEDIAWIKI}/core"
WSL_CORE="${WSL_MEDIAWIKI}/core"
W10_SKINS="${W10_MEDIAWIKI}/skins"
WSL_SKINS="${WSL_MEDIAWIKI}/skins"
W10_EXTENSIONS="${W10_MEDIAWIKI}/extensions"
WSL_EXTENSIONS="${WSL_MEDIAWIKI}/extensions"

declare -A MTIME_CACHE_W10
declare -A MTIME_CACHE_WSL

declare -i PROCESSORS
PROCESSORS=$(nproc)

function sync_project_code() {
	local SRC=$1
	local DST=$2
	local SRC_GIT_INDEX="${SRC}/.git/index"
	local DST_GIT_INDEX="${DST}/.git/index"
	local SRC_VENDOR="${SRC}/vendor"
	local DST_VENDOR="${DST}/vendor"
	local SRC_NPM="${SRC}/node_modules"
	local DST_NPM="${DST}/node_modules"

	local SRC_GIT_MTIME DST_GIT_MTIME
	local SRC_VENDOR_MTIME DST_VENDOR_MTIME
	local SRC_NODE_MTIME DST_NODE_MTIME

	SRC_GIT_MTIME=$(stat_file_w10 "${SRC_GIT_INDEX}")
	DST_GIT_MTIME=$(stat_file_wsl "${DST_GIT_INDEX}")
	if [ -z "${SRC_GIT_MTIME}" ]; then
		if [ -n "$(stat_file_w10 "${SRC}/IGNORE")" ]; then
			# Repo was removed from gerrit at some point
			exit 0
		else
			# There should be a .git directory and index
			echo "File not found: ${SRC_GIT_INDEX}" >/dev/stderr
			exit 1
		fi
	elif [ "${SRC_GIT_MTIME}" != "${DST_GIT_MTIME}" ]; then
		echo "${SRC} -> ${DST} (.git)"
		echo "Source: ${SRC_GIT_MTIME}; Destination: ${DST_GIT_MTIME}"
		sudo -u "${WWW_USER}" rsync -dq "${SRC}/" "${DST}" || exit 1
		sudo -u "${WWW_USER}" rsync -rltDiq "${SRC}/.git/" "${DST}/.git" || exit 1

		# Synchronize the destination using git commands
		(
			local CHANGES
			cd "${DST}" || exit 1
			CHANGES="$(sudo -u "${WWW_USER}" -H git status --porcelain --untracked-files=no)"
			if [ -n "${CHANGES}" ]; then
				echo "${SRC} -> ${DST} (checkout)"
				echo "${CHANGES}"
				# Reset working directory to git HEAD
				sudo -u "${WWW_USER}" -H git reset --hard 1>/dev/null || exit 1
				# Purge excess files (ignoring composer/npm and dirs with a .git dir)
				sudo -u "${WWW_USER}" -H git clean -xfd \
					--exclude='vendor/**' --exclude='node_modules/**' --exclude='*Settings.php' \
					1>/dev/null || exit 1
			fi
		) || exit 1

		# Mark git/working directory as updated
		sudo -u "${WWW_USER}" touch -m --date "${SRC_GIT_MTIME}" "${DST}/.git/index"
	fi

	# Synchronize composer files that are not in the git repo
	SRC_VENDOR_MTIME=$(stat_file_w10 "${SRC_VENDOR}")
	if [ -n "${SRC_VENDOR_MTIME}" ]; then
		DST_VENDOR_MTIME=$(stat_file_wsl "${DST_VENDOR}")
		if [ "${SRC_VENDOR_MTIME}" != "${DST_VENDOR_MTIME}" ]; then
			echo "${SRC} -> ${DST} (vendor)"
			echo "Source: ${SRC_VENDOR_MTIME}; Destination: ${DST_VENDOR_MTIME}"
			sudo -u "${WWW_USER}" rsync -rltDiq "${SRC_VENDOR}/" "${DST_VENDOR}" || exit 1
			sudo -u "${WWW_USER}" touch -m --date "${SRC_VENDOR_MTIME}" "${DST_VENDOR}" || exit 1
		fi
	fi

	# Synchronize NPM files that are not in the git repo
	SRC_NODE_MTIME=$(stat_file_w10 "${SRC_NPM}")
	if [ -n "${SRC_NODE_MTIME}" ]; then
		DST_NODE_MTIME=$(stat_file_wsl "${DST_NPM}")
		if [ "${SRC_NODE_MTIME}" != "${DST_NODE_MTIME}" ]; then
			echo "${SRC} -> ${DST} (node_modules)"
			echo "Source: ${SRC_NODE_MTIME}; Destination: ${DST_NODE_MTIME}"
			sudo -u "${WWW_USER}" rsync -rltDiq "${SRC_NPM}/" "${DST_NPM}" || exit 1
			sudo -u "${WWW_USER}" touch -m --date "${SRC_NODE_MTIME}" "${DST_NPM}" || exit 1
		fi
	fi
}

function sync_dir_subprojects() {
	local SRC=$1
	local DST=$2
	shift 2
	local PROJECT_NAMES=("$@")

	local SRC_PROJECT_ROOT DST_PROJECT_ROOT

	prestat_dir_projects "${SRC}" "${DST}" "${PROJECT_NAMES[@]}" || exit 1

	set -m
	declare -i CHILD_JOB_COUNT=0
	trap "wait && exit" INT
	for PROJECT_NAME in "${PROJECT_NAMES[@]}"; do
		SRC_PROJECT_ROOT="${SRC}/${PROJECT_NAME}"
		DST_PROJECT_ROOT="${DST}/${PROJECT_NAME}"
		sync_project_code "${SRC_PROJECT_ROOT}" "${DST_PROJECT_ROOT}" &
		CHILD_JOB_COUNT=$((CHILD_JOB_COUNT + 1))
		if [ ${CHILD_JOB_COUNT} -ge "${PROCESSORS}" ]; then
			wait -n
			CHILD_JOB_COUNT=$(jobs -r | wc -l)
		fi
	done
	wait
}

function prestat_dir_projects() {
	local SRC=$1
	local DST=$2
	shift 2
	local PROJECT_NAMES=("$@")
	local SRC_NO_MNT="${SRC/#\/mnt\//\/}"

	local SRC_PROJECT DST_PROJECT FILE_PATH

	# Initialize a NULL last-modified timestamp for each NTFS file to stat
	for PROJECT_NAME in "${PROJECT_NAMES[@]}"; do
		SRC_PROJECT="${SRC}/${PROJECT_NAME}"
		MTIME_CACHE_W10["${SRC_PROJECT}/.git/index"]=""
		MTIME_CACHE_W10["${SRC_PROJECT}/vendor"]=""
		MTIME_CACHE_W10["${SRC_PROJECT}/node_modules"]=""
		MTIME_CACHE_W10["${SRC_PROJECT}/IGNORE"]=""

		DST_PROJECT="${DST}/${PROJECT_NAME}"
		MTIME_CACHE_WSL["${DST_PROJECT}/.git/index"]=""
		MTIME_CACHE_WSL["${DST_PROJECT}/vendor"]=""
		MTIME_CACHE_WSL["${DST_PROJECT}/node_modules"]=""
	done

	# Preload the last-modified timestamp for each of these source files that exist
	while IFS="|" read -r relative_path last_modified; do
		FILE_PATH="${SRC}/${relative_path}"
		#echo "StatLoad [${FILE_PATH}] = ${last_modified}"
		MTIME_CACHE_W10[$FILE_PATH]="${last_modified}"
	done < <(
		"${W10_FIND_BIN}" "${SRC_NO_MNT}" \
		-mindepth 2 -maxdepth 3 \
		\( \
			-path "\*/.git/index" -o \
			-path "\*/vendor" -o \
			-path "\*/node_modules" -o \
			-path "\*/IGNORE" \
		\) \
		-printf "%P|%TT\n" 2>/dev/null
	)
	# Preload the last-modified timestamp for each of these destination files that exist
	while IFS="|" read -r relative_path last_modified; do
		FILE_PATH="${DST}/${relative_path}"
		#echo "StatLoad [${FILE_PATH}] = ${last_modified}"
		MTIME_CACHE_WSL[$FILE_PATH]="${last_modified}"
	done < <(
		find "${DST}" \
		-mindepth 2 -maxdepth 3 \
		\( \
			-path "*/.git/index" -o \
			-path "*/vendor" -o \
			-path "*/node_modules" \
		\) \
		-printf "%P|%TT\n" 2>/dev/null
	)
}

function sync_project_config() {
	local SRC=$1
	local DST=$2

	sudo -u "${WWW_USER}" rsync -rltDiq --include '*Settings.php' --exclude '*' "${SRC}/" "${DST}/"
}

function stat_file_w10() {
	local FILE_PATH=$1

	local MTIME
	if [[ -v MTIME_CACHE_W10[$FILE_PATH] ]]; then
		MTIME="${MTIME_CACHE_W10[$FILE_PATH]}"
	else
		# Note that find.exe is slower if no batching is used
		MTIME=$(find "${FILE_PATH}" -maxdepth 0 -printf "%TT" 2>/dev/null)
		echo "StatMiss [${FILE_PATH}] = ${MTIME}" >/dev/stderr
	fi

	echo "${MTIME}"
}

function stat_file_wsl() {
	local FILE_PATH=$1

	local MTIME
	if [[ -v MTIME_CACHE_WSL[$FILE_PATH] ]]; then
		MTIME="${MTIME_CACHE_WSL[$FILE_PATH]}"
	else
		MTIME=$(find "${FILE_PATH}" -maxdepth 0 -printf "%TT" 2>/dev/null)
		echo "StatMiss [${FILE_PATH}] = ${MTIME}" >/dev/stderr
	fi

	echo "${MTIME}"
}

set -m
trap "wait && exit" INT
(
	prestat_dir_projects "${W10_MEDIAWIKI}" "${WSL_MEDIAWIKI}" "core" || exit 1
	sync_project_code "${W10_CORE}" "${WSL_CORE}" &&
		sync_project_config	"${W10_CORE}" "${WSL_CORE}"
) &
(
	readarray -t SKIN_REPO_NAMES < <(dir -U1 "${W10_SKINS}" | grep -v "\.")
	sudo -u "${WWW_USER}" \
		rsync -dq "${W10_SKINS}/" "${WSL_SKINS}" &&
		sync_dir_subprojects "${W10_SKINS}" "${WSL_SKINS}" "${SKIN_REPO_NAMES[@]}"
) &
(
	readarray -t EXTENSION_REPO_NAMES < <(dir -U1 "${W10_EXTENSIONS}" | grep -v "\.")
	sudo -u "${WWW_USER}" \
		rsync -dq "${W10_EXTENSIONS}/" "${WSL_EXTENSIONS}" &&
		sync_dir_subprojects "${W10_EXTENSIONS}" "${WSL_EXTENSIONS}" "${EXTENSION_REPO_NAMES[@]}"
) &
wait
