#!/usr/bin/env bash
set -euo pipefail

export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=$LFS/tools/bin:/usr/bin:/bin

cd $LFS/sources

log() {
    echo -e "\n>>> $1\n"
}

extract() {
    tar xf "$1"
}

enter_dir() {
    cd "$1"
}

cleanup() {
    cd $LFS/sources
    rm -rf "$1"
}

build_m4() {
    log "m4"
    PKG=m4-1.4.21
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_ncurses() {
    log "ncurses"
    PKG=ncurses-6.6
    extract $PKG.tar.gz
    enter_dir $PKG

    ./configure \
        --prefix=$LFS/tools \
        --with-shared \
        --without-debug \
        --without-ada \
        --enable-widec

    make -j$(nproc)
    make install

    cleanup $PKG
}

build_bash() {
    log "bash"
    PKG=bash-5.3
    extract $PKG.tar.gz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools --without-bash-malloc
    make -j$(nproc)
    make install

    ln -sf bash $LFS/tools/bin/sh

    cleanup $PKG
}

build_coreutils() {
    log "coreutils"
    PKG=coreutils-9.10
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure \
        --prefix=$LFS/tools \
        --enable-install-program=hostname

    make -j$(nproc)
    make install

    cleanup $PKG
}

build_diffutils() {
    log "diffutils"
    PKG=diffutils-3.12
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_file() {
    log "file"
    PKG=file-5.46
    extract $PKG.tar.gz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_findutils() {
    log "findutils"
    PKG=findutils-4.10.0
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_gawk() {
    log "gawk"
    PKG=gawk-5.3.2
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_grep() {
    log "grep"
    PKG=grep-3.12
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_gzip() {
    log "gzip"
    PKG=gzip-1.14
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_make() {
    log "make"
    PKG=make-4.4.1
    extract $PKG.tar.gz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_patch() {
    log "patch"
    PKG=patch-2.8
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_sed() {
    log "sed"
    PKG=sed-4.9
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_tar() {
    log "tar"
    PKG=tar-1.35
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

build_xz() {
    log "xz"
    PKG=xz-5.8.2
    extract $PKG.tar.xz
    enter_dir $PKG

    ./configure --prefix=$LFS/tools
    make -j$(nproc)
    make install

    cleanup $PKG
}

main() {
    build_m4
    build_ncurses
    build_bash
    build_coreutils
    build_diffutils
    build_file
    build_findutils
    build_gawk
    build_grep
    build_gzip
    build_make
    build_patch
    build_sed
    build_tar
    build_xz
}

main

echo "==== CH6 DONE ===="
