#!/usr/bin/env sh
set +x
set -o errexit

GPG="gpg --quiet --no-tty --batch --pinentry-mode loopback"
OPTS_COREUTILS=""
SUMS_TMP="/tmp/checksumsign.tmp"
SUMS_COREUTILS="/tmp/checksumsign.coreutils"
SUMS_BUSYBOX="/tmp/checksumsign.busybox"
GENERATED_FILES="/tmp/checksumsign.generated"

# Check args
echo "${INPUT_CHECKSUM_DIGESTS}" | tr ',' '\n' | while read -r digest; do
  case "${digest}" in
  sha256|sha512)
    ;;
  *)
    printf "❌ checksum_digests: invalid value, choose: (sha256|sha512) "
    exit 1
    ;;
  esac

  # shellcheck disable=SC2086
  [ ! -e "/opt/${digest}sum" ] && ln -s /bin/busybox /opt/${digest}sum
done

if [ -z "${INPUT_PATH}" ]; then
  printf "❌ path: missing "
  exit 1
fi

case "${INPUT_CHECKSUM_FORMAT}" in
gnu)
  ;;
bsd)
  OPTS_COREUTILS="--tag"
  ;;
*)
  printf "❌ checksum_format: invalid value, choose: (gnu|bsd) "
  exit 1
  ;;
esac

case "${INPUT_CHECKSUM_OUTPUT}" in
one_file|one_file_per_digest|artifact_one_file|artifact_one_file_per_digest)
  ;;
*)
  printf "❌ checksum_output: invalid value, choose: (one_file|one_file_per_digest|artifact_one_file|artifact_one_file_per_digest) "
  exit 1
  ;;
esac

if [ -n "${INPUT_SIGN_KEY}" ]; then
  if [ -z "${INPUT_SIGN_KEY_FINGERPRINT}" ]; then
    printf "❌ sign_key_fingerprint: missing "
    exit 1
  fi

  if [ -z "${INPUT_SIGN_KEYSERVER}" ]; then
    printf "❌ sign_keyserver: missing "
    exit 1
  fi

  if [ -z "${INPUT_SIGN_KEY_PASSPHRASE}" ]; then
    printf "❌ sign_key_passphrase: missing "
    exit 1
  fi

  case "${INPUT_SIGN_OUTPUT}" in
  checksum_detach|checksum_clear|artifact_detach)
    ;;
  *)
    printf "❌ sign_output: invalid value, choose: (checksum_detach|checksum_clear|artifact_detach) "
    exit 1
    ;;
  esac
fi

# Main
set -o nounset

checkBusyBoxDigest() {
  input=$1
  digest=$2

  case "${INPUT_CHECKSUM_FORMAT}" in
  gnu)
    cp "${input}" "${SUMS_BUSYBOX}"
    ;;
  bsd)
    # sha*sum binaries on busybox don't accept openssl/libressl digests format
    sed 's/.*(\(.\+\))\ = \([a-zA-Z0-9]\+\)/\2  \1/g' "${input}" > "${SUMS_BUSYBOX}"
    ;;
  esac

  # shellcheck disable=SC2086
  /opt/${digest}sum -sc "${SUMS_BUSYBOX}"

  return $?
}

#
# 1. go to workdir
#
DIRNAME=$(dirname "${INPUT_PATH}")
BASENAME=$(basename "${INPUT_PATH}")
OLDIR=$(pwd)
cd "${DIRNAME}" >/dev/null 2>&1

#
# 2. do sums
#
printf "🧮 Computing checksums"
[ "${INPUT_CHECKSUM_FORMAT}" = "bsd" ] && printf " 🐡"
printf "\n"

