#!/bin/bash

W10_USER=$(/mnt/c/WINDOWS/system32/whoami.exe | grep -Po '[^\\]+$' | tr -d '\r')
W10_CORE="/mnt/c/Users/${W10_USER}/PhpstormProjects/wsl_core"
WSL_CORE="${HOME}/OSS/core";
CATEGORY=$1

sync_project() {
  local SRC=$1
  local DST=$2

  SAVEIFS=$IFS
  IFS=$'\n'
  local MTIMES=($(stat -c %y "${SRC}/.git/index" "${DST}/.git/index"  2>/dev/null))
  local SRC_GIT_MTIME=${MTIMES[0]}
  local DST_GIT_MTIME=${MTIMES[1]}
  local MTIMES=($(stat -c %y "${SRC}/vendor" "${DST}/vendor" 2>/dev/null))
  local SRC_VENDOR_MTIME=${MTIMES[0]}
  local DST_VENDOR_MTIME=${MTIMES[1]}
  local MTIMES=($(stat -c %y "${SRC}/node_modules" "${DST}/node_modules" 2>/dev/null))
  local SRC_NODE_MTIME=${MTIMES[0]}
  local DST_NODE_MTIME=${MTIMES[1]}
  IFS=$SAVEIFS

  if [ -n "${SRC_GIT_MTIME}" ] && [ "${SRC_GIT_MTIME}" != "${DST_GIT_MTIME}" ]; then
    echo "${SRC} -> ${DST} (.git)"
    echo "Source: ${SRC_GIT_MTIME}; Destination: ${DST_GIT_MTIME}"
    rsync -dq "${SRC}/" "${DST}" && rsync -rltDoiq "${SRC}/.git/" "${DST}/.git"

    (
      cd "${DST}" || exit 1
      if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        echo "${SRC} -> ${DST} (checkout)"
        git status --porcelain --untracked-files=no
        # Reset working directory to git HEAD
        git reset --hard 1>/dev/null &&
        # Purge excess files (ignoring composer/npm and dirs with a .git dir)
        git clean -xfd --exclude='vendor/**' --exclude='node_modules/**' 1>/dev/null
      fi
    ) || return 1

    # Mark git/working directory as updated
    touch -m --date="${SRC_GIT_MTIME}" "${DST}/.git/index"
  fi

  if [ -n "${SRC_VENDOR_MTIME}" ] && [ "${SRC_VENDOR_MTIME}" != "${DST_VENDOR_MTIME}" ]; then
    echo "${SRC} -> ${DST} (vendor)"
    echo "Source: ${SRC_VENDOR_MTIME}; Destination: ${DST_VENDOR_MTIME}"
    rsync -rltDoiq "${SRC}/vendor/" "${DST}/vendor" &&
    touch -m --date="${SRC_VENDOR_MTIME}" "${DST}/vendor"
  fi

  if [ -n "${SRC_NODE_MTIME}" ] && [ "${SRC_NODE_MTIME}" != "${DST_NODE_MTIME}" ]; then
    echo "${SRC} -> ${DST} (node_modules)"
    echo "Source: ${SRC_NODE_MTIME}; Destination: ${DST_NODE_MTIME}"
    rsync -rltDoiq "${SRC}/node_modules/" "${DST}/node_modules" &&
    touch -m --date="${SRC_NODE_MTIME}" "${DST}/node_modules"
  fi
}

sync_subprojects() {
  local PROCESSORS=8
  local SRC=$1
  local DST=$2
  shift 2
  local PROJECT_NAMES=("$@")

  for PROJECT_NAME in "${PROJECT_NAMES[@]}"; do
    local SRC_PROJECT_ROOT="${SRC}/${PROJECT_NAME}"
    local DST_PROJECT_ROOT="${DST}/${PROJECT_NAME}"
    sync_project "${SRC_PROJECT_ROOT}" "${DST_PROJECT_ROOT}" &
    while [ "$(jobs -r | wc -l)" -ge "${PROCESSORS}" ]; do
       wait -n
    done
  done
  wait
}

trap "wait && exit" INT

sync_project "${W10_CORE}" "${WSL_CORE}" &

rsync -dq "${W10_CORE}/skins/" "${WSL_CORE}/skins"
SKIN_NAMES=($(find "${W10_CORE}/skins/"* -maxdepth 0 -type d -printf "%f\n"))
sync_subprojects "${W10_CORE}/skins" "${WSL_CORE}/skins" "${SKIN_NAMES[@]}" &

if [ "$CATEGORY" == "wmf" ]; then
  CACHE_FILE="${W10_CORE}/extensions/.wmf-extensions.list.cache"
  if ! test `find "${CACHE_FILE}" -mmin -86400`; then
    echo -n "Retrieving Wikimedia-deployed MediaWiki extension list..."
    PATH_PREFIX='$IP/extensions/'
    curl -sL "https://raw.githubusercontent.com/wikimedia/operations-mediawiki-config/master/wmf-config/extension-list" | \
    grep "${PATH_PREFIX}" | \
    sed "s,${PATH_PREFIX},," | \
    sed "s,/.*$,," > "${CACHE_FILE}"
    echo "done"
  fi
  EXTENSION_NAMES=($(cat "${CACHE_FILE}"))
else
  EXTENSION_NAMES=($(find "${W10_CORE}/extensions/"* -maxdepth 0 -type d -printf "%f\n"))
fi
rsync -dq "${W10_CORE}/extensions/" "${WSL_CORE}/extensions"
sync_subprojects "${W10_CORE}/extensions" "${WSL_CORE}/extensions" "${EXTENSION_NAMES[@]}" &

rsync -rltDoiq --include '*Settings.php' --exclude '*' "${W10_CORE}/" "${WSL_CORE}/" &

wait
exit
