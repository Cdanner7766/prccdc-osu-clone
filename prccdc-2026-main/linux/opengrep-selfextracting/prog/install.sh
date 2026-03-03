#!/bin/sh

tar xzvf rules.tar.gz

proglang="$1"
shift


if ldd 2>&1 | grep -q musl; then
    ./opengrep_musllinux_x86 -f opengrep-rules/"$proglang" "$@"
else
    ./opengrep_manylinux_x86 -f opengrep-rules/"$proglang" "$@"
fi