case "${INPUT_CHECKSUM_OUTPUT}" in
one_file)
  echo "${INPUT_CHECKSUM_DIGESTS}" | tr ',' '\n' | while read -r digest; do
    printf " 💎 %s %s >> %s " "${digest}" "${DIRNAME}/${BASENAME}" "${DIRNAME}/CHECKSUMS"
    # shellcheck disable=SC2086
    /usr/bin/${digest}sum ${OPTS_COREUTILS} ${BASENAME} > "${SUMS_TMP}"
    printf "✅ "

    checkBusyBoxDigest "${SUMS_TMP}" "${digest}"
    printf "✅\n"

    cat "${SUMS_TMP}" >> CHECKSUMS
  done

  echo "CHECKSUMS" >> "${SUMS_COREUTILS}"
  echo "${DIRNAME}/CHECKSUMS" >> "${GENERATED_FILES}"
  ;;
one_file_per_digest)
  echo "${INPUT_CHECKSUM_DIGESTS}" | tr ',' '\n' | while read -r digest; do
    __file=$(echo "${digest}sums" | tr '[:lower:]' '[:upper:]')
    printf " 💎 %s %s >> %s " "${digest}" "${DIRNAME}/${BASENAME}" "${DIRNAME}/${__file}"
    # shellcheck disable=SC2086
    /usr/bin/${digest}sum ${OPTS_COREUTILS} ${BASENAME} > "${SUMS_TMP}"
    printf "✅ "

    checkBusyBoxDigest "${SUMS_TMP}" "${digest}"
    printf "✅\n"

    cat "${SUMS_TMP}" >> "${__file}"

    echo "${__file}" >> "${SUMS_COREUTILS}"
    echo "${DIRNAME}/${__file}" >> "${GENERATED_FILES}"
  done
  ;;
artifact_one_file)
  for artifact in ${BASENAME}; do
    echo "${INPUT_CHECKSUM_DIGESTS}" | tr ',' '\n' | while read -r digest; do
      printf " 💎 %s %s >> %s " "${digest}" "${DIRNAME}/${artifact}" "${DIRNAME}/${artifact}.checksums"
      # shellcheck disable=SC2086
      /usr/bin/${digest}sum ${OPTS_COREUTILS} "${artifact}" > "${SUMS_TMP}"
      printf "✅ "

      checkBusyBoxDigest "${SUMS_TMP}" "${digest}"
      printf "✅\n"

      cat "${SUMS_TMP}" >> "${artifact}.checksums"
    done

    echo "${artifact}.checksums" >> "${SUMS_COREUTILS}"
    echo "${DIRNAME}/${artifact}.checksums" >> "${GENERATED_FILES}"
  done
  ;;
artifact_one_file_per_digest)
  for artifact in ${BASENAME}; do
    echo "${INPUT_CHECKSUM_DIGESTS}" | tr ',' '\n' | while read -r digest; do
      printf " 💎 %s %s > %s " "${digest}" "${DIRNAME}/${artifact}" "${DIRNAME}/${artifact}.${digest}"
      # shellcheck disable=SC2086
      /usr/bin/${digest}sum ${OPTS_COREUTILS} "${artifact}" > "${SUMS_TMP}"
      printf "✅ "

      checkBusyBoxDigest "${SUMS_TMP}" "${digest}"
      printf "✅\n"

      cat "${SUMS_TMP}" >> "${artifact}.${digest}"

      echo "${artifact}.${digest}" >> "${SUMS_COREUTILS}"
      echo "${DIRNAME}/${artifact}.${digest}" >> "${GENERATED_FILES}"
    done
  done
  ;;
esac

