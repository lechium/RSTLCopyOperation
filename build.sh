#!/bin/bash

xcodebuild | xcpretty
rm /usr/local/bin/cpv
cp build/Release/Copy /usr/local/bin/cpv

