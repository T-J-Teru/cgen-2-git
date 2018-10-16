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

## Comparison Of Past Release Files

The past release tar files include more than just the cgen
subdirectory.  They include the top level repository infrastructure
that was shared with all of the tools that used to live in the old cvs
repository.

As part of this git conversion the assumption is being made that non
of this additional infrastructure is really needed to cgen, and has
been discarded.  As a result, when looking at the past release tar
files only the `cgen/` subdirectory of the release can be compared.

### cgen-1-0

Downloaded the CGEN 1.0 release tar file from:

  ftp://sourceware.org/pub/cgen/releases/cgen-1.0.tar.gz

unpacked it, and then compared the `cgen/` subdirectory in the release
with a git checkout of the cgen-1-0 tag.  There are no differences.

### cgen-1-1

Downloaded the CGEN 1.1 release tar file from:

  ftp://sourceware.org/pub/cgen/releases/cgen-1.1.tar.gz

unpacked it, and then compared the `cgen/` subdirectory in the release
with a git checkout of the cgen-1-1 tag.  There are no differences.

## Comparison Of Branches And Tags In Version Control

### Tip Of Branch Comparisons

There are only two branches, `master`, which needs to be compared with
the main branch from cvs, and the `cgen-1_1-branch` branch which is
present in both git and cvs.

Both of these comparisons were done by manually checking out the
required branch from cvs and git and comparing.  There are no
differences.

This check is part of the automated `convert.sh` script, if the
`--validate` argument is passed.

### Tag Comparisons

I checked out all of the tags `cgen-1-0`, and `cgen-snapshot-*` in
both CVS and git, and compared the checkouts, excluding `CVS` and
`.git` directories.

The `cgen-1-1` tag can't be compared as this is a tag I have created
as part of the conversion from CVS to git.

There were no differences.

This check is part of the automated `convert.sh` script, if the
`--validate` argument is passed.

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
make -C opcodes stamp-epiphany stamp-fr30 stamp-frv stamp-ip2k \
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
make -C opcodes stamp-epiphany stamp-fr30 stamp-frv stamp-ip2k \
                stamp-iq2000 stamp-lm32 stamp-m32c stamp-m32r \
                stamp-mep stamp-mt stamp-or1k stamp-xc16x \
                stamp-xstormy16
```

#### Results

Using both cvs and git, both in tree and out of tree, the results are
the same.

The regenerated source files are identical to the versions already
committed into binutils-gdb.

### Generating libsim Source in binutils-gdb

#### Building with in tree CGEN

I think that the only simulator targets that currently use CGEN are:

* `cris`
* `frv`
* `iq2000`
* `lm32`
* `m32r`
* `sh64`

To regenerate the simulator source files using cgen we will configure
for a suitable target and then rebuild the simulator.  This should
trigger regeneration of all cgen source files.  The targets we will
configure for are:

* `cris-elf`
* `frv-elf`
* `iq2000-elf`
* `lm32-elf`
* `m32r-elf`

The `sh64` target is currently in the process of being removed from
the binutils-gdb, attempting to configure for this target in the bfd/
subdirectory will give an error about the target having been removed.

```
../src/configure --target=TARGET --enable-cgen-maint
make all-sim
```

#### Building with out of tree CGEN

As with regenerating libopcodes, with the binutils-gdb patch applied
cgen can be located outside of the binutils-gdb tree, but otherwise
the instructions are unchanged:

**NOTE:** The `cris-elf` target requires an extra patch, this has not
yet been submitted upstream, and is included in this repository as
`cris-sim.patch` for now.

```
../src/configure --target=TARGET --enable-cgen-maint=/path/to/cgen
make all-sim
```

#### Validating For sh64

Despite having been removed from bfd/ we can still check that the sh64
source files are regenerated correctly.  We just need to follow a
slightly different process.

First, configure with either in tree or out of tree cgen as before,
passing `--target=sh64` to configure, and then:

```
make configure-sim
make -C sim/sh64 stamp-all
```

This should trigger the regeneration of the cgen components.

#### Results

For all targets, the files regenerated using the latest CVS commit
don't exactly match the versions committed into the sim/ directory.
The files regenerated using out of tree CVS are identical to the files
regenerated using in tree CVS.

The differences between what is checked into the sim/ directory, and
what is regenerated is more than just comments, though it is unclear
how significant these changes are.  All of the targets other than
`sh64` build successfully, even with the regenerated source, so that's
something.

The files regenerate when using the git conversions exactly match the
files regenerated when using CVS, so, as far as the git conversion is
concerned, I believe that we are fine.

### Generating sid Source

See [sid](https://sourceware.org/sid/).

The instructions for sid on the project page are out of date.  You'll
need to fetch the sources from sourceware.org, not sources.redhat.com
as they suggest.

With the checkout complete you'll find that sid comes complete with a
cgen checkout from CVS.

In order to regenerate the sid sources correctly we need to copy
around some of the cpu descriptions, so, from the root of the source
checkout:

```
cp cpu/mep* cgen/cpu/
cp cpu/xstormy16* cgen/cpu/
```

Now create a build directory, and configure sid, this should be done
outside of the source checkout:

```
mkdir build
cd build
../src/configure --enable-targets=all --enable-cgen-maint
make all-sid
```

The last make will most likely fail unless you have a very old
compiler.  Non of the tools I had sitting around were able to build
sid, however, I don't think this matters.

Once the complete build tree has been configured as part of the failed
make attempt, we can regenerate the cgen source.  Again, from the
build directory, run:

```
make -C sid/component/cgen-cpu/ cgen-all
```

This should regenerate all of the cgen components within sid using the
current cgen (from cvs).  The only differences I saw were that the
copyright dates changed (to include current year), and the extra file
`sid/component/cgen-cpu/m32r/m32r-write.cxx` was created.  As all the
other targets appear to have their own version of this file my current
assumption is that this was missed from a CVS commit at some point.

After this delete the cgen directory out of the source tree, and copy
in the current HEAD of the git master branch.  Then recopy the missing
cpu descriptions, and repeat the configure and build steps.

The end result is that the regenerated sid sources are identical using
the CVS repository and when using the git conversion copied into the
sid tree.

Currently there is no patch for sid to support using out of tree cgen.
The last real commit to sid was in 2001, and the last maintenance
commit was in 2007.  Since then sid has been dormant, and so I'm
reluctant to invest time in fixing the build system, however, it would
seem surprising if this proved to be a difficult task, considering how
easy it was for the opcodes/ and sim/ directories.

#### Results

Using the latest version of cgen from CVS and the HEAD of the master
branch from the cvs to git conversion, the generated source components
of sid are identical.  These generated components are (other than
trivial comment changes) identical to the source components currently
checked into CVS.