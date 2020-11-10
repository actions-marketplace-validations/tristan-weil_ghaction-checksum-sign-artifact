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
# prepare env
#
TEST_GPG="gpg --no-tty --batch --pinentry-mode loopback"
TEST_SIGN_HOMEDIR="/tmp/gpgtest"
TEST_SIGN_VERIFY_DIR="${TEST_SIGN_HOMEDIR}/verify"

echo "💡️ importing public key"
mkdir "${TEST_SIGN_HOMEDIR}" "${TEST_SIGN_VERIFY_DIR}"
chmod 700 "${TEST_SIGN_HOMEDIR}" "${TEST_SIGN_VERIFY_DIR}"
if ! ${TEST_GPG} --homedir "${TEST_SIGN_VERIFY_DIR}" --keyserver "${TEST_SIGN_KEYSERVER}" --recv-keys "${TEST_SIGN_FINGERPRINT}"; then
  echo "::error ::unable to import public key"
  exit 1
fi

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

echo "💡 checking signatures file"
if [ ! -s "build.zip.asc" ]; then
  echo "::error ::no signatures: 'build/build.zip.asc'"
  exit 1
fi

echo "💡 checking signatures"
if ! ${TEST_GPG} --homedir "${TEST_SIGN_VERIFY_DIR}" --verify "build.zip.asc" "build.zip"; then
  echo "::error ::incorrect signatures: 'build/build.zip.asc'"
  exit 1
fi