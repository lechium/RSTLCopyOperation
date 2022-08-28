#!/bin/bash

xcodebuild | xcpretty
rm /usr/local/bin/ncp
cp build/Release/ncp /usr/local/bin/ncp
pd=$(/usr/bin/which pandoc)
if [  -z $pd ]; then
    echo "pandoc is required to build the manpage. 'brew install pandoc'"
    cp ncp.1.gz /usr/local/share/man/man1/
    exit 0
fi

pandoc ncp.1.md -s -t man -o ncp.1
gzip -f ncp.1
if [ -d usr ]; then
    cp build/Release/ncp usr/local/bin/
    cp ncp.1.gz usr/local/share/man/man1/
    tar cp --gid 20 --uid 501 --lzma -P --exclude .DS_Store -f ncp.tar.xz usr
fi
cp ncp.1.gz /usr/local/share/man/man1/ 

