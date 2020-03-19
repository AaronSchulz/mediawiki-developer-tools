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

# Create/cleanup /tmp dirs
"${BASE_DIR}/make_tempfs.sh"
sudo -u www-data rm -rf /tmp/mw-temp/*

# Work around poorly divided suites
sudo -u www-data cp "${BASE_DIR}/mw_core_suite.xml" /srv/mediawiki/core/tests/phpunit/

(
	cd /srv/mediawiki/core &&
	sudo -u www-data ~/.config/composer/vendor/bin/paratest \
  --phpunit tests/phpunit/phpunit.php \
  --configuration tests/phpunit/mw_core_suite.xml \
  --bootstrap "${BASE_DIR}/dummy.php" \
  --parallel-suite \
  --colors \
	2>&1 | less -R
)
