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

# Sync code
"${BASE_DIR}/sync.sh" core || exit 1

# Create/cleanup temp directory
"${BASE_DIR}/make_tempfs.sh" /mw-temp || exit 1

# Work around poorly divided suites
sudo -u www-data cp "${BASE_DIR}/mw_core_suite.xml" "${WSL_CORE}/tests/phpunit/" || exit 1
sudo -u www-data cp "${BASE_DIR}/ParatestWrapperSettings.php" "${WSL_CORE}/" || exit 1

(
	cd /srv/mediawiki/core &&
	sudo TMPDIR="/mw-temp" -u www-data paratest \
  --phpunit tests/phpunit/phpunit.php \
  --configuration tests/phpunit/mw_core_suite.xml \
  --bootstrap "${BASE_DIR}/dummy.php" \
  --parallel-suite \
  --colors \
	--passthru="--conf ParatestWrapperSettings.php ${ARGS}" 2>&1 | less -R
)
