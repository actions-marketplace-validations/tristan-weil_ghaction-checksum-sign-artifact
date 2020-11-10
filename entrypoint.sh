#!/usr/bin/env sh

printf "🚀 Starting\n"
/sumsign.sh; rc=$?

if [ ${rc} -ne 0 ]; then
  printf "❌\n"
  echo "::error ::something wrong just happened"
fi

printf "🔥 Cleaning\n"
pkill dirmngr
pkill gpg-agent
rm -rf /gpg /tmp/checksumsign.coreutils /tmp/checksumsign.busybox /tmp/checksumsign.generated /tmp/checksumsign.tmp

exit ${rc}
