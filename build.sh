#!/bin/bash

xcodebuild | xcpretty
rm /usr/local/bin/ncp
cp build/Release/Copy /usr/local/bin/ncp
pandoc ncp.1.md -s -t man -o ncp.1
gzip ncp.1
mv ncp.1.gz /usr/local/share/man/man1/ 

