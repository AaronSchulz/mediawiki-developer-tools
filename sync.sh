#!/bin/bash

W10_CORE="/mnt/c/Users/aschu/PhpstormProjects/wsl_core"
WSL_CORE="/home/aaron/OSS/core";
CATEGORY=$1

sync_project() {
  local SRC=$1
  local DST=$2

  [ -d "${SRC}/.git/" ] || return 0

  # Short-circuit
  local SRC_MTIME=$(stat -c %y "${SRC}")
  local DST_MTIME=$(stat -c %y "${DST}")
  [ "${SRC_MTIME}" != "${DST_MTIME}" ] || return 0
  # Ignore irrelevant timestamp changes on .git and .git/index
  echo "${SRC} -> ${DST} (.git)"
  echo "${SRC_MTIME} -> ${DST_MTIME}"
  local FLIST=$(rsync -rltDi "${SRC}/.git/" "${DST}/.git" | grep -vP ' (\./|index)$')
  if [ -n "${FLIST}" ]; then
    echo "${FLIST}"
    if ! cd "${DST}"; then
      echo "Could not cd into ${DST}"
      return 1;
    fi

    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
      echo "${SRC} -> ${DST} (checkout)"
      git reset --hard 1>/dev/null
    fi
  fi
  # Mark directory as updated
  touch -m --date="${SRC_MTIME}" "${DST}"

  if [ -f "${SRC}/composer.lock" ]; then
    SRC_VENDOR_MTIME=$(stat -c %y "${SRC}/vendor")
    DST_VENDOR_MTIME=$(stat -c %y "${DST}/vendor")
    if [ "${SRC_VENDOR_MTIME}" != "${DST_VENDOR_MTIME}" ]; then
      echo "${SRC} -> ${DST} (vendor)"
      echo "${SRC_VENDOR_MTIME} -> ${DST_VENDOR_MTIME}"
      rsync -rltDi "${SRC}/vendor/" "${DST}/vendor" &&
      touch -m --date="${SRC_MTIME}" "${DST}/vendor"
    fi
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

trap "exit" INT

sync_project "${W10_CORE}" "${WSL_CORE}" &
sync_subprojects "${W10_CORE}" "${WSL_CORE}" "skins" &

if [ "$CATEGORY" == "wmf" ]; then
  if ! test `find ".wmf-extensions.list.cache" -mmin -86400`; then
    echo -n "Retrieving Wikimedia-deployed MediaWiki extension list..."
    PATH_PREFIX='$IP/extensions/'
    curl -sL "https://raw.githubusercontent.com/wikimedia/operations-mediawiki-config/master/wmf-config/extension-list" | \
    grep "${PATH_PREFIX}" | \
    sed "s,${PATH_PREFIX},," | \
    sed "s,/.*$,," > .wmf-extensions.list.cache
    echo "done"
  fi
  EXTENSION_NAMES=($(cat ".wmf-extensions.list.cache"))
else
  EXTENSION_NAMES=($(ls "${W10_CORE}/extensions"))
fi

sync_subprojects "${W10_CORE}/extensions" "${WSL_CORE}/extensions" "${EXTENSION_NAMES[@]}" &

wait
exit
