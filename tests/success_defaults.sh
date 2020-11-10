#!/usr/bin/env sh
# shellcheck disable=SC2129

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

# shellcheck disable=SC2059
check_one_file() {
  __CHECKSUMS=$1
  __DIGEST=$2
  __COMPARE_TO=$3

  if [ "${TEST_SIGN_OUTPUT}" = "checksum_clear" ]; then
    __CHECKSUMS="${__CHECKSUMS}.asc"
  fi

  echo "💡️ [${__DIGEST}] checking digests files"
  if [ ! -s "${__CHECKSUMS}" ]; then
    echo "::error ::no digests: 'build/${__CHECKSUMS}'"
    exit 1
  fi

  echo "💡 [${__DIGEST}] checking digests"
  # shellcheck disable=SC2086
  if ! "${__DIGEST}sum" -wc "${__CHECKSUMS}"; then
    echo "::error ::checksums failed: 'build/${__CHECKSUMS}'"
    exit 1
  fi

  case "${__DIGEST}" in
  "sha256")
    SUM=$(grep "build.zip" "${__CHECKSUMS}" | head -1)
    ;;
  "sha512")
    SUM=$(grep "build.zip" "${__CHECKSUMS}" | tail -1)
    ;;
  esac

  if [ "${SUM}" != "${__COMPARE_TO}" ]; then
    echo "::error ::invalid checksums: 'build/${__CHECKSUMS}'"
    exit 1
  fi

  if [ "${TEST_SIGN_OUTPUT}" = "checksum_detach" ]; then
    echo "💡 [${__DIGEST}] checking signatures file"
    if [ ! -s "${__CHECKSUMS}.asc" ]; then
      echo "::error ::no signatures: 'build/${__CHECKSUMS}.asc'"
      exit 1
    fi

    echo "💡 [${__DIGEST}] checking signatures"
    if ! ${TEST_GPG} --homedir "${TEST_SIGN_VERIFY_DIR}" --verify "${__CHECKSUMS}.asc" "${__CHECKSUMS}"; then
      echo "::error ::incorrect signatures: 'build/${__CHECKSUMS}.asc'"
      exit 1
    fi
  elif [ "${TEST_SIGN_OUTPUT}" = "checksum_clear" ]; then
    echo "💡 [${__DIGEST}] checking signatures file"
    if [ ! -s "${__CHECKSUMS}" ]; then
      echo "::error ::no signatures: 'build/${__CHECKSUMS}'"
      exit 1
    fi

    echo "💡 [${__DIGEST}] checking signatures"
    if ! ${TEST_GPG} --homedir "${TEST_SIGN_VERIFY_DIR}" --verify "${__CHECKSUMS}"; then
      echo "::error ::incorrect signatures: 'build/${__CHECKSUMS}'"
      exit 1
    fi
  elif [ "${TEST_SIGN_OUTPUT}" = "artifact_detach" ]; then
    echo "💡 [${__DIGEST}] checking signatures file"
    if [ ! -s "build.zip.asc" ]; then
      echo "::error ::no signatures: 'build/build.zip.asc'"
      exit 1
    fi

    echo "💡 [${__DIGEST}] checking signatures"
    if ! ${TEST_GPG} --homedir "${TEST_SIGN_VERIFY_DIR}" --verify "build.zip.asc" "build.zip"; then
      echo "::error ::incorrect signatures: 'build/build.zip.asc'"
      exit 1
    fi
  fi
}

# one_file
if [ "${TEST_CHECKSUM_OUTPUT}" = "one_file" ]; then
  check_one_file "CHECKSUMS" "sha256" "${TEST_ZIP_SHA256SUM}"
  check_one_file "CHECKSUMS" "sha512" "${TEST_ZIP_SHA512SUM}"

  if [ "${TEST_SIGN_OUTPUT}" = "checksum_detach" ]; then
    echo "build/CHECKSUMS" >> DIFF_EXPECTED
    echo "build/CHECKSUMS.asc" >> DIFF_EXPECTED
  elif [ "${TEST_SIGN_OUTPUT}" = "checksum_clear" ]; then
    echo "build/CHECKSUMS.asc" >> DIFF_EXPECTED
  elif [ "${TEST_SIGN_OUTPUT}" = "artifact_detach" ]; then
    echo "build/CHECKSUMS" >> DIFF_EXPECTED
    echo "build/build.zip.asc" >> DIFF_EXPECTED
  fi
