#/bin/bash

if [ ! -f .wmf-extensions.list.cache ]; then
    echo "Missing .wmf-extensions.list.cache; did you run './git-wmf pull'?"
fi

DIRS=($(cat .wmf-extensions.list.cache))
for DIR in "${DIRS[@]}"; do grep -r "$@" "/srv/mediawiki/extensions/${DIR}"; done
