#!/usr/bin/env bash
set -e
set -o pipefail

LOG=/mnt/lfs/build.log
exec > >(tee -a $LOG) 2>&1

echo "==== LFS TEMP TOOLCHAIN BUILD START ===="

# 基础变量
export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=$LFS/tools/bin:/usr/bin:/bin

cd $LFS/sources

build_binutils_pass1() {
    echo ">>> binutils pass1"
    tar xf binutils-*.tar.*
    cd binutils-2.46.0
    mkdir -v build && cd build

    ../configure \
        --prefix=$LFS/tools \
        --with-sysroot=$LFS \
        --target=$LFS_TGT \
        --disable-nls \
        --enable-gprofng=no \
        --disable-werror

    make -j$(nproc)
    make install

    cd ../..
    rm -rf binutils-2.46.0
}

build_gcc_pass1() {
    echo ">>> gcc pass1"
    tar xf gcc-*.tar.*
    cd gcc-15.2.0

    tar xf ../mpfr-*.tar.* && mv mpfr-* mpfr
    tar xf ../gmp-*.tar.* && mv gmp-* gmp
    tar xf ../mpc-*.tar.* && mv mpc-* mpc

    mkdir build && cd build

    ../configure \
        --target=$LFS_TGT \
        --prefix=$LFS/tools \
        --with-glibc-version=2.37 \
        --with-sysroot=$LFS \
        --with-newlib \
        --without-headers \
        --enable-default-pie \
        --enable-default-ssp \
        --disable-nls \
        --disable-shared \
        --disable-multilib \
        --disable-threads \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libvtv \
        --disable-libstdcxx \
        --enable-languages=c,c++

    make -j$(nproc) && make install

    cd ../..
    rm -rf gcc-15.2.0
}

build_linux_headers() {
    echo ">>> linux headers"
    tar xf linux-*.tar.*
    cd linux-6.18.10
    make mrproper && make headers

    find usr/include -name '.*' -delete
    rm usr/include/Makefile

    cp -rv usr/include $LFS/usr

    cd ..
    rm -rf linux-6.18.10
}

build_glibc() {
    echo ">>> glibc"
    tar xf glibc-*.tar.*
    GLIBC=$(ls -d glibc-* | head -n1)
    cd $GLIBC

    rm -rf build && mkdir build && cd build

    ../configure \
        --prefix=/usr \
        --host=$LFS_TGT \
        --build=$(../config.guess) \
        --enable-kernel=4.14 \
        --with-headers=$LFS/usr/include

    make -j$(nproc)
    make DESTDIR=$LFS install

    cd ../..
    rm -rf glibc-2.43
}

build_libstdcpp() {
    echo ">>> libstdc++"

    tar xf gcc-*.tar.*
    GCC_DIR=$(ls -d gcc-* | head -n1)
    cd $GCC_DIR

    mkdir -v build && cd build

    ../libstdc++-v3/configure \
        --host=$LFS_TGT \
        --build=$(../config.guess) \
        --prefix=/usr \
        --disable-multilib \
        --disable-nls \
        --disable-libstdcxx-pch \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0

    make -j$(nproc)
    make DESTDIR=$LFS install

    cd ../..
    rm -rf $GCC_DIR
}

main() {
    build_binutils_pass1
    build_gcc_pass1
    build_linux_headers
    build_glibc
    build_libstdcpp
}

main

echo "==== BUILD COMPLETE ===="

