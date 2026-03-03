#!/bin/sh

mkdir -p prog

rm -rf ./prog/opengrep_*
rm -f ./prog/rules.tar.gz

cd prog

wget https://github.com/opengrep/opengrep/releases/download/v1.15.1/opengrep_manylinux_x86
wget https://github.com/opengrep/opengrep/releases/download/v1.15.1/opengrep_musllinux_x86

chmod +x opengrep_*

git clone https://github.com/opengrep/opengrep-rules opengrep-rules
tar czvf rules.tar.gz \
    ./opengrep-rules/php \
    ./opengrep-rules/html \
    ./opengrep-rules/java \
    ./opengrep-rules/javascript \
    ./opengrep-rules/python \
    ./opengrep-rules/ruby \
    ./opengrep-rules/c

rm -rf ./opengrep-rules

cd ..

makeself ./prog ./prog.run "OpenGrep Scanning tool" ./install.sh


