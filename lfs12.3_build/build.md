
[官方文档](https://linuxfromscratch.org/lfs/read.html)

[中文文档](https://lfs.xry111.site/zh_CN/13.0-systemd/)



# 前奏
```shell
2026-4-20 7:40 AM

Linux From Scratch（LFS）是一个开源项目，旨在指导用户从零开始构建一个完整的、最小化的Linux系统。与直接安装发行版（如Ubuntu、CentOS）不同，LFS要求你手动编译每一个组件——从内核到基础工具，再到系统库。
该过程虽然耗时，但能让你深入理解Linux系统的底层架构、组件依赖关系和启动流程。
无论你是想定制一个极致精简的嵌入式系统，还是想系统学习Linux原理，LFS都是绝佳的实践途径

本文将介绍LFS的构建流程，包括前置准备、环境搭建、工具编译、系统构建、配置与启动等核心步骤，并穿插最佳实践和常见问题解决，帮助你顺利完成第一个LFS系统

本次在vmware workstation 17 pro上的Ubuntu24.04.1 LTS上操作

# VM Configuration
8v/16G/172.16.186.128/24
sys disk：80G
lfs disk：60G (mount to /mnt/lfs)

```





# introduction
## Hardware Requirements
```shell
# 宿主系统要求
LFS需要在一个已有的Linux系统（称为“宿主系统”）上构建，推荐使用Debian/Ubuntu、Fedora或Arch等主流发行版，且需满足以下条件：
宿主系统内核版本 ≥ 4.14（LFS 11.2要求，旧版本可能存在兼容性问题）；
已安装开发工具链（gcc、g++、make、binutils等）；
支持64位架构（LFS默认构建64位系统，32位需额外配置）
验证宿主系统兼容性：
LFS提供了一个脚本检查宿主系统是否满足要求，可通过以下命令下载并运行：


# update repo
rambo@ub24-1:~$ cat /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: noble noble-updates noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

rambo@ub24-1:~$ sudo apt update

# 安装缺失的核心编译工具
rambo@ub24-1:~$ sudo apt install -y build-essential bison gawk m4 make texinfo

# 将 sh 修改为指向 bash (选择 "No" 或手动链接)
rambo@ub24-1:~$ sudo ln -sf /bin/bash /bin/sh

# 验证 yacc 软链接
rambo@ub24-1:~$ sudo ln -sf /usr/bin/bison /usr/bin/yacc



rambo@ub24-1:~$ cat > version-check.sh << "EOF"
#!/bin/bash
# A script to list version numbers of critical development tools

# If you have tools installed in other directories, adjust PATH here AND
# in ~lfs/.bashrc (section 4.4) as well.

LC_ALL=C 
PATH=/usr/bin:/bin

bail() { echo "FATAL: $1"; exit 1; }
grep --version > /dev/null 2> /dev/null || bail "grep does not work"
sed '' /dev/null || bail "sed does not work"
sort   /dev/null || bail "sort does not work"

ver_check()
{
   if ! type -p $2 &>/dev/null
   then 
     echo "ERROR: Cannot find $2 ($1)"; return 1; 
   fi
   v=$($2 --version 2>&1 | grep -E -o '[0-9]+\.[0-9\.]+[a-z]*' | head -n1)
   if printf '%s\n' $3 $v | sort --version-sort --check &>/dev/null
   then 
     printf "OK:    %-9s %-6s >= $3\n" "$1" "$v"; return 0;
   else 
     printf "ERROR: %-9s is TOO OLD ($3 or later required)\n" "$1"; 
     return 1; 
   fi
}

ver_kernel()
{
   kver=$(uname -r | grep -E -o '^[0-9\.]+')
   if printf '%s\n' $1 $kver | sort --version-sort --check &>/dev/null
   then 
     printf "OK:    Linux Kernel $kver >= $1\n"; return 0;
   else 
     printf "ERROR: Linux Kernel ($kver) is TOO OLD ($1 or later required)\n" "$kver"; 
     return 1; 
   fi
}

# Coreutils first because --version-sort needs Coreutils >= 7.0
ver_check Coreutils      sort     8.1 || bail "Coreutils too old, stop"
ver_check Bash           bash     3.2
ver_check Binutils       ld       2.13.1
ver_check Bison          bison    2.7
ver_check Diffutils      diff     2.8.1
ver_check Findutils      find     4.2.31
ver_check Gawk           gawk     4.0.1
ver_check GCC            gcc      5.2
ver_check "GCC (C++)"    g++      5.2
ver_check Grep           grep     2.5.1a
ver_check Gzip           gzip     1.3.12
ver_check M4             m4       1.4.10
ver_check Make           make     4.0
ver_check Patch          patch    2.5.4
ver_check Perl           perl     5.8.8
ver_check Python         python3  3.4
ver_check Sed            sed      4.1.5
ver_check Tar            tar      1.22
ver_check Texinfo        texi2any 5.0
ver_check Xz             xz       5.0.0
ver_kernel 5.4 

if mount | grep -q 'devpts on /dev/pts' && [ -e /dev/ptmx ]
then echo "OK:    Linux Kernel supports UNIX 98 PTY";
else echo "ERROR: Linux Kernel does NOT support UNIX 98 PTY"; fi

alias_check() {
   if $1 --version 2>&1 | grep -qi $2
   then printf "OK:    %-4s is $2\n" "$1";
   else printf "ERROR: %-4s is NOT $2\n" "$1"; fi
}
echo "Aliases:"
alias_check awk GNU
alias_check yacc Bison
alias_check sh Bash

echo "Compiler check:"
if printf "int main(){}" | g++ -x c++ -
then echo "OK:    g++ works";
else echo "ERROR: g++ does NOT work"; fi
rm -f a.out

if [ "$(nproc)" = "" ]; then
   echo "ERROR: nproc is not available or it produces empty output"
else
   echo "OK: nproc reports $(nproc) logical cores are available"
fi
EOF


rambo@ub24-1:~$ bash version-check.sh
OK:    Coreutils 9.4    >= 8.1
OK:    Bash      5.2.21 >= 3.2
OK:    Binutils  2.42   >= 2.13.1
OK:    Bison     3.8.2  >= 2.7
OK:    Diffutils 3.10   >= 2.8.1
OK:    Findutils 4.9.0  >= 4.2.31
OK:    Gawk      5.2.1  >= 4.0.1
OK:    GCC       13.3.0 >= 5.4
OK:    GCC (C++) 13.3.0 >= 5.4
OK:    Grep      3.11   >= 2.5.1a
OK:    Gzip      1.12   >= 1.3.12
OK:    M4        1.4.19 >= 1.4.10
OK:    Make      4.3    >= 4.0
OK:    Patch     2.7.6  >= 2.5.4
OK:    Perl      5.38.2 >= 5.8.8
OK:    Python    3.12.3 >= 3.4
OK:    Sed       4.9    >= 4.1.5
OK:    Tar       1.35   >= 1.22
OK:    Texinfo   7.1    >= 5.0
OK:    Xz        5.4.5  >= 5.0.0
OK:    Linux Kernel 6.8.0 >= 5.4
OK:    Linux Kernel supports UNIX 98 PTY
Aliases:
OK:    awk  is GNU
OK:    yacc is Bison
OK:    sh   is Bash
Compiler check:
OK:    g++ works
OK: nproc reports 8 logical cores are available

```



# 分阶段构建LFS
```shell
# 60G磁盘分区与格式化
rambo@ub24-1:~$ sudo fdisk /dev/sdb -l
Disk /dev/sdb: 60 GiB, 64424509440 bytes, 125829120 sectors
Disk model: VMware Virtual S
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


# 进入分区工具
rambo@ub24-1:~$ sudo fdisk /dev/sdb
Welcome to fdisk (util-linux 2.39.3).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table.
Created a new DOS (MBR) disklabel with disk identifier 0xcf146a4e.

Command (m for help): g
Created a new GPT disklabel (GUID: 4DA2451A-1AF1-409C-9F91-61134C404477).

Command (m for help): n
Partition number (1-128, default 1): 
First sector (2048-125829086, default 2048): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-125829086, default 125827071): +5M

Created a new partition 1 of type 'Linux filesystem' and of size 5 MiB.

Command (m for help): t
Selected partition 1
Partition type or alias (type L to list all): 4                                 # 这是BIOS boot，专门给GRUB用的
Changed type of partition 'Linux server data' to 'BIOS boot'.

Command (m for help): n
Partition number (2-128, default 2): 
First sector (12288-125829086, default 12288):  
Last sector, +/-sectors or +/-size{K,M,G,T,P} (12288-125829086, default 125827071): +6G      # 作为Swap

Created a new partition 2 of type 'Linux filesystem' and of size 6 GiB.

Command (m for help): t
Partition number (1,2, default 2): 
Partition type or alias (type L to list all): 19                                # Linux swap

Changed type of partition 'Linux filesystem' to 'Linux swap'.

Command (m for help): n
Partition number (3-128, default 3): 
First sector (12595200-125829086, default 12595200): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (12595200-125829086, default 125827071):          # 剩下的全部给LFS

Created a new partition 3 of type 'Linux filesystem' and of size 54 Gi


Command (m for help): w



# 格式化分区为ext4
rambo@ub24-1:~$ sudo mkfs.ext4 /dev/sdb3

# 初始化Swap(sdb2)
rambo@ub24-1:~$ sudo mkswap /dev/sdb2

# 启用Swap(这样编译时内存更充裕)
rambo@ub24-1:~$ sudo swapon -v /dev/sdb2




# 设置 $LFS 环境变量和 Umask
rambo@ub24-1:~$ sudo mkdir -p /mnt/lfs
rambo@ub24-1:~$ export LFS=/mnt/lfs
rambo@ub24-1:~$ umask 022
rambo@ub24-1:~$ echo $LFS
/mnt/lfs
rambo@ub24-1:~$ umask
0022



# 挂载文件系统
将新分区挂载到宿主系统的临时目录（如/mnt/lfs），并设置必要的挂载点
rambo@ub24-1:~$ lsblk -f /dev/sdb
NAME   FSTYPE FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sdb                                                                           
├─sdb1                                                                        
├─sdb2 swap   1           f1caaec8-12bc-4557-9366-82f995e79cd5                [SWAP]
└─sdb3 ext4   1.0         a21cd4a8-f0f6-4d13-8c95-be53f4311b7c                



rambo@ub24-1:~$ echo 'UUID=a21cd4a8-f0f6-4d13-8c95-be53f4311b7c   /mnt/lfs   ext4  defaults 0 0' | sudo tee -a /etc/fstab

rambo@ub24-1:~$ sudo systemctl daemon-reload
rambo@ub24-1:~$ sudo mount -a

rambo@ub24-1:~$ df -Th /mnt/lfs
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/sdb3      ext4   53G   24K   51G   1% /mnt/lfs

将$LFS目录 (即为LFS系统新创建的文件系统的根目录) 的所有者设为root，访问权限设为755，以防个别宿主发行版中mkfs被配置为使用与此不同的默认值
rambo@ub24-1:~$ sudo chown root:root $LFS && sudo chmod 755 $LFS


# 挂载必要的伪文件系统（确保后续编译正常访问系统资源）
rambo@ub24-1:~$ sudo mkdir -p /mnt/lfs/{dev/pts,proc,sys,run}
sudo mount --bind /dev /mnt/lfs/dev
sudo mount --bind /dev/pts /mnt/lfs/dev/pts
sudo mount -t proc proc /mnt/lfs/proc
sudo mount -t sysfs sysfs /mnt/lfs/sys
sudo mount -t tmpfs tmpfs /mnt/lfs/run



# aliyun的gnu地址
https://mirrors.aliyun.com/gnu/




# 软件包和补丁
rambo@ub24-1:~$ sudo mkdir $LFS/sources && sudo chmod  a+wt $LFS/sources
rambo@ub24-1:~$ cd $LFS/sources/

# ================== 这部分不在官方文档中 ================================
# 需要单独下载的包，这2个包是为安装openssh
rambo@ub24-1:/mnt/lfs/sources$ wget https://mirrors.aliyun.com/openssh/portable/openssh-10.1p1.tar.gz \
https://www.thrysoee.dk/editline/libedit-20251016-3.1.tar.gz

注意：
如果需要创建好的LFS有更多的功能，需要单独下载并安装包，这里就只做备用和测试
openssh-10.1p1.tar.gz中的p1代表Portable，这是 Linux 系统专用的版本

wget https://mirrors.aliyun.com/gnu/wget/wget2-2.2.1.tar.gz


# =====================================================================


# 这是官方提供的包
rambo@ub24-1:/mnt/lfs/sources$ wget https://www.linuxfromscratch.org/lfs/view/12.3-systemd/wget-list-systemd \
https://www.linuxfromscratch.org/lfs/view/12.3-systemd/md5sums

rambo@ub24-1:/mnt/lfs/sources$ wget --input-file=wget-list-systemd --continue --directory-prefix=$LFS/sources
注意：请在干净的网络环境下进行，如使用了特殊网络则需要先去除


# 检查所有软件包的正确性
rambo@ub24-1:/mnt/lfs/sources$ pushd $LFS/sources; md5sum -c md5sums; popd
注意：可能出现报错，如出现包没有的情况则需要执行以下命令
rambo@ub24-1:/mnt/lfs/sources$ wget -nc -i wget-list-systemd -P $LFS/sources          # 如还有No such file or directory则需要再次执行该命令

# 再来检查所有软件包的正确性
rambo@ub24-1:/mnt/lfs/sources$ pushd $LFS/sources; md5sum -c md5sums; popd
....
  ....
expect-5.45.4-gcc15-1.patch: OK
glibc-fhs-1.patch: OK
kbd-2.9.0-backspace-1.patch: OK
/mnt/lfs/sources



官方提供的补丁地址：https://www.linuxfromscratch.org/lfs/view/stable/chapter03/patches.html





接下来做最后准备工作
在 LFS 文件系统中创建有限目录布局
rambo@ub24-1:/mnt/lfs/sources$ sudo mkdir -p $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

rambo@ub24-1:/mnt/lfs/sources$ for i in bin lib sbin;do sudo ln -s usr/$i $LFS/$i;done

rambo@ub24-1:/mnt/lfs/sources$ case $(uname -m) in  x86_64) sudo mkdir -p  $LFS/lib64 ;;esac

# 创建交叉编译的目录
rambo@ub24-1:/mnt/lfs/sources$ sudo mkdir -p $LFS/tools
rambo@ub24-1:/mnt/lfs/sources$ sudo ln -sfv $LFS/tools  /        # 这一步没错，就是要挂载到宿主机的/上
rambo@ub24-1:~$ ls -ld  /tools
lrwxrwxrwx 1 root root 14 Apr 19 16:37 /tools -> /mnt/lfs/tools



# 添加LFS用户
作用：宿主机上的lfs用户是在Ubuntu宿机上设置的。目的是为了让你在编译"临时工具链"时有一个干净的、不被Ubuntu干扰的环境。这些配置保存在Ubuntu磁盘的/home/lfs/.bashrc中
rambo@ub24-1:/mnt/lfs/sources$ sudo groupadd lfs && sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
rambo@ub24-1:/mnt/lfs/sources$ sudo passwd lfs          # 密码是6a

rambo@ub24-1:/mnt/lfs/sources$ sudo chown  lfs $LFS/{usr{,/*},var,etc,tools}
rambo@ub24-1:/mnt/lfs/sources$ case $(uname -m) in   x86_64)  sudo chown  lfs $LFS/lib64 ;;esac


# 切换到lfs用户
rambo@ub24-1:/mnt/lfs/sources$ echo $LFS
/mnt/lfs

rambo@ub24-1:/mnt/lfs/sources$ su - lfs
Password:             # 密码是6a
lfs@ub24-1:~$ cd /mnt/lfs/sources/



# 环境搭建
1. 确保 LFS 的 /etc 目录存在
lfs@ub24-1:/mnt/lfs/sources$ mkdir -pv $LFS/etc
lfs@ub24-1:/mnt/lfs/sources$ cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
释义:
\u:用户名 
\h:主机名
\w：代表当前完整的工作路径(Working Directory)
\W：只代表当前目录的最后一级


lfs@ub24-1:/mnt/lfs/sources$ cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=$LFS/tools/bin:/bin:/usr/bin
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF


lfs@ub24-1:/mnt/lfs/sources$ source ~/.bash_profile

# 验证
lfs@ub24-1:/mnt/lfs/sources$ echo $LFS              # 结果必须是/mnt/lfs
/mnt/lfs
lfs@ub24-1:/mnt/lfs/sources$ echo $LC_ALL           # 结果必须是POSIX
POSIX
lfs@ub24-1:/mnt/lfs/sources$ echo $PATH             # 结果开头必须是/mnt/lfs/tools/bin:/bin:/usr/bin
/mnt/lfs/tools/bin:/bin:/usr/bin

```





# 构建LFS跨工具链和临时工具
## 编译交叉工具链
```shell
# binutils-2.46编译
lfs@ub24-1:/mnt/lfs/sources$ tar -xvf binutils-2.44.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd binutils-2.44
lfs@ub24-1:/mnt/lfs/sources/binutils-2.44$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46/build$ ../configure --prefix=$LFS/tools \
--with-sysroot=$LFS \
--target=$LFS_TGT   \
--disable-nls       \
--enable-gprofng=no \
--disable-werror    \
--enable-new-dtags  \
--enable-default-hash-style=gnu


lfs@ub24-1:/mnt/lfs/sources/binutils-2.46/build$ make -j$(nproc) && make install
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46/build$ cd ../../
lfs@ub24-1:/mnt/lfs/sources$ rm -rf binutils-2.44




# gcc-14.2.0编译
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gcc-14.2.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd gcc-14.2.0
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ 
tar -xf ../mpfr-4.2.1.tar.xz && mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc

lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac


lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ ../configure \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.41 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++

lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ make -j$(nproc) && make install

lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ cd ..
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gcc-14.2.0




# linux-6.13.4 API头文件
lfs@ub24-1:/mnt/lfs/sources$ tar xvf linux-6.13.4.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd linux-6.13.4
lfs@ub24-1:/mnt/lfs/sources/linux-6.13.4$ make mrproper
lfs@ub24-1:/mnt/lfs/sources/linux-6.13.4$ make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include  $LFS/usr

lfs@ub24-1:/mnt/lfs/sources/linux-6.13.4$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf linux-6.13.4



# glibc-2.41
lfs@ub24-1:/mnt/lfs/sources$ tar xvf glibc-2.41.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd glibc-2.41
lfs@ub24-1:/mnt/lfs/sources/glibc-2.41$ case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac

lfs@ub24-1:/mnt/lfs/sources/glibc-2.41$ patch -Np1 -i ../glibc-2.41-fhs-1.patch
lfs@ub24-1:/mnt/lfs/sources/glibc-2.41$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/glibc-2.41/build$ echo "rootsbindir=/usr/sbin" > configparms
lfs@ub24-1:/mnt/lfs/sources/glibc-2.41/build$ ../configure \
--prefix=/usr                      \
--host=$LFS_TGT                    \
--build=$(../scripts/config.guess) \
--enable-kernel=5.4                \
--with-headers=$LFS/usr/include    \
--disable-nscd                     \
libc_cv_slibdir=/usr/lib

lfs@ub24-1:/mnt/lfs/sources/glibc-2.41/build$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/glibc-2.41/build$ cd ../.. && rm -rf glibc-2.41



# GCC-14.2.0的Libstdc++
lfs@ub24-1:/mnt/lfs/sources$ tar -xvf gcc-14.2.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd gcc-14.2.0
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ ../libstdc++-v3/configure \
--host=$LFS_TGT               \
--build=$(../config.guess)    \
--prefix=/usr                 \
--disable-multilib            \
--disable-nls                 \
--disable-libstdcxx-pch       \
--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/14.2.0

lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la       # 删除libtool归档文件，因为它们对交叉编译有害
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ cd ../..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gcc-14.2.0


```






# 交叉编译临时工具
```shell
# M4-1.4.19
lfs@ub24-1:/mnt/lfs/sources$ tar xvf m4-1.4.19.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd m4-1.4.19
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.19$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.19$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.19$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf m4-1.4.19



# ncurses-6.5
lfs@ub24-1:/mnt/lfs/sources$ tar zxvf ncurses-6.5.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd ncurses-6.5
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.5$ mkdir build
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.5$ pushd build
  ../configure AWK=gawk
  make -C include
  make -C progs tic
popd

lfs@ub24-1:/mnt/lfs/sources/ncurses-6.5$ ./configure --prefix=/usr \
--host=$LFS_TGT --build=$(./config.guess) --mandir=/usr/share/man \
--with-manpage-format=normal --with-shared --without-normal --with-cxx-shared \
--without-debug --without-ada --disable-stripping AWK=gawk

lfs@ub24-1:/mnt/lfs/sources/ncurses-6.5$ make -j$(nproc) && make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.5$ ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.5$ sed -e 's/^#if.*XOPEN.*$/#if 1/'  -i $LFS/usr/include/curses.h
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.5$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf ncurses-6.5




# bash-5.2.37
lfs@ub24-1:/mnt/lfs/sources$ tar -zxvf  bash-5.2.37.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd bash-5.2.37
lfs@ub24-1:/mnt/lfs/sources/bash-5.2.37$ ./configure --prefix=/usr --build=$(sh support/config.guess) --host=$LFS_TGT --without-bash-malloc
lfs@ub24-1:/mnt/lfs/sources/bash-5.2.37$ make -j$(nproc)  && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/bash-5.2.37$ ln -sv bash  $LFS/bin/sh
lfs@ub24-1:/mnt/lfs/sources/bash-5.2.37$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf bash-5.2.37


# coreutils-9.6
lfs@ub24-1:/mnt/lfs/sources$ tar xvf coreutils-9.6.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd coreutils-9.6
lfs@ub24-1:/mnt/lfs/sources/coreutils-9.6$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
--enable-install-program=hostname --enable-no-install-program=kill,uptime

lfs@ub24-1:/mnt/lfs/sources/coreutils-9.6$ make -j$(nproc) && make DESTDIR=$LFS install
将程序移动到其最终预期位置。虽然在这个临时环境中并非必要，但我们必须这样做，因为有些程序将可执行文件的位置硬编码在代码中：
lfs@ub24-1:/mnt/lfs/sources/coreutils-9.6$ 
mv -v $LFS/usr/bin/chroot    $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'  $LFS/usr/share/man/man8/chroot.8

lfs@ub24-1:/mnt/lfs/sources/coreutils-9.6$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf coreutils-9.6



# diffutils-3.11
lfs@ub24-1:/mnt/lfs/sources$ tar xvf diffutils-3.11.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd diffutils-3.11
lfs@ub24-1:/mnt/lfs/sources/diffutils-3.11$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/diffutils-3.11$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf diffutils-3.11


# file-5.46
lfs@ub24-1:/mnt/lfs/sources$ tar -zxvf file-5.46.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd file-5.46
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ mkdir build
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ pushd build
  ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
  make
popd

lfs@ub24-1:/mnt/lfs/sources/file-5.46$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) && make FILE_COMPILE=$(pwd)/build/src/file && make DESTDIR=$LFS install

lfs@ub24-1:/mnt/lfs/sources/file-5.46$ rm -v $LFS/usr/lib/libmagic.la
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf file-5.46



# findutils-4.10.0
lfs@ub24-1:/mnt/lfs/sources$ tar xvf findutils-4.10.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd findutils-4.10.0
lfs@ub24-1:/mnt/lfs/sources/findutils-4.10.0$ ./configure --prefix=/usr --localstatedir=/var/lib/locate --host=$LFS_TGT --build=$(build-aux/config.guess) &&  make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/findutils-4.10.0$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf findutils-4.10.0



# gawk-5.3.1
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gawk-5.3.1.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd gawk-5.3.1 
lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.1$ sed -i 's/extras//' Makefile.in
lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.1$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install

lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.1$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gawk-5.3.1


# grep-3.11
lfs@ub24-1:/mnt/lfs/sources$ tar xvf grep-3.11.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd grep-3.11
lfs@ub24-1:/mnt/lfs/sources/grep-3.11$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/grep-3.11$ cd .. 
lfs@ub24-1:/mnt/lfs/sources$ rm -rf grep-3.11



# gzip-1.13
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gzip-1.13.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd gzip-1.13
lfs@ub24-1:/mnt/lfs/sources/gzip-1.13$ ./configure --prefix=/usr --host=$LFS_TGT && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/gzip-1.13$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gzip-1.13


# make-4.4.1
lfs@ub24-1:/mnt/lfs/sources$ tar zxvf make-4.4.1.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd make-4.4.1
lfs@ub24-1:/mnt/lfs/sources/make-4.4.1$ ./configure --prefix=/usr --without-guile --host=$LFS_TGT --build=$(build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install

lfs@ub24-1:/mnt/lfs/sources/make-4.4.1$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf make-4.4.1



# Patch-2.7.6
lfs@ub24-1:/mnt/lfs/sources$ tar xvf patch-2.7.6.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd patch-2.7.6
lfs@ub24-1:/mnt/lfs/sources/patch-2.7.6$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/patch-2.7.6$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf patch-2.7.6


# sed-4.9
lfs@ub24-1:/mnt/lfs/sources$ tar xvf sed-4.9.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd sed-4.9
lfs@ub24-1:/mnt/lfs/sources/sed-4.9$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/sed-4.9$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf sed-4.9



# tar-1.35
lfs@ub24-1:/mnt/lfs/sources$ tar xvf tar-1.35.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd tar-1.35
lfs@ub24-1:/mnt/lfs/sources/tar-1.35$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/tar-1.35$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf tar-1.35



# xz-5.6.4
lfs@ub24-1:/mnt/lfs/sources$ tar xvf xz-5.6.4.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd xz-5.6.4
lfs@ub24-1:/mnt/lfs/sources/xz-5.6.4$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) --disable-static --docdir=/usr/share/doc/xz-5.6.4 &&  make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/xz-5.6.4$ rm -v $LFS/usr/lib/liblzma.la
lfs@ub24-1:/mnt/lfs/sources/xz-5.6.4$ cd .. && rm -rf xz-5.6.4



# binutils-2.44 - 第2遍
lfs@ub24-1:/mnt/lfs/sources$ tar xvf binutils-2.44.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd binutils-2.44
lfs@ub24-1:/mnt/lfs/sources/binutils-2.44$ sed '6031s/$add_dir//' -i ltmain.sh
lfs@ub24-1:/mnt/lfs/sources/binutils-2.44$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/binutils-2.44$ ../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT \
--disable-nls --enable-shared  --enable-gprofng=no  --disable-werror --enable-64-bit-bfd --enable-new-dtags \
--enable-default-hash-style=gnu

lfs@ub24-1:/mnt/lfs/sources/binutils-2.44$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/binutils-2.44$ rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
lfs@ub24-1:/mnt/lfs/sources/binutils-2.44$ cd ../..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf binutils-2.44




# GCC-14.2.0 - 第2遍
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gcc-14.2.0 mpfr-4.2.1 gmp-6.3.0 mpc-1.3.1
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gcc-14.2.0.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd gcc-14.2.0
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ 
tar -xf ../mpfr-4.2.1.tar.xz && mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc

lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ ../configure \
    --build=$(../config.guess)                     \
    --host=$LFS_TGT                                \
    --target=$LFS_TGT                              \
    LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc      \
    --prefix=/usr                                  \
    --with-build-sysroot=$LFS                      \
    --enable-default-pie                           \
    --enable-default-ssp                           \
    --disable-nls                                  \
    --disable-multilib                             \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libsanitizer                         \
    --disable-libssp                               \
    --disable-libvtv                               \
    --enable-languages=c,c++

lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ ln -sv gcc  $LFS/usr/bin/cc
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ cd ../..



```






# 第三部分：构建LFS交叉工具链和临时工具
```shell
# 所有权变更
lfs@ub24-1:/mnt/lfs/sources$ exit

rambo@ub24-1:/mnt/lfs/sources$ echo $LFS            # 如没有输出则需要先设置变量export LFS=/mnt/lfs
/mnt/lfs


rambo@ub24-1:/mnt/lfs/sources$ sudo chown --from lfs -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools}
rambo@ub24-1:/mnt/lfs/sources$ case $(uname -m) in  x86_64) sudo chown --from lfs -R root:root $LFS/lib64 ;; esac




特别注意：往下一定要切换到root用户，否则所有的黑窗口会出问题
rambo@ub24-1:~$ sudo su -

root@ub24-1:~# export LFS=/mnt/lfs
root@ub24-1:~# echo $LFS
/mnt/lfs


# 准备虚拟内核文件系统（务必不要实用sudo）
# 创建这些虚拟文件系统将挂载到的目录
root@ub24-1:~$ mkdir -pv $LFS/{dev,proc,sys,run}

注意：文档要求挂载这些目录，是为了让你在接下来的 chroot 环境里拥有像“真系统”一样的能力：
/dev：让新系统里的 GCC 能找到 /dev/null
/proc & /sys：让编译程序知道你 CPU 有几个核心（用于 make -jX）

# 挂载和填充/dev，即挂载物理设备目录
root@ub24-1:~$ mount -v --bind /dev $LFS/dev

挂载虚拟内核文件系统
root@ub24-1:~$ 
mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys             # 这个如果挂载异常就需要umount -v $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
释义：
挂载点            目的
$LFS/dev       访问硬盘、键盘等硬件设备
$LFS/dev/pts   支持终端多窗口（虚拟终端）
$LFS/proc      访问进程信息
$LFS/sys       访问内核定义的系统信息
$LFS/run       存放系统运行时的临时数据





处理/dev/shm(LFS 12.3建议的操作)
root@ub24-1:~$ if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
else
  mount -vt tmpfs shm $LFS/dev/shm
fi






# 进入Chroot环境
释义: 执行chroot命令后你的根目录已经切换到了$LFS(即/mnt/lfs). 此时Bash已看不到宿主机的/home/lfs/.bashrc. 它会尝试从LFS内部的/etc/profile或/root/.bash_profile读取配置
root@ub24-1:~$ chroot "$LFS" /usr/bin/env -i HOME=/root TERM="$TERM" \
PS1='(lfs chroot) \u:\w\$ ' \
PATH=/usr/bin:/usr/sbin     \
MAKEFLAGS="-j$(nproc)"      \
TESTSUITEFLAGS="-j$(nproc)" \
/bin/bash --login

注意：bash提示符将显示I have no name! "这是正常的，因为/etc/passwd文件尚未创建"
(lfs chroot) I have no name!:/# 


# 创建目录
现在是时候在LFS文件系统中创建一些不在前几章所要求的有限目录中的根级目录结构了)
(lfs chroot) I have no name!:/# id
uid=0 gid=0 groups=0

(lfs chroot) I have no name!:/# mkdir -pv /{boot,home,mnt,opt,srv}

在根目录下创建所需的子目录集：
(lfs chroot) I have no name!:/# 
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp





# 创建必要文件和符号链接
历史上，Linux 将已挂载文件系统的列表保存在/etc/mtab文件中
现代内核在内部维护此列表，并通过/proc文件系统将其暴露给用户。为了满足那些期望找到 /etc/mtab 的工具的需求，请创建以下符号链接：
(lfs chroot) I have no name!:/# ln -sv /proc/self/mounts /etc/mtab
(lfs chroot) I have no name!:/# cat > /etc/hosts << "EOF"
127.0.0.1  localhost lfs
::1        localhost
EOF

为了使用户 root 能够登录并识别root这个名称，/etc/passwd 和 /etc/group 文件中必须包含相关的条目
创建 /etc/passwd 文件：
(lfs chroot) I have no name!:/# cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF


root用户的实际密码稍后设置。创建/etc/group文件：
(lfs chroot) I have no name!:/# cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF



# 在宿主机操作时路径要加上$LFS,比如cat > $LFS/etc/bashrc << "EOF"...
(lfs chroot) I have no name!:/# cat > /etc/bashrc << "EOF"
# /etc/bashrc

# 核心: 定义完整的PATH路径
# 包含sbin目录，否则root用户无法直接执行管理命令
export PATH=/usr/bin:/usr/sbin:/bin:/sbin

# 颜色定义
CYAN='\[\e[36m\]'
GREEN='\[\e[32m\]'
PURPLE='\[\e[35;1m\]'
RESET='\[\e[0m\]'

# 苹果风格温和配色PS1
# \u:用户名 \h:主机名 \w:完整路径 (解决你看不见路径的问题)
export PS1="${CYAN}\u${RESET}@${GREEN}\h${RESET}:${PURPLE}\w${RESET}\$ "

alias ls='ls --color=auto'
alias ll='ls -l'
EOF


Linux 系统中的用户组和 GID 并没有统一的强制标准，而是由实际需求（如 Udev 配置）、发行版惯例以及测试环境共同决定。
Linux Standard Base 仅建议必须存在 root（GID=0）和 bin（GID=1）两个组，像 tty（GID=5）这样的分配属于常见约定（在 systemd 中也有使用），但并非强制。
除此之外，组名和 GID 可以由管理员自由设定，规范的软件应依赖组名而非数字ID。内核使用 65534 表示未映射的用户或组，通常对应 nobody/nogroup，但不同发行版实现可能不同，
因此不应依赖这一映射关系。另外，为了运行测试，会临时创建普通用户并在测试结束后删除
(lfs chroot) I have no name!:/# 
echo "zhangsan:x:101:101::/home/zhangsan:/bin/bash" >> /etc/passwd
echo "zhangsan:x:101:" >> /etc/group
install -o zhangsan -d /home/zhangsan


要移除"I have no name!" 提示，请启动一个新的 shell。由于 /etc/passwd 和 /etc/group 文件已经创建，所以此时用户名和组名解析现在可以正常工作了：
(lfs chroot) I have no name!:/# exec /usr/bin/bash --login
(lfs chroot) root:/# 

登录程序、agetty 程序和 init 程序（以及其他程序）使用多个日志文件来记录诸如系统登录用户及其登录时间等信息。但是，如果日志文件不存在，这些程序将不会写入这些文件。请初始化日志文件并赋予它们适当的权限：
(lfs chroot) root:/# 
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp
释义：
/var/log/wtmp 文件记录所有登录和注销操作
/var/log/lastlog 文件记录每个用户上次登录的时间
/var/log/faillog 文件记录登录失败的尝试
/var/log/btmp 文件记录错误的登录尝试





# Gettext-0.24安装 (https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter07/gettext.html)
Gettext 软件包包含用于国际化和本地化的实用程序。这些实用程序允许使用 NLS（本地语言支持）编译程序，从而使程序能够以用户的母语输出消息
在chroot环境里，你就是最高权限，所有的命令直接输入即可
依然在chroot里的 /sources 目录下（对应宿主机的 /mnt/lfs/sources）进行解压和编译
(lfs chroot) root:/# cd /sources/
(lfs chroot) root:/sources# tar xvf gettext-0.24.tar.xz 
(lfs chroot) root:/sources# cd gettext-0.24   
(lfs chroot) root:/sources/gettext-0.24# ./configure --disable-shared
释义：
--disable-shared         目前我们不需要安装任何共享的 Gettext 库，因此无需构建它们

(lfs chroot) root:/sources/gettext-0.24# make -j$(nproc)

安装msgfmt、 msgmerge和xgettext程序：
(lfs chroot) root:/sources/gettext-0.24# cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext}  /usr/bin
(lfs chroot) root:/sources/gettext-0.24# cd ..
(lfs chroot) root:/sources# rm -rf gettext-0.24


# bison-3.8.2
(lfs chroot) root:/sources# tar xvf bison-3.8.2.tar.xz
(lfs chroot) root:/sources# cd bison-3.8.2 
(lfs chroot) root:/sources/bison-3.8.2# ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2 && make -j$(nproc) && make install
(lfs chroot) root:/sources/bison-3.8.2# cd ..
(lfs chroot) root:/sources# rm -rf bison-3.8.2


# perl-5.40.1
(lfs chroot) root:/sources# tar xvf perl-5.40.1.tar.xz
(lfs chroot) root:/sources# cd perl-5.40.1
(lfs chroot) root:/sources/perl-5.40.1# sh Configure -des \
-D prefix=/usr                               \
-D vendorprefix=/usr                         \
-D useshrplib                                \
-D privlib=/usr/lib/perl5/5.40/core_perl     \
-D archlib=/usr/lib/perl5/5.40/core_perl     \
-D sitelib=/usr/lib/perl5/5.40/site_perl     \
-D sitearch=/usr/lib/perl5/5.40/site_perl    \
-D vendorlib=/usr/lib/perl5/5.40/vendor_perl \
-D vendorarch=/usr/lib/perl5/5.40/vendor_perl

(lfs chroot) root:/sources/perl-5.40.1# make -j$(nproc) && make install
(lfs chroot) root:/sources/perl-5.40.1# cd ..
(lfs chroot) root:/sources# rm -rf perl-5.40.1


# Python-3.13.2
(lfs chroot) root:/sources# tar -xvf Python-3.13.2.tar.xz
(lfs chroot) root:/sources# cd Python-3.13.2
(lfs chroot) root:/sources/Python-3.13.2# ./configure --prefix=/usr --enable-shared --without-ensurepip && make -j$(nproc) && make install
(lfs chroot) root:/sources/Python-3.13.2# cd ..
(lfs chroot) root:/sources# rm -rf Python-3.13.2


# texinfo-7.2
(lfs chroot) root:/sources# tar xvf texinfo-7.2.tar.xz
(lfs chroot) root:/sources# cd texinfo-7.2
(lfs chroot) root:/sources/texinfo-7.2# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/texinfo-7.2# cd ..
(lfs chroot) root:/sources# rm -rf texinfo-7.2


# Util-linux-2.40.4
(lfs chroot) root:/sources# tar -xvf util-linux-2.40.4.tar.xz
(lfs chroot) root:/sources# cd util-linux-2.40.4
(lfs chroot) root:/sources/util-linux-2.40.4# mkdir -pv /var/lib/hwclock
(lfs chroot) root:/sources/util-linux-2.40.4# ./configure --libdir=/usr/lib \
--runstatedir=/run --disable-chfn-chsh --disable-login --disable-nologin     \
--disable-su --disable-setpriv --disable-runuser --disable-pylibmount  \
--disable-static --disable-liblastlog2 --without-python \
ADJTIME_PATH=/var/lib/hwclock/adjtime \
--docdir=/usr/share/doc/util-linux-2.40.4

(lfs chroot) root:/sources/util-linux-2.40.4# make -j$(nproc) && make install
(lfs chroot) root:/sources/util-linux-2.40.4# cd ..
(lfs chroot) root:/sources# rm -rf util-linux-2.40.4



# 清理和保存临时系统
删除当前已安装的文档文件，以防止它们最终出现在最终系统中
(lfs chroot) root:/sources# rm -rf /usr/share/{info,man,doc}/*

其次，在现代 Linux 系统中，libtool 的 .la 文件仅对 libltdl 有用。libltdl 不会加载 LFS 中的任何库，而且已知某些 .la 文件会导致 BLFS 包加载失败。请立即删除这些文件：
(lfs chroot) root:/sources# find /usr/{lib,libexec} -name \*.la -delete

当前系统大小约为3GB，但/tools目录已不再需要
(lfs chroot) root:/sources# rm -rf /tools



# 备份
至此，必要的程序和库已创建完毕，您当前的 LFS 系统状态良好。现在可以备份系统以备后用
如果在后续章节中出现严重故障，通常情况下，删除所有内容并（更加谨慎地）重新开始是最佳恢复方法
遗憾的是，所有临时文件也将被删除。为了避免浪费时间重复已成功完成的操作，创建当前 LFS 系统的备份可能非常有用
以下步骤需要在 chroot 环境之外执行。这意味着您必须先退出 chroot 环境才能继续。这样做的目的是为了访问 chroot 环境之外的文件系统位置，以便存储/读取备份归档文件，该文件不应位于 chroot 环境的 $LFS层级结构内
如果您已决定进行备份，请退出chroot环境：
(lfs chroot) root:/sources# exit

备份之前，请先卸载虚拟文件系统：
使用“懒卸载” (Lazy Unmount)
这是最简单有效的方法。-l 参数会立即将文件系统从目录树中摘除，等所有进程不再使用该目录时再彻底释放。
root@ub24-1:~# umount -l $LFS/dev

检查并杀死残留进程（如果懒卸载不起作用）
root@ub24-1:~# fuser -m $LFS/dev               # 查看哪些进程占用了该目录
/mnt/lfs/dev:         3538c

直接杀死它们
root@ub24-1:~# fuser -kvm $LFS/dev
                     USER        PID ACCESS COMMAND
/mnt/lfs/dev:        root     kernel mount /mnt/lfs
                     rambo      3538 ..c.. bash

root@ub24-1:~# 
umount $LFS/dev/pts && umount $LFS/dev/shm
umount $LFS/run && umount $LFS/proc
umount $LFS/sys && umount $LFS/dev



root@ub24-1:~# mount | grep "$LFS"
/dev/sdb1 on /mnt/lfs type ext4 (rw,relatime)

root@ub24-1:~# cat /proc/mounts | grep "$LFS"
/dev/sdb1 /mnt/lfs ext4 rw,relatime 0 0
注意：
/dev/sdb1 on /mnt/lfs是唯一一个挂载点是你的LFS物理分区，这是必须保留的，因为现在正站在这个分区里操作，如果把它也卸载了，你就看不见里面的文件，也就没法打包备份了


# 验证卸载
root@ub24-1:~# for dir in dev/pts dev proc sys run; do
    mountpoint -q $LFS/$dir && echo "$LFS/$dir 仍处于挂载状态！"
done
注意：返回为空则虚拟文件系统已卸载干净

最后的确认：/dev目录
在执行tar之前，最后用肉眼看一眼：
root@ub24-1:~# ls -l $LFS/dev
total 4
drwxr-xr-x 2 root root 4096 Apr 20 08:07 pts

注意：
如果是空的，或者只有极少数几个静态文件（如 console 或 null）：正确
如果是密密麻麻的设备（如 sda, tty, input 等）：那说明刚才没卸载掉（但根据你上面的 mountpoint 检查，这不可能发生）


在宿主机（rambo或root）环境下切换到/mnt/lfs目录下进行打包
root@ub24-1:~# cd $LFS

# 使用多线程压缩（-T0 代表使用所有可用的 CPU 核心）
root@ub24-1:/mnt/lfs# tar -cvpf ../lfs-temp-tools-12.3.tar.xz --exclude='./sources' --use-compress-program="xz -T0" .
释义：
-c: 创建
-p: 保留所有权限（极其重要，否则恢复后系统会瘫痪）
-f: 指定文件名
-T0：使用所有可用的CPU核心
--exclude：排除掉某个目录
.: 代表当前目录


# 查看备份完成的包
root@ub24-1:/mnt/lfs# ls -alh ../lfs-temp-tools-12.3.tar.xz 
-rw-r--r-- 1 root root 471M Apr 20 18:57 ../lfs-temp-tools-12.3.tar.xz




# 恢复（因为备份的时候就是在$LFS中进行的，所以恢复时也要在该目录中执行）
如果操作失误需要重新开始，可用此备份来恢复系统，从而节省恢复时间。由于源代码位于$LFS目录下，因此也包含在备份存档中，无需再次下载。确认$LFS设置正确后，可用以下命令来恢复备份：
root@ub24-1:~# export LFS=/mnt/lfs
root@ub24-1:~# mkdir -pv $LFS
root@ub24-1:~# mount /dev/sdb1 $LFS
root@ub24-1:~# cd $LFS
root@ub24-1:/mnt/lfs# rm -rf ./*
root@ub24-1:/mnt/lfs# tar -xJvpf ../lfs-temp-tools-12.3-systemd.tar.xz



```








# 构建LFS系统
<font color=red>**绝对不能在宿主机的rambo或宿主机的root用户下执行**</font>
<font color=red>**由于之前退出了chroot所以需要重新登录**</font>
```shell
在宿主机挂载内核虚拟文件系统（如果已经挂载请跳过）：
# 确保以宿主机root身份执行
root@ub24-1:/mnt/lfs# 
mount -v --bind /dev $LFS/dev
mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run


进入chroot
root@ub24-1:/mnt/lfs# chroot "$LFS" /usr/bin/env -i \
HOME=/root                  \
TERM="$TERM"                \
PS1='(lfs chroot) \u:\w\$ ' \
PATH=/usr/bin:/usr/sbin     \
MAKEFLAGS="-j$(nproc)"      \
/bin/bash --login


(lfs chroot) root:/# cd sources/
(lfs chroot) root:/sources# 



```





## 安装基本系统软件
```shell
(lfs chroot) root:/# cd sources/

# Man-pages-6.12
(lfs chroot) root:/sources# tar xvf man-pages-6.12.tar.xz
(lfs chroot) root:/sources# cd man-pages-6.12
(lfs chroot) root:/sources/man-pages-6.12# rm -v man3/crypt*
(lfs chroot) root:/sources/man-pages-6.12# make -R GIT=false prefix=/usr install
(lfs chroot) root:/sources/man-pages-6.12# cd ..
(lfs chroot) root:/sources# rm -rf man-pages-6.12


# Iana-Etc-20250123
(lfs chroot) root:/sources# tar -zxvf iana-etc-20250123.tar.gz
(lfs chroot) root:/sources# cp iana-etc-20250123/{services,protocols}  /etc/
释义：
etc/protocols：描述了 TCP/IP 子系统提供的各种DARPA互联网协议
/etc/services：提供互联网服务的友好文本名称与其底层分配的端口号和协议类型之间的映射关系

```

## Glibc-2.41
```shell
(lfs chroot) root:/sources# tar xvf glibc-2.41.tar.xz
(lfs chroot) root:/sources# cd glibc-2.41
(lfs chroot) root:/sources/glibc-2.41# patch -Np1 -i ../glibc-2.41-fhs-1.patch
(lfs chroot) root:/sources/glibc-2.41# mkdir build && cd build
(lfs chroot) root:/sources/glibc-2.41/build# echo "rootsbindir=/usr/sbin" > configparms
(lfs chroot) root:/sources/glibc-2.41/build# ../configure --prefix=/usr \
--disable-werror --enable-kernel=5.4 --enable-stack-protector=strong  \
--disable-nscd libc_cv_slibdir=/usr/lib

(lfs chroot) root:/sources/glibc-2.41/build# make -j$(nproc) && touch /etc/ld.so.conf
(lfs chroot) root:/sources/glibc-2.41/build# sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
(lfs chroot) root:/sources/glibc-2.41/build# make install
(lfs chroot) root:/sources/glibc-2.41/build# sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

可以使用 localedef 程序安装单个语言环境。
例如下面的第二个 localedef 命令将/usr/share/i18n/locales/cs_CZ字符集无关语言环境定义与/usr/share/i18n/charmaps/UTF-8.gz字符映射定义合并，并将结果追加到 /usr/lib/locale/locale-archive文件中
以下说明将安装测试覆盖率达到最佳所需的最小语言环境集：
(lfs chroot) root:/sources/glibc-2.41/build# 
localedef -i C -f UTF-8 C.UTF-8
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i el_GR -f ISO-8859-7 el_GR
localedef -i en_GB -f ISO-8859-1 en_GB
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_ES -f ISO-8859-15 es_ES@euro
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i is_IS -f ISO-8859-1 is_IS
localedef -i is_IS -f UTF-8 is_IS.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f ISO-8859-15 it_IT@euro
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i se_NO -f UTF-8 se_NO.UTF-8
localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
localedef -i zh_TW -f UTF-8 zh_TW.UTF-8

此外，请安装您所在国家/地区、语言和字符集的区域设置。
或者可用以下耗时的命令一次性安装 glibc-2.41/localedata/SUPPORTED 文件中列出的所有区域设置（其中包含上述所有区域设置以及更多其他区域设置）：
(lfs chroot) root:/sources/glibc-2.41/build# make localedata/install-locales

然后当需要时可用 localedef 命令创建并安装 glibc-2.41/localedata/SUPPORTED 文件中未列出的语言环境。例如，本章后面的一些测试需要以下两个语言环境：
(lfs chroot) root:/sources/glibc-2.41/build# localedef -i C -f UTF-8 C.UTF-8 && localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true

# 配置Glibc
需要先创建/etc/nsswitch.conf，因为Glibc的默认设置无法在网络环境下正常工作
(lfs chroot) root:/sources/glibc-2.41/build# cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

# 添加时区数据
(lfs chroot) root:/sources/glibc-2.41/build# tar -xf ../../tzdata2025a.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p Asia/Shanghai
unset ZONEINFO tz

确定本地时区的一种方法是运行以下脚本：tzselect
然后创建文件：ln -sfv /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime


# 配置动态加载器
创建/etc/ld.so.conf新文件：
(lfs chroot) root:/sources/glibc-2.41/build# cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF

(lfs chroot) root:/sources/glibc-2.41/build# cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF

(lfs chroot) root:/sources/glibc-2.41/build# mkdir -p /etc/ld.so.conf.d

(lfs chroot) root:/sources/glibc-2.41/build# cd ../../




# Zlib-1.3.1
(lfs chroot) root:/sources# tar -zxvf zlib-1.3.1.tar.gz
(lfs chroot) root:/sources# cd zlib-1.3.1
(lfs chroot) root:/sources/zlib-1.3.1# ./configure --prefix=/usr && make -j$(nporc) && make check && make install
删除无用的静态库：
(lfs chroot) root:/sources/zlib-1.3.1# rm -fv /usr/lib/libz.a
(lfs chroot) root:/sources/zlib-1.3.1# cd ..


# Bzip2-1.0.8
(lfs chroot) root:/sources# tar zxvf bzip2-1.0.8.tar.gz
(lfs chroot) root:/sources# cd bzip2-1.0.8
(lfs chroot) root:/sources/bzip2-1.0.8# patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
(lfs chroot) root:/sources/bzip2-1.0.8# sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
(lfs chroot) root:/sources/bzip2-1.0.8# sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
准备 Bzip2 进行编译
(lfs chroot) root:/sources/bzip2-1.0.8# make -f Makefile-libbz2_so
(lfs chroot) root:/sources/bzip2-1.0.8# make clean
(lfs chroot) root:/sources/bzip2-1.0.8# make -j$(nporc) && make PREFIX=/usr install

安装共享库：
(lfs chroot) root:/sources/bzip2-1.0.8# 
cp -av libbz2.so.* /usr/lib
ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so

将共享的bzip2二进制文件 安装到 目录中，并将两个bzip2/usr/bin副本替换为符号链接：
(lfs chroot) root:/sources/bzip2-1.0.8# 
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done

删除无用的静态库：
(lfs chroot) root:/sources/bzip2-1.0.8# rm -fv /usr/lib/libbz2.a
(lfs chroot) root:/sources/bzip2-1.0.8# cd ..
(lfs chroot) root:/sources# rm -rf bzip2-1.0.8


# xz-5.6.4
(lfs chroot) root:/sources# tar xvf xz-5.6.4.tar.xz
(lfs chroot) root:/sources# cd xz-5.6.4
(lfs chroot) root:/sources/xz-5.6.4# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/xz-5.6.4
(lfs chroot) root:/sources/xz-5.6.4# make -j$(nporc) && make check && make install
(lfs chroot) root:/sources/xz-5.6.4# cd ..
(lfs chroot) root:/sources# rm -rf xz-5.6.4


#lz4-1.10.0
(lfs chroot) root:/sources# tar zxvf lz4-1.10.0.tar.gz
(lfs chroot) root:/sources# cd lz4-1.10.0
(lfs chroot) root:/sources/lz4-1.10.0# make BUILD_STATIC=no PREFIX=/usr && make -j$(nproc) && make BUILD_STATIC=no PREFIX=/usr install
(lfs chroot) root:/sources/lz4-1.10.0# cd ..
(lfs chroot) root:/sources# rm -rf lz4-1.10.0


# zstd-1.5.7
(lfs chroot) root:/sources# tar zxvf zstd-1.5.7.tar.gz 
(lfs chroot) root:/sources# cd zstd-1.5.7
(lfs chroot) root:/sources/zstd-1.5.7# make prefix=/usr && make prefix=/usr  install
移除静态库：
(lfs chroot) root:/sources/zstd-1.5.7# rm -v /usr/lib/libzstd.a
(lfs chroot) root:/sources/zstd-1.5.7# cd ..
(lfs chroot) root:/sources# rm -rf zstd-1.5.7



# file-5.46
(lfs chroot) root:/sources# tar zxvf file-5.46.tar.gz
(lfs chroot) root:/sources# cd file-5.46
(lfs chroot) root:/sources/file-5.46# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/file-5.46# cd ..
(lfs chroot) root:/sources# rm -rf file-5.46


# Readline-8.2.13
(lfs chroot) root:/sources# tar -zxvf readline-8.2.13.tar.gz
(lfs chroot) root:/sources# cd readline-8.2.13
(lfs chroot) root:/sources/readline-8.2.13# 
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf

(lfs chroot) root:/sources/readline-8.2.13# ./configure --prefix=/usr --disable-static --with-curses --docdir=/usr/share/doc/readline-8.2.13
(lfs chroot) root:/sources/readline-8.2.13# make SHLIB_LIBS="-lncursesw" && make install && install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.2.13
(lfs chroot) root:/sources/readline-8.2.13# cd ..
(lfs chroot) root:/sources# rm -rf readline-8.2.13


# M4-1.4.19
(lfs chroot) root:/sources# tar xvf m4-1.4.19.tar.xz
(lfs chroot) root:/sources# cd m4-1.4.19
(lfs chroot) root:/sources/m4-1.4.19# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/m4-1.4.19# cd ..
(lfs chroot) root:/sources# rm -rf m4-1.4.19


# bc-7.0.3
(lfs chroot) root:/sources# tar -xvf bc-7.0.3.tar.xz
(lfs chroot) root:/sources# cd bc-7.0.3
(lfs chroot) root:/sources/bc-7.0.3# CC=gcc ./configure --prefix=/usr -G -O3 -r && make -j$(nproc) && make install 
(lfs chroot) root:/sources/bc-7.0.3# cd ..
(lfs chroot) root:/sources# rm -rf bc-7.0.3


# flex-2.6.4
(lfs chroot) root:/sources# tar zxvf flex-2.6.4.tar.gz
(lfs chroot) root:/sources# cd flex-2.6.4
(lfs chroot) root:/sources/flex-2.6.4# ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4 --disable-static && make -j$(nproc) && make install 
(lfs chroot) root:/sources/flex-2.6.4# ln -sv flex  /usr/bin/lex && ln -sv flex.1 /usr/share/man/man1/lex.1
(lfs chroot) root:/sources/flex-2.6.4# cd ..
(lfs chroot) root:/sources# rm -rf flex-2.6.4


# tcl-8.6.16
(lfs chroot) root:/sources# tar zxvf tcl8.6.16-src.tar.gz 
(lfs chroot) root:/sources# cd tcl8.6.16
(lfs chroot) root:/sources/tcl8.6.16# SRCDIR=$(pwd)
(lfs chroot) root:/sources/tcl8.6.16# cd unix && ./configure --prefix=/usr --mandir=/usr/share/man --disable-rpath
(lfs chroot) root:/sources/tcl8.6.16/unix# make -j$(nproc)
(lfs chroot) root:/sources/tcl8.6.16/unix# sed -e "s|$SRCDIR/unix|/usr/lib|" -e "s|$SRCDIR|/usr/include|" -i tclConfig.sh

(lfs chroot) root:/sources/tcl8.6.16/unix# 
sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.10|/usr/lib/tdbc1.1.10|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10/library|/usr/lib/tcl8.6|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10|/usr/include|"            \
    -i pkgs/tdbc1.1.10/tdbcConfig.sh

(lfs chroot) root:/sources/tcl8.6.16/unix# sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.2|/usr/lib/itcl4.3.2|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.2/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.3.2|/usr/include|"            \
    -i pkgs/itcl4.3.2/itclConfig.sh

(lfs chroot) root:/sources/tcl8.6.16/unix# unset SRCDIR

(lfs chroot) root:/sources/tcl8.6.16/unix# make install

(lfs chroot) root:/sources/tcl8.6.16/unix# chmod -v u+w /usr/lib/libtcl8.6.so && make install-private-headers
(lfs chroot) root:/sources/tcl8.6.16/unix# ln -sfv tclsh8.6 /usr/bin/tclsh
(lfs chroot) root:/sources/tcl8.6.16/unix# mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
(lfs chroot) root:/sources/tcl8.6.16/unix# cd ..
(lfs chroot) root:/sources/tcl8.6.16# tar -xf ../tcl8.6.16-html.tar.gz --strip-components=1
(lfs chroot) root:/sources/tcl8.6.16# mkdir -v -p /usr/share/doc/tcl-8.6.16
(lfs chroot) root:/sources/tcl8.6.16# cp -v -r  ./html/* /usr/share/doc/tcl-8.6.16
(lfs chroot) root:/sources/tcl8.6.16# cd ..
(lfs chroot) root:/sources# rm -rf tcl8.6.16


# expect-5.45.4
(lfs chroot) root:/sources# tar zxvf expect5.45.4.tar.gz
(lfs chroot) root:/sources# cd expect5.45.4
(lfs chroot) root:/sources/expect5.45.4# python3 -c 'from pty import spawn; spawn(["echo", "ok"])'
(lfs chroot) root:/sources/expect5.45.4# patch -Np1 -i ../expect-5.45.4-gcc14-1.patch
(lfs chroot) root:/sources/expect5.45.4# ./configure --prefix=/usr \
--with-tcl=/usr/lib     \
--enable-shared         \
--disable-rpath         \
--mandir=/usr/share/man \
--with-tclinclude=/usr/include

(lfs chroot) root:/sources/expect5.45.4# make -j$(nproc) && make install
(lfs chroot) root:/sources/expect5.45.4# ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
(lfs chroot) root:/sources/expect5.45.4# cd ..
(lfs chroot) root:/sources# rm -rf expect5.45.4



# dejaGNU-1.6.3
(lfs chroot) root:/sources# tar zxvf dejagnu-1.6.3.tar.gz
(lfs chroot) root:/sources# cd dejagnu-1.6.3
(lfs chroot) root:/sources/dejagnu-1.6.3# mkdir build && cd build
(lfs chroot) root:/sources/dejagnu-1.6.3/build# ../configure --prefix=/usr
(lfs chroot) root:/sources/dejagnu-1.6.3/build# 
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi

(lfs chroot) root:/sources/dejagnu-1.6.3/build# make install
(lfs chroot) root:/sources/dejagnu-1.6.3/build#
install -v -dm755  /usr/share/doc/dejagnu-1.6.3
install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3

(lfs chroot) root:/sources/dejagnu-1.6.3/build# cd ../..
(lfs chroot) root:/sources# rm -rf dejagnu-1.6.3


# pkgconf-2.3.0
(lfs chroot) root:/sources# tar xvf pkgconf-2.3.0.tar.xz
(lfs chroot) root:/sources# cd pkgconf-2.3.0
(lfs chroot) root:/sources/pkgconf-2.3.0# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/pkgconf-2.3.0 && make -j$(nproc) && make install
(lfs chroot) root:/sources/pkgconf-2.3.0# 
ln -sv pkgconf   /usr/bin/pkg-config
ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1

(lfs chroot) root:/sources/pkgconf-2.3.0# cd ..
(lfs chroot) root:/sources# rm -rf pkgconf-2.3.0


# Binutils-2.44
(lfs chroot) root:/sources# tar xvf binutils-2.44.tar.xz
(lfs chroot) root:/sources# cd binutils-2.44
(lfs chroot) root:/sources/binutils-2.44# mkdir build && cd build
(lfs chroot) root:/sources/binutils-2.44/build# ../configure --prefix=/usr \
--sysconfdir=/etc --enable-ld=default --enable-plugins    \
--enable-shared --disable-werror --enable-64-bit-bfd \
--enable-new-dtags  --with-system-zlib --enable-default-hash-style=gnu

(lfs chroot) root:/sources/binutils-2.44/build# make tooldir=/usr
检验结果：
(lfs chroot) root:/sources/binutils-2.44/build# make -k check

要查看失败的测试列表，请运行：
(lfs chroot) root:/sources/binutils-2.44/build# grep '^FAIL:' $(find -name '*.log')
注意：正确的回显应为空

安装软件包：
(lfs chroot) root:/sources/binutils-2.44/build# make tooldir=/usr install

删除无用的静态库和其他文件：
(lfs chroot) root:/sources/binutils-2.44/build# rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a   /usr/share/doc/gprofng/
(lfs chroot) root:/sources/binutils-2.44/build# cd ../..
(lfs chroot) root:/sources# rm -rf binutils-2.44


# GMP-6.3.0
(lfs chroot) root:/sources# tar xvf gmp-6.3.0.tar.xz
(lfs chroot) root:/sources# cd gmp-6.3.0
(lfs chroot) root:/sources/gmp-6.3.0# ./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.3.0 && make -j$(nporc) && make html

(lfs chroot) root:/sources/gmp-6.3.0# make check 2>&1 | tee gmp-check-log
(lfs chroot) root:/sources/gmp-6.3.0# awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log         # 回显为199
(lfs chroot) root:/sources/gmp-6.3.0# make install && make install-html
(lfs chroot) root:/sources/gmp-6.3.0# cd ../
(lfs chroot) root:/sources# rm -rf gmp-6.3.0


# mpfr-4.2.1
(lfs chroot) root:/sources# tar xvf mpfr-4.2.1.tar.xz
(lfs chroot) root:/sources# cd mpfr-4.2.1
(lfs chroot) root:/sources/mpfr-4.2.1# ./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.1 && make -j$(nporc) && make html

(lfs chroot) root:/sources/mpfr-4.2.1# make check && make install && make install-html
(lfs chroot) root:/sources/mpfr-4.2.1# cd ..
(lfs chroot) root:/sources# rm -rf mpfr-4.2.1


# mpc-1.3.1
(lfs chroot) root:/sources# tar zxvf mpc-1.3.1.tar.gz
(lfs chroot) root:/sources# cd mpc-1.3.1
(lfs chroot) root:/sources/mpc-1.3.1# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpc-1.3.1 && make -j$(nproc) && make html && make check
安装软件包及其文档：
(lfs chroot) root:/sources/mpc-1.3.1# make install && make install-html
(lfs chroot) root:/sources/mpc-1.3.1# cd ..
(lfs chroot) root:/sources# rm -rf mpc-1.3.1


# attr-2.5.2
(lfs chroot) root:/sources# tar zxvf attr-2.5.2.tar.gz
(lfs chroot) root:/sources# cd attr-2.5.2
(lfs chroot) root:/sources/attr-2.5.2# ./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/attr-2.5.2
(lfs chroot) root:/sources/attr-2.5.2# make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/attr-2.5.2# cd ..
(lfs chroot) root:/sources# rm -rf attr-2.5.2


# Acl-2.3.2
(lfs chroot) root:/sources# tar xvf acl-2.3.2.tar.xz
(lfs chroot) root:/sources# cd acl-2.3.2
(lfs chroot) root:/sources/acl-2.3.2# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/acl-2.3.2
(lfs chroot) root:/sources/acl-2.3.2# make -j$(nproc) && make check 
(lfs chroot) root:/sources/acl-2.3.2# make install                  注意：这一步会有一个FAIL，不影响
(lfs chroot) root:/sources/acl-2.3.2# cd ..
(lfs chroot) root:/sources# rm -rf acl-2.3.2


# libcap-2.73
(lfs chroot) root:/sources# tar -xvf libcap-2.73.tar.xz
(lfs chroot) root:/sources# cd libcap-2.73
(lfs chroot) root:/sources/libcap-2.73# sed -i '/install -m.*STA/d' libcap/Makefile
(lfs chroot) root:/sources/libcap-2.73# make prefix=/usr lib=lib && make test && make prefix=/usr lib=lib install
(lfs chroot) root:/sources/libcap-2.73# cd ..
(lfs chroot) root:/sources# rm -rf libcap-2.73


# Libxcrypt-4.4.38
(lfs chroot) root:/sources# tar xvf libxcrypt-4.4.38.tar.xz 
(lfs chroot) root:/sources# cd libxcrypt-4.4.38
(lfs chroot) root:/sources/libxcrypt-4.4.38# ./configure --prefix=/usr \
--enable-hashes=strong,glibc --enable-obsolete-api=no \
--disable-static --disable-failure-tokens

(lfs chroot) root:/sources/libxcrypt-4.4.38# make -j$(nproc) && make check 
(lfs chroot) root:/sources/libxcrypt-4.4.38# make install
(lfs chroot) root:/sources/libxcrypt-4.4.38# cd ..
(lfs chroot) root:/sources# rm -rf libxcrypt-4.4.38


# Shadow-4.17.3
(lfs chroot) root:/sources# tar xvf shadow-4.17.3.tar.xz
(lfs chroot) root:/sources# cd shadow-4.17.3
(lfs chroot) root:/sources/shadow-4.17.3# 
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;


(lfs chroot) root:/sources/shadow-4.17.3# sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
-e 's:/var/spool/mail:/var/mail:'   \
-e '/PATH=/{s@/sbin:@@;s@/bin:@@}'  \
-i etc/login.defs

(lfs chroot) root:/sources/shadow-4.17.3# touch /usr/bin/passwd
(lfs chroot) root:/sources/shadow-4.17.3# ./configure --sysconfdir=/etc --disable-static --with-{b,yes}crypt --without-libbsd --with-group-name-max-length=32
(lfs chroot) root:/sources/shadow-4.17.3# make -j$(nproc) && make exec_prefix=/usr install && make -C man install-man

配置shadows
启用隐藏密码
(lfs chroot) root:/sources/shadow-4.17.3# pwconv
启用隐藏组密码
(lfs chroot) root:/sources/shadow-4.17.3# grpconv

释义：
在没有shadow口令的远古时代，所有的用户信息（包括加密后的密码）都存在 /etc/passwd 里
问题： /etc/passwd 必须对所有用户可读（不然你运行 ls -l 时系统没法把 UID 转换成用户名）。这意味着任何普通用户都能拿到所有人的加密密码，然后带回家进行暴力破解

pwconv命令的作用：
它会把加密后的密码从 /etc/passwd 中抽离出来
把它转移到 /etc/shadow 文件中
结果： /etc/passwd 里的密码位变成了 x。而 /etc/shadow 权限被设为仅 root 可读

grpconv命令的作用：
同理，它把 /etc/group 里的组密码转移到 /etc/gshadow 中


要更改默认参数，/etc/default/useradd必须创建并根据您的特定需求定制该文件。创建方法如下：
(lfs chroot) root:/sources/shadow-4.17.3# mkdir -p /etc/default
(lfs chroot) root:/sources/shadow-4.17.3# useradd -D --gid 999
释义：
此参数设置 /etc/group 文件中使用的组编号的起始值。此处的值 999 来自上面的 --gid 参数。您可以将其设置为任何所需的值
请注意，useradd 命令永远不会重复使用 UID 或 GID。如果此参数中指定的编号已被使用，它将使用下一个可用的编号
另请注意，如果您的系统中没有 ID 等于此编号的组，则首次在不使用 -g 参数的情况下使用 useradd 命令时，即使帐户已正确创建，也会生成错误消息“useradd: unknown GID 999”
这就是为什么我们在 7.6 节“创建必要文件和符号链接”中创建了具有此组 ID 的 users 组的原因

CREATE_MAIL_SPOOL=yes
此参数使 useradd 为每个新用户创建一个邮箱文件。useradd会将此文件的组所有权分配给具有 0660 权限的邮件组。如不想创建这些文件：
(lfs chroot) root:/sources/shadow-4.17.3# sed -i '/MAIL/s/yes/no/' /etc/default/useradd


设置root密码
(lfs chroot) root:/sources/shadow-4.17.3# passwd root
Changing password for root
Enter the new password (minimum of 5 characters)                            # 输入新密码(最小5个字符)
Please use a combination of upper and lower case letters and numbers.       # 请使用大小写字母和数字的组合
New password:                    # A星
Re-enter new password: 
passwd: password changed.


(lfs chroot) root:/sources/shadow-4.17.3# cd ..
(lfs chroot) root:/sources# rm -rf shadow-4.17.3



# GCC-14.2.0
(lfs chroot) root:/sources# tar xvf gcc-14.2.0.tar.xz
(lfs chroot) root:/sources# cd gcc-14.2.0
(lfs chroot) root:/sources/gcc-14.2.0# case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

(lfs chroot) root:/sources/gcc-14.2.0# rm -rf build/                     # 这个目录要删除掉重新创建
(lfs chroot) root:/sources/gcc-14.2.0# mkdir build && cd build
(lfs chroot) root:/sources/gcc-14.2.0/build# ../configure --prefix=/usr  \
LD=ld                    \
--enable-languages=c,c++ \
--enable-default-pie     \
--enable-default-ssp     \
--enable-host-pie        \
--disable-multilib       \
--disable-bootstrap      \
--disable-fixincludes    \
--with-system-zlib

(lfs chroot) root:/sources/gcc-14.2.0/build# make -j$(nproc)

将栈大小硬限制设置为无限
(lfs chroot) root:/sources/gcc-14.2.0/build# ulimit -s -H unlimited

现在移除/修复几个已知的测试失败案例
(lfs chroot) root:/sources/gcc-14.2.0/build# 
sed -e '/cpython/d'               -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp
sed -e 's/no-pic /&-no-pie /'     -i ../gcc/testsuite/gcc.target/i386/pr113689-1.c
sed -e 's/300000/(1|300000)/'     -i ../libgomp/testsuite/libgomp.c-c++-common/pr109062.c
sed -e 's/{ target nonpic } //' -e '/GOTPCREL/d'  -i ../gcc/testsuite/gcc.target/i386/fentryname3.c

# =========================================================================
以非特权用户身份测试结果，但不要止步于错误：
(lfs chroot) root:/sources/gcc-14.2.0/build# chown -R zhangsan .
(lfs chroot) root:/sources/gcc-14.2.0/build# su zhangsan -c "PATH=$PATH make -k check"
要提取测试套件结果摘要
(lfs chroot) root:/sources/gcc-14.2.0/build# ../contrib/test_summary
# =========================================================================

(lfs chroot) root:/sources/gcc-14.2.0/build# make install

GCC 构建目录的所有者目前是 zhangsan，已安装的头文件目录（及其内容）的所有权不正确。请将所有权更改为root用户和组：
(lfs chroot) root:/sources/gcc-14.2.0/build# ls -al /usr/lib/gcc/
total 24
drwxr-xr-x  4 root root  4096 Apr 20 15:34 .
drwxr-xr-x 26 root root 12288 Apr 20 15:34 ..
drwxr-xr-x  3 root root  4096 Apr 20 03:00 x86_64-lfs-linux-gnu
drwxr-xr-x  3 root root  4096 Apr 20 15:34 x86_64-pc-linux-gnu

(lfs chroot) root:/sources/gcc-14.2.0/build# chown -v -R root:root /usr/lib/gcc/$(gcc -dumpmachine)/14.2.0/include{,-fixed}

出于"历史"原因，FHS需要创建一个符号链接
(lfs chroot) root:/sources/gcc-14.2.0/build# ln -svr /usr/bin/cpp /usr/lib

许多软件包使用 cc 来调用 C 编译器。我们已经在 gcc-pass2 中创建了 cc 的符号链接，请同时创建其 man 手册页的符号链接：
(lfs chroot) root:/sources/gcc-14.2.0/build# ln -sv gcc.1 /usr/share/man/man1/cc.1

添加兼容性符号链接，以启用使用链接时优化 (LTO) 构建程序：
(lfs chroot) root:/sources/gcc-14.2.0/build# ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/14.2.0/liblto_plugin.so /usr/lib/bfd-plugins/

现在我们的最终工具链已经就绪，接下来需要再次确保编译和链接能够按预期工作。为此，我们执行一些健全性检查：
(lfs chroot) root:/sources/gcc-14.2.0/build# echo 'int main(){}' > dummy.c
(lfs chroot) root:/sources/gcc-14.2.0/build# cc dummy.c -v -Wl,--verbose &> dummy.log
(lfs chroot) root:/sources/gcc-14.2.0/build# readelf -l a.out | grep ': /lib'             # 下一行是回显
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]

现在请确保我们已设置好要使用正确的启动文件：
(lfs chroot) root:/sources/gcc-14.2.0/build# grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log         # 下面几行是回显
/usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/../../../../lib/Scrt1.o succeeded
/usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/../../../../lib/crti.o succeeded
/usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/../../../../lib/crtn.o succeeded

根据您的机器架构，上述步骤可能略有不同。区别在于 /usr/lib/gcc 之后的目录名称。这里需要重点检查的是 gcc 是否已在 /usr/lib 目录下找到所有三个 crt*.o 文件

验证编译器是否正在查找正确的头文件：
(lfs chroot) root:/sources/gcc-14.2.0/build# grep -B4 '^ /usr/include' dummy.log
#include <...> search starts here:
 /usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/include
 /usr/local/include
 /usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/include-fixed
 /usr/include

验证新链接器是否使用了正确的搜索路径：
(lfs chroot) root:/sources/gcc-14.2.0/build# grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'         # 下面几行是回显
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib64")
SEARCH_DIR("/usr/local/lib64")
SEARCH_DIR("/lib64")
SEARCH_DIR("/usr/lib64")
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib")
SEARCH_DIR("/usr/local/lib")
SEARCH_DIR("/lib")
SEARCH_DIR("/usr/lib");

接下来，请确保我们使用的是正确的 libc 库：
(lfs chroot) root:/sources/gcc-14.2.0/build# grep "/lib.*/libc.so.6 " dummy.log            # 下一行是回显
attempt to open /usr/lib/libc.so.6 succeeded

请确保 GCC 使用的是正确的动态链接器：
(lfs chroot) root:/sources/gcc-14.2.0/build# grep found dummy.log                          # 下一行是回显
found ld-linux-x86-64.so.2 at /usr/lib/ld-linux-x86-64.so.2

如果输出结果与上述不符，或者根本没有输出，则说明出现了严重问题。请仔细检查并重新执行所有步骤，找出问题所在并加以解决。所有问题都必须在继续操作之前解决。

一切正常后，请清理测试文件：
(lfs chroot) root:/sources/gcc-14.2.0/build# rm -v dummy.c a.out dummy.log

最后，移动一个放错位置的文件：
(lfs chroot) root:/sources/gcc-14.2.0/build# 
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib


(lfs chroot) root:/sources/gcc-14.2.0/build# cd ../../





# Ncurses-6.5
(lfs chroot) root:/sources# tar zxvf ncurses-6.5.tar.gz
(lfs chroot) root:/sources# cd ncurses-6.5
(lfs chroot) root:/sources/ncurses-6.5# ./configure --prefix=/usr --mandir=/usr/share/man --with-shared \
--without-debug --without-normal --with-cxx-shared --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig

(lfs chroot) root:/sources/ncurses-6.5# make -j$(nproc) && make DESTDIR=$PWD/dest install

(lfs chroot) root:/sources/ncurses-6.5# install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
(lfs chroot) root:/sources/ncurses-6.5# rm -v  dest/usr/lib/libncursesw.so.6.5
(lfs chroot) root:/sources/ncurses-6.5# sed -e 's/^#if.*XOPEN.*$/#if 1/' -i dest/usr/include/curses.h
(lfs chroot) root:/sources/ncurses-6.5# cp -av dest/*  /
(lfs chroot) root:/sources/ncurses-6.5# for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done

(lfs chroot) root:/sources/ncurses-6.5# ln -sfv libncursesw.so /usr/lib/libcurses.so
(lfs chroot) root:/sources/ncurses-6.5# cp -v -R doc -T /usr/share/doc/ncurses-6.5
(lfs chroot) root:/sources/ncurses-6.5# cd ..
(lfs chroot) root:/sources# rm -rf ncurses-6.5



# Sed-4.9           https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter08/sed.html
(lfs chroot) root:/sources# tar xvf sed-4.9.tar.xz
(lfs chroot) root:/sources# cd sed-4.9
(lfs chroot) root:/sources/sed-4.9# ./configure --prefix=/usr && make -j$(nproc) && make html
# =========================================================
测试结果(本次未做)：
(lfs chroot) root:/sources/sed-4.9# chown -R zhangsan .
(lfs chroot) root:/sources/sed-4.9# su zhangsan -c "PATH=$PATH make check"
# =========================================================

(lfs chroot) root:/sources/sed-4.9# make install
(lfs chroot) root:/sources/sed-4.9# install -d -m755  /usr/share/doc/sed-4.9
(lfs chroot) root:/sources/sed-4.9# install -m644 doc/sed.html /usr/share/doc/sed-4.9
(lfs chroot) root:/sources/sed-4.9# cd ..
(lfs chroot) root:/sources# rm -rf sed-4.9



# Psmisc-23.7
(lfs chroot) root:/sources# tar xvf psmisc-23.7.tar.xz
(lfs chroot) root:/sources# cd psmisc-23.7
(lfs chroot) root:/sources/psmisc-23.7# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/psmisc-23.7# cd ..
(lfs chroot) root:/sources# rm -rf psmisc-23.7


# Gettext-0.24
(lfs chroot) root:/sources# tar xvf gettext-0.24.tar.xz
(lfs chroot) root:/sources# cd gettext-0.24
(lfs chroot) root:/sources/gettext-0.24# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/gettext-0.24
(lfs chroot) root:/sources/gettext-0.24# make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/gettext-0.24# chmod -v 0755 /usr/lib/preloadable_libintl.so
(lfs chroot) root:/sources/gettext-0.24# cd ..
(lfs chroot) root:/sources# rm -rf gettext-0.24


# Bison-3.8.2
(lfs chroot) root:/sources# tar xvf bison-3.8.2.tar.xz
(lfs chroot) root:/sources# cd bison-3.8.2
(lfs chroot) root:/sources/bison-3.8.2# ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2 && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/bison-3.8.2# cd ..
(lfs chroot) root:/sources# rm -rf bison-3.8.2



# Grep-3.11
(lfs chroot) root:/sources# tar xvf grep-3.11.tar.xz
(lfs chroot) root:/sources# cd grep-3.11
(lfs chroot) root:/sources/grep-3.11# sed -i "s/echo/#echo/" src/egrep.sh
(lfs chroot) root:/sources/grep-3.11# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/grep-3.11# cd ..
(lfs chroot) root:/sources# rm -rf grep-3.11




# Bash-5.2.37
(lfs chroot) root:/sources# tar zxvf bash-5.2.37.tar.gz 
(lfs chroot) root:/sources# cd bash-5.2.37
(lfs chroot) root:/sources/bash-5.2.37# ./configure --prefix=/usr --without-bash-malloc --with-installed-readline --docdir=/usr/share/doc/bash-5.2.37

(lfs chroot) root:/sources/bash-5.2.37# make -j$(nproc) && make install


(lfs chroot) root:/sources/bash-5.2.37# ldd /usr/bin/bash
	linux-vdso.so.1 (0x00007004ff7b6000)
	libreadline.so.8 => /usr/lib/libreadline.so.8 (0x00007004ff653000)
	libhistory.so.8 => /usr/lib/libhistory.so.8 (0x00007004ff645000)
	libncursesw.so.6 => /usr/lib/libncursesw.so.6 (0x00007004ff5ce000)
	libc.so.6 => /usr/lib/libc.so.6 (0x00007ef524eac000)                   # 旧的libc.so.6内存地址
	/lib64/ld-linux-x86-64.so.2 (0x00007004ff7b8000)

运行新编译的bash程序（替换当前正在执行的程序）：
(lfs chroot) root:/sources/bash-5.2.37# exec /usr/bin/bash --login

(lfs chroot) root:/sources/bash-5.2.37# ldd /usr/bin/bash
	linux-vdso.so.1 (0x00007b8fe1bd3000)
	libreadline.so.8 => /usr/lib/libreadline.so.8 (0x00007b8fe1a70000)
	libhistory.so.8 => /usr/lib/libhistory.so.8 (0x00007b8fe1a62000)
	libncursesw.so.6 => /usr/lib/libncursesw.so.6 (0x00007b8fe19eb000)
	libc.so.6 => /usr/lib/libc.so.6 (0x00007409dcb94000)                   # 新的libc.so.6内存地址，说明已经进入到新的Bash中了
	/lib64/ld-linux-x86-64.so.2 (0x00007b8fe1bd5000)

(lfs chroot) root:/sources/bash-5.2.37# cd ..

注意：不用退出，继续执行




# libtool-2.5.4
(lfs chroot) root:/sources# tar xvf libtool-2.5.4.tar.xz 
(lfs chroot) root:/sources# cd libtool-2.5.4
(lfs chroot) root:/sources/libtool-2.5.4# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
删除无用的静态库：
(lfs chroot) root:/sources/libtool-2.5.4# rm -fv /usr/lib/libltdl.a
(lfs chroot) root:/sources/libtool-2.5.4# cd ..
(lfs chroot) root:/sources# rm -rf libtool-2.5.4



# GDBM-1.24
(lfs chroot) root:/sources# tar zxvf gdbm-1.24.tar.gz
(lfs chroot) root:/sources# cd gdbm-1.24
(lfs chroot) root:/sources/gdbm-1.24# ./configure --prefix=/usr --disable-static --enable-libgdbm-compat && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/gdbm-1.24# cd .. && rm -rf gdbm-1.24



# Gperf-3.1
(lfs chroot) root:/sources# tar zxvf gperf-3.1.tar.gz
(lfs chroot) root:/sources# cd gperf-3.1
(lfs chroot) root:/sources/gperf-3.1# ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
(lfs chroot) root:/sources/gperf-3.1# make -j$(nproc) && make install
(lfs chroot) root:/sources/gperf-3.1# cd ..
(lfs chroot) root:/sources# rm -rf gperf-3.1




# Expat-2.6.4
(lfs chroot) root:/sources# tar -xvf expat-2.6.4.tar.xz
(lfs chroot) root:/sources# cd expat-2.6.4
(lfs chroot) root:/sources/expat-2.6.4# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/expat-2.6.4
(lfs chroot) root:/sources/expat-2.6.4# make -j$(nproc) && make check && make install
如需文档则安装：
(lfs chroot) root:/sources/expat-2.6.4# install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.6.4
(lfs chroot) root:/sources/expat-2.6.4# cd .. && rm -rf expat-2.6.4


# Inetutils-2.6
(lfs chroot) root:/sources# tar xvf inetutils-2.6.tar.xz
(lfs chroot) root:/sources# cd inetutils-2.6
(lfs chroot) root:/sources/inetutils-2.6# sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c        # 需用gcc-14.1+版本构建软件包
(lfs chroot) root:/sources/inetutils-2.6# ./configure --prefix=/usr \
--bindir=/usr/bin  --localstatedir=/var \
--disable-logger  --disable-whois  \
--disable-rcp   --disable-rexec   \
--disable-rlogin  --disable-rsh  \
--disable-servers

(lfs chroot) root:/sources/inetutils-2.6# make -j$(nproc) && make check && make install

将程序移动到正确的位置：
(lfs chroot) root:/sources/inetutils-2.6# mv -v /usr/bin/ifconfig  /usr/sbin/ifconfig

(lfs chroot) root:/sources/inetutils-2.6# cd ../
(lfs chroot) root:/sources# rm -rf inetutils-2.6




# Less-668
(lfs chroot) root:/sources# tar -zxvf less-668.tar.gz 
(lfs chroot) root:/sources# cd less-668
(lfs chroot) root:/sources/less-668# ./configure --prefix=/usr --sysconfdir=/etc && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/less-668# cd ..
(lfs chroot) root:/sources# rm -rf less-668



# Perl-5.40.1             https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter08/perl.html
(lfs chroot) root:/sources# tar xvf perl-5.40.1.tar.xz
(lfs chroot) root:/sources# cd perl-5.40.1
(lfs chroot) root:/sources/perl-5.40.1# export BUILD_ZLIB=False && export BUILD_BZIP2=0
(lfs chroot) root:/sources/perl-5.40.1# sh Configure -des  \
-D prefix=/usr   -D vendorprefix=/usr   \
-D privlib=/usr/lib/perl5/5.40/core_perl      \
-D archlib=/usr/lib/perl5/5.40/core_perl      \
-D sitelib=/usr/lib/perl5/5.40/site_perl      \
-D sitearch=/usr/lib/perl5/5.40/site_perl     \
-D vendorlib=/usr/lib/perl5/5.40/vendor_perl  \
-D vendorarch=/usr/lib/perl5/5.40/vendor_perl \
-D man1dir=/usr/share/man/man1   \
-D man3dir=/usr/share/man/man3     \
-D pager="/usr/bin/less -isR"      \
-D useshrplib  -D usethreads

(lfs chroot) root:/sources/perl-5.40.1# make -j$(nproc) && TEST_JOBS=$(nproc) make test_harness && make install
(lfs chroot) root:/sources/perl-5.40.1# unset BUILD_ZLIB BUILD_BZIP2
(lfs chroot) root:/sources/perl-5.40.1# cd ..
(lfs chroot) root:/sources# rm -rf perl-5.40.1



# XML::Parser-2.47
(lfs chroot) root:/sources# tar zxvf XML-Parser-2.47.tar.gz
(lfs chroot) root:/sources# cd XML-Parser-2.47
(lfs chroot) root:/sources/XML-Parser-2.47# perl Makefile.PL
(lfs chroot) root:/sources/XML-Parser-2.47# make -j$(nproc) && make test && make install
(lfs chroot) root:/sources/XML-Parser-2.47# cd ..
(lfs chroot) root:/sources# rm -rf XML-Parser-2.47



# Intltool-0.51.0
(lfs chroot) root:/sources# tar zxvf intltool-0.51.0.tar.gz
(lfs chroot) root:/sources# cd intltool-0.51.0
(lfs chroot) root:/sources/intltool-0.51.0# sed -i 's:\\\${:\\\$\\{:' intltool-update.in
(lfs chroot) root:/sources/intltool-0.51.0# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/intltool-0.51.0# install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
(lfs chroot) root:/sources/intltool-0.51.0# cd ..
(lfs chroot) root:/sources# rm -rf intltool-0.51.0



# Autoconf-2.72
(lfs chroot) root:/sources# tar xvf autoconf-2.72.tar.xz
(lfs chroot) root:/sources# cd autoconf-2.72
(lfs chroot) root:/sources/autoconf-2.72# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/autoconf-2.72# cd ..
(lfs chroot) root:/sources# rm -rf autoconf-2.72



# Automake-1.17
(lfs chroot) root:/sources# tar xvf automake-1.17.tar.xz
(lfs chroot) root:/sources# cd automake-1.17
(lfs chroot) root:/sources/automake-1.17# ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.17 && make -j$(nproc) && make -j$(($(nproc)>4?$(nproc):4)) check && make install
(lfs chroot) root:/sources/automake-1.17# cd ..
(lfs chroot) root:/sources# rm -rf automake-1.17



# OpenSSL-3.4.1
(lfs chroot) root:/sources# tar zxvf openssl-3.4.1.tar.gz 
(lfs chroot) root:/sources# cd openssl-3.4.1
(lfs chroot) root:/sources/openssl-3.4.1# ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib  shared  zlib-dynamic
(lfs chroot) root:/sources/openssl-3.4.1# make -j$(nproc) && HARNESS_JOBS=$(nproc) make test
(lfs chroot) root:/sources/openssl-3.4.1# sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
(lfs chroot) root:/sources/openssl-3.4.1# make MANSUFFIX=ssl install
(lfs chroot) root:/sources/openssl-3.4.1# mv -v /usr/share/doc/openssl  /usr/share/doc/openssl-3.4.1            # 将版本号添加到文档目录名称中，以与其他软件包保持一致
(lfs chroot) root:/sources/openssl-3.4.1# cp -vfr doc/* /usr/share/doc/openssl-3.4.1                            # 按需安装额外文档
(lfs chroot) root:/sources/openssl-3.4.1# cd ..
(lfs chroot) root:/sources# rm -rf openssl-3.4.1



# Elfutils-0.192                    https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter08/libelf.html
(lfs chroot) root:/sources# tar jxvf elfutils-0.192.tar.bz2
(lfs chroot) root:/sources# cd elfutils-0.192
(lfs chroot) root:/sources/elfutils-0.192# ./configure --prefix=/usr --disable-debuginfod --enable-libdebuginfod=dummy
(lfs chroot) root:/sources/elfutils-0.192# make -j$(nproc) && make check
仅安装Libelf：
(lfs chroot) root:/sources/elfutils-0.192# make -C libelf install
(lfs chroot) root:/sources/elfutils-0.192# install -vm644 config/libelf.pc /usr/lib/pkgconfig
(lfs chroot) root:/sources/elfutils-0.192# rm /usr/lib/libelf.a
(lfs chroot) root:/sources/elfutils-0.192# cd ..
(lfs chroot) root:/sources# rm -rf elfutils-0.192




# Libffi-3.4.7
(lfs chroot) root:/sources# tar zxvf libffi-3.4.7.tar.gz
(lfs chroot) root:/sources# cd libffi-3.4.7
(lfs chroot) root:/sources/libffi-3.4.7# ./configure --prefix=/usr --disable-static --with-gcc-arch=native
(lfs chroot) root:/sources/libffi-3.4.7# make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/libffi-3.4.7# cd ..
(lfs chroot) root:/sources# rm -rf libffi-3.4.7 




# Python-3.13.2
(lfs chroot) root:/sources# tar xvf Python-3.13.2.tar.xz
(lfs chroot) root:/sources# cd Python-3.13.2
(lfs chroot) root:/sources/Python-3.13.2# ./configure --prefix=/usr --enable-shared --with-system-expat --enable-optimizations
(lfs chroot) root:/sources/Python-3.13.2# make -j$(nproc)
有些测试偶尔会无限期地挂起。因此，为了测试结果，请运行测试套件，但为每个测试用例设置2分钟的时间限制：
(lfs chroot) root:/sources/Python-3.13.2# make test TESTOPTS="--timeout 120" && make install
(lfs chroot) root:/sources/Python-3.13.2# cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

(lfs chroot) root:/sources/Python-3.13.2# install -v -dm755 /usr/share/doc/python-3.13.2/html
(lfs chroot) root:/sources/Python-3.13.2# tar --strip-components=1  --no-same-owner --no-same-permissions \
-C /usr/share/doc/python-3.13.2/html  -xvf ../python-3.13.2-docs-html.tar.bz2
(lfs chroot) root:/sources/Python-3.13.2# cd ..
(lfs chroot) root:/sources/Python-3.13.2# rm -rf Python-3.13.2




# flit-Core-3.11.0
(lfs chroot) root:/sources# tar -zxvf flit_core-3.11.0.tar.gz
(lfs chroot) root:/sources# cd flit_core-3.11.0
(lfs chroot) root:/sources/flit_core-3.11.0# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD          # 构建软件包
(lfs chroot) root:/sources/flit_core-3.11.0# pip3 install --no-index --find-links dist flit_core                            # 安装软件包
(lfs chroot) root:/sources/flit_core-3.11.0# cd ..
(lfs chroot) root:/sources# rm -rf flit_core-3.11.0



# Wheel-0.45.1
(lfs chroot) root:/sources# tar zxvf wheel-0.45.1.tar.gz
(lfs chroot) root:/sources# cd wheel-0.45.1
(lfs chroot) root:/sources/wheel-0.45.1# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD         # 编译 Wheel
(lfs chroot) root:/sources/wheel-0.45.1# pip3 install --no-index --find-links dist wheel                               # 安装Wheel
(lfs chroot) root:/sources/wheel-0.45.1# cd ..
(lfs chroot) root:/sources# rm -rf wheel-0.45.1




# Setuptools-75.8.1
(lfs chroot) root:/sources# tar xvf setuptools-75.8.1.tar.gz 
(lfs chroot) root:/sources# cd setuptools-75.8.1
(lfs chroot) root:/sources/setuptools-75.8.1# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
(lfs chroot) root:/sources/setuptools-75.8.1# pip3 install --no-index --find-links dist setuptools
(lfs chroot) root:/sources/setuptools-75.8.1# cd ..
(lfs chroot) root:/sources# rm -rf setuptools-75.8.1



# Ninja-1.12.1
(lfs chroot) root:/sources# tar zxvf ninja-1.12.1.tar.gz
(lfs chroot) root:/sources# cd ninja-1.12.1
(lfs chroot) root:/sources/ninja-1.12.1# export NINJAJOBS=4          # 将Ninja 的并行进程数限制为四个
(lfs chroot) root:/sources/ninja-1.12.1# sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc

(lfs chroot) root:/sources/ninja-1.12.1# python3 configure.py --bootstrap --verbose
(lfs chroot) root:/sources/ninja-1.12.1# 
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

(lfs chroot) root:/sources/ninja-1.12.1# cd ..
(lfs chroot) root:/sources# rm -rf ninja-1.12.1




# Meson-1.7.0                     https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter08/meson.html
(lfs chroot) root:/sources# tar -zxvf meson-1.7.0.tar.gz
(lfs chroot) root:/sources# cd meson-1.7.0
(lfs chroot) root:/sources/meson-1.7.0# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
释义：-w dist 将生成的 wheel 文件放入dist目录中

(lfs chroot) root:/sources/meson-1.7.0# pip3 install --no-index --find-links dist meson
释义：--find-links dist 从dist 目录安装 wheel 文件

(lfs chroot) root:/sources/meson-1.7.0# install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
(lfs chroot) root:/sources/meson-1.7.0# install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
(lfs chroot) root:/sources/meson-1.7.0# cd ..
(lfs chroot) root:/sources# rm -rf meson-1.7.0



# Kmod-34
(lfs chroot) root:/sources# tar xvf kmod-34.tar.xz
(lfs chroot) root:/sources# cd kmod-34
(lfs chroot) root:/sources/kmod-34# mkdir build && cd build
(lfs chroot) root:/sources/kmod-34# meson setup --prefix=/usr .. --sbindir=/usr/sbin --buildtype=release -D manpages=false
(lfs chroot) root:/sources/kmod-34# ninja && ninja install
(lfs chroot) root:/sources/kmod-34# cd ../..
(lfs chroot) root:/sources# rm -rf kmod-34



# Coreutils-9.6
(lfs chroot) root:/sources# tar xvf coreutils-9.6.tar.xz 
(lfs chroot) root:/sources# cd coreutils-9.6
(lfs chroot) root:/sources/coreutils-9.6# patch -Np1 -i ../coreutils-9.6-i18n-1.patch
(lfs chroot) root:/sources/coreutils-9.6# autoreconf -fv && automake -af
(lfs chroot) root:/sources/coreutils-9.6# FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --enable-no-install-program=kill,uptime
(lfs chroot) root:/sources/coreutils-9.6# make -j$(nproc) && make install
注：make完后有个测试的环境，本次未做，做完测试后才是make install
(lfs chroot) root:/sources/coreutils-9.6# mv -v /usr/bin/chroot /usr/sbin && mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
(lfs chroot) root:/sources/coreutils-9.6# sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
(lfs chroot) root:/sources/coreutils-9.6# cd ..
(lfs chroot) root:/sources# rm -rf coreutils-9.6




# Check-0.15.2
(lfs chroot) root:/sources# tar zxvf check-0.15.2.tar.gz
(lfs chroot) root:/sources# cd check-0.15.2
(lfs chroot) root:/sources/check-0.15.2# ./configure --prefix=/usr --disable-static && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/check-0.15.2# cd ..
(lfs chroot) root:/sources# rm -rf check-0.15.2


# Diffutils-3.11
(lfs chroot) root:/sources# tar xvf diffutils-3.11.tar.xz 
(lfs chroot) root:/sources# cd diffutils-3.11
(lfs chroot) root:/sources/diffutils-3.11# ./configure --prefix=/usr --disable-static && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/diffutils-3.11# cd ..
(lfs chroot) root:/sources# rm -rf diffutils-3.11


# Gawk-5.3.1
(lfs chroot) root:/sources# tar xvf gawk-5.3.1.tar.xz 
(lfs chroot) root:/sources# cd gawk-5.3.1
(lfs chroot) root:/sources/gawk-5.3.1# sed -i 's/extras//'  Makefile.in
(lfs chroot) root:/sources/gawk-5.3.1# ./configure --prefix=/usr && make -j$(nproc) && rm -f /usr/bin/gawk-5.3.1 && make install
(lfs chroot) root:/sources/gawk-5.3.1# ln -sv gawk.1  /usr/share/man/man1/awk.1
(lfs chroot) root:/sources/gawk-5.3.1# install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.1
(lfs chroot) root:/sources/gawk-5.3.1# cd ..
(lfs chroot) root:/sources# rm -rf gawk-5.3.1


# Findutils-4.10.0
(lfs chroot) root:/sources# tar -xvf findutils-4.10.0.tar.xz
(lfs chroot) root:/sources# cd findutils-4.10.0
(lfs chroot) root:/sources/findutils-4.10.0# ./configure --prefix=/usr --localstatedir=/var/lib/locate && make && make install
(lfs chroot) root:/sources/findutils-4.10.0# cd ..
(lfs chroot) root:/sources# rm -rf findutils-4.10.0


# Groff-1.23.0
(lfs chroot) root:/sources# tar -zxvf groff-1.23.0.tar.gz
(lfs chroot) root:/sources# cd groff-1.23.0
(lfs chroot) root:/sources/groff-1.23.0# PAGE=A4 ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/groff-1.23.0# cd ..
(lfs chroot) root:/sources# rm -rf groff-1.23.0



# GRUB-2.12
取消设置任何可能影响构建的环境变量：
(lfs chroot) root:/sources# unset {C,CPP,CXX,LD}FLAGS

(lfs chroot) root:/sources# tar xvf grub-2.12.tar.xz 
(lfs chroot) root:/sources# cd grub-2.12
添加发布 tar 包中缺失的文件：
(lfs chroot) root:/sources/grub-2.12# echo depends bli part_gpt > grub-core/extra_deps.lst

准备GRUB进行编译：
(lfs chroot) root:/sources/grub-2.12# ./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror && make -j$(nproc) && make install
(lfs chroot) root:/sources/grub-2.12# mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
(lfs chroot) root:/sources/grub-2.12# cd ..
(lfs chroot) root:/sources# rm -rf grub-2.12



# Gzip-1.13
(lfs chroot) root:/sources# tar xvf gzip-1.13.tar.xz
(lfs chroot) root:/sources# cd gzip-1.13
(lfs chroot) root:/sources/gzip-1.13# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/gzip-1.13# cd ..
(lfs chroot) root:/sources# rm -rf gzip-1.13


# IPRoute2-6.13.0
(lfs chroot) root:/sources# tar xvf iproute2-6.13.0.tar.xz
(lfs chroot) root:/sources# cd iproute2-6.13.0
(lfs chroot) root:/sources/iproute2-6.13.0# sed -i /ARPD/d Makefile && rm -fv man/man8/arpd.8
(lfs chroot) root:/sources/iproute2-6.13.0# make NETNS_RUN_DIR=/run/netns && make SBINDIR=/usr/sbin install
(lfs chroot) root:/sources/iproute2-6.13.0# install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.13.0
(lfs chroot) root:/sources/iproute2-6.13.0# cd ..
(lfs chroot) root:/sources# rm -rf iproute2-6.13.0


# Kbd-2.7.1
(lfs chroot) root:/sources# tar xvf kbd-2.7.1.tar.xz 
(lfs chroot) root:/sources# cd kbd-2.7.1
(lfs chroot) root:/sources/kbd-2.7.1# patch -Np1 -i ../kbd-2.7.1-backspace-1.patch
(lfs chroot) root:/sources/kbd-2.7.1# sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure && sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
(lfs chroot) root:/sources/kbd-2.7.1# ./configure --prefix=/usr --disable-vlock && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/kbd-2.7.1# cp -R -v docs/doc -T /usr/share/doc/kbd-2.7.1
(lfs chroot) root:/sources/kbd-2.7.1# cd ..
(lfs chroot) root:/sources# rm -rf kbd-2.7.1



# Libpipeline-1.5.8
(lfs chroot) root:/sources# tar zxvf libpipeline-1.5.8.tar.gz
(lfs chroot) root:/sources# cd libpipeline-1.5.8
(lfs chroot) root:/sources/libpipeline-1.5.8# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/libpipeline-1.5.8# cd ..
(lfs chroot) root:/sources# rm -rf libpipeline-1.5.8


# Make-4.4.1
(lfs chroot) root:/sources# tar zxvf make-4.4.1.tar.gz 
(lfs chroot) root:/sources# cd make-4.4.1
(lfs chroot) root:/sources/make-4.4.1# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/make-4.4.1# cd ..
(lfs chroot) root:/sources# rm -rf make-4.4.1


# Patch-2.7.6
(lfs chroot) root:/sources# tar xvf patch-2.7.6.tar.xz
(lfs chroot) root:/sources# cd patch-2.7.6
(lfs chroot) root:/sources/patch-2.7.6# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/patch-2.7.6# cd ..
(lfs chroot) root:/sources# rm -rf patch-2.7.6


# Tar-1.35
(lfs chroot) root:/sources# tar -xvf tar-1.35.tar.xz
(lfs chroot) root:/sources# cd tar-1.35
(lfs chroot) root:/sources/tar-1.35# FORCE_UNSAFE_CONFIGURE=1  ./configure --prefix=/usr && make -j$(nproc) && make install
注意：这一步不用make check，执行make check会报错

(lfs chroot) root:/sources/tar-1.35# make -C doc install-html docdir=/usr/share/doc/tar-1.35
(lfs chroot) root:/sources/tar-1.35# cd ..
(lfs chroot) root:/sources# rm -rf tar-1.35



# Texinfo-7.2
(lfs chroot) root:/sources# tar xvf texinfo-7.2.tar.xz
(lfs chroot) root:/sources# cd texinfo-7.2
(lfs chroot) root:/sources/texinfo-7.2# ./configure --prefix=/usr && make -j$(nproc) && make check && make install && make TEXMF=/usr/share/texmf install-tex
(lfs chroot) root:/sources/texinfo-7.2# pushd /usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
popd

(lfs chroot) root:/sources/texinfo-7.2# cd ..
(lfs chroot) root:/sources# rm -rf texinfo-7.2


# Vim-9.1.1166
(lfs chroot) root:/sources# tar -zxvf vim-9.1.1166.tar.gz 
(lfs chroot) root:/sources# cd vim-9.1.1166
(lfs chroot) root:/sources/vim-9.1.1166# echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
(lfs chroot) root:/sources/vim-9.1.1166# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/vim-9.1.1166# ln -sv vim /usr/bin/vi
(lfs chroot) root:/sources/vim-9.1.1166# ln -sv ../vim/vim91/doc /usr/share/doc/vim-9.1.1166

配置vim
(lfs chroot) root:/sources/vim-9.1.1166# cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF

(lfs chroot) root:/sources/vim-9.1.1166# cd ..
(lfs chroot) root:/sources# rm -rf vim-9.1.1166



# MarkupSafe-3.0.2
(lfs chroot) root:/sources# tar zxvf markupsafe-3.0.2.tar.gz
(lfs chroot) root:/sources# cd markupsafe-3.0.2
(lfs chroot) root:/sources/markupsafe-3.0.2# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
(lfs chroot) root:/sources/markupsafe-3.0.2# pip3 install --no-index --find-links dist Markupsafe
(lfs chroot) root:/sources/markupsafe-3.0.2# cd ..
(lfs chroot) root:/sources# rm -rf markupsafe-3.0.2


# Jinja2-3.1.5
(lfs chroot) root:/sources# tar -zxvf jinja2-3.1.5.tar.gz
(lfs chroot) root:/sources# cd jinja2-3.1.5
(lfs chroot) root:/sources/jinja2-3.1.5# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
(lfs chroot) root:/sources/jinja2-3.1.5# pip3 install --no-index --find-links dist Jinja2
(lfs chroot) root:/sources/jinja2-3.1.5# cd ..
(lfs chroot) root:/sources# rm -rf jinja2-3.1.5



# Systemd-257.3     这部分是个重点             https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter08/systemd.html
(lfs chroot) root:/sources# tar zxvf systemd-257.3.tar.gz
(lfs chroot) root:/sources# cd systemd-257.3
(lfs chroot) root:/sources/systemd-257.3# sed -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' -i rules.d/50-udev-default.rules.in
(lfs chroot) root:/sources/systemd-257.3# mkdir build && cd build
(lfs chroot) root:/sources/systemd-257.3/build# meson setup ..  --prefix=/usr  --buildtype=release   -D default-dnssec=no \
-D firstboot=false   -D install-tests=false  -D ldconfig=false   -D sysusers=false \
-D rpmmacrosdir=no  -D homed=disabled  -D userdb=false  \
-D man=disabled   -D mode=release  -D pamconfdir=no  -D dev-kvm-mode=0660 \
-D nobody-group=nogroup  -D sysupdate=disabled  -D ukify=disabled \
-D docdir=/usr/share/doc/systemd-257.3


(lfs chroot) root:/sources/systemd-257.3/build# ninja

某些测试需要一个基本/etc/os-release文件。要测试结果，请执行以下命令：
(lfs chroot) root:/sources/systemd-257.3/build# echo 'NAME="Linux From Scratch v1"' > /etc/os-release

cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="12.3-systemd"
DISTRIB_CODENAME="<your name here>"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF

cat > /etc/os-release << "EOF"
NAME="Linux From Scratch"
VERSION="12.3-systemd"
ID=lfs
PRETTY_NAME="Linux From Scratch 12.3-systemd"
VERSION_CODENAME="<your name here>"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
RELEASE_TYPE="stable"
EOF


(lfs chroot) root:/sources/systemd-257.3/build# ninja test
....
  ....
1637/1638 systemd:dist / check-version-systemd-vpick             OK               0.05s
1638/1638 systemd:dist / check-help-systemd-vpick                OK               0.07s

Summary of Failures:

1063/1638 systemd:core / test-namespace           FAIL             0.66s   killed by signal 6 SIGABRT

Ok:                 1605
Expected Fail:      0   
Fail:               1   
Unexpected Pass:    0   
Skipped:            32  
Timeout:            0   

Full log written to /sources/systemd-257.3/build/meson-logs/testlog.txt
FAILED: meson-internal__test                                   # 那个test-namespace失败，在chroot环境中是非常典型且预料之中的
/usr/bin/meson test --no-rebuild --print-errorlogs
ninja: build stopped: subcommand failed.

1. 为什么 test-namespace 会失败？
这个测试主要检测 Systemd 对 Linux 命令空间（Namespaces）的管理能力。它失败通常不是因为你编译得不对，而是因为：
（1）环境受限：你现在处于 chroot 环境中，某些内核命名空间隔离功能（如 Mount Namespace 或 User Namespace）在 chroot 内部会被内核限制，导致测试进程无法获得必要的权限
（2）宿主机内核限制：如果你宿主机的内核开启了某些安全限制（如 unprivileged_userns_clone 为 0），也会导致这个涉及命名空间的测试被 SIGABRT（信号 6，通常是内部断言失败触发的自杀）杀掉
（3）直接执行下一步即可

(lfs chroot) root:/sources/systemd-257.3/build# ninja install
(lfs chroot) root:/sources/systemd-257.3/build# tar -xf ../../systemd-man-pages-257.3.tar.xz --no-same-owner --strip-components=1 -C /usr/share/man
创建systemd-journald/etc/machine-id所需的文件：
(lfs chroot) root:/sources/systemd-257.3/build# systemd-machine-id-setup
建立基本目标结构：
(lfs chroot) root:/sources/systemd-257.3/build# systemctl preset-all
(lfs chroot) root:/sources/systemd-257.3/build# cd ../.. 
(lfs chroot) root:/sources# rm -rf systemd-257.3



# D-Bus-1.16.0
(lfs chroot) root:/sources# tar -xvf dbus-1.16.0.tar.xz
(lfs chroot) root:/sources# cd dbus-1.16.0
(lfs chroot) root:/sources/dbus-1.16.0# mkdir build && cd build
(lfs chroot) root:/sources/dbus-1.16.0/build# meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..         # 会有几个NO的提示，没影响
(lfs chroot) root:/sources/dbus-1.16.0/build# ninja && ninja test && ninja install
创建一个符号链接，以便 D-Bus 和 systemd 可以使用同一个 machine-id文件：
(lfs chroot) root:/sources/dbus-1.16.0/build# ln -sfv /etc/machine-id /var/lib/dbus
(lfs chroot) root:/sources/dbus-1.16.0/build# cd ../..
(lfs chroot) root:/sources# rm -rf dbus-1.16.0


# Man-DB-2.13.0
(lfs chroot) root:/sources# tar xvf man-db-2.13.0.tar.xz
(lfs chroot) root:/sources# cd man-db-2.13.0
(lfs chroot) root:/sources/man-db-2.13.0# ./configure --prefix=/usr  --docdir=/usr/share/doc/man-db-2.13.0 \
--sysconfdir=/etc   --disable-setuid \
--enable-cache-owner=bin  --with-browser=/usr/bin/lynx \
--with-vgrind=/usr/bin/vgrind  --with-grap=/usr/bin/grap

(lfs chroot) root:/sources/man-db-2.13.0# make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/man-db-2.13.0# cd ..
(lfs chroot) root:/sources# rm -rf man-db-2.13.0


# Procps-ng-4.0.5
(lfs chroot) root:/sources# tar xvf procps-ng-4.0.5.tar.xz
(lfs chroot) root:/sources# cd procps-ng-4.0.5
(lfs chroot) root:/sources/procps-ng-4.0.5# ./configure --prefix=/usr  --docdir=/usr/share/doc/procps-ng-4.0.5 \
--disable-static  --disable-kill  --enable-watch8bit  --with-systemd

(lfs chroot) root:/sources/procps-ng-4.0.5# make -j$(nproc) && make install
(lfs chroot) root:/sources/procps-ng-4.0.5# cd ..
(lfs chroot) root:/sources# rm -rf procps-ng-4.0.5



# Util-linux-2.40.4       这个是重要的一部分        https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter08/util-linux.html
(lfs chroot) root:/sources# tar xvf util-linux-2.40.4.tar.xz
(lfs chroot) root:/sources# cd util-linux-2.40.4
(lfs chroot) root:/sources/util-linux-2.40.4# ./configure --bindir=/usr/bin \
--libdir=/usr/lib  --runstatedir=/run   --sbindir=/usr/sbin   \
--disable-chfn-chsh  --disable-login  --disable-nologin  \
--disable-su  --disable-setpriv   --disable-runuser  \
--disable-pylibmount  --disable-liblastlog2 \
--disable-static  --without-python  \
ADJTIME_PATH=/var/lib/hwclock/adjtime \
--docdir=/usr/share/doc/util-linux-2.40.4

(lfs chroot) root:/sources/util-linux-2.40.4# make -j$(nproc) && make install
(lfs chroot) root:/sources/util-linux-2.40.4# cd ..
(lfs chroot) root:/sources# rm -rf util-linux-2.40.4


# E2fsprogs-1.47.2
(lfs chroot) root:/sources# tar zxvf e2fsprogs-1.47.2.tar.gz
(lfs chroot) root:/sources# cd e2fsprogs-1.47.2
(lfs chroot) root:/sources/e2fsprogs-1.47.2# mkdir build && cd build
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# ../configure --prefix=/usr \
--sysconfdir=/etc --enable-elf-shlibs --disable-libblkid      \
--disable-libuuid --disable-uuidd --disable-fsck

(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# make -j$(nproc) 
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# make check              # 这一步有报错没关系，直接往下执行
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# make install

删除无用的静态库：
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

此软件包安装的是一个 gzip 压缩.info 文件，但不会更新系统级dir文件。请解压缩此文件，然后dir使用以下命令更新系统文件：
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# gunzip -v /usr/share/info/libext2fs.info.gz
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

如果需要，可以通过执行以下命令创建并安装一些其他文档：
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# 
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info

配置E2fsprogs
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf
(lfs chroot) root:/sources/e2fsprogs-1.47.2/build# cd ../../
(lfs chroot) root:/sources# rm -rf e2fsprogs-1.47.2



# 剥离             https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter08/stripping.html
(lfs chroot) root:/sources# save_usrlib="$(cd /usr/lib; ls ld-linux*[^g])
             libc.so.6
             libthread_db.so.1
             libquadmath.so.0.0.0
             libstdc++.so.6.0.33
             libitm.so.1.0.0
             libatomic.so.1.2.0"

(lfs chroot) root:/sources# cd /usr/lib

(lfs chroot) root:/usr/lib# for LIB in $save_usrlib; do
    objcopy --only-keep-debug --compress-debug-sections=zlib $LIB $LIB.dbg
    cp $LIB /tmp/$LIB
    strip --strip-unneeded /tmp/$LIB
    objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

(lfs chroot) root:/usr/lib# online_usrbin="bash find strip"
(lfs chroot) root:/usr/lib# online_usrlib="libbfd-2.44.so
               libsframe.so.1.0.0
               libhistory.so.8.2
               libncursesw.so.6.5
               libm.so.6
               libreadline.so.8.2
               libz.so.1.3.1
               libzstd.so.1.5.7
               $(cd /usr/lib; find libnss*.so* -type f)"

(lfs chroot) root:/usr/lib# for BIN in $online_usrbin; do
    cp /usr/bin/$BIN /tmp/$BIN
    strip --strip-unneeded /tmp/$BIN
    install -vm755 /tmp/$BIN /usr/bin
    rm /tmp/$BIN
done

(lfs chroot) root:/usr/lib# for LIB in $online_usrlib; do
    cp /usr/lib/$LIB /tmp/$LIB
    strip --strip-unneeded /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

(lfs chroot) root:/usr/lib# for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
         $(find /usr/lib -type f -name \*.a)                 \
         $(find /usr/{bin,sbin,libexec} -type f); do
    case "$online_usrbin $online_usrlib $save_usrlib" in
        *$(basename $i)* )
            ;;
        * ) strip --strip-unneeded $i
            ;;
    esac
done

(lfs chroot) root:/usr/lib# unset BIN LIB save_usrlib online_usrbin online_usrlib



# 清理
(lfs chroot) root:/usr/lib# rm -rf /tmp/{*,.*}
(lfs chroot) root:/usr/lib# find /usr/lib /usr/libexec -name \*.la -delete

(lfs chroot) root:/usr/lib# find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf

最后删除上一章开头创建的临时“测试”用户帐户
(lfs chroot) root:/usr/lib# userdel -r zhangsan
userdel: zhangsan mail spool (/var/mail/zhangsan) not found


```







## 系统配置
### 一般网络配置
```shell
(lfs chroot) root:/usr/lib# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:93:90:28 brd ff:ff:ff:ff:ff:ff
    altname enp2s1
    inet 172.16.186.141/24 brd 172.16.186.255 scope global dynamic noprefixroute ens33
       valid_lft 1449sec preferred_lft 1449sec
    inet6 fe80::20c:29ff:fe93:9028/64 scope link proto kernel_ll 
       valid_lft forever preferred_lft forever
释义：
上述在 chroot 中能看到 ens33 并且已经有 IP（172.16.186.128），这是因为 chroot 环境共享了宿主机（Ubuntu）的内核和网络堆栈
虽然现在看着有网，但这只是“借用”宿主机的成果。为了让你脱离宿主机独立启动 LFS 后网络依然正常，你需要按照刚才看到的 ens33 这个名字来编写配置文件。
1. 编写 LFS 独立的网络配置
请直接在当前 chroot 环境下执行以下命令（针对你的 ens33）：
# 创建网络配置目录（以防万一还没创建）
(lfs chroot) root:/usr/lib# mkdir -pv /etc/systemd/network

# 编写DHCP配置文件（本次使用该配置文件）
(lfs chroot) root:/usr/lib# vim /etc/systemd/network/10-eth-dhcp.network
[Match]
Name=ens33

[Network]
DHCP=ipv4

注意: dhcp和静态IP可以同时存在，但(1)文件名的开头不要相同，在systemd-networkd中文件是按文件名字符顺序加载的，并且一旦匹配到网卡名称，后续的逻辑可能会发生冲突或叠加
为什么155没生效？
原因主要有两个：
(1) 文件冲突：你同时拥有 10-eth-dhcp.network 和 10-eth-static.network。由于它们都匹配 Name=ens33，systemd-networkd 可能同时启动了 DHCP 客户端并尝试设置静态地址。在很多情况下，DHCP获取到的地址会覆盖或与静态地址共存，但你的DHCP显然先拿到了172.16.186.141
(2) 加载顺序：两个文件名都以 10- 开头，加载顺序是不确定的
你不能同时保留这两份文件，除非你希望在 DHCP 失败时回退到静态（那需要更复杂的配置）
# ===============================================================================
# 编写静态IP配置
(lfs chroot) root:/usr/lib# vim /etc/systemd/network/10-eth-static.network
[Match]
Name=ens33

[Network]
Address=172.16.186.155/24
Gateway=172.16.186.2
DNS=172.16.186.2
Domains=172.16.186.2

注意：
如果需要使用静态IP则需要把静态文件名改成比如10-eth-static.network.bak,只留下10-eth-dhcp.network
如果2个文件都使用则需要把名字改成比如10-eth-static.network 和 20-eth-dhcp.network，这样会优先使用静态IP,如果静态IP配错/异常则会退而求其次使用dhcp获取IP,比如:
root@lfs:~$ mv /etc/systemd/network/10-eth-dhcp.network  /etc/systemd/network/20-eth-dhcp.network
root@lfs:~$ systemctl restart systemd-networkd
此时IP就会变成手动配置的那个静态IP(即.155)

# ===============================================================================


2. 为什么你在 chroot 里看到的是“借来的”网络？
在Linux中，网络接口是由内核管理的。由于chroot只是改变了进程看到的根目录，并没有隔离内核空间，所以：
宿主机 Ubuntu 的内核已经驱动了ens33
宿主机的 systemd-networkd 或 NetworkManager 已经完成了 DHCP 握手
你在 chroot 里执行 ip a，其实是在查看宿主机内核的状态

3. 下一步：配置DNS解析
有了IP还不够，新系统启动后需要知道去哪里找网页。即使现在 chroot 能上网，你也必须为 LFS 建立自己的解析配置：
# 建立 systemd 推荐的 resolv.conf 软链接
(lfs chroot) root:/usr/lib# ln -sfv /run/systemd/resolve/resolv.conf /etc/resolv.conf

4. 关键点：关于systemctl的报错
你可能会尝试在chroot里执行
(lfs chroot) root:/usr/lib# systemctl enable systemd-networkd             # 本次未报错
如果报错：
System has not been booted with systemd as init system (PID 1). Can't operate.
请完全忽略这个报错。 这是因为 chroot 环境的 PID 1 依然是宿主机的 init。只要你把上面的 .network 文件写对了，当你真正从硬盘启动 LFS 系统时，
LFS自己的 systemd 会作为 PID 1 启动，它会自动扫描 /etc/systemd/network/ 目录并拉起网络


配置系统主机名
(lfs chroot) root:/usr/lib# echo lfs > /etc/hostname

自定义 /etc/hosts 文件
(lfs chroot) root:/usr/lib# cat > /etc/hosts << "EOF"
127.0.0.1  localhost lfs
::1        localhost
EOF







# 设备和模块操作概述        https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter09/udev.html
这一步（9.3. Udev自定义规则）属于可选操作，在大多数情况下，你不需要特意去编写自定义规则，除非你有非常特殊的需求
简单来说，它的存在是为了解决某些设备命名不符合你心意的情况

1. 为什么通常不需要执行？
默认规则已足够：你在第 8 章安装 systemd（包含 udev）时，已经安装了一套非常完善的默认规则。它会自动识别你的磁盘、网卡、显卡等
网卡命名：现在 systemd 使用的是“可预测网络接口名称”（如你看到的 ens33）。如果你强行用 udev 规则把它改回老掉牙的 eth0，反而可能导致某些现代脚本出错
自动加载：现在的内核和 udev 配合得很好，只要硬件驱动编译进了内核（或作为模块），设备文件（/dev/*）就会自动生成

2. 什么情况下你才需要动它？
只有当你遇到以下“强迫症”或特殊硬件需求时才需要执行：
固定乱跳的设备名：比如你有两个一模一样的 USB 网卡，系统每次开机随机把其中一个设为 wan0，另一个设为 wan1。你需要通过 MAC 地址绑定它们
修改设备权限：比如你接了一个串口设备或 USB 调试器，默认只有 root 能读写，你想让普通用户也能用，就可以写个规则把它的 MODE 改成 0666
创建自定义软链接：比如你想让 /dev/my_disk 永远指向你的某个特定硬盘分区

3. 文档里提到的 LFS 规则包
文档中提到了 lfs-udev-rules-20230813（或类似版本）。
如果你在第 8 章安装 systemd 时已经按照说明把这些基础规则放进去了，那么现在就不需要再做任何事。
第九章的这一节主要是教你原理，告诉你如果以后想改设备名该去哪里改。

💡 建议直接跳过。 对于第一次构建 LFS 的你来说，保持默认是最高效的。只要你的 ens33 能被识别，硬盘能挂载，就没必要去折腾udev




# 设备管理（直接跳过）       https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter09/symlinks.html
# 配置系统时钟（直接跳过）    https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter09/clock.html


# 配置Linux控制台        https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter09/console.html
(lfs chroot) root:/usr/lib# echo FONT=Lat2-Terminus16 > /etc/vconsole.conf

英文键盘和控制台的示例
(lfs chroot) root:/usr/lib# cat > /etc/vconsole.conf << "EOF"
KEYMAP=us
FONT=Lat2-Terminus16
EOF


确保重启后这个字体能真的加载出来，请务必在 chroot 里执行一下这个命令检查文件是否存在：
(lfs chroot) root:/usr/lib# ls /usr/share/consolefonts/Lat2-Terminus16.psfu.gz          # 下一行是回显
/usr/share/consolefonts/Lat2-Terminus16.psfu.gz  

# 试着手动加载它（即使在 chroot 里没效果，但能测试命令是否报错）
(lfs chroot) root:/usr/lib# setfont Lat2-Terminus16




# 配置系统区域设置            https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter09/locale.html
生成Locale（区域定义）
(lfs chroot) root:/usr/lib# localedef -i en_US -f UTF-8 en_US.UTF-8

创建配置文件（此时这里不要用中文，因为很有可能会出错）
(lfs chroot) root:/usr/lib# cat > /etc/locale.conf << "EOF"
LANG=en_US.UTF-8
EOF

# 查看当前生成的全部区域
(lfs chroot) root:/usr/lib# localectl list-locales          # 这个命令会报错，没影响
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down

注意：完全符合预期！在 chroot 环境中看到这个报错是绝对正常的，这恰恰证明你之前的操作没毛病。
1. 为什么会报错？
localectl、hostnamectl、systemctl 这些命令都是 systemd 的管理工具。它们的工作原理是：

命令执行后，会去寻找系统中的 PID 1（即 systemd 守护进程）
通过一个叫 D-Bus 的“总线”与 systemd 进行通讯
但在 chroot 里：
没有 PID 1：你当前环境的“老大”是你的宿主机内核，而不是 LFS 的 systemd
总线没开：LFS 的系统服务还没跑起来，通讯信道（D-Bus）当然是断开的

用最原始的底层命令来检查/验证 Locale 是否生成成功
(lfs chroot) root:/usr/lib# ls -F /usr/lib/locale
locale-archive
注意：
如看到 en_US.utf8 文件夹（或者一个巨大的 locale-archive 文件）：说明你之前的 localedef 命令已经成功把语言包“编译”进系统了
只要文件在：当你以后真正重启进入 LFS 时，systemd 就会识别到它们

(lfs chroot) root:/usr/lib# localedef --list-archive | grep en_US.utf8
en_US.utf8




# 创建 /etc/inputrc 文件
(lfs chroot) root:/usr/lib# cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8-bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF



# 创建 /etc/shells 文件
(lfs chroot) root:/usr/lib# cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF


(lfs chroot) root:/usr/lib# cd /

# Systemd 的使用和配置 （不需要执行）          https://www.linuxfromscratch.org/lfs/view/12.3-systemd/chapter09/systemd-custom.html
强烈建议跳过（不执行）
如果你执行了这一步：你的网卡会变回 eth0，那么你之前写的那个 10-eth-dhcp.network 文件（里面写的是 Name=ens33）就会失效，导致你进系统后没网
如果你不执行：一切保持原样，符合现代 Linux 的标准



```







## 使LFS系统可启动
```shell
现在是时候让 LFS 系统可启动了。本章将讨论如何创建启动/etc/fstab文件、为新的 LFS 系统构建内核，以及安装 GRUB 引导加载程序，以便在启动时可以选择 LFS 系统作为启动项。
(lfs chroot) root:/# blkid |grep sdb
/dev/sdb2: UUID="f1caaec8-12bc-4557-9366-82f995e79cd5" TYPE="swap" PARTUUID="bb7c0db5-7dd6-4b8c-a641-36fe0dc1ef13"
/dev/sdb3: UUID="a21cd4a8-f0f6-4d13-8c95-be53f4311b7c" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="87506661-b42c-4cdc-ad43-b9356544871d"
/dev/sdb1: PARTUUID="e56885bd-a29b-44c2-afd5-c4d38a88f1e3"

释义：
分区信息分析
/dev/sdb1: BIOS boot占位符，等着GRUB往里灌二进制代码
/dev/sdb2: 这是你的交换分区 (Swap)
/dev/sdb3：已经正确挂载在 /（在chroot环境下）


# 编写/etc/fstab
(lfs chroot) root:/# mkdir -pv /proc /sys /dev/pts /run /dev/shm

在chroot环境下，执行以下命令来创建这个至关重要的文件。为了系统的稳定性，我们直接使用
(lfs chroot) root:/# cat > /etc/fstab << "EOF"
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=a21cd4a8-f0f6-4d13-8c95-be53f4311b7c / ext4 defaults 1 1
UUID=f1caaec8-12bc-4557-9366-82f995e79cd5 swap swap pri=1 0 0

# Virtual file systems (standard for LFS)
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devshm         /dev/shm     tmpfs    nosuid,nodev        0     0
EOF

关键点检查
根分区挂载点: 注意第一行，UUID 对应的是你的 /dev/sdb3（即你编译LFS的地方），挂载点是 /
文件系统类型: 确认为 ext4
虚拟文件系统: /proc、/sys 等是 systemd 正常运行所必需的，请务必保留


(lfs chroot) root:/# ls -alh /etc/fstab 
-rw-r--r-- 1 root root 553 Apr 23 22:22 /etc/fstab

```




# 安装内核前有必要做个快照
```shell
(lfs chroot) root:/# exit
root@ub24-1:/mnt/lfs# 
umount -v $LFS/dev/pts
umount -v $LFS/dev
umount -v $LFS/run
umount -v $LFS/proc
umount -v $LFS/sys

由于之前之前执行了 swapon /dev/sdb2，虽然它不是直接挂载在 /mnt/lfs 上，但它是同一个磁盘设备，有时会产生关联影响
root@ub24-1:~# swapoff -v /dev/sdb2
root@ub24-1:~# umount -v $LFS

关闭宿主机 Ubuntu
root@ub24-1:~# poweroff



```











# 内核安装
```shell
# 重新连接后
rambo@ub24-1:~$ sudo su -

重新声明变量
root@ub24-1:~# export LFS=/mnt/lfs

重新启用 Swap
root@ub24-1:~# swapon -v /dev/sdb2

重新挂载虚拟文件系统
root@ub24-1:~# 
mount -v --bind /dev $LFS/dev
mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run

重新进入 Chroot
root@ub24-1:~# chroot "$LFS" /usr/bin/env -i HOME=/root TERM="$TERM" \
PS1='(lfs chroot) \u:\w\$ ' PATH=/usr/bin:/usr/sbin /bin/bash --login


它是整个LFS项目的“心脏”所在，如果不编译内核，现在做的只是硬盘上的“一堆文件”；编译完内核并配置好引导后，它才真正变成一个“操作系统”
内核源码通常在之前存放所有软件包源码的目录中。根据LFS的标准操作流程，需要在 chroot 环境中进行编译
(lfs chroot) root:/# cd sources/
(lfs chroot) root:/sources# tar xvf linux-6.13.4.tar.xz 
(lfs chroot) root:/sources# cd linux-6.13.4
(lfs chroot) root:/sources/linux-6.13.4# make mrproper


# 核心配置阶段 (make menuconfig)
内核配置中有个"依赖项陷阱"。在 menuconfig 中，如果一个选项的前提条件没有被满足，该选项就会被隐藏，即使你直接搜索能看到它，进入菜单后也是找不到的
Depends on: (它依赖哪些项)。如果某个依赖显示 [=n]，你就得先去把那个依赖项找出来开了，这一项才会出现

运行 make menuconfig 后，会弹出一个蓝底菜单。在 VMware 中，请务必确保以下选项被编译进内核（状态为 [*] 而不是 <M>）：
(lfs chroot) root:/sources/linux-6.13.4# make menuconfig
[*] (星号)：表示驱动直接编译进内核二进制文件（bzImage）。内核启动时直接就有这些功能
<M> (字母M)：表示驱动是独立文件。内核启动时需要去硬盘找这些文件

A. 必须的处理器与核心选项
Processor type and features ->
[*] EFI runtime service support


B. 关键驱动：VMware 硬盘驱动 (漏选则无法开机)
由于你的 LFS 在 /dev/sdb1 (SCSI 设备)，内核必须能认出 VMware 的虚拟硬盘控制器：

Device Drivers -> SCSI device support -> [*]
Device Drivers -> SCSI device support -> SCSI low-level drivers ->
  [*] LSI MPT Fusion SAS 2.0 Device Driver
  [*] VMware PVSCSI driver support (VMware 准虚拟化驱动)

Device Drivers -> Fusion MPT device support
[*] Fusion MPT ScsiHost drivers for SPI (必须勾选,针对VMware默认的LSI Logic平行/SAS控制器)

C. 文件系统 (漏选则无法挂载根分区)
File systems -> [*] The Extended 4 (ext4) filesystem

D. Systemd必须的选项
LFS-systemd 版本对内核有特殊要求，请检查：
General setup -> 
  [*] Control Group support
  [*] Namespaces support (容器化和 systemd 安全特性需要)

Device Drivers -> Generic Driver Options
  [*] Maintain a devtmpfs filesystem to mount at /dev (这个没选，开机必挂)
  [*] Automount devtmpfs at /dev, after the kernel mounted the rootfs

Systemd 对系统时钟有依赖，如果没选，启动时可能会报错
Device Drivers -> Real Time Clock -> [*] PC-style 'CMOS'



# 开始编译（使用-j参数利用所有CPU核心）
(lfs chroot) root:/sources/linux-6.13.4# make -j$(nproc)
注：核心越多，编译越快。如果只有1核，可能需要等半小时以上；如果是4核或更多，10分钟左右就能搞定

....
  ...
  ZOFFSET arch/x86/boot/zoffset.h
  OBJCOPY arch/x86/boot/vmlinux.bin
  AS      arch/x86/boot/header.o
  LD      arch/x86/boot/setup.elf
  OBJCOPY arch/x86/boot/setup.bin
  BUILD   arch/x86/boot/bzImage
Kernel: arch/x86/boot/bzImage is ready  (#1)


编译完成后，先安装模块（这会放到 /lib/modules 目录下
(lfs chroot) root:/sources/linux-6.13.4# make modules_install

手动安装内核镜像到 /boot
(lfs chroot) root:/sources/linux-6.13.4# cp -iv arch/x86/boot/bzImage  /boot/vmlinuz-6.13.4-lfs-12.3-systemd

安装 System.map（调试用）
(lfs chroot) root:/sources/linux-6.13.4# cp -iv System.map /boot/System.map-6.13.4

备份你的辛苦成果（下次编译时可以基于此配置）
(lfs chroot) root:/sources/linux-6.13.4# cp -iv .config /boot/config-6.13.4

安装 Linux 内核文档
(lfs chroot) root:/sources/linux-6.13.4# cp -r Documentation -T /usr/share/doc/linux-6.13.4





# 使用 GRUB 设置启动过程
这一步（10.4. 使用 GRUB 设置启动过程）是整个 LFS 实验的最后一道关卡。如果说内核是系统的“心脏”，那么 GRUB 就是“点火开关”
根据之前的 blkid 信息和编译的内核版本，我们需要在 chroot 环境中精准地完成以下操作：
核心概念：GRUB 的命名规则
GRUB 对硬盘的称呼和 Linux 不同：
Linux 里的 /dev/sda 或 /dev/sdb，在 GRUB 里叫 (hd0) 或 (hd1)
你的 LFS 在 /dev/sdb1，在 GRUB 看来通常是 (hd1,1)（第二块硬盘的第一个分区）


安装 GRUB 引导程序
既然你在 VMware 里，我们需要把 GRUB 的引导代码写进虚拟硬盘
如果是在物理机上双系统操作，请小心这一步，因为会影响到另一个系统。但在虚拟机里可放心执行
# 将 GRUB 安装到 LFS 所在的磁盘（根据你的 blkid，LFS 在 sdb）
(lfs chroot) root:/sources/linux-6.13.4# grub-install /dev/sdb
Installing for i386-pc platform.
Installation finished. No error reported.

# ======================================================================
注：如果出现报错就需要直接加 --force 参数，虽然它会报警，但在虚拟机这种单一、稳定的硬件环境下，blocklists 通常是能工作的
(lfs chroot) root:/sources/linux-6.13.4# grub-install /dev/sdb --force
Installing for i386-pc platform.
grub-install: warning: this GPT partition label contains no BIOS Boot Partition; embedding won't be possible.
grub-install: warning: Embedding is not possible.  GRUB can only be installed in this setup by using blocklists.  However, blocklists are UNRELIABLE and their use is discouraged..
Installation finished. No error reported.          # 已经成功
虽然 GRUB 依然在唠叨警告（Warning），但它已经成功地通过“强行挂载（blocklists）”的方式把引导代码塞进去了。在虚拟机环境里，这种方式其实非常稳定

# ======================================================================

# 最后的最后：确认配置文件
在重启之前，请务必最后一次确认你的 /boot/grub/grub.cfg 内容是否正确。这一步写错，开机就会进入黑乎乎的 grub> 命令行

自动生成和手动写grub.cfg的内容会有出入的区别下面有说明

# 自动生成grub.cfg
(lfs chroot) root:/sources/linux-6.13.4# grub-mkconfig -o /boot/grub/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.13.4-lfs-12.3-systemd
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done


(lfs chroot) root:/sources/linux-6.13.4# cat /boot/grub/grub.cfg
#
# DO NOT EDIT THIS FILE
#
# It is automatically generated by grub-mkconfig using templates
# from /etc/grub.d and settings from /etc/default/grub
#

### BEGIN /etc/grub.d/00_header ###
if [ -s $prefix/grubenv ]; then
  load_env
fi
if [ "${next_entry}" ] ; then
   set default="${next_entry}"
   set next_entry=
   save_env next_entry
   set boot_once=true
else
   set default="0"
fi

if [ x"${feature_menuentry_id}" = xy ]; then
  menuentry_id_option="--id"
else
  menuentry_id_option=""
fi

export menuentry_id_option

if [ "${prev_saved_entry}" ]; then
  set saved_entry="${prev_saved_entry}"
  save_env saved_entry
  set prev_saved_entry=
  save_env prev_saved_entry
  set boot_once=true
fi

function savedefault {
  if [ -z "${boot_once}" ]; then
    saved_entry="${chosen}"
    save_env saved_entry
  fi
}

function load_video {
  if [ x$feature_all_video_module = xy ]; then
    insmod all_video
  else
    insmod efi_gop
    insmod efi_uga
    insmod ieee1275_fb
    insmod vbe
    insmod vga
    insmod video_bochs
    insmod video_cirrus
  fi
}

if loadfont unicode ; then
  set gfxmode=auto
  load_video
  insmod gfxterm
fi
terminal_output gfxterm
if [ x$feature_timeout_style = xy ] ; then
  set timeout_style=menu
  set timeout=5
# Fallback normal timeout code in case the timeout_style feature is
# unavailable.
else
  set timeout=5
fi
### END /etc/grub.d/00_header ###

### BEGIN /etc/grub.d/10_linux ###
menuentry 'GNU/Linux' --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-a21cd4a8-f0f6-4d13-8c95-be53f4311b7c' {
	load_video
	insmod gzio
	insmod part_gpt
	insmod ext2
	set root='hd1,gpt3'
	if [ x$feature_platform_search_hint = xy ]; then
	  search --no-floppy --fs-uuid --set=root --hint-bios=hd1,gpt3 --hint-efi=hd1,gpt3 --hint-baremetal=ahci1,gpt3  a21cd4a8-f0f6-4d13-8c95-be53f4311b7c
	else
	  search --no-floppy --fs-uuid --set=root a21cd4a8-f0f6-4d13-8c95-be53f4311b7c
	fi
	echo	'Loading Linux 6.13.4-lfs-12.3-systemd ...'
	linux	/boot/vmlinuz-6.13.4-lfs-12.3-systemd root=/dev/sdb3 ro  
}
submenu 'Advanced options for GNU/Linux' $menuentry_id_option 'gnulinux-advanced-a21cd4a8-f0f6-4d13-8c95-be53f4311b7c' {
	menuentry 'GNU/Linux, with Linux 6.13.4-lfs-12.3-systemd' --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-6.13.4-lfs-12.3-systemd-advanced-a21cd4a8-f0f6-4d13-8c95-be53f4311b7c' {
		load_video
		insmod gzio
		insmod part_gpt
		insmod ext2
		set root='hd1,gpt3'
		if [ x$feature_platform_search_hint = xy ]; then
		  search --no-floppy --fs-uuid --set=root --hint-bios=hd1,gpt3 --hint-efi=hd1,gpt3 --hint-baremetal=ahci1,gpt3  a21cd4a8-f0f6-4d13-8c95-be53f4311b7c
		else
		  search --no-floppy --fs-uuid --set=root a21cd4a8-f0f6-4d13-8c95-be53f4311b7c
		fi
		echo	'Loading Linux 6.13.4-lfs-12.3-systemd ...'
		linux	/boot/vmlinuz-6.13.4-lfs-12.3-systemd root=/dev/sdb3 ro  
	}
	menuentry 'GNU/Linux, with Linux 6.13.4-lfs-12.3-systemd (recovery mode)' --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-6.13.4-lfs-12.3-systemd-recovery-a21cd4a8-f0f6-4d13-8c95-be53f4311b7c' {
		load_video
		insmod gzio
		insmod part_gpt
		insmod ext2
		set root='hd1,gpt3'
		if [ x$feature_platform_search_hint = xy ]; then
		  search --no-floppy --fs-uuid --set=root --hint-bios=hd1,gpt3 --hint-efi=hd1,gpt3 --hint-baremetal=ahci1,gpt3  a21cd4a8-f0f6-4d13-8c95-be53f4311b7c
		else
		  search --no-floppy --fs-uuid --set=root a21cd4a8-f0f6-4d13-8c95-be53f4311b7c
		fi
		echo	'Loading Linux 6.13.4-lfs-12.3-systemd ...'
		linux	/boot/vmlinuz-6.13.4-lfs-12.3-systemd root=/dev/sdb3 ro single 
	}
}

### END /etc/grub.d/10_linux ###

### BEGIN /etc/grub.d/20_linux_xen ###
### END /etc/grub.d/20_linux_xen ###

### BEGIN /etc/grub.d/25_bli ###
if [ "$grub_platform" = "efi" ]; then
  insmod bli
fi
### END /etc/grub.d/25_bli ###

### BEGIN /etc/grub.d/30_os-prober ###
### END /etc/grub.d/30_os-prober ###

### BEGIN /etc/grub.d/30_uefi-firmware ###
if [ "$grub_platform" = "efi" ]; then
	fwsetup --is-supported
	if [ "$?" = 0 ]; then
		menuentry 'UEFI Firmware Settings' $menuentry_id_option 'uefi-firmware' {
			fwsetup
		}
	fi
fi
### END /etc/grub.d/30_uefi-firmware ###

### BEGIN /etc/grub.d/40_custom ###
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.
### END /etc/grub.d/40_custom ###

### BEGIN /etc/grub.d/41_custom ###
if [ -f  ${config_directory}/custom.cfg ]; then
  source ${config_directory}/custom.cfg
elif [ -z "${config_directory}" -a -f  $prefix/custom.cfg ]; then
  source $prefix/custom.cfg
fi
### END /etc/grub.d/41_custom ###










# =======================================================================================
对于LFS这种单一系统的环境，手动写一个 grub.cfg 是最稳妥、最清晰的。在chroot中直接执行下面这段命令：              # 复制的时候不要带中文
(lfs chroot) root:/sources/linux-6.13.4# cat > /boot/grub/grub.cfg << "EOF"
# 开始GRUB引导配置
set default=0
set timeout=5

# 针对你的 GPT 分区表
insmod part_gpt
insmod ext2

# 设置根分区 (hd1,1) 代表第二块硬盘的第一个分区
set root=(hd1,1)

menuentry "GNU/Linux, Linux From Scratch 12.3-systemd" {
    linux /boot/vmlinuz-6.13.4-lfs-12.3-systemd root=UUID=4413c8fa-2a72-4948-9f48-c1ac8f4ea18f ro
}
EOF

注意：
手写grub.cfg用 insmod ext2 就可以，但用 insmod ext4 也可以
在 GRUB 的逻辑中，ext2 模块实际上是一个“全家桶”驱动

1. 为什么官方和教程通常写ext2？
GRUB 的 ext2.mod 驱动具有向下兼容性。它实际上支持 ext2、ext3 和 ext4 三种格式
在 GRUB 的早期开发中，这三种文件系统的磁盘结构非常相似，因此开发者将它们整合在了一个模块里。
即使你的分区是 ext4，加载 insmod ext2 也能正常读取其中的内核文件

2. 能写insmod ext4吗？
可以。 在现代版本的 GRUB 中，通常会提供一个指向 ext2 的别名，或者直接提供 ext4.mod。

如果你执行 insmod ext4，GRUB 也会明白你的意思
如果你去看 /boot/grub/i386-pc/ 目录，你可能会发现只有 ext2.mod，而没有单独的 ext4.mod。这是因为 ext2.mod 已经涵盖了一切
如果你想 100% 确定你的 LFS 环境中 GRUB 到底支持哪个名字，可以在 chroot 里看一眼：
(lfs chroot) root:/sources/linux-6.13.4# ls /boot/grub/i386-pc/ext*
/boot/grub/i386-pc/ext2.mod   /boot/grub/i386-pc/extcmd.mod

注：如果你只看到 ext2.mod，那么 grub.cfg 里必须写 insmod ext2。
如果你看到了 ext4.mod，那写哪个都行

💡 架构师的“避坑”建议
为了保证最大的兼容性，建议保留 insmod ext2
为什么？ 因为在 GRUB 启动的那个微秒级瞬间，它只需要最基本的读取能力来找到内核镜像。一旦内核接管系统，它会使用你在 make menuconfig 里亲自编译进去的那个真正的 ext4 驱动来挂载硬盘，那时候才真正发挥 ext4 的性能


# 区别
主要的不同点在于以下几个方面：
1. 复杂度与“冗余”代码
手动写的：只包含启动内核所必须的指令。我们直接指定了 root 分区、内核路径和 UUID。它像一张“直达车票”，简单明了
自动生成的：为了保证兼容性，它会加入大量的探测代码（如 insmod 各种模块、设置终端字体、加载视频模式、处理逻辑卷 LVM、处理加密盘等）。即使你没用到这些功能，它也会把代码塞进去，导致文件看起来非常臃肿

2. 搜索逻辑 (search vs set root)
手动写的：我们通常直接用 set root=(hd1,1)。这是硬编码，假设你的硬盘顺序永远不变
自动生成的：它会使用 search --no-floppy --fs-uuid --set=root ... 这种指令。它的逻辑是：“我不确定内核在哪块盘，但我会拿着 UUID 在所有硬盘里搜一遍，搜到了就把那块盘设为 root”。这在物理机多硬盘环境下更安全，但在 chroot 环境下有时会搜错

3. 环境依赖项
自动生成的：高度依赖宿主机（Ubuntu）的环境。因为你在 chroot 运行它，它可能会把宿主机的内核、微码（microcode）甚至一些 Ubuntu 特有的启动参数也抓取进来。这会导致生成的 grub.cfg 试图去加载一些 LFS 根本不存在的文件

为什么我建议你用手动写的？
在 LFS 构建阶段，“可控性”高于“自动化”。
排除干扰：如果自动生成的配置文件报错，你很难分辨是内核编译的问题，还是 grub-mkconfig 脚本写错的问题
路径纯净：手动写的路径（如 /boot/vmlinuz-...）是我们亲手创建的，绝对可靠
学习底层：手写一次 grub.cfg，你能彻底明白 GRUB 是如何交棒给 Kernel 的

💡 如何判断该用哪一个？
如果你追求一次点亮：使用手动写的版本。它最直接，不容易受 chroot 环境干扰
如果你以后想省事：等你的 LFS 成功启动进入系统后，再在 LFS 本机环境里运行 grub-mkconfig。那时候系统环境是真实的，生成的配置文件会更专业且符合自动化运维习惯

🏁 最后的确认
既然你已经对比了两者，建议你使用我之前提供给你的手动版本，只需确保：
vmlinuz 的版本号和你在 /boot 里看到的一字不差
UUID 是 /dev/sdb1 的那个

# =======================================================================================


```






# 退出 chroot并重启
```shell
在完成 LFS 所有的配置后，正确的“退出与重启”流程至关重要，因为这涉及到文件系统缓存的刷新和虚拟文件系统的干净卸载
第一步：清理并退出 chroot
首先，确保你当前不在任何源码目录（如 /sources/linux-6.13.4）中，先回到根目录，然后退出。
(lfs chroot) root:/sources/linux-6.13.4# cd /
(lfs chroot) root:/# logout

第二步：卸载虚拟文件系统（核心步骤）
这一步是为了断开宿主机（Ubuntu）与 LFS 分区之间的绑定。必须在宿主机环境下执行（即你退出 chroot 后的那个终端）。
# 按照挂载的逆序进行卸载
root@ub24-1:/mnt/lfs# 
umount -v $LFS/dev/pts
umount -v $LFS/dev
umount -v $LFS/run
umount -v $LFS/proc
umount -v $LFS/sys
注意：如果提示 target is busy，说明有进程还在使用这些目录。你可以尝试使用 umount -l $LFS/dev（懒惰卸载）或者确认所有 chroot 终端已关闭


第三步：卸载 LFS 主分区
root@ub24-1:/mnt/lfs# cd /           # 必须离开/mnt/lfs

这是为了确保所有写入的数据（包括你刚写的 grub.cfg 和内核）都真正从内存同步到了硬盘。
root@ub24-1:/mnt/lfs# umount -v $LFS


# 关机，把第一启动项设置成从60G的磁盘启动
root@ub24-1:~# poweroff


# ==========================================================
第四步：重启系统
现在可以安全地重启你的虚拟机了
root@ub24-1:/# reboot

⚠️ 重启时的关键操作（针对 VMware 用户）
这是很多 LFS 玩家"翻车"的地方，请务必留意：
设置第一启动项为第二块硬盘
进入GRUB：如果你看到一个蓝色的菜单，上面写着 GNU/Linux, Linux From Scratch 12.3-systemd，那么恭喜你，你已经成功了一半！

💡 如果启动后卡住了怎么办？
如果卡在 "Kernel Panic - not syncing: VFS: Unable to mount root fs..."：说明内核没认出硬盘（驱动没编进内核）或者 fstab/grub.cfg 里的 UUID 写错了。
如果看到 systemd 的绿色 [ OK ] 滚屏：说明你赢了！

# ==========================================================
```
![image](https://github.com/Coding-01/LFS12.3-systemd-Build/blob/main/images/1.png)
![image](https://github.com/Coding-01/LFS12.3-systemd-Build/blob/main/images/2.png)
![image](https://github.com/Coding-01/LFS12.3-systemd-Build/blob/main/images/3.png)
![image](https://github.com/Coding-01/LFS12.3-systemd-Build/blob/main/images/4.png)
```shell
root / A星
zhangsan / 6a

```
![image](https://github.com/Coding-01/LFS12.3-systemd-Build/blob/main/images/5.png)

