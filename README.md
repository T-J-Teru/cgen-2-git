# Overview

This is a set of scripts for performing
a [CVS](http://www.nongnu.org/cvs/) to [git](https://git-scm.com/)
conversion of [CGEN](https://www.sourceware.org/cgen/).

The hope is that this will be used as the basis for converting the
official project from CVS to git.

# Prerequisites

You'll need to install:

* [cvs-fast-export](http://www.catb.org/esr/cvs-fast-export/)
* [reposurgeon](http://www.catb.org/esr/reposurgeon/)

# Usage

Once the prerequisites are installed, clone the repository, then:

```
cd cgen-2-git
./convert.sh --working-dir working
```

this will create a new `working` directory, inside which you will find
the following sub-directories:

1. `cgen-mirror` - this is an rsync mirror of the official upstream
   CGEN repository, used as the basis for the conversion.
2. `logs` - inside here you'll find date stamped log files, one for
   each run of the `convert.sh` script.
3. `conversion-DATE` - date stamped conversion directories in which
   the CVS to git conversion has actually been performed.  The
   conversion itself is done using reposurgeon.  More details of
   what's inside this directory can be found below.

## Inside The Conversion

Each run of the `convert.sh` script creates a new date stamped
conversion directory.  The contents of each conversion directory are
generated largely from reposurgeon, however, some of these files are
updated by the `conversion.sh` script.

The output of the conversion is in the `cgen-git` directory, this is
the newly created git repository.

# Branch And Tag List

## Branches

These are all of the branches in the generated repository.

* `cgen-1_1-branch`
* `master`

## Tags

These are all of the tags in the generated repository:

* `cgen-1-0`
* `cgen-1-1`
* `cgen-snapshot-*` - There are many tags matching this pattern, all
                       with the `*` replaced by a date stamp.

# Testing

This is a list of what testing has been done to ensure that the new
repository is correct.  It's not clear to me how much of the testing
below is required, if we can show that the contents of each branch are
identical between CVS and git.

## Code Comparison Tests

### Tip Of Branch Comparisons

**TODO**

### Tag Comparisons

#### cgen-1-0

Downloaded the CGEN 1.0 release tar file from:

  ftp://sourceware.org/pub/cgen/releases/cgen-1.0.tar.gz

unpacked it, and then compared the cgen/ subdirectory in the release
with a git checkout of the cgen-1-0 tag.  The only difference was that
the git repository has a `.gitignore` file.

#### cgen-1-1

Downloaded the CGEN 1.1 release tar file from:

  ftp://sourceware.org/pub/cgen/releases/cgen-1.1.tar.gz

unpacked it, and then compared the cgen/ subdirectory in the release
with a git checkout of the cgen-1-1 tag.  The only difference was that
the git repository has a `.gitignore` file.

#### Comparison Against CVS

I checked out all of the tags `cgen-1-0`, and `cgen-snapshot-*` in
both CVS and git, and compared the checkouts, excluding `CVS` and
`.git` directories.

The only difference in any checkout was that the git repository had a
`.gitignore` file.

The `cgen-1-1` tag can't be compared as this is a tag I have created
as part of the conversion from CVS to git.

## Code Execution Tests

The purpose of this section is to show how CGEN is currently used with
some projects to generate source code components.  I document here my
experiences of using cgen, both before and after the git conversion,
to regenerate the components of these projects.  Any issues I
encounter, or differences between the cvs and git cgen repositories
are also documented.

### Generating libopcodes Source In binutils-gdb

#### Patching binutils-gdb

To make it easier to use cgen with binutils-gdb, I have a patch that
allows binutils-gdb to use an out of tree cgen source tree.  The patch
has been posted to the mailing list, but as of yet has not been
merged.

The patch can be found here:

  https://sourceware.org/ml/binutils/2018-10/msg00172.html

#### Setting up binutils-gdb

Clone the `binutils-gdb` repository:

```
mkdir binutils-gdb
cd binutils-gdb
git clone git://sourceware.org/git/binutils-gdb.git src
mkdir build
```

#### Building with in tree CGEN

Now copy a version of CGEN into `binutils-gdb/src/cgen/`, which is a
directory that doesn't exist in a standard `binuils-gdb` clone.  Then:

```
cd build
../src/configure --enable-cgen-maint
make all-opcodes
cd opcodes
make stamp-epiphany stamp-fr30 stamp-frv stamp-ip2k \
     stamp-iq2000 stamp-lm32 stamp-m32c stamp-m32r \
     stamp-mep stamp-mt stamp-or1k stamp-xc16x \
     stamp-xstormy16
```

This will regenerate all of the libopcodes source files.  Repeat this
process with both the CVS and git versions of CGEN to ensure te same
results are created.

#### Building with out of tree CGEN

This relies on having the patch mentioned previously applied to the
binutils-gdb tree.  The advantage here is that cgen doesn't need to be
copied into the binutils-gdb tree.

```
cd build      # Enter the binutils-gdb build directory.
../src/configure --enable-cgen-maint=/path/to/cgen
make all-opcodes
cd opcodes
make stamp-epiphany stamp-fr30 stamp-frv stamp-ip2k \
     stamp-iq2000 stamp-lm32 stamp-m32c stamp-m32r \
     stamp-mep stamp-mt stamp-or1k stamp-xc16x \
     stamp-xstormy16
```

#### Results

**TODO** - Run tests, and add results.

### Generating libsim Source in binutils-gdb

#### Building with in tree CGEN

I think that the only simulator targets that currently use CGEN are:

* `cris`
* `frv`
* `iq2000`
* `lm32`
* `m32r`
* `sh64`

To regenerate the simulator souce files using cgen, you'll need to,
for each target:

```
../src/configure --target=TARGET --enable-cgen-maint
make all-sim
cd sim
make stamp-arch stamp-cpu
```

#### Building with out of tree CGEN

As with regenerating libopcodes, with the binutils-gdb patch applied
cgen can be located outside of the binutils-gdb tree, but otherwise
the instructions are unchanged:

```
../src/configure --target=TARGET --enable-cgen-maint=/path/to/cgen
make all-sim
cd sim
make stamp-arch stamp-cpu
```

#### Results

**TODO** - Run tests, and add results.

### Generating sid Source

See [sid](https://sourceware.org/sid/).

**TODO** This still needs to be done.  The sid project seems to be
even less actively developed than CGEN, but we probably should still
check that the generated source can still be generated.
