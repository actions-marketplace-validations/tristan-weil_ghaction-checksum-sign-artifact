# Github Docker Action: Checksum and Sign Artifact

This Github Docker Action adds checksums to your artifacts and sign them using the OpenPGP standard.

[![Tests Success Status](https://github.com/tristan-weil/ghaction-checksum-sign-artifact/workflows/Tests%20Success/badge.svg)](https://github.com/tristan-weil/ghaction-checksum-sign-artifact/actions?query=workflow%3A%22Tests+Success%22)
[![Tests Failure Status](https://github.com/tristan-weil/ghaction-checksum-sign-artifact/workflows/Tests%20Failure/badge.svg)](https://github.com/tristan-weil/ghaction-checksum-sign-artifact/actions?query=workflow%3A%22Tests+Failure%22)
[![Linters Status](https://github.com/tristan-weil/ghaction-checksum-sign-artifact/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/tristan-weil/ghaction-checksum-sign-artifact/actions?query=workflow%3A%22Lint+Code+Base%22)

## Inputs

### `path`

Path to the artifact(s).

Globing is supported (ex: build/*.zip)

**Required**

### `checksum_digests`

List of digests functions to use.

Use a comma separated list of allowed values:
- `sha256`
- `sha512`

**Default**: `sha256`

### `checksum_format`

Format of each digest's line.

Use one of the allowed values:
- `gnu`: print a line with the digest, a space, a character indicating the input mode (' ' on GNU systems), and the name of the artifact (ex: `abcd1234[space][space]my_file.zip`)
- `bsd`: print a line with the digest function, a space, the name of the artifact inside parenthesis, an equal character between two spaces and the digest  (ex: `SHA256[space](my_file.zip)[space]=[space]abcd1234`)

**Default**: `gnu`

### `checksum_output`

Output method to store the digest(s).

Use one of the allowed values:
- `one_file`: the digests of all artifacts, for all digests functions, are stored in one file, named `CHECKSUMS`
- `one_file_per_digest`: the digests of all artifacts are stored in a separate file for each digests functions (ex: `SHA256SUMS`)
- `artifact_one_file`: the digests of each artifact, for all digests functions, are stored in a separate file, named after each artifact's name (ex: `my_file.zip.checksums`)
- `artifact_one_file_per_digest`: the digests of each artifact are stored in a separate file for each digests functions and named after each artifact's name (ex: `my_file.zip.sha256`)

**Default**: `one_file_per_digest`

### `sign_key`

Key used to sign the artifact(s)

### `sign_key_passphrase`

Passphrase to unlock the `sign_key`.

**Required** if `sign_key`

### `sign_key_fingerprint`

Fingerprint used to find the public key of `sign_key` in the `sign_keyserver`, in order to validate the newly created signature(s).

**Required if** `sign_key`

### `sign_keyserver`

Keyserver where the fingerprint is stored.

**Default**: `keys.openpgp.org`

### `sign_output`

Output method to store the signature(s).

Use one of the allowed values:
- `checksum_detach`: the signature(s) are stored in a separate file for each digests files (ex: `SHA256SUMS.asc`)
- `checksum_clear`: the signature(s) are stored in a new file (the original file is removed) with each digests files (ex: `SHA256SUMS.asc`)
- `artifact_detach`: the signature(s) are stored in a separate file for each artifacts (ex: `my_file.zip.asc`)

**Default**: `checksum_detach`

## Outputs

### `generated-files`

List of generated files (new lines are escaped with %0A so it can be used in another action).

## Example usage

    uses: tristan-weil/ghaction-checksum-sign-artifact@v1
    with:
      path: 'build/*.zip'
      sign_key: '${{ secrets.SIGN_KEY }}'
      sign_key_passphrase: '${{ secrets.SIGN_KEY_PASSPHRASE }}'
      sign_key_fingerprint: 'ABCD1234'
      sign_keyserver: 'keys.openpgp.org'

## Caveats

The `busybox` version of the sha(256|512)sum commands does not support:
- the `bsd` format
- the `one_file` output with different digests
- a checksum file clear-signed with `checksum_clear`

## License

See [LICENSE.md](LICENSE.md)
