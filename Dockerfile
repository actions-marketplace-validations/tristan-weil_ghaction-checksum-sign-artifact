FROM alpine:3

RUN set -x \
    && apk --no-cache add gnupg coreutils

COPY entrypoint.sh  /
COPY sumsign.sh     /

ENTRYPOINT ["/entrypoint.sh"]