fi

# one_file_per_digest
if [ "${TEST_CHECKSUM_OUTPUT}" = "one_file_per_digest" ]; then
  check_one_file "SHA256SUMS" "sha256" "${TEST_ZIP_SHA256SUM}"
  check_one_file "SHA512SUMS" "sha512" "${TEST_ZIP_SHA512SUM}"

  if [ "${TEST_SIGN_OUTPUT}" = "checksum_detach" ]; then
    echo "build/SHA256SUMS" >> DIFF_EXPECTED
    echo "build/SHA512SUMS" >> DIFF_EXPECTED
    echo "build/SHA256SUMS.asc" >> DIFF_EXPECTED
    echo "build/SHA512SUMS.asc" >> DIFF_EXPECTED
  elif [ "${TEST_SIGN_OUTPUT}" = "checksum_clear" ]; then
    echo "build/SHA256SUMS.asc" >> DIFF_EXPECTED
    echo "build/SHA512SUMS.asc" >> DIFF_EXPECTED
  elif [ "${TEST_SIGN_OUTPUT}" = "artifact_detach" ]; then
    echo "build/SHA256SUMS" >> DIFF_EXPECTED
    echo "build/SHA512SUMS" >> DIFF_EXPECTED
    echo "build/build.zip.asc" >> DIFF_EXPECTED
  fi
fi

# artifact_one_file
if [ "${TEST_CHECKSUM_OUTPUT}" = "artifact_one_file" ]; then
  check_one_file "build.zip.checksums" "sha256" "${TEST_ZIP_SHA256SUM}"
  check_one_file "build.zip.checksums" "sha512" "${TEST_ZIP_SHA512SUM}"

  if [ "${TEST_SIGN_OUTPUT}" = "checksum_detach" ]; then
    echo "build/build.zip.checksums" >> DIFF_EXPECTED
    echo "build/build.zip.checksums.asc" >> DIFF_EXPECTED
  elif [ "${TEST_SIGN_OUTPUT}" = "checksum_clear" ]; then
    echo "build/build.zip.checksums.asc" >> DIFF_EXPECTED
  elif [ "${TEST_SIGN_OUTPUT}" = "artifact_detach" ]; then
    echo "build/build.zip.checksums" >> DIFF_EXPECTED
    echo "build/build.zip.asc" >> DIFF_EXPECTED
  fi
fi

# artifact_one_file_per_digest
if [ "${TEST_CHECKSUM_OUTPUT}" = "artifact_one_file_per_digest" ]; then
  check_one_file "build.zip.sha256" "sha256" "${TEST_ZIP_SHA256SUM}"
  check_one_file "build.zip.sha512" "sha512" "${TEST_ZIP_SHA512SUM}"

  if [ "${TEST_SIGN_OUTPUT}" = "checksum_detach" ]; then
    echo "build/build.zip.sha256" >> DIFF_EXPECTED
    echo "build/build.zip.sha512" >> DIFF_EXPECTED
    echo "build/build.zip.sha256.asc" >> DIFF_EXPECTED
    echo "build/build.zip.sha512.asc" >> DIFF_EXPECTED
  elif [ "${TEST_SIGN_OUTPUT}" = "checksum_clear" ]; then
    echo "build/build.zip.sha256.asc" >> DIFF_EXPECTED
    echo "build/build.zip.sha512.asc" >> DIFF_EXPECTED
  elif [ "${TEST_SIGN_OUTPUT}" = "artifact_detach" ]; then
    echo "build/build.zip.sha256" >> DIFF_EXPECTED
    echo "build/build.zip.sha512" >> DIFF_EXPECTED
    echo "build/build.zip.asc" >> DIFF_EXPECTED
  fi
fi

# chcking output
echo "💡 checking output"

# shellcheck disable=SC2059
printf "${TEST_GENERATED}\n" > DIFF_GENERATED

if ! diff -q DIFF_GENERATED DIFF_GENERATED; then
  echo "::error ::missing expected files"
  exit 1
fi
