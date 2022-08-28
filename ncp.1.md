% ncp(1) ncp 1.0
% Kevin Bradley
% Aug  2022

# NAME

ncp -- copy files with progress

# SYNOPSIS
**ncp** **-f** **-s** **-m** **-c** [**-vq**] source_file target_file\

# DESCRIPTION

**ncp** is meant to be a safe replacement for standard issue cp. By default it will give you a fancy progress bar keeping track of the current file copying. For singular file copying it will check available space before attempting to copy a file. In safe mode this safety measure will apply to copying folders as well. If the folder has a lot of files, this will slow down the initial copying process as we calculate the folder size. 

# OPTIONS

**-f**, **--force**
: Force the copy to take place if the target files already exist, overwriting as necessary.

**-s**, **--safe**
: When copying directories check to make sure there is sufficient space in the target directory before starting to copy.

**-m**, **--move**
: Move the file(s)/folder(s) instead of copying.

**-c**, **--clone**
: Copy files using clonefile(2).

**-v**, **--verbose**
: Cause **ncp** to be verbose. showing files as they are copied.

**-q**, **--quiet**
: Cause **ncp** to be quiet. No progress bars will be shown during the copying process.

# EXAMPLES
**ncp**
: Displays the usage and version information, then exits.

**ncp -v -s folder_one /Volumes/MacintoshHD/**
: Will recursively, verbosely and safely copy the files from **folder_one** into **/Volumes/MacintoshHDD/** checking to make sure there is sufficient free space available to copy the contents of **folder_one**.\

# EXIT STATUS
**0**
: Success

**>0**
: Failure

# COPYRIGHT

Copyright © 2022 Kevin Bradley. License MIT.
