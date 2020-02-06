#!/bin/bash

W10_USER=$(/mnt/c/WINDOWS/system32/whoami.exe | grep -Po '[^\\]+$' | tr -d '\r')
WWW_USER="www-data"

W10_MEDIAWIKI="/mnt/c/Users/${W10_USER}/PhpstormProjects/mediawiki"
WSL_MEDIAWIKI="/srv/mediawiki"
W10_CORE="${W10_MEDIAWIKI}/core"
WSL_CORE="${WSL_MEDIAWIKI}/core"
W10_SKINS="${W10_MEDIAWIKI}/skins"
WSL_SKINS="${WSL_MEDIAWIKI}/skins"
W10_EXTENSIONS="${W10_MEDIAWIKI}/extensions"
WSL_EXTENSIONS="${WSL_MEDIAWIKI}/extensions"

CATEGORY=$1

sync_project() {
  local SRC=$1
  local DST=$2

  local SRC_GIT_MTIME=$(stat -c %y "${SRC}/.git/index" 2>/dev/null)
  local DST_GIT_MTIME=$(stat -c %y "${DST}/.git/index" 2>/dev/null)
  local SRC_VENDOR_MTIME=$(stat -c %y "${SRC}/vendor" 2>/dev/null)
  local DST_VENDOR_MTIME=$(stat -c %y "${SRC}/vendor" 2>/dev/null)
  local SRC_NODE_MTIME=$(stat -c %y "${SRC}/node_modules" 2>/dev/null)
  local DST_NODE_MTIME=$(stat -c %y "${SRC}/node_modules" 2>/dev/null)

  if [ -n "${SRC_GIT_MTIME}" ] && [ "${SRC_GIT_MTIME}" != "${DST_GIT_MTIME}" ]; then
    echo "${SRC} -> ${DST} (.git)"
    echo "Source: ${SRC_GIT_MTIME}; Destination: ${DST_GIT_MTIME}"
    rsync -dq --chown "${WWW_USER}" "${SRC}/" "${DST}" &&
    rsync -rltDiq --chown "${WWW_USER}" "${SRC}/.git/" "${DST}/.git"

    (
      cd "${DST}" || exit 1
      local DIFFERENCE="$(sudo -u "${WWW_USER}" git status --porcelain --untracked-files=no)"
      if [ -n "${DIFFERENCE}" ]; then
        echo "${SRC} -> ${DST} (checkout)"
        echo "${DIFFERENCE}"
        # Set owner/permissions
        sudo chown -R "${WWW_USER}" .
        # Reset working directory to git HEAD
        sudo -u "${WWW_USER}" git reset --hard 1>/dev/null &&
        # Purge excess files (ignoring composer/npm and dirs with a .git dir)
        sudo -u "${WWW_USER}" git clean -xfd --exclude='vendor/**' --exclude='node_modules/**' --exclude='*Settings.php' 1>/dev/null
      fi
    ) || return 1

    # Mark git/working directory as updated
    touch -m --date "${SRC_GIT_MTIME}" "${DST}/.git/index"
  fi

  if [ -n "${SRC_VENDOR_MTIME}" ] && [ "${SRC_VENDOR_MTIME}" != "${DST_VENDOR_MTIME}" ]; then
    echo "${SRC} -> ${DST} (vendor)"
    echo "Source: ${SRC_VENDOR_MTIME}; Destination: ${DST_VENDOR_MTIME}"
    rsync -rltDiq --chown "${WWW_USER}" "${SRC}/vendor/" "${DST}/vendor" &&
    touch -m --date "${SRC_VENDOR_MTIME}" "${DST}/vendor"
  fi

  if [ -n "${SRC_NODE_MTIME}" ] && [ "${SRC_NODE_MTIME}" != "${DST_NODE_MTIME}" ]; then
    echo "${SRC} -> ${DST} (node_modules)"
    echo "Source: ${SRC_NODE_MTIME}; Destination: ${DST_NODE_MTIME}"
    rsync -rltDiq --chown "${WWW_USER}" "${SRC}/node_modules/" "${DST}/node_modules" &&
    touch -m --date "${SRC_NODE_MTIME}" "${DST}/node_modules"
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

(
sync_project "${W10_CORE}" "${WSL_CORE}" &&
rsync -rltDiq --include '*Settings.php' --exclude '*' --chown "${WWW_USER}" "${W10_CORE}/" "${WSL_CORE}/"
) &

SKIN_NAMES=($(find "${W10_SKINS}/"* -maxdepth 0 -type d -printf "%f\n"))
(
rsync -dq --chown "${WWW_USER}" "${W10_SKINS}/" "${WSL_SKINS}" &&
sync_subprojects "${W10_SKINS}" "${WSL_SKINS}" "${SKIN_NAMES[@]}"
) &

if [ "$CATEGORY" == "wmf" ]; then
  CACHE_FILE="${W10_EXTENSIONS}/.wmf-extensions.list.cache"
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
  EXTENSION_NAMES=($(find "${W10_EXTENSIONS}/"* -maxdepth 0 -type d -printf "%f\n"))
fi
(
rsync -dq --chown "${WWW_USER}" "${W10_EXTENSIONS}/" "${WSL_EXTENSIONS}" &&
sync_subprojects "${W10_EXTENSIONS}" "${WSL_EXTENSIONS}" "${EXTENSION_NAMES[@]}"
) &

wait
exit
