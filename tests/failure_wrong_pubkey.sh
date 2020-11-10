#!/usr/bin/env sh
set +x
set -o errexit
set -o nounset

cd build/

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
echo "💡 checking error during verify"
${TEST_GPG} --homedir "${TEST_SIGN_VERIFY_DIR}" --verify "CHECKSUMS.asc" "CHECKSUMS" || exit 0
echo "::error ::correct signatures: 'build/CHECKSUMS.asc'"