#
# 3. sign
#
if [ -n "${INPUT_SIGN_KEY}" ]; then
  echo "🔑️ Signing"
  SIGN_HOMEDIR="/gpg"
  SIGN_SIGN_DIR="${SIGN_HOMEDIR}/sign"
  SIGN_VERIFY_DIR="${SIGN_HOMEDIR}/verify"
  SIGN_KEY="${SIGN_HOMEDIR}/sign.key"

  mkdir "${SIGN_HOMEDIR}" "${SIGN_SIGN_DIR}" "${SIGN_VERIFY_DIR}"
  chmod 700 "${SIGN_HOMEDIR}" "${SIGN_SIGN_DIR}" "${SIGN_VERIFY_DIR}"

  # shellcheck disable=SC2059
  printf "${INPUT_SIGN_KEY}" > "${SIGN_KEY}"
  chmod 400 "${SIGN_KEY}"

  printf " 💡️ importing key "
  (echo "${INPUT_SIGN_KEY_PASSPHRASE}" | ${GPG} --homedir "${SIGN_SIGN_DIR}" --passphrase-fd 0 --import "${SIGN_KEY}") >/dev/null 2>&1
  printf "✅\n"
  printf " 💡️ importing public key "
  ${GPG} --homedir "${SIGN_VERIFY_DIR}" --keyserver "${INPUT_SIGN_KEYSERVER}" --recv-keys "${INPUT_SIGN_KEY_FINGERPRINT}" >/dev/null 2>&1
  printf "✅\n"

  case "${INPUT_SIGN_OUTPUT}" in
  checksum_detach)
    while read -r sum_file; do
      printf " 💎 detach-sign %s > %s " "${DIRNAME}/${sum_file}" "${DIRNAME}/${sum_file}.asc"
      (echo "${INPUT_SIGN_KEY_PASSPHRASE}" | ${GPG} --homedir "${SIGN_SIGN_DIR}" --passphrase-fd 0 --armor --detach-sign "${sum_file}") >/dev/null 2>&1
      printf "✅ "
      ${GPG} --homedir "${SIGN_VERIFY_DIR}" --verify "${sum_file}.asc" "${sum_file}" >/dev/null 2>&1
      printf "✅\n"

      echo "${DIRNAME}/${sum_file}.asc" >> "${GENERATED_FILES}"
    done < "${SUMS_COREUTILS}"
    ;;
  checksum_clear)
    while read -r sum_file; do
      printf " 💎 clear-sign %s > %s " "${DIRNAME}/${sum_file}" "${DIRNAME}/${sum_file}.asc"
      (echo "${INPUT_SIGN_KEY_PASSPHRASE}" | ${GPG} --homedir "${SIGN_SIGN_DIR}" --passphrase-fd 0 --armor --clear-sign "${sum_file}") >/dev/null 2>&1
      printf "✅ "
      ${GPG} --homedir "${SIGN_VERIFY_DIR}" --verify "${sum_file}.asc" >/dev/null 2>&1
      printf "✅\n"

      rm "${sum_file}"

      sed -i -e 's/'"${sum_file}"'/'"${sum_file}".asc'/' ${GENERATED_FILES}
    done < "${SUMS_COREUTILS}"
    ;;
  artifact_detach)
    for artifact in ${BASENAME}; do
      printf " 💎 detach-sign %s > %s " "${DIRNAME}/${artifact}" "${DIRNAME}/${artifact}.asc"
      (echo "${INPUT_SIGN_KEY_PASSPHRASE}" | ${GPG} --homedir "${SIGN_SIGN_DIR}" --passphrase-fd 0 --armor --detach-sign "${artifact}") >/dev/null 2>&1
      printf "✅ "
      ${GPG} --homedir "${SIGN_VERIFY_DIR}" --verify "${artifact}.asc" "${artifact}" >/dev/null 2>&1
      printf "✅\n"

      echo "${DIRNAME}/${artifact}.asc" >> "${GENERATED_FILES}"
    done
    ;;
  esac
fi

#
# 4. end
#
#changelog="${changelog//$'\n'/'%0A'}"
printf "🔖 Generated files\n"
sed 's/^/ ✨ /' "${GENERATED_FILES}"

output=$(sed ':a;N;$!ba;s/\n/%0A/g' "${GENERATED_FILES}")
echo "::set-output name=generated-files::${output}"

cd "${OLDIR}"
