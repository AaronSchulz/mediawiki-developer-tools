#!/bin/bash

ARGS="$@"
WSL_CORE="/srv/mediawiki/core"
GIT_BIN="git"
BASE_DIR=$(dirname $(realpath $0))

# Use Git for Windows git for the WIN10 path
CHANGES=$($GIT_BIN diff --name-only)
if [ -n "${CHANGES}" ]; then
  echo "The following core file(s) have uncommitted changes in git:"
  echo "${CHANGES}"
  exit 1
fi

"${BASE_DIR}/sync.sh" core
"${BASE_DIR}/make_tempfs.sh"

(
	cd /srv/mediawiki/core &&
	sudo -u www-data rm -rf /tmp/mw-temp/* &&
	sudo -u www-data ~/.config/composer/vendor/bin/paratest \
  --phpunit /srv/mediawiki/core/tests/phpunit/phpunit.php \
  --configuration /srv/mediawiki/core/tests/phpunit/suite.xml \
  --bootstrap "${BASE_DIR}"/dummy.php \
  --parallel-suite \
  --colors \
	2>&1 | less -R
)
