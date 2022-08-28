# ncp
**ncp** is meant to be a safe replacement for standard issue cp. By default it will give you a fancy progress bar keeping track of the current file copying. For singular file copying it will check available space before attempting to copy a file. In safe mode this safety measure will apply to copying folders as well. If the folder has a lot of files, this will slow down the initial copying process as we calculate the folder size. 

## Features

- [x] Copy files with descriptive progress
- [x] Safety features check available space before initiating a copy

## Requirements

- macOS 10.8+
- Xcode 11

## Installation

#### Manually

1. Change into the **ncp** folder
2. `./build.sh`

## Contribute

We would love you for the contribution to **ncp**, check the ``LICENSE`` file for more info.

## Meta

Kevin Bradley 

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/yourname/github-link](https://github.com/dbader/)

[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
