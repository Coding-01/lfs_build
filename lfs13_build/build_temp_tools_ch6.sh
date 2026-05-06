#!/usr/bin/env bash
set -euo pipefail

# 基础变量
export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=$LFS/tools/bin:/usr/bin:/bin

# 确保在 sources 目录
cd $LFS/sources

log() {
    echo -e "\n\033[1;32m>>> Building: $1\033[0m\n"
}

extract() {
    local file=$(ls $1*.tar.* | head -n1)
    tar xf "$file"
}

cleanup() {
    local dir=$1
    cd $LFS/sources
    rm -rf "$dir"
    # 给系统一点时间清理文件句柄
    sync
}

# --- 核心修复函数：同步 GCC 头文件 ---
fix_gcc_headers() {
    log "Fixing GCC internal headers..."
    # 找到 mkheaders 脚本并执行，确保 GCC 看到 Glibc 的 limits.h
    find $LFS/tools/libexec/gcc/$LFS_TGT -name mkheaders -exec {} \;
    sync && sleep 2
}

# --- 开始构建函数 ---

build_m4() {
    log "M4"
    extract m4
    cd m4-1.4.21
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup m4-1.4.21
}

build_ncurses() {
    log "Ncurses"
    extract ncurses
    cd ncurses-6.6
    sed -i s/mawk// configure
    mkdir -p build
    pushd build
      ../configure
      make -C include
      make -C progs tic
    popd
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) \
                --with-shared --without-debug --without-ada --enable-widec --disable-normal
    make -j$(nproc)
    make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
    cleanup ncurses-6.6
}

build_bash() {
    log "Bash"
    extract bash
    cd bash-5.3
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(sh support/config.guess) --without-bash-malloc
    make -j$(nproc) && make DESTDIR=$LFS install
    ln -sf bash $LFS/usr/bin/sh
    cleanup bash-5.3
}

build_coreutils() {
    log "Coreutils (with MB_LEN_MAX fix)"
    extract coreutils
    cd coreutils-9.10
    
    # 【关键修改】：显式定义 MB_LEN_MAX 解决脚本运行过快导致的头文件冲突
    export CFLAGS="-DMB_LEN_MAX=16"
    
    ./configure --prefix=/usr                     \
                --host=$LFS_TGT                   \
                --build=$(build-aux/config.guess) \
                --enable-install-program=hostname \
                --enable-no-install-program=kill,uptime
    
    make -j$(nproc)
    make DESTDIR=$LFS install
    
    unset CFLAGS
    
    # 移动文件到符合 FHS 标准的位置
    mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
    mkdir -pv $LFS/usr/share/man/man8
    mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
    
    cleanup coreutils-9.10
}

build_diffutils() {
    log "Diffutils"
    extract diffutils
    cd diffutils-3.12
    gl_cv_func_strcasecmp_works=yes \
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup diffutils-3.12
}

build_file() {
    log "File"
    extract file
    cd file-5.46
    mkdir -p build
    pushd build
      ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
      make
    popd
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
    make -j$(nproc) FILE_COMPILE=$(pwd)/build/src/file && make DESTDIR=$LFS install
    cleanup file-5.46
}

build_findutils() {
    log "Findutils"
    extract findutils
    cd findutils-4.10.0
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup findutils-4.10.0
}

build_gawk() {
    log "Gawk"
    extract gawk
    cd gawk-5.3.2
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup gawk-5.3.2
}

build_grep() {
    log "Grep"
    extract grep
    cd grep-3.12
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup grep-3.12
}

build_gzip() {
    log "Gzip"
    extract gzip
    cd gzip-1.14
    ./configure --prefix=/usr --host=$LFS_TGT
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup gzip-1.14
}

build_make() {
    log "Make"
    extract make
    cd make-4.4.1
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) --without-guile
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup make-4.4.1
}

build_patch() {
    log "Patch"
    extract patch
    cd patch-2.8
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup patch-2.8
}

build_sed() {
    log "Sed"
    extract sed
    cd sed-4.9
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup sed-4.9
}

build_tar() {
    log "Tar"
    extract tar
    cd tar-1.35
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup tar-1.35
}

build_xz() {
    log "Xz"
    extract xz
    cd xz-5.8.2
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) --disable-static
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup xz-5.8.2
}

build_python() {
    log "Python (Final Robust Build)"
    local VER=3.14.3
    tar xf Python-${VER}.tar.*
    cd Python-${VER}

    # 1. 编译宿主机临时 python (确保版本一致)
    mkdir -p native-build
    pushd native-build
        ../configure --config-cache
        make -j$(nproc) python
    popd

    # 2. 交叉编译主程序
    # ac_cv_func_chflags=no: 修复 posixmodule.c 中的 chflags 报错
    # ac_cv_func_lchflags=no: 预防类似的 lchflags 报错
    # ac_cv_buggy_getaddrinfo=no: 绕过网络函数 Bug 检测
    # CPPFLAGS="-DSSIZE_MAX=LONG_MAX": 补齐缺失的宏定义
    
    ac_cv_func_chflags=no \
    ac_cv_func_lchflags=no \
    ac_cv_buggy_getaddrinfo=no \
    ac_cv_file__dev_ptmx=yes \
    ac_cv_file__dev_ptc=no \
    CPPFLAGS="-DSSIZE_MAX=LONG_MAX" \
    ./configure --prefix=/usr \
                --host=$LFS_TGT \
                --build=$(./config.guess) \
                --enable-shared \
                --without-ensurepip \
                --with-build-python=$(pwd)/native-build/python

    make -j$(nproc)
    make DESTDIR=$LFS install
    
    cleanup Python-${VER}
}

build_texinfo() {
    log "Texinfo"
    extract texinfo
    cd texinfo-7.2
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make -j$(nproc) && make DESTDIR=$LFS install
    cleanup texinfo-7.2
}

build_util_linux() {
    log "Util-linux (Final Cleanup Build)"
    local VER=2.41.3
    tar xf util-linux-${VER}.tar.*
    cd util-linux-${VER}
    
    mkdir -pv $LFS/var/lib/hwclock

    # 核心修复：
    # 1. CPPFLAGS="-DLINE_MAX=2048": 强制定义缺失的 LINE_MAX，解决 bits.c 报错
    # 2. --disable-liblastlog2: 避开对 sqlite3 的依赖
    # 3. --without-python: 避免调用不完整的 Python 环境
    
    ./configure --host=$LFS_TGT \
                --build=$(./config.guess) \
                --libdir=/usr/lib \
                --runstatedir=/run \
                --disable-chfn-chsh \
                --disable-login \
                --disable-nologin \
                --disable-su \
                --disable-setpriv \
                --disable-runuser \
                --disable-pylibmount \
                --disable-static \
                --disable-liblastlog2 \
                --without-python \
                --without-tinfo \
                --without-readline \
		--disable-makeinstall-chown \
                --disable-makeinstall-setuid \
                CPPFLAGS="-DLINE_MAX=2048" \
                ADJTIME_PATH=/var/lib/hwclock/adjtime

    make -j$(nproc)
    make DESTDIR=$LFS install
    
    cleanup util-linux-${VER}
}

# --- 主程序 ---

main() {
    # 确保GCC头文件同步（解决 MB_LEN_MAX 隐患）
    fix_gcc_headers

    # 按顺序执行
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
    build_python
    build_texinfo
    build_util_linux
}

main

echo -e "\n\033[1;34m==== LFS 第 6 章构建完成！ ====\033[0m"

