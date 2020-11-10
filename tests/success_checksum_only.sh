#!/usr/bin/env sh
set +x
set -o errexit
set -o nounset

cd build/

#
# list generated files
#
echo "💡️ listing"
ls -latr

#
# tests
#
echo "💡️ checking digests file"
if [ ! -s "CHECKSUMS" ]; then
  echo "::error ::no digests: 'build/CHECKSUMS'"
  exit 1
fi

echo "💡 checking digests"
if ! sha256sum -wc "CHECKSUMS"; then
  echo "::error ::checksums failed: 'build/CHECKSUMS'"
  exit 1
fi

if ! sha512sum -wc "CHECKSUMS"; then
  echo "::error ::checksums failed: 'build/CHECKSUMS'"
  exit 1
fi

echo "💡 compare digests"
SUM=$(grep "build.zip" "CHECKSUMS" | head -1 | sed 's/.*(\(.\+\))\ = \([a-zA-Z0-9]\+\)/\2  \1/g')
if [ "${SUM}" != "${TEST_ZIP_SHA256SUM}" ]; then
  echo "::error ::invalid checksums: 'build/CHECKSUMS'"
  exit 1
fi

SUM=$(grep "build.zip" "CHECKSUMS" | tail -1 | sed 's/.*(\(.\+\))\ = \([a-zA-Z0-9]\+\)/\2  \1/g')
if [ "${SUM}" != "${TEST_ZIP_SHA512SUM}" ]; then
  echo "::error ::invalid checksums: 'build/CHECKSUMS'"
  exit 1
fi
