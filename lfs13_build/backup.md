[toc]

# 前奏
```shell
8vCPU
16G Mem
80G Disk(SCSI): Ubuntu24.04.1 LTS (GNU/Linux 6.8.0-51-generic x86_64)
60G Disk(SCSI): LFS
172.16.186.128/24


本文档仅适用于lfs13.0版本的systemd版本



1、LFS的包是有严格依赖顺序的。如果你脚本里调整了顺序，哪怕是一个很小的库，后面都会崩
2、虽然-j4或-j8很快，但在编译GCC或Glibc这种核心包时，如果报错了，并行编译的日志是乱跳的，你根本看不出哪里错了。重头来时，建议关键包先不用-j参数
3、在LFS中，切换到lfs用户就像是从"上帝模式"进入"车间模式",切的时间点在创建完 lfs 用户并配置好环境(.bash_profile 和 .bashrc)之后立即切换



# 啥时候加执行make时加-j参数?
A. 绝对禁止加-j (或官方明确警告)
Glibc (测试阶段)： 编译 Glibc 时可以加 -j，但如果你运行 make check（测试），严禁使用 -j。并发测试会导致大量虚假失败，让你误以为系统坏了
GCC (某些阶段)： 在第 5 章和第 6 章构建临时工具链时，如果你的宿主机性能极强但内存不足，-j 可能会导致内存溢出（OOM）崩溃
Perl： Perl 的 Configure 脚本和部分安装逻辑对并发支持并不完美。虽然现代版本有所改进，但作为底层核心，建议保守使用或仅用低并发（如 -j2）
Automake / Autoconf： 它们的测试套件（Test Suites）对并发非常敏感，必须单线程运行测试。

B. 推荐开启-j(提升效率巨大)
Binutils / GCC / Libtool： 这些包源码巨大，单核编译会让你等到怀疑人生。一定要开启 -j$(nproc)
Linux Kernel（内核）： 内核对并发的支持是完美的，你有多少核就开多少


```





# 磁盘分区
```shell
rambo@ub24-1:~$ sudo su - 
[sudo] password for rambo: 

root@ub24-1:~# fdisk -l | grep "Disk /dev/sd"
Disk /dev/sda: 80 GiB, 85899345920 bytes, 167772160 sectors            # 系统盘
Disk /dev/sdb: 60 GiB, 64424509440 bytes, 125829120 sectors            # 做LFS用

root@ub24-1:~# fdisk /dev/sdb

Welcome to fdisk (util-linux 2.39.3).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table.
Created a new DOS (MBR) disklabel with disk identifier 0x946e2967.

Command (m for help): g
Created a new GPT disklabel (GUID: 93621A1E-CFA1-40FD-8DBD-B029932F42B7).

Command (m for help): n
Partition number (1-128, default 1): 
First sector (2048-125829086, default 2048): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-125829086, default 125827071): +5M

Created a new partition 1 of type 'Linux filesystem' and of size 5 MiB.

Command (m for help): t
Selected partition 1
Partition type or alias (type L to list all): 4                                 # 这是BIOS boot，专门给GRUB用的
Changed type of partition 'Linux filesystem' to 'BIOS boot'.

Command (m for help): n
Partition number (2-128, default 2): 
First sector (12288-125829086, default 12288): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (12288-125829086, default 125827071): +6G      # 作为Swap

Created a new partition 2 of type 'Linux filesystem' and of size 6 GiB.

Command (m for help): t
Partition number (1,2, default 2): 
Partition type or alias (type L to list all): 19                                             # Linux swap

Changed type of partition 'Linux filesystem' to 'Linux swap'.

Command (m for help): n
Partition number (3-128, default 3): 
First sector (12595200-125829086, default 12595200): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (12595200-125829086, default 125827071): 

Created a new partition 3 of type 'Linux filesystem' and of size 54 GiB.                     # 剩下的全部给根

Command (m for help): w


root@ub24-1:~# mkfs.ext4 /dev/sdb3

# 初始化Swap(sdb2)
root@ub24-1:~$ mkswap /dev/sdb2

# 启用Swap(这样编译时内存更充裕)
root@ub24-1:~$ swapon -v /dev/sdb2


```



# [构建准备](https://linuxfromscratch.org/lfs/view/stable-systemd/part2.html)
## [准备主机系统](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter02/chapter02.html)
```shell
# 更新源
root@ub24-1:~$ cat /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: noble noble-updates noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
 
root@ub24-1:~$ apt update
# 安装缺失的核心编译工具
root@ub24-1:~$ apt install -y build-essential bison gawk m4 make texinfo
# 将 sh 修改为指向 bash (选择 "No" 或手动链接)
root@ub24-1:~$ ln -sf /bin/bash /bin/sh
# 验证 yacc 软链接
root@ub24-1:~$ ln -sf /usr/bin/bison /usr/bin/yacc
 


# 官方提供的检查脚本
root@ub24-1:~$ cat > version-check.sh << "EOF"
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
ver_check GCC            gcc      5.4
ver_check "GCC (C++)"    g++      5.4
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


root@ub24-1:~$ bash version-check.sh


```




# 设置$LFS变量和Umask
```shell
root@ub24-1:~# mkdir /mnt/lfs
root@ub24-1:~# export LFS=/mnt/lfs
root@ub24-1:~# umask 022
root@ub24-1:~# echo $LFS
/mnt/lfs
root@ub24-1:~# umask
0022
 
 
root@ub24-1:~# lsblk -f /dev/sdb
NAME   FSTYPE FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sdb                                                                           
├─sdb1                                                                        
├─sdb2 swap   1           c5cc11f1-b799-4a1b-8753-ba875c179dc8                [SWAP]
└─sdb3 ext4   1.0         dd9c60f6-dff7-43c0-a91d-c6776f586015           
        
root@ub24-1:~# echo 'UUID=dd9c60f6-dff7-43c0-a91d-c6776f586015   /mnt/lfs  ext4  defaults 0 0' | tee -a /etc/fstab 
root@ub24-1:~# systemctl daemon-reload
root@ub24-1:~# mount -a
root@ub24-1:~# df -Th /mnt/lfs/
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/sdb3      ext4   53G   24K   51G   1% /mnt/lfs
 
将$LFS目录 (即为LFS系统新创建的文件系统的根目录) 的所有者设为root，访问权限设为755，以防个别宿主发行版中mkfs被配置为使用与此不同的默认值
root@ub24-1:~$ chown root:root $LFS && sudo chmod 755 $LFS


```




# [软件包和补丁](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter03/introduction.html)
```shell
root@ub24-1:~$ mkdir $LFS/sources && chmod  a+wt $LFS/sources && cd $LFS/sources/
root@ub24-1:/mnt/lfs/sources# 
 
# ================== 这部分不在官方文档中 ================================
# 安装sshd所需
root@ub24-1:/mnt/lfs/sources$ wget https://mirrors.aliyun.com/openssh/portable/openssh-10.1p1.tar.gz \
https://www.thrysoee.dk/editline/libedit-20251016-3.1.tar.gz

# 移植pacman所需
root@ub24-1:/mnt/lfs/sources$ wget \
https://curl.se/download/curl-8.20.0.tar.gz \
https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz \
https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.gz \
https://www.gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2 \
https://www.gnupg.org/ftp/gcrypt/libksba/libksba-1.7.0.tar.bz2 \
https://www.gnupg.org/ftp/gcrypt/gnupg/gnupg-w32-2.5.19_20260424.tar.xz \
https://gnupg.org/ftp/gcrypt/npth/npth-1.7.tar.bz2 \
https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.gz \
https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.0.tar.bz2 \
https://ftp.gnu.org/gnu/wget/wget2-2.2.1.tar.gz \
https://libarchive.org/downloads/libarchive-3.8.7.tar.xz \
https://gnupg.org/ftp/gcrypt/gpgme/gpgme-2.0.1.tar.bz2 \
https://github.com/lfs-book/make-ca/archive/refs/tags/v1.16.1.tar.gz \
https://github.com/p11-glue/p11-kit/releases/download/0.26.2/p11-kit-0.26.2.tar.xz \
https://gitlab.archlinux.org/pacman/pacman/-/archive/v7.1.0/pacman-v7.1.0.tar.gz \
https://github.com/pciutils/pciutils/releases/download/v3.15.0/pciutils-3.15.0.tar.gz \
https://github.com/libusb/libusb/releases/download/v1.0.29/libusb-1.0.29.tar.bz2 \
https://github.com/gregkh/usbutils/archive/refs/tags/v019.tar.gz

# 其他所需
root@ub24-1:/mnt/lfs/sources$ wget \
https://git.kernel.org/pub/scm/linux/kernel/git/dhowells/keyutils.git/snapshot/keyutils-1.6.3.tar.gz \
https://github.com/vim/vim/archive/refs/tags/v9.2.0488.tar.gz

注意：
1. make-ca的1.16.1的包有时会下不下来, 无比确保它大小不为0,如果不行就从网页端下载
2. 如果需要创建好的LFS有更多的功能，需要单独下载并安装包，这里就只做备用和测试
openssh-10.1p1.tar.gz中的p1代表Portable，这是 Linux 系统专用的版本

# =====================================================================


root@ub24-1:/mnt/lfs/sources# wget https://linuxfromscratch.org/lfs/view/stable-systemd/wget-list-systemd \
https://linuxfromscratch.org/lfs/view/stable-systemd/md5sums
 
root@ub24-1:/mnt/lfs/sources# wget --input-file=wget-list-systemd --continue --directory-prefix=$LFS/sources
# 检查所有软件包的正确性
root@ub24-1:/mnt/lfs/sources$ pushd $LFS/sources; md5sum -c md5sums; popd
注意：可能出现报错，如出现包没有的情况则需要执行以下命令
root@ub24-1:/mnt/lfs/sources$ wget -nc -i wget-list-systemd -P $LFS/sources          # 如还有No such file or directory则需要再次执行该命令，实在下载异常就单独找找
 
官方提供的所有包下载地址：https://linuxfromscratch.org/lfs/view/stable-systemd/chapter03/packages.html
官方提供的补丁地址：https://www.linuxfromscratch.org/lfs/view/stable/chapter03/patches.html
 
 
# 再来检查所有软件包的正确性
root@ub24-1:/mnt/lfs/sources$ pushd $LFS/sources; md5sum -c md5sums; popd
....
  ....
expect-5.45.4-gcc15-1.patch: OK
glibc-fhs-1.patch: OK
kbd-2.9.0-backspace-1.patch: OK
/mnt/lfs/sources
 
注意：所有文件的属主/组应该是root:root


最后准备工作
# 在 LFS 文件系统中创建有限目录布局
root@ub24-1:/mnt/lfs/sources# mkdir -pv $LFS/{etc,var}  $LFS/usr/{bin,lib,sbin}  
 
root@ub24-1:/mnt/lfs/sources# for i in bin lib sbin; do
  ln -sv usr/$i $LFS/$i
done
 
root@ub24-1:/mnt/lfs/sources# case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac
 
# 交叉编译器将安装在一个特殊的目录中，以与其他程序隔离
root@ub24-1:/mnt/lfs/sources# mkdir -pv $LFS/tools
 
 
# 添加LFS用户
root@ub24-1:/mnt/lfs/sources# groupadd lfs
root@ub24-1:/mnt/lfs/sources# useradd -s /bin/bash -g lfs -m -k /dev/null lfs
root@ub24-1:/mnt/lfs/sources# passwd lfs
将lfs设置为所有者，授予 lfs 对 $LFS 下所有目录的完全访问权限：
root@ub24-1:/mnt/lfs/sources# chown -v lfs $LFS/{usr{,/*},var,etc,tools}
root@ub24-1:/mnt/lfs/sources# case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac
 



root@ub24-1:/mnt/lfs/sources# chown lfs:lfs $LFS/sources/*
必须su - lfs。进场之后，哪怕遇到权限报错，也别轻易用 sudo，而是去检查为什么lfs用户没权限

root@ub24-1:/mnt/lfs/sources# su - lfs


 
 
# 设置环境
lfs@ub24-1:~$ cd /mnt/lfs/sources/
lfs@ub24-1:/mnt/lfs/sources$ cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
 
lfs@ub24-1:/mnt/lfs/sources$ cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF
 
 
lfs@ub24-1:/mnt/lfs/sources$ source ~/.bash_profile             # 必须是以下输出
 
lfs@ub24-1:/mnt/lfs/sources$ echo $LFS
/mnt/lfs
lfs@ub24-1:/mnt/lfs/sources$ echo $LC_ALL
POSIX
lfs@ub24-1:/mnt/lfs/sources$ echo $PATH
/mnt/lfs/tools/bin:/usr/bin
 


```






# [构建LFS跨工具链和临时工具](https://linuxfromscratch.org/lfs/view/stable-systemd/part3.html)
## 编译交叉工具链(下面方式二选一)
### 脚本代替手动执行
```shell
lfs@ub24-1:/mnt/lfs/sources$ vim compiling_a_cross-toolchain.sh
#!/bin/bash
set -eux
# Binutils-2.46.0 - 第1遍
tar xvf binutils-2.46.0.tar.xz
cd binutils-2.46.0
mkdir build && cd build
../configure --prefix=$LFS/tools \
 --with-sysroot=$LFS \
 --target=$LFS_TGT   \
 --disable-nls       \
 --enable-gprofng=no \
 --disable-werror    \
 --enable-new-dtags  \
 --enable-default-hash-style=gnu
make -j2 && make install
cd ../.. && rm -rf binutils-2.46.0

sleep 5

# GCC-15.2.0 - 第1遍
tar xvf gcc-15.2.0.tar.xz
cd gcc-15.2.0
tar -xf ../mpfr-4.2.2.tar.xz && mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz  && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac
mkdir build && cd build
../configure \
--target=$LFS_TGT         \
--prefix=$LFS/tools       \
--with-glibc-version=2.43 \
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
make -j2 && make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
cd .. && rm -rf gcc-15.2.0


sleep 5


# Linux-6.18.10 API 头文件
tar xvf linux-6.18.10.tar.xz
cd linux-6.18.10
make mrproper && make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd .. && rm -rf linux-6.18.10


sleep 5


# Glibc-2.43
tar xvf glibc-2.43.tar.xz
cd glibc-2.43
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac
patch -Np1 -i ../glibc-fhs-1.patch
mkdir build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=4.19               \
      --with-headers=$LFS/usr/include    \
      --disable-nls                      \
      libc_cv_slibdir=/usr/lib
make -j2 && make DESTDIR=$LFS install
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
cd ../.. && rm -rf glibc-2.43


sleep 5

# Libstdc++ from GCC-15.2.0
tar xvf gcc-15.2.0.tar.xz
cd gcc-15.2.0
mkdir build && cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0
make -j2 && make DESTDIR=$LFS install
ln -sv libstdc++.la $LFS/usr/lib/libstdc++.la
# ==================================================
# 这里可能会报一个这样的错，不影响，不用理会
# make[1]: Leaving directory '/mnt/lfs/sources/gcc-15.2.0/build'
# + ln -sv libstdc++.la /mnt/lfs/usr/lib/libstdc++.la
# ln: failed to create symbolic link '/mnt/lfs/usr/lib/libstdc++.la': File exists
# ==================================================

cd ../.. && rm -rf gcc-15.2.0



已验证，没问题...

```





### 手动执行每一步
```
Binutils、GCC、Glibc（被称为“三剑客”），这三个包决定了你工具链的生死，一定要盯着手敲 且 绝对不能再用 sudo 或回到 root 和使用-j参数，make时要看结果

# Binutils-2.46.0 - 第1遍
lfs@ub24-1:/mnt/lfs/sources$ tar xvf binutils-2.46.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd binutils-2.46.0
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ ../configure --prefix=$LFS/tools \
 --with-sysroot=$LFS \
 --target=$LFS_TGT   \
 --disable-nls       \
 --enable-gprofng=no \
 --disable-werror    \
 --enable-new-dtags  \
 --enable-default-hash-style=gnu
 
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ make && make install                # Binutils、GCC、Glibc不要加-j参数
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ cd ../.. && rm -rf binutils-2.46.0
 


# GCC-15.2.0 - 第一遍
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gcc-15.2.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd gcc-15.2.0
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ 
tar -xf ../mpfr-4.2.2.tar.xz && mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz  && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ../configure \
--target=$LFS_TGT         \
--prefix=$LFS/tools       \
--with-glibc-version=2.43 \
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
 
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ make && make install                 # Binutils、GCC、Glibc不要加-j参数
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ cd ..
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ cd .. && rm -rf gcc-15.2.0
 


# Linux-6.18.10 API 头文件
lfs@ub24-1:/mnt/lfs/sources$ tar xvf linux-6.18.10.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd linux-6.18.10
lfs@ub24-1:/mnt/lfs/sources/linux-6.18.10$ make mrproper && make headers
lfs@ub24-1:/mnt/lfs/sources/linux-6.18.10$ 
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include  $LFS/usr
 
lfs@ub24-1:/mnt/lfs/sources/linux-6.18.10$ cd .. && rm -rf linux-6.18.10




# Glibc-2.43
lfs@ub24-1:/mnt/lfs/sources$ tar xvf glibc-2.43.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd glibc-2.43
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43$ case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac
 
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43$ patch -Np1 -i ../glibc-fhs-1.patch
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ echo "rootsbindir=/usr/sbin" > configparms
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ ../configure \
--prefix=/usr                      \
--host=$LFS_TGT                    \
--build=$(../scripts/config.guess) \
--disable-nscd                     \
libc_cv_slibdir=/usr/lib           \
--enable-kernel=5.4
 
 
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ make && make DESTDIR=$LFS install                 # Binutils、GCC、Glibc不要加-j参数
 
修复ldd脚本 中指向可执行加载器的硬编码路径：
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
 
交叉编译工具链已经搭建完成，接下来需要确保编译和链接功能能够按预期运行
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ echo 'int main(){}' | $LFS_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ readelf -l a.out | grep ': /lib'
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]            # 这一行是输出
 
确保使用正确的启动文件：
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" dummy.log       # 以下3行是输出
/mnt/lfs/lib/../lib/Scrt1.o succeeded
/mnt/lfs/lib/../lib/crti.o succeeded
/mnt/lfs/lib/../lib/crtn.o succeeded
# 验证编译器是否正在查找正确的头文件
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ grep -B3 "^ $LFS/usr/include" dummy.log
#include <...> search starts here:
 /mnt/lfs/tools/lib/gcc/x86_64-lfs-linux-gnu/15.2.0/include
 /mnt/lfs/tools/lib/gcc/x86_64-lfs-linux-gnu/15.2.0/include-fixed
 /mnt/lfs/usr/include
# 验证新链接器是否使用了正确的搜索路径
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'        # 该行是命令
SEARCH_DIR("=/mnt/lfs/tools/x86_64-lfs-linux-gnu/lib64")
SEARCH_DIR("=/usr/local/lib64")
SEARCH_DIR("=/lib64")
SEARCH_DIR("=/usr/lib64")
SEARCH_DIR("=/mnt/lfs/tools/x86_64-lfs-linux-gnu/lib")
SEARCH_DIR("=/usr/local/lib")
SEARCH_DIR("=/lib")
SEARCH_DIR("=/usr/lib");
# 确保使用的是正确的libc库
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ grep "/lib.*/libc.so.6 " dummy.log
attempt to open /mnt/lfs/usr/lib/libc.so.6 succeeded
 
确保 GCC 使用的是正确的动态链接器：
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ grep found dummy.log
found ld-linux-x86-64.so.2 at /mnt/lfs/usr/lib/ld-linux-x86-64.so.2        # 这行是回显
 
如果输出结果与上述所示不符，或者根本没有收到输出，则说明出现了严重问题。请仔细检查并重新执行所有步骤，找出问题所在并加以解决。所有问题都必须在继续操作之前解决
 
一切运行正常后，清理测试文件：
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ rm -v a.out dummy.log
 
 
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ cd ../.. && rm -rf glibc-2.43



# 来自 GCC-15.2.0 的 Libstdc++
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gcc-15.2.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd gcc-15.2.0
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ../libstdc++-v3/configure \
--host=$LFS_TGT            \
--build=$(../config.guess) \
--prefix=/usr              \
--disable-multilib         \
--disable-nls              \
--disable-libstdcxx-pch    \
--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ make && make DESTDIR=$LFS install                 # Binutils、GCC、Glibc不要加-j参数
删除 libtool 归档文件，因为它们对交叉编译有害：
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ cd ../.. && rm -rf gcc-15.2.0
 

```






# [交叉编译临时工具](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter06/introduction.html)(下面方式二选一)

## 脚本代替手动执行
```shell
lfs@ub24-1:/mnt/lfs/sources$ vim cross_compiling_temporary_tools.sh
#!/bin/bash
set -eux

# M4-1.4.21
tar xvf m4-1.4.21.tar.xz
cd m4-1.4.21
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf m4-1.4.21

sleep 3

# Ncurses-6.6
tar xvf ncurses-6.6.tar.gz
cd ncurses-6.6
mkdir build
pushd build
  ../configure --prefix=$LFS/tools AWK=gawk
  make -C include
  make -C progs tic
  install progs/tic $LFS/tools/bin
popd
sleep 3
./configure --prefix=/usr                \
--host=$LFS_TGT              \
--build=$(./config.guess)    \
--mandir=/usr/share/man      \
--with-manpage-format=normal \
--with-shared                \
--without-normal             \
--with-cxx-shared            \
--without-debug              \
--without-ada                \
--disable-stripping          \
AWK=gawk

sleep 3

make -j2 && make DESTDIR=$LFS install
ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
sed -e 's/^#if.*XOPEN.*$/#if 1/'  -i $LFS/usr/include/curses.h
cd .. && rm -rf ncurses-6.6

sleep 3

# Bash-5.3
tar xvf bash-5.3.tar.gz
cd bash-5.3
./configure --prefix=/usr                      \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT                    \
            --without-bash-malloc              \
            bash_cv_strtold_broken=no
make -j2 && make DESTDIR=$LFS install
ln -sv bash $LFS/bin/sh
cd .. && rm -rf bash-5.3

sleep 3

# Coreutils-9.10
tar xvf coreutils-9.10.tar.xz
cd coreutils-9.10
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
make -j2 && make DESTDIR=$LFS install
mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
cd .. && rm -rf coreutils-9.10

sleep 3

# Diffutils-3.12
tar xvf diffutils-3.12.tar.xz
cd diffutils-3.12
gl_cv_func_getopt_gnu=yes gl_cv_func_strcasecmp_works=yes ./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess)
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf diffutils-3.12

sleep 3

# File-5.46
tar xvf file-5.46.tar.gz
cd file-5.46
mkdir build
pushd build
  ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib
  make
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file && make DESTDIR=$LFS install
rm -v $LFS/usr/lib/libmagic.la
cd .. && rm -rf file-5.46

sleep 3

# Findutils-4.10.0
tar xvf findutils-4.10.0.tar.xz
cd findutils-4.10.0
./configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT                 \
            --build=$(build-aux/config.guess)
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf findutils-4.10.0

sleep 3

# Gawk-5.3.2
tar xvf gawk-5.3.2.tar.xz
cd gawk-5.3.2
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf gawk-5.3.2

sleep 3

# Grep-3.12
tar xvf grep-3.12.tar.xz
cd grep-3.12
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf grep-3.12

sleep 3

# Gzip-1.14
tar xvf gzip-1.14.tar.xz
cd gzip-1.14
./configure --prefix=/usr --host=$LFS_TGT
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf gzip-1.14

sleep 3

# Make-4.4.1
tar xvf make-4.4.1.tar.gz
cd make-4.4.1
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess) \
            --without-guile
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf make-4.4.1

sleep 3

# Patch-2.8
tar xvf patch-2.8.tar.xz
cd patch-2.8
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf patch-2.8

sleep 3

# Sed-4.9
tar xvf sed-4.9.tar.xz
cd sed-4.9
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf sed-4.9

sleep 3

# Tar-1.35
tar xvf tar-1.35.tar.xz
cd tar-1.35
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess)
make -j2 && make DESTDIR=$LFS install
cd .. && rm -rf tar-1.35

sleep 3

# Xz-5.8.2
tar xvf xz-5.8.2.tar.xz
cd xz-5.8.2
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.8.2
make -j2 && make DESTDIR=$LFS install
rm -v $LFS/usr/lib/liblzma.la
cd .. && rm -rf xz-5.8.2

sleep 3

# Binutils-2.46.0 - 第2遍
tar xvf binutils-2.46.0.tar.xz
cd binutils-2.46.0
sed '6009s/$add_dir//' -i ltmain.sh
mkdir build && cd build
../configure \
    --prefix=/usr              \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --disable-nls              \
    --enable-shared            \
    --enable-gprofng=no        \
    --disable-werror           \
    --enable-64-bit-bfd        \
    --enable-new-dtags         \
    --enable-default-hash-style=gnu
make -j2 && make DESTDIR=$LFS install
rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
cd ../.. && rm -rf binutils-2.46.0

sleep 3

# GCC-15.2.0 - 第2遍
tar xvf gcc-15.2.0.tar.xz
cd gcc-15.2.0
tar -xf ../mpfr-4.2.2.tar.xz && mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz  && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac
sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
mkdir build && cd build
../configure                                       \
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
    --disable-libssp                               \
    --disable-libvtv                               \
    --enable-languages=c,c++

sleep 3

make -j2 && make DESTDIR=$LFS install
ln -sv gcc $LFS/usr/bin/cc
cd ../.. && rm -rf gcc-15.2.0





lfs@ub24-1:/mnt/lfs/sources$ bash cross_compiling_temporary_tools.sh



已操作完，没问题


```












## 手动执行每一步
```shell
# M4-1.4.21
lfs@ub24-1:/mnt/lfs/sources$ tar xvf m4-1.4.21.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd m4-1.4.21
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.21$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.21$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.21$ cd .. && rm -rf m4-1.4.21
 
# Ncurses-6.6
lfs@ub24-1:/mnt/lfs/sources$ tar zxvf ncurses-6.6.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd ncurses-6.6
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ mkdir build
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ pushd build
  ../configure --prefix=$LFS/tools AWK=gawk
  make -C include
  make -C progs tic
  install progs/tic $LFS/tools/bin
popd
 
 
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ ./configure --prefix=/usr  \
--host=$LFS_TGT              \
--build=$(./config.guess)    \
--mandir=/usr/share/man      \
--with-manpage-format=normal \
--with-shared                \
--without-normal             \
--with-cxx-shared            \
--without-debug              \
--without-ada                \
--disable-stripping          \
AWK=gawk
 
 
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ sed -e 's/^#if.*XOPEN.*$/#if 1/'  -i $LFS/usr/include/curses.h
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ cd .. && rm -rf ncurses-6.6



# Bash-5.3
lfs@ub24-1:/mnt/lfs/sources$ tar zxvf bash-5.3.tar.gz 
lfs@ub24-1:/mnt/lfs/sources$ cd bash-5.3
lfs@ub24-1:/mnt/lfs/sources/bash-5.3$ ./configure --prefix=/usr --build=$(sh support/config.guess) --host=$LFS_TGT --without-bash-malloc
lfs@ub24-1:/mnt/lfs/sources/bash-5.3$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/bash-5.3$ ln -sv bash $LFS/bin/sh
lfs@ub24-1:/mnt/lfs/sources/bash-5.3$ cd .. && rm -rf bash-5.3
 
 
# Coreutils-9.10
lfs@ub24-1:/mnt/lfs/sources$ tar xvf coreutils-9.10.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd coreutils-9.10
lfs@ub24-1:/mnt/lfs/sources/coreutils-9.10$ ./configure --prefix=/usr  \
--host=$LFS_TGT                   \
--build=$(build-aux/config.guess) \
--enable-install-program=hostname \
--enable-no-install-program=kill,uptime
 
lfs@ub24-1:/mnt/lfs/sources/coreutils-9.10$ make -j$(nproc) && make DESTDIR=$LFS install
将程序移动到其最终预期位置。虽然在这个临时环境中并非必要，但我们必须这样做，因为有些程序将可执行文件的位置硬编码在代码中：
mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
 
lfs@ub24-1:/mnt/lfs/sources/coreutils-9.10$ cd .. && rm -rf coreutils-9.10


# Diffutils-3.12
lfs@ub24-1:/mnt/lfs/sources$ tar xvf diffutils-3.12.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd diffutils-3.12
lfs@ub24-1:/mnt/lfs/sources/diffutils-3.12$ ./configure --prefix=/usr \
--host=$LFS_TGT  gl_cv_func_strcasecmp_works=y  --build=$(./build-aux/config.guess)
 
lfs@ub24-1:/mnt/lfs/sources/diffutils-3.12$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/diffutils-3.12$ cd .. && rm -rf diffutils-3.12


# File-5.46
lfs@ub24-1:/mnt/lfs/sources$ tar zxvf file-5.46.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd file-5.46
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ mkdir build
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ pushd build
  ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
  make -j$(nproc)
popd
 
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ make FILE_COMPILE=$(pwd)/build/src/file && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ rm -v $LFS/usr/lib/libmagic.la
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ cd .. && rm -rf file-5.46
 
 
# Findutils-4.10.0
lfs@ub24-1:/mnt/lfs/sources$ tar xvf findutils-4.10.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd findutils-4.10.0
lfs@ub24-1:/mnt/lfs/sources/findutils-4.10.0$ ./configure --prefix=/usr  \
--localstatedir=/var/lib/locate \
--host=$LFS_TGT                 \
--build=$(build-aux/config.guess)
 
lfs@ub24-1:/mnt/lfs/sources/findutils-4.10.0$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/findutils-4.10.0$ cd .. && rm -rf findutils-4.10.0
 
 
# Gawk-5.3.2
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gawk-5.3.2.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd gawk-5.3.2
lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.2$ sed -i 's/extras//' Makefile.in
lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.2$ ./configure --prefix=/usr  --host=$LFS_TGT  --build=$(build-aux/config.guess) && \
make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.2$ cd .. && rm -rf gawk-5.3.2
 
# Grep-3.12
lfs@ub24-1:/mnt/lfs/sources$ tar xvf grep-3.12.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd grep-3.12
lfs@ub24-1:/mnt/lfs/sources/grep-3.12$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess) && \
make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/grep-3.12$ cd .. && rm -rf grep-3.12


# Gzip-1.14
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gzip-1.14.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd gzip-1.14
lfs@ub24-1:/mnt/lfs/sources/gzip-1.14$ ./configure --prefix=/usr --host=$LFS_TGT && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/gzip-1.14$ cd .. && rm -rf gzip-1.14
 
# Make-4.4.1
lfs@ub24-1:/mnt/lfs/sources$ tar -zxvf make-4.4.1.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd make-4.4.1
lfs@ub24-1:/mnt/lfs/sources/make-4.4.1$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/make-4.4.1$ cd .. && rm -rf make-4.4.1
 
# Patch-2.8
lfs@ub24-1:/mnt/lfs/sources$ tar xvf patch-2.8.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd patch-2.8
lfs@ub24-1:/mnt/lfs/sources/patch-2.8$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/patch-2.8$ cd .. && rm -rf patch-2.8
 
# Sed-4.9
lfs@ub24-1:/mnt/lfs/sources$ tar xvf sed-4.9.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd sed-4.9
lfs@ub24-1:/mnt/lfs/sources/sed-4.9$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/sed-4.9$ cd .. && rm -rf sed-4.9
 
# Tar-1.35
lfs@ub24-1:/mnt/lfs/sources$ tar xvf tar-1.35.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd tar-1.35
lfs@ub24-1:/mnt/lfs/sources/tar-1.35$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/tar-1.35$ cd .. && rm -rf tar-1.35
 
# Xz-5.8.2
lfs@ub24-1:/mnt/lfs/sources$ tar xvf xz-5.8.2.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd xz-5.8.2
lfs@ub24-1:/mnt/lfs/sources/xz-5.8.2$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
--disable-static --docdir=/usr/share/doc/xz-5.8.2
 
lfs@ub24-1:/mnt/lfs/sources/xz-5.8.2$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/xz-5.8.2$ rm -v $LFS/usr/lib/liblzma.la
lfs@ub24-1:/mnt/lfs/sources/xz-5.8.2$ cd .. && rm -rf xz-5.8.2




# Binutils-2.46.0 - 第2遍
lfs@ub24-1:/mnt/lfs/sources$ tar xvf binutils-2.46.0.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd binutils-2.46.0
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0$ sed '6031s/$add_dir//' -i ltmain.sh
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ ../configure \
--prefix=/usr              \
--build=$(../config.guess) \
--host=$LFS_TGT            \
--disable-nls              \
--enable-shared            \
--enable-gprofng=no        \
--disable-werror           \
--enable-64-bit-bfd        \
--enable-new-dtags         \
--enable-default-hash-style=gnu
 
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ make -j2 && make DESTDIR=$LFS install                    # Binutils、GCC、Glibc不要加-j参数
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ cd ../.. && rm -rf binutils-2.46.0
 
 
# GCC-15.2.0 - 第2遍
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gcc-15.2.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd gcc-15.2.0
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ 
tar -xf ../mpfr-4.2.2.tar.xz && mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ../configure  \
--build=$(../config.guess) \
--host=$LFS_TGT            \
--target=$LFS_TGT          \
--prefix=/usr              \
--with-build-sysroot=$LFS  \
--enable-default-pie       \
--enable-default-ssp       \
--disable-nls              \
--disable-multilib         \
--disable-libatomic        \
--disable-libgomp          \
--disable-libquadmath      \
--disable-libsanitizer     \
--disable-libssp           \
--disable-libvtv           \
--enable-languages=c,c++   \
LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ make -j2 && make DESTDIR=$LFS install                    # Binutils、GCC、Glibc不要加-j参数
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ln -sv gcc $LFS/usr/bin/cc
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ cd ../.. && rm -rf gcc-15.2.0



```





# [进入Chroot环境并构建额外的临时工具](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter07/introduction.html)

## 脚本代替手动执行
```shell

lfs@ub24-1:/mnt/lfs/sources$ exit        # 务必退出lfs用户


root@ub24-1:/mnt/lfs/sources# vim entering_the_chroot_environment.sh
#!/bin/bash
mkdir -pv $LFS/{dev,proc,sys,run}
mount -v --bind /dev $LFS/dev
mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi



root@ub24-1:/mnt/lfs/sources# bash entering_the_chroot_environment.sh


```




## 手动执行每一步
```shell
lfs@ub24-1:/mnt/lfs/sources$ exit       # 退出lfs用户
# 准备虚拟内核文件系统
root@ub24-1:/mnt/lfs/sources# mkdir -pv $LFS/{dev,proc,sys,run}
root@ub24-1:/mnt/lfs/sources# mount -v --bind /dev $LFS/dev          # 挂载和填充/dev，即挂载物理设备目录
 
挂载剩余的虚拟内核文件系统：
root@ub24-1:/mnt/lfs/sources# 
mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
 
在其他主机系统中，/dev/shm存在 tmpfs 的挂载点。在这种情况下，上面挂载 /dev 只会在 chroot 环境中创建 /dev/shm 目录。因此，我们必须显式挂载tmpfs
root@ub24-1:/mnt/lfs/sources# if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi


```




# [进入Chroot环境](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter07/chroot.html)
```shell
root@ub24-1:/mnt/lfs/sources# chroot "$LFS" /usr/bin/env -i \
HOME=/root                  \
TERM="$TERM"                \
PS1='(lfs chroot) \u:\w\$ ' \
PATH=/usr/bin:/usr/sbin     \
MAKEFLAGS="-j$(nproc)"      \
TESTSUITEFLAGS="-j$(nproc)" \
/bin/bash --login

(lfs chroot) I have no name!:/# 

```



## 创建目录
```shell
(lfs chroot) I have no name!:/# 
mkdir -pv /{boot,home,mnt,opt,srv}
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


```



## 创建必要文件和符号链接
```shell
(lfs chroot) I have no name!:/# ln -sv /proc/self/mounts /etc/mtab
(lfs chroot) I have no name!:/# cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF
 
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
clock:x:14:
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
 
# 移除PS1中的I have no name
(lfs chroot) I have no name!:/# exec /usr/bin/bash --login
(lfs chroot) root:/# 
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp


```









## 在真正的lfs13里继续安装工具(下面方式二选一)
### 安装vim
```shell
# 先安装vim
(lfs chroot) root:/sources# tar -zxvf vim-9.2.0488.tar.gz
(lfs chroot) root:/sources# cd vim-9.2.0488
# 在文件末尾追加定义，而不是覆盖
(lfs chroot) root:/sources/vim-9.2.0488# echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
(lfs chroot) root:/sources/vim-9.2.0488# ./configure --prefix=/usr --with-features=huge \
--enable-gui=no --without-x --disable-nls --with-tlib=ncursesw

(lfs chroot) root:/sources/vim-9.2.0488# make -j$(nproc) && make install

cat > /etc/vimrc << "EOF"
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


(lfs chroot) root:/sources/vim-9.2.0488# cd .. && rm -rf vim-9.2.0488

```






### 脚本代替手动执行
```shell
root@ub24-1:/mnt/lfs/sources# chroot "$LFS" /usr/bin/env -i \
    HOME=/root \
    TERM="$TERM" \
    PS1='(lfs chroot) root:\w# ' \
    PATH=/usr/bin:/usr/sbin:/tools/bin \
    /bin/bash --login


进到chroot环境中

(lfs chroot) root:/# cd sources/
(lfs chroot) root:/sources# vim entering_chroot_and_building_additional_temporary_tools.sh 
#!/bin/bash
tar xvf gettext-1.0.tar.xz
cd gettext-1.0
./configure --disable-shared && make -j$(nproc) && cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
cd .. && rm -rf gettext-1.0
 
# Bison-3.8.2
tar xvf bison-3.8.2.tar.xz 
cd bison-3.8.2
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2 && make -j$(nproc) && make install
cd .. && rm -rf bison-3.8.2


# Perl-5.42.0
tar xvf perl-5.42.0.tar.xz 
cd perl-5.42.0
sh Configure -des \
-D prefix=/usr                               \
-D vendorprefix=/usr                         \
-D useshrplib                                \
-D privlib=/usr/lib/perl5/5.42/core_perl     \
-D archlib=/usr/lib/perl5/5.42/core_perl     \
-D sitelib=/usr/lib/perl5/5.42/site_perl     \
-D sitearch=/usr/lib/perl5/5.42/site_perl    \
-D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
-D vendorarch=/usr/lib/perl5/5.42/vendor_perl
 
make -j2 && make install 
cd .. && rm -rf perl-5.42.0

# Python-3.14.3
tar -xvf Python-3.14.3.tar.xz
cd Python-3.14.3
./configure --prefix=/usr --enable-shared --without-ensurepip --without-static-libpython
make -j$(nproc) && make install
cd .. && rm -rf Python-3.14.3
 
# Texinfo-7.2
tar xvf texinfo-7.2.tar.xz
cd texinfo-7.2
./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf texinfo-7.2
 
# Util-linux-2.41.3
tar xvf util-linux-2.41.3.tar.xz
cd util-linux-2.41.3
mkdir -pv /var/lib/hwclock
./configure --libdir=/usr/lib \
--runstatedir=/run    \
--disable-chfn-chsh   \
--disable-login       \
--disable-nologin     \
--disable-su          \
--disable-setpriv     \
--disable-runuser     \
--disable-pylibmount  \
--disable-static      \
--disable-liblastlog2 \
--without-python      \
ADJTIME_PATH=/var/lib/hwclock/adjtime \
--docdir=/usr/share/doc/util-linux-2.41.3
 
make -j$(nproc) && make install
cd .. && rm -rf util-linux-2.41.3





(lfs chroot) root:/sources# bash entering_chroot_and_building_additional_temporary_tools.sh


```






### 手动执行每一步
```shell
# Gettext-1.0
(lfs chroot) root:/# cd sources/
(lfs chroot) root:/sources# tar xvf gettext-1.0.tar.xz
(lfs chroot) root:/sources# cd gettext-1.0
(lfs chroot) root:/sources/gettext-1.0# ./configure --disable-shared && make -j$(nproc) && cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
(lfs chroot) root:/sources/gettext-1.0# cd .. && rm -rf gettext-1.0
 
# Bison-3.8.2
(lfs chroot) root:/sources# tar xvf bison-3.8.2.tar.xz 
(lfs chroot) root:/sources# cd bison-3.8.2
(lfs chroot) root:/sources/bison-3.8.2# ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2 && make -j$(nproc) && make install
(lfs chroot) root:/sources/bison-3.8.2# cd .. && rm -rf bison-3.8.2


# Perl-5.42.0
(lfs chroot) root:/sources# tar xvf perl-5.42.0.tar.xz 
(lfs chroot) root:/sources# cd perl-5.42.0
(lfs chroot) root:/sources/perl-5.42.0# sh Configure -des \
-D prefix=/usr                               \
-D vendorprefix=/usr                         \
-D useshrplib                                \
-D privlib=/usr/lib/perl5/5.42/core_perl     \
-D archlib=/usr/lib/perl5/5.42/core_perl     \
-D sitelib=/usr/lib/perl5/5.42/site_perl     \
-D sitearch=/usr/lib/perl5/5.42/site_perl    \
-D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
-D vendorarch=/usr/lib/perl5/5.42/vendor_perl
 
(lfs chroot) root:/sources/perl-5.42.0# make -j2 && make install       # 以防万一，不要加-j参数，保守使用或仅用低并发（如-j2）
(lfs chroot) root:/sources/perl-5.42.0# cd .. && rm -rf perl-5.42.0



# Python-3.14.3
(lfs chroot) root:/sources# tar -xvf Python-3.14.3.tar.xz
(lfs chroot) root:/sources# cd Python-3.14.3
(lfs chroot) root:/sources/Python-3.14.3# ./configure --prefix=/usr --enable-shared --without-ensurepip --without-static-libpython
(lfs chroot) root:/sources/Python-3.14.3# make -j$(nproc) && make install
(lfs chroot) root:/sources/Python-3.14.3# cd .. && rm -rf Python-3.14.3
 
# Texinfo-7.2
(lfs chroot) root:/sources# tar xvf texinfo-7.2.tar.xz
(lfs chroot) root:/sources# cd texinfo-7.2
(lfs chroot) root:/sources/texinfo-7.2# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/texinfo-7.2# cd .. && rm -rf texinfo-7.2
 
# Util-linux-2.41.3
(lfs chroot) root:/sources# tar xvf util-linux-2.41.3.tar.xz
(lfs chroot) root:/sources# cd util-linux-2.41.3
(lfs chroot) root:/sources/util-linux-2.41.3# mkdir -pv /var/lib/hwclock
(lfs chroot) root:/sources/util-linux-2.41.3# ./configure --libdir=/usr/lib \
--runstatedir=/run    \
--disable-chfn-chsh   \
--disable-login       \
--disable-nologin     \
--disable-su          \
--disable-setpriv     \
--disable-runuser     \
--disable-pylibmount  \
--disable-static      \
--disable-liblastlog2 \
--without-python      \
ADJTIME_PATH=/var/lib/hwclock/adjtime \
--docdir=/usr/share/doc/util-linux-2.41.3
 
(lfs chroot) root:/sources/util-linux-2.41.3# make -j$(nproc) && make install
(lfs chroot) root:/sources/util-linux-2.41.3# cd .. && rm -rf util-linux-2.41.3
 
 


```





# 清理和保存临时系统(最后做)
注意: 这一步最后执行也可
```shell
(lfs chroot) root:/sources# rm -rf /usr/share/{info,man,doc}/*
 
在现代 Linux 系统中，libtool 的 .la 文件仅对libltdl有用。libltdl不会加载LFS中的任何库，而且已知某些.la文件会导致BLFS包加载失败。删除这些文件：
(lfs chroot) root:/sources# find /usr/{lib,libexec} -name \*.la -delete
 
# 当前系统大小约为3GB，如果你是用的脚本安装就先不要删除/tools
# (lfs chroot) root:/sources# rm -rf /tools
 
 


这里我没做这一步



```








# 构建lfs系统

## [安装基本系统软件](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter08/chapter08.html)
```shell
(lfs chroot) root:/sources/vim-9.2.0078# cd ..
(lfs chroot) root:/sources# vim installing_basic_system_software.sh
# man-page-6.17
tar -xvf man-pages-6.17.tar.xz
cd man-pages-6.17
rm man3/crypt*
make -R GIT=false prefix=/usr install
cd .. && rm -rf man-pages-6.17

sleep 3

# iana-Etc-20260202
tar -zxvf iana-etc-20260202.tar.gz
cd iana-etc-20260202
cp -v services protocols /etc
cd .. && rm -rf iana-etc-20260202
 
sleep 3

# Glibc-2.43
hash -r
 
tar xvf glibc-2.43.tar.xz
cd glibc-2.43
patch -Np1 -i ../glibc-fhs-1.patch
mkdir build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --disable-werror --disable-nscd libc_cv_slibdir=/usr/lib --enable-stack-protector=strong --enable-kernel=5.4
 
make 
touch /etc/ld.so.conf && sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
 sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
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

cat > /etc/nsswitch.conf << "EOF"
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

tar -xf ../../tzdata2025c.tar.gz
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
 
for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done
 
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO tz

cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF

cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF

mkdir -pv /etc/ld.so.conf.d
cd ../.. && rm -rf glibc-2.43

# Zlib-1.3.2
tar zxvf zlib-1.3.2.tar.gz
cd zlib-1.3.2
./configure --prefix=/usr
make -j$(nproc) && make install && rm -fv /usr/lib/libz.a
d .. && rm -rf zlib-1.3.2

sleep 3

# Bzip2-1.0.8
tar zxvf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make -j$(nproc) && make PREFIX=/usr install

sleep 3

# 安装共享库
cp -av libbz2.so.* /usr/lib
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
 
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
rm -fv /usr/lib/libbz2.a
cd .. && rm -rf bzip2-1.0.8

sleep 3

# Xz-5.8.2
tar xvf xz-5.8.2.tar.xz
cd xz-5.8.2
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/xz-5.8.2
make -j$(nproc) && make install
cd .. && rm -rf xz-5.8.2

sleep 3

# lz4-1.10.0
tar zxvf lz4-1.10.0.tar.gz
cd lz4-1.10.0
make BUILD_STATIC=no PREFIX=/usr && make BUILD_STATIC=no PREFIX=/usr install
cd .. && rm -rf lz4-1.10.0

sleep 3

# zstd-1.5.7
tar zxvf zstd-1.5.7.tar.gz
cd zstd-1.5.7
make prefix=/usr && make -j4 prefix=/usr install && rm -v /usr/lib/libzstd.a
cd .. && rm -rf zstd-1.5.7

sleep 3

# file-5.46
tar zxvf file-5.46.tar.gz
cd file-5.46
./configure --prefix=/usr && make -j4 && make install
cd .. && rm -rf file-5.46

sleep 3

 # Readline-8.3
tar zxvf readline-8.3.tar.gz
cd readline-8.3
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
sed -e '270a\
     else\
       chars_avail = 1;'      \
    -e '288i\   result = -1;' \
    -i.orig input.c

./configure --prefix=/usr --disable-static --with-curses --docdir=/usr/share/doc/readline-8.3
make SHLIB_LIBS="-lncursesw" && make install
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3
cd .. && rm -rf readline-8.3

sleep 3

# Pcre2-10.47
tar jxvf pcre2-10.47.tar.bz2
cd pcre2-10.47
./configure --prefix=/usr \
--docdir=/usr/share/doc/pcre2-10.47 \
--enable-unicode                    \
--enable-jit                        \
--enable-pcre2-16                   \
--enable-pcre2-32                   \
--enable-pcre2grep-libz             \
--enable-pcre2grep-libbz2           \
--enable-pcre2test-libreadline      \
--disable-static
 
make -j4 && make install
cd .. && rm -rf pcre2-10.47

sleep 3

# M4-1.4.21
tar xvf m4-1.4.21.tar.xz
cd m4-1.4.21
./configure --prefix=/usr && make -j4 && make install
cd .. && rm -rf m4-1.4.21

sleep 3
 
# Bc-7.0.3            https://linuxfromscratch.org/lfs/view/stable-systemd/chapter08/bc.html
tar xvf bc-7.0.3.tar.xz
cd bc-7.0.3
CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
make -j$(nproc) && make install
cd .. && rm -rf bc-7.0.3

sleep 3

# Flex-2.6.4
tar zxvf flex-2.6.4.tar.gz 
cd flex-2.6.4
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/flex-2.6.4
make -j$(nproc) && make install
ln -sv flex   /usr/bin/lex && ln -sv flex.1 /usr/share/man/man1/lex.1
cd .. && rm -rf flex-2.6.4

sleep 3

# Tcl-8.6.17
tar zxvf tcl8.6.17-src.tar.gz
cd tcl8.6.17
SRCDIR=$(pwd)
cd unix/
./configure --prefix=/usr --mandir=/usr/share/man --disable-rpath
make -j$(nproc)

sed -e "s|$SRCDIR/unix|/usr/lib|" -e "s|$SRCDIR|/usr/include|"  -i tclConfig.sh
 
sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.12|/usr/lib/tdbc1.1.12|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12/generic|/usr/include|"     \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12/library|/usr/lib/tcl8.6|"  \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12|/usr/include|"             \
    -i pkgs/tdbc1.1.12/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.4|/usr/lib/itcl4.3.4|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.4/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.3.4|/usr/include|"            \
    -i pkgs/itcl4.3.4/itclConfig.sh

unset SRCDIR
make install && chmod 644 /usr/lib/libtclstub8.6.a

chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
mv -v /usr/share/man/man3/{Thread,Tcl_Thread}.3


cd ..
tar -xf ../tcl8.6.17-html.tar.gz --strip-components=1
mkdir -v -p /usr/share/doc/tcl-8.6.17
cp -v -r  ./html/* /usr/share/doc/tcl-8.6.17
 
cd .. && rm -rf tcl8.6.17

sleep 3

# Expect-5.45.4
tar zxvf expect5.45.4.tar.gz
cd expect5.45.4
python3 -c 'from pty import spawn; spawn(["echo", "ok"])'
patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
./configure --prefix=/usr --with-tcl=/usr/lib --enable-shared --disable-rpath --mandir=/usr/share/man --with-tclinclude=/usr/include
 
make -j$(nproc) && make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
cd .. && rm -rf expect5.45.4

sleep 3

# DejaGNU-1.6.3
tar zxvf dejagnu-1.6.3.tar.gz
cd dejagnu-1.6.3
mkdir build && cd build
../configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
make install
install -v -dm755  /usr/share/doc/dejagnu-1.6.3
install -v -m644   doc/dejagnu.{html,txt}  /usr/share/doc/dejagnu-1.6.3
cd ../.. && rm -rf dejagnu-1.6.3

sleep 3
 
# Pkgconf-2.5.1
tar xvf pkgconf-2.5.1.tar.xz
cd pkgconf-2.5.1
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/pkgconf-2.5.1
make -j$(nproc) && make install
# ln -sv pkgconf   /usr/bin/pkg-config
# ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1
cd .. && rm -rf pkgconf-2.5.1

sleep 3

# Binutils-2.46.0          # Binutils、GCC、Glibc不要加-j参数
tar xvf binutils-2.46.0.tar.xz
cd binutils-2.46.0
mkdir build && cd build
../configure --prefix=/usr \
--sysconfdir=/etc   \
--enable-ld=default \
--enable-plugins    \
--enable-shared     \
--disable-werror    \
--enable-64-bit-bfd \
--enable-new-dtags  \
--with-system-zlib  \
--enable-default-hash-style=gnu
 
make tooldir=/usr && grep '^FAIL:' $(find -name '*.log') || true
make tooldir=/usr install
rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a   /usr/share/doc/gprofng/
cd ../.. && rm -rf binutils-2.46.0

sleep 3

# GMP-6.3.0
tar xvf gmp-6.3.0.tar.xz
cd gmp-6.3.0
sed -i '/long long t1;/,+1s/()/(...)/' configure
./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.3.0
make -j$(nproc) && make html
make check 2>&1 | tee gmp-check-log
awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
make install && make install-html
cd .. && rm -rf gmp-6.3.0

sleep 3

# MPFR-4.2.2
tar xvf mpfr-4.2.2.tar.xz
cd mpfr-4.2.2
./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.2
make -j$(nproc) && make html && make install&& make install-html
cd .. && rm -rf mpfr-4.2.2

sleep 3

# MPC-1.3.1
tar zxvf mpc-1.3.1.tar.gz
cd mpc-1.3.1
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpc-1.3.1
make -j$(nproc) && make html && make install && make install-html
cd .. && rm -rf mpc-1.3.1

sleep 3

# Attr-2.5.2
tar zxvf attr-2.5.2.tar.gz
cd attr-2.5.2
./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/attr-2.5.2
make -j$(nproc) && make install
cd .. && rm -rf attr-2.5.2



安装完attr之后必须额外安装keyutils



(lfs chroot) root:/sources# tar zxvf keyutils-1.6.3.tar.gz
(lfs chroot) root:/sources# cd keyutils-1.6.3
keyutils 的原生 Makefile 在处理 64 位系统（x86_64）时，默认会把库文件安装到 /lib64 和 /usr/lib64。这违反了LFS13的标准(lfs13采用纯64位架构，所有库文件必须存放在/lib和/usr/lib 中，不使用lib64)

为了防止它创建错误的目录导致后续链接失败，编译前执行以下sed命令进行修正：
(lfs chroot) root:/sources/keyutils-1.6.3# 
sed -i 's:$(LIBDIR)/$(USRLIBDIR):/usr/lib:g' Makefile
sed -i 's:/lib64:/lib:g' Makefile
sed -i 's:/usr/lib64:/usr/lib:g' Makefile


(lfs chroot) root:/sources/keyutils-1.6.3# make CFLAGS="-O2 -Wall" NO_ARFILTER=1
释义：NO_ARFILTER=1是为了防止某些高版本GCC在处理旧版 keyutils 的静态库时抛出ar参数错误

在lfs中安装第三方或额外包时，为了防止其 Makefile 中的 NO_ROOT 或权限逻辑出错，我们需要显式指定安装路径和运行参数
(lfs chroot) root:/sources/keyutils-1.6.3# make BINDIR=/usr/bin \
SBINDIR=/usr/sbin \
SHAREDIR=/usr/share/keyutils \
MANDIR=/usr/share/man \
INCLUDEDIR=/usr/include \
LIBDIR=/lib \
USRLIBDIR=/usr/lib \
install

安装完成后必须立刻验证keyutils是否正确嵌入了你当前的lfs系统，并且没有产生错误的软链接

检查动态链接是否正常：
(lfs chroot) root:/sources/keyutils-1.6.3# ldd /usr/bin/keyctl
	linux-vdso.so.1 (0x00007ffc4349a000)
	libkeyutils.so.1 => /usr/lib/libkeyutils.so.1 (0x00007161c5b1c000)
	libc.so.6 => /usr/lib/libc.so.6 (0x00007161c5936000)
	/lib64/ld-linux-x86-64.so.2 (0x00007161c5c35000)


(lfs chroot) root:/sources/keyutils-1.6.3# keyctl --version
keyctl from keyutils-1.6.3 (Built 2026-05-16)

(lfs chroot) root:/sources/keyutils-1.6.3# cd .. && rm -rf keyutils-1.6.3




# 往后继续按原来的文档操作


# Acl-2.3.2
tar xvf acl-2.3.2.tar.xz
cd acl-2.3.2
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/acl-2.3.2
make -j$(nproc) && make install
cd .. && rm -rf acl-2.3.2

 
# Libcap-2.77
tar xvf libcap-2.77.tar.xz 
cd libcap-2.77
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib && make prefix=/usr lib=lib install
cd .. && rm -rf libcap-2.77


# Libxcrypt-4.5.2
tar xvf libxcrypt-4.5.2.tar.xz 
cd libxcrypt-4.5.2
sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c
./configure --prefix=/usr --enable-hashes=strong,glibc --enable-obsolete-api=no --disable-static --disable-failure-tokens
make -j$(nproc) && make install
cd .. && rm -rf libxcrypt-4.5.2

# Shadow-4.19.3
tar xvf shadow-4.19.3.tar.xz
cd shadow-4.19.3
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
 
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs
 
touch /usr/bin/passwd
./configure --sysconfdir=/etc --disable-static --with-{b,yes}crypt \
--without-libbsd  --disable-logind  --with-group-name-max-length=32
make -j$(nproc) && make exec_prefix=/usr install && make -C man install-man
pwconv && grpconv
mkdir -p /etc/default && useradd -D --gid 999
echo "root:aaaaaa" | chpasswd
grep root /etc/shadow
if [[ $? -eq 0 ]];then
    cd .. && rm -rf shadow-4.19.3
else
    echo "password change fail..."
fi




# GCC-15.2.0
tar xvf gcc-15.2.0.tar.xz
cd gcc-15.2.0
sed -i 's/char [*]q/const &/' libgomp/affinity-fmt.c
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac
 
mkdir build && cd build
../configure --prefix=/usr  LD=ld --enable-languages=c,c++ \
--enable-default-pie --enable-default-ssp --enable-host-pie --disable-multilib --disable-bootstrap --disable-fixincludes --with-system-zlib
make -j2
ulimit -s -H unlimited
sed -e '/cpython/d' -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp
make install
chown -v -R root:root  /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include{,-fixed}
ln -svr /usr/bin/cpp /usr/lib
ln -sv gcc.1 /usr/share/man/man1/cc.1
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/15.2.0/liblto_plugin.so /usr/lib/bfd-plugins/



# Ncurses-6.6
tar zxvf ncurses-6.6.tar.gz
cd ncurses-6.6
./configure --prefix=/usr --mandir=/usr/share/man \
--with-shared --without-debug --without-normal --with-cxx-shared --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig
 
make -j$(nproc) && make DESTDIR=$PWD/dest install
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i dest/usr/include/curses.h
cp --remove-destination -av dest/*  /
for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done
 
ln -sfv libncursesw.so /usr/lib/libcurses.so
cp -v -R doc -T /usr/share/doc/ncurses-6.6
cd .. && rm -rf ncurses-6.6

sleep 3

# Sed-4.9
tar xvf sed-4.9.tar.xz
cd sed-4.9 && ./configure --prefix=/usr
make -j$(nproc) && make html && make install
install -d -m755  /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9
cd .. && rm -rf sed-4.9

sleep 3

# Psmisc-23.7
tar xvf psmisc-23.7.tar.xz
cd psmisc-23.7
./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf psmisc-23.7

# Gettext-1.0
tar xvf gettext-1.0.tar.xz
cd gettext-1.0
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/gettext-1.0
make -j$(nproc) && make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
cd .. && rm -rf gettext-1.0

sleep 3

# Bison-3.8.2
tar xvf bison-3.8.2.tar.xz
cd bison-3.8.2 
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2 && make -j$(nproc) && make install
cd .. && rm -rf bison-3.8.2 

sleep 3

# Grep-3.12
tar xvf grep-3.12.tar.xz
cd grep-3.12
sed -i "s/echo/#echo/" src/egrep.sh
./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf grep-3.12


# Bash-5.3
tar zxvf bash-5.3.tar.gz
cd bash-5.3
./configure --prefix=/usr --without-bash-malloc --with-installed-readline --docdir=/usr/share/doc/bash-5.3

sleep 3

make -j4 && make install
exec /usr/bin/bash --login -c 'echo "New Bash-5.3 test success!"'
cd .. && rm -rf bash-5.3

# Libtool-2.5.4
tar xvf libtool-2.5.4.tar.xz
cd libtool-2.5.4
./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf libtool-2.5.4

# GDBM-1.26
tar zxvf gdbm-1.26.tar.gz
cd gdbm-1.26
./configure --prefix=/usr --disable-static --enable-libgdbm-compat && make -j$(nproc) && make install
cd .. && rm -rf gdbm-1.26


# Gperf-3.3
tar zxvf gperf-3.3.tar.gz
cd gperf-3.3
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3 && make -j$(nproc) && make install
cd .. && rm -rf gperf-3.3


# Expat-2.7.4
tar xvf expat-2.7.4.tar.xz
cd expat-2.7.4
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/expat-2.7.4 && make -j$(nproc) && make install
install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.4
cd .. && rm -rf expat-2.7.4

sleep 3

# Inetutils-2.7
tar zxvf inetutils-2.7.tar.gz
cd inetutils-2.7
sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var \
--disable-logger     \
--disable-whois      \
--disable-rcp        \
--disable-rexec      \
--disable-rlogin     \
--disable-rsh        \
--disable-servers
make -j$(nproc) && make install
mv -v /usr/{,s}bin/ifconfig
cd .. && rm -rf  inetutils-2.7


# Less-692
tar zxvf less-692.tar.gz
cd less-692
./configure --prefix=/usr --sysconfdir=/etc && make -j$(nproc) && make install
cd .. && rm -rf less-692


# Perl-5.42.0
tar xvf perl-5.42.0.tar.xz 
cd perl-5.42.0
export BUILD_ZLIB=False && export BUILD_BZIP2=0
sh Configure -des \
-D prefix=/usr                                \
-D vendorprefix=/usr                          \
-D privlib=/usr/lib/perl5/5.42/core_perl      \
-D archlib=/usr/lib/perl5/5.42/core_perl      \
-D sitelib=/usr/lib/perl5/5.42/site_perl      \
-D sitearch=/usr/lib/perl5/5.42/site_perl     \
-D vendorlib=/usr/lib/perl5/5.42/vendor_perl  \
-D vendorarch=/usr/lib/perl5/5.42/vendor_perl \
-D man1dir=/usr/share/man/man1                \
-D man3dir=/usr/share/man/man3                \
-D pager="/usr/bin/less -isR"                 \
-D useshrplib                                 \
-D usethreads

sleep 3

make -j4 && make install
unset BUILD_ZLIB BUILD_BZIP2
cd .. && rm -rf perl-5.42.0


# XML::Parser-2.47
tar zxvf XML-Parser-2.47.tar.gz
cd XML-Parser-2.47
perl Makefile.PL && make -j4 && make install
cd .. && rm -rf XML-Parser-2.47

sleep 3

# Intltool-0.51.0
tar zxvf intltool-0.51.0.tar.gz
cd intltool-0.51.0
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr && make -j$(nproc) && make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
cd .. && rm -rf intltool-0.51.0

sleep 3

# Autoconf-2.72
tar xvf autoconf-2.72.tar.xz
cd autoconf-2.72
./configure --prefix=/usr && make && make install        # 不要加-j
cd .. && rm -rf autoconf-2.72
 
sleep 3

# Automake-1.18.1
tar xvf automake-1.18.1.tar.xz
cd automake-1.18.1
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1
make && make install 
cd .. && rm -rf automake-1.18.1


```





## 在LFS13中为 OpenSSL 开启CFI(控制流完整性)防御
```shell
CFI(控制流完整性): 这要求你在编译 Chapter 5 和 Chapter 6 的临时工具链时，就开始引入 LLVM/Clang 的特性。如果事后改，整个系统的动态链接库(.so)可能会冲突
保持系统工具链(第 5-6 章)使用GCC以确保稳定。仅在最后安装 Nginx 或 OpenSSL 时，引入 LLVM/Clang 软件包，专门为这些核心应用开启 -fsanitize=cfi 编译

在不打破现有稳定系统的前提下，最稳妥、最快变现的“外科手术式”引入方案如下：

# 在Chroot内紧急构建最小化LLVM/Clang
不需要编译整个臃肿的 LLVM，只需要编译能让OpenSSL跑起来的CFI编译器底座。在第8章编译 OpenSSL 之前，停下来，先编译LLVM


(lfs chroot) root:/sources# exit          # 退出chroot环境

root@ub24-1:/mnt/lfs/sources# pwd
/mnt/lfs/sources

root@ub24-1:/mnt/lfs/sources# wget https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.5/llvm-project-22.1.5.src.tar.xz \
https://github.com/Kitware/CMake/releases/download/v4.3.2/cmake-4.3.2-linux-x86_64.tar.gz

# 先安装cmake
(lfs chroot) root:/sources# tar zxvf cmake-4.3.2-linux-x86_64.tar.gz 
(lfs chroot) root:/sources# cd cmake-4.3.2-linux-x86_64
root@ub24-1:/mnt/lfs/sources# cp -av cmake-4.3.2-linux-x86_64/bin/*   /mnt/lfs/usr/bin/
root@ub24-1:/mnt/lfs/sources# cp -av cmake-4.3.2-linux-x86_64/share/*  /mnt/lfs/usr/share/



# 重新进入chroot环境
root@ub24-1:/mnt/lfs/sources# chroot "$LFS" /usr/bin/env -i HOME=/root \
TERM="$TERM" \
PS1='(lfs chroot) \u:\w\$ ' PATH=/usr/bin:/usr/sbin \
MAKEFLAGS="-j$(nproc)"  \
TESTSUITEFLAGS="-j$(nproc)" /bin/bash --login


# 重新进入Chroot验证cmake版本
(lfs chroot) root:/# cmake --version
cmake version 4.3.2

CMake suite maintained and supported by Kitware (kitware.com/cmake).


(lfs chroot) root:/# cd sources/
(lfs chroot) root:/sources# tar -xvf llvm-project-22.1.5.src.tar.xz && cd llvm-project-22.1.5.src
(lfs chroot) root:/sources# cd llvm-project-22.1.5.src/llvm
(lfs chroot) root:/sources/llvm-project-22.1.5.src/llvm# mkdir build && cd build

# 2026年最新LLVM 22.x构建参数优化(最小化编译),这里有个小坑，在Chroot命令行里，多行命令用 \ 拼接时极易因为空格或漏掉符号导致语法解析错误。以后跑自动化脚本或手动编译，尽可能把参数写在一行内，最稳妥也最不容易报错
(lfs chroot) root:/sources/llvm-project-22.1.5.src/llvm/build# cmake -DCMAKE_INSTALL_PREFIX=/usr  -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_ENABLE_RUNTIMES="compiler-rt"  -DLLVM_TARGETS_TO_BUILD="X86" -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -G "Unix Makefiles" ..

(lfs chroot) root:/sources/llvm-project-22.1.5.src/llvm/build# make -j$(nproc) && make install

当 make install 成功完成，在 Chroot 里输入 clang -v 能够看到 22.1.5 版本后，不需要退出 Chroot，直接在里面进入 OpenSSL 的目录开始加固编译
(lfs chroot) root:/sources/llvm-project-22.1.5.src/llvm/build# clang -v
clang version 22.1.5
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /usr/bin
Found candidate GCC installation: /usr/bin/../lib/gcc/x86_64-pc-linux-gnu/15.2.0
Selected GCC installation: /usr/bin/../lib/gcc/x86_64-pc-linux-gnu/15.2.0
Candidate multilib: .;@m64
Selected multilib: .;@m64


(lfs chroot) root:/sources/llvm-project-22.1.5.src/llvm/build# cd ../../..




# 继续往下编译OpenSSL，因为这个是重要的包
(lfs chroot) root:/sources# tar -zxvf  openssl-3.6.1.tar.gz
(lfs chroot) root:/sources# cd openssl-3.6.1

# 声明全套 LLVM 22 工具链参数，强制把链接器绑在lld上
(lfs chroot) root:/sources/openssl-3.6.1# 
rt CC=clang
export CXX=clang++
export CFLAGS="-fsanitize=cfi -flto -fvisibility=default -fsanitize-cfi-cross-dso -w"
export LDFLAGS="-fsanitize=cfi -flto -fsanitize-cfi-cross-dso -fuse-ld=lld"

# 执行 OpenSSL 配置
(lfs chroot) root:/sources/openssl-3.6.1# ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared threads no-tests $CFLAGS $LDFLAGS
(lfs chroot) root:/sources/openssl-3.6.1# make -j$(nproc)

这里不要执行make test，因为在执行 ./config 的时候，我们为了绕过之前的动态链接器和插件死结，已经显式传入了 no-tests 参数
这意味着 OpenSSL 的构建系统压根就没有生成测试所需的二进制文件和脚本。如果此时强行跑make test，系统会直接报错找不到目标，或者提示测试被禁用

(lfs chroot) root:/sources/openssl-3.6.1# make install

# 刷新系统的动态链接库缓存，让 LFS 识别到刚装好的新 libcrypto.so 和 libssl.so
(lfs chroot) root:/sources/openssl-3.6.1# ldconfig


(lfs chroot) root:/sources/openssl-3.6.1# openssl version
OpenSSL 3.6.1 27 Jan 2026 (Library: OpenSSL 3.6.1 27 Jan 2026)


(lfs chroot) root:/sources/openssl-3.6.1# cd ..


```






## 往下按官网操作安装
```shell

(lfs chroot) root:/sources# vim installing_basic_system_software.sh          # 清空该文件中之前的安装步骤
#!/bin/bash
set -eux

# Libelf from Elfutils-0.194
tar jxvf elfutils-0.194.tar.bz2 
cd elfutils-0.194
CFLAGS="-O2 -fno-sanitize=cfi -fno-lto" \
LDFLAGS="-fno-sanitize=cfi -fno-lto" \
./configure --prefix=/usr --disable-debuginfod --enable-libdebuginfod=dummy
make -C lib && make -C libelf
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm -f /usr/lib/libelf.a
cd .. && rm -rf elfutils-0.194
 
# Libffi-3.5.2
tar zxvf libffi-3.5.2.tar.gz 
cd libffi-3.5.2
./configure --prefix=/usr --disable-static --with-gcc-arch=native && make -j$(nproc) && make install
cd .. && rm -rf libffi-3.5.2

sleep 3

# Sqlite-3510200
tar zxvf sqlite-autoconf-3510200.tar.gz
cd sqlite-autoconf-3510200
tar -xf ../sqlite-doc-3510200.tar.xz
./configure --prefix=/usr \
            --disable-static  \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                      -D SQLITE_SECURE_DELETE=1"
 
make LDFLAGS.rpath="" && make install
install -v -m755 -d /usr/share/doc/sqlite-3.51.2
cp -v -R sqlite-doc-3510200/* /usr/share/doc/sqlite-3.51.2
cd .. && rm -rf sqlite-autoconf-3510200

sleep 3

# Python-3.14.3
tar xvf Python-3.14.3.tar.xz
cd Python-3.14.3

export CFLAGS="-I/usr/include"
export LDFLAGS="-L/usr/lib"

./configure --prefix=/usr --enable-shared --with-system-expat --enable-optimizations

sleep 3

make -j4 && make install       # 没用-j$(nproc)
cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF
 
install -v -dm755 /usr/share/doc/python-3.14.3/html
tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.14.3/html \
    -xvf ../python-3.14.3-docs-html.tar.bz2

python3 -c "import zlib; print('Zlib load success!')"

cd .. && rm -rf Python-3.14.3
 
# Flit-Core-3.12.0
tar zxvf flit_core-3.12.0.tar.gz
cd flit_core-3.12.0
python3 -m flit_core.wheel
python3 -c "import zipfile, sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" dist/*.whl /usr/lib/python3.14/site-packages
cd .. && rm -rf flit_core-3.12.0

# 现场验证确保多米诺第一块牌倒下
python3 -c "import flit_core; print('Flit-Core 终于安装成功了！')"


# gpep517-19
# 确保你下载的压缩包名字和解压目录对齐
tar zxvf v19.tar.gz
cd gpep517-19
python3 -m flit_core.wheel
python3 -c "import zipfile, sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" dist/*.whl /usr/lib/python3.14/site-packages
cd .. && rm -rf gpep517-19


# Setuptools-82.0.0
tar zxvf setuptools-82.0.0.tar.gz
cd setuptools-82.0.0
python3 -m gpep517 build-wheel --backend setuptools.build_meta --output-fd 3 --wheel-dir dist 3>&1
python3 -c "import zipfile, sys, glob; zipfile.ZipFile(glob.glob('dist/*.whl')[0]).extractall(sys.argv[1])" /usr/lib/python3.14/site-packages
cd .. && rm -rf setuptools-82.0.0


# Ninja-1.13.2
tar zxvf ninja-1.13.2.tar.gz
cd ninja-1.13.2
export NINJAJOBS=4
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
 
python3 configure.py --bootstrap --verbose
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
cd .. && rm -rf ninja-1.13.2
 

# Meson-1.10.1
tar zxvf meson-1.10.1.tar.gz
cd meson-1.10.1
cp -r mesonbuild /usr/lib/python3.14/site-packages/
cp meson.py /usr/bin/meson
chmod +x /usr/bin/meson

install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
cd .. && rm -rf meson-1.10.1


# Kmod-34.2
tar xvf kmod-34.2.tar.xz
cd kmod-34.2
# 物理切除 man 目录的 subdir 依赖（双保险，防止某些版本死锁）
sed -i '/subdir(\x27man\x27)/d' meson.build 2>/dev/null || sed -i '/subdir("man")/d' meson.build
# 提前注入全局链接器变量，允许宿主机 OpenSSL 的 __cfi_slowpath 未定义符号放行
export LDFLAGS="-Wl,--allow-shlib-undefined"
# 用标准 Meson 命令直接一步到位：创建 build 目录并生成 release 配置
#（这里移除了你命令里错误的 ".."，并将构建目标直接指定为当前目录下的 build）
meson setup --prefix=/usr .. --buildtype=release -D manpages=false   --sysconfdir=/etc --localstatedir=/var
mkdir build && cd build
ninja && ninja install
depmod -a 6.18.10
cd ../.. && rm -rf kmod-34.2

(lfs chroot) root:/sources/kmod-34.2/build# ls -lh /lib/modules/6.18.10/modules.dep
-rw-r--r-- 1 root root 356 May 16 22:35 /lib/modules/6.18.10/modules.dep



# Coreutils-9.10
tar xvf coreutils-9.10.tar.xz
cd coreutils-9.10
patch -Np1 -i ../coreutils-9.10-i18n-1.patch
autoreconf -fv && automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr && make -j$(nproc) && make install
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
cd .. && rm -rf coreutils-9.10


# Diffutils-3.12
tar xvf diffutils-3.12.tar.xz
cd diffutils-3.12
# 安全修正：注入防御参数，防止交叉编译特征测试挂掉
gl_cv_func_getopt_gnu=yes ./configure --prefix=/usr 
make -j$(nproc) && make install
cd .. && rm -rf diffutils-3.12



# Gawk-5.3.2
tar xvf gawk-5.3.2.tar.xz 
cd gawk-5.3.2
sed -i 's/extras//'  Makefile.in
./configure --prefix=/usr && make -j$(nproc) && rm -f /usr/bin/gawk-5.3.2 && make install
ln -sv gawk.1 /usr/share/man/man1/awk.1
install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.2
cd .. && rm -rf gawk-5.3.2


# Findutils-4.10.0
tar xvf findutils-4.10.0.tar.xz
cd findutils-4.10.0
./configure --prefix=/usr --localstatedir=/var/lib/locate && make -j$(nproc) && make install
cd .. && rm -rf findutils-4.10.0


# Groff-1.23.0
tar zxvf groff-1.23.0.tar.gz
cd groff-1.23.0
PAGE=A4 ./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf groff-1.23.0

 
# GRUB-2.14
unset {C,CPP,CXX,LD}FLAGS
tar xvf grub-2.14.tar.xz 
cd grub-2.14
sed 's/--image-base/--nonexist-linker-option/' -i configure
./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror && make -j$(nproc) && make install
cd .. && rm -rf grub-2.14


# Gzip-1.14
tar xvf gzip-1.14.tar.xz
cd gzip-1.14
./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf gzip-1.14

# IPRoute2-6.18.0
tar xvf iproute2-6.18.0.tar.xz 
cd iproute2-6.18.0
sed -i /ARPD/d Makefile && rm -fv man/man8/arpd.8
make NETNS_RUN_DIR=/run/netns && make SBINDIR=/usr/sbin install
install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.18.0
cd .. && rm -rf iproute2-6.18.0

# Kbd-2.9.0
tar xvf kbd-2.9.0.tar.xz
cd kbd-2.9.0
patch -Np1 -i ../kbd-2.9.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock && make -j$(nproc) && make install && cp -R -v docs/doc -T /usr/share/doc/kbd-2.9.0
cd .. && rm -rf kbd-2.9.0

# Libpipeline-1.5.8
tar zxvf libpipeline-1.5.8.tar.gz
cd libpipeline-1.5.8
./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf libpipeline-1.5.8

# Make-4.4.1
tar zxvf make-4.4.1.tar.gz
cd make-4.4.1
./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf make-4.4.1

# Patch-2.8
tar xvf patch-2.8.tar.xz 
cd patch-2.8
./configure --prefix=/usr && make -j$(nproc) && make install
cd .. && rm -rf patch-2.8

# Tar-1.35
tar xvf tar-1.35.tar.xz 
cd tar-1.35
FORCE_UNSAFE_CONFIGURE=1  ./configure --prefix=/usr
make -j$(nproc) && make install && make -C doc install-html docdir=/usr/share/doc/tar-1.35
cd .. && rm -rf tar-1.35

# Texinfo-7.2
tar xvf texinfo-7.2.tar.xz
cd texinfo-7.2
sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm
./configure --prefix=/usr && make -j$(nproc) && make install
make TEXMF=/usr/share/texmf install-tex
cd .. && rm -rf texinfo-7.2


# MarkupSafe-3.0.3
tar zxvf markupsafe-3.0.3.tar.gz
cd markupsafe-3.0.3
cp -r src/markupsafe  /usr/lib/python3.14/site-packages/
cd .. && rm -rf markupsafe-3.0.3


# Jinja2-3.1.6
tar zxvf jinja2-3.1.6.tar.gz
cd jinja2-3.1.6
cp -r src/jinja2   /usr/lib/python3.14/site-packages/
cd .. && rm -rf jinja2-3.1.6
 
 
# Systemd-259.1
tar zxvf systemd-259.1.tar.gz 
cd systemd-259.1
sed -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' -i rules.d/50-udev-default.rules.in
mkdir build && cd build
meson setup .. \
      --prefix=/usr           \
      --buildtype=release     \
      -D default-dnssec=no    \
      -D firstboot=false      \
      -D install-tests=false  \
      -D ldconfig=false       \
      -D sysusers=false       \
      -D rpmmacrosdir=no      \
      -D homed=disabled       \
      -D man=disabled         \
      -D mode=release         \
      -D pamconfdir=no        \
      -D dev-kvm-mode=0660    \
      -D nobody-group=nogroup \
      -D sysupdate=disabled   \
      -D ukify=disabled       \
      -D docdir=/usr/share/doc/systemd-259.1 \
      -D openssl=disabled     \
      -D gcrypt=disabled
 

ninja
echo 'NAME="Linux From Scratch"' > /etc/os-release
ninja install
tar -xf ../../systemd-man-pages-259.1.tar.xz --no-same-owner --strip-components=1 -C /usr/share/man
systemd-machine-id-setup && systemctl preset-all
cd ../.. && rm -rf systemd-259.1
 
# D-Bus-1.16.2
tar xvf dbus-1.16.2.tar.xz
cd dbus-1.16.2
mkdir build && cd build
meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
ninja && ninja install && ln -sfv /etc/machine-id /var/lib/dbus
cd ../.. && rm -rf dbus-1.16.2

# Man-DB-2.13.1
tar xvf man-db-2.13.1.tar.xz
cd man-db-2.13.1
./configure --prefix=/usr  \
--docdir=/usr/share/doc/man-db-2.13.1 \
--sysconfdir=/etc                     \
--disable-setuid                      \
--enable-cache-owner=bin              \
--with-browser=/usr/bin/lynx          \
--with-vgrind=/usr/bin/vgrind         \
--with-grap=/usr/bin/grap
 
make -j$(nproc) && make install
cd .. && rm -rf man-db-2.13.1


# Procps-ng-4.0.6
tar xvf procps-ng-4.0.6.tar.xz 
cd procps-ng-4.0.6
./configure --prefix=/usr \
--docdir=/usr/share/doc/procps-ng-4.0.6 \
--disable-static --disable-kill --enable-watch8bit --with-systemd
 
make -j$(nproc) && make install
cd .. && rm -rf procps-ng-4.0.6


# Util-linux-2.41.3
tar xvf util-linux-2.41.3.tar.xz 
cd util-linux-2.41.3
./configure --bindir=/usr/bin --libdir=/usr/lib   --runstatedir=/run \
--sbindir=/usr/sbin   \
--disable-chfn-chsh   \
--disable-login       \
--disable-nologin     \
--disable-su          \
--disable-setpriv     \
--disable-runuser     \
--disable-pylibmount  \
--disable-liblastlog2 \
--disable-static      \
--without-python      \
ADJTIME_PATH=/var/lib/hwclock/adjtime \
--docdir=/usr/share/doc/util-linux-2.41.3
 
make -j$(nproc) && touch /etc/fstab && make install
cd .. && rm -rf util-linux-2.41.3


# E2fsprogs-1.47.3
tar zxvf e2fsprogs-1.47.3.tar.gz 
cd e2fsprogs-1.47.3
mkdir build && cd build
../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs --disable-libblkid --disable-libuuid --disable-uuidd --disable-fsck
 
make -j$(nproc) && make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf
cd ../.. && rm -rf e2fsprogs-1.47.3





# 清空之前该脚本中的内容
(lfs chroot) root:/sources# vim installing_basic_system_software.sh
#!/bin/bash
# =====================================================================
# 8.78. 剥离调试符号与清理 (完美闭环版)
# =====================================================================
set -eux

cd /usr/lib

# 1. 定义需要人肉提取调试符号并安全保护的核心共享库
save_usrlib="ld-linux-x86-64.so.2 libc.so.6 libthread_db.so.1 libquadmath.so.0.0.0 libstdc++.so.6.0.34 libitm.so.1.0.0 libatomic.so.1.2.0 libcrypto.so.3 libssl.so.3"

for LIB in $save_usrlib; do
    if [ -f "$LIB" ]; then
        objcopy --only-keep-debug --compress-debug-sections=zstd "$LIB" "$LIB.dbg"
        cp "$LIB" /tmp/"$LIB"
        strip --strip-debug /tmp/"$LIB"
        objcopy --add-gnu-debuglink="$LIB.dbg" /tmp/"$LIB"
        install -vm755 /tmp/"$LIB" /usr/lib
        rm -f /tmp/"$LIB"
    fi
done

# 2. 定义当前 Shell 正在线上运行、绝对不能在原地直接被修改的基础命令和库
online_usrbin="bash find strip"
online_usrlib="ld-linux-x86-64.so.2
               libbfd-2.46.0.20260210.so
               libsframe.so.3.0.0
               libhistory.so.8.3
               libncursesw.so.6.6
               libm.so.6
               libreadline.so.8.3
               libz.so.1.3.2
               libzstd.so.1.5.7
               $(find libnss*.so* -type f 2>/dev/null || true)"

for BIN in $online_usrbin; do
    if [ -f "/usr/bin/$BIN" ]; then
        cp /usr/bin/$BIN /tmp/$BIN
        strip --strip-debug /tmp/$BIN
        install -vm755 /tmp/$BIN /usr/bin
        rm -f /tmp/$BIN
    fi
done

for LIB in $online_usrlib; do
    if [ -f "/usr/lib/$LIB" ]; then
        cp /usr/lib/$LIB /tmp/$LIB
        strip --strip-debug /tmp/$LIB
        install -vm755 /tmp/$LIB /usr/lib
        rm -f /tmp/$LIB
    fi
done

# 3. 大普查循环：核心改进！
# 在 find 出来的候选文件送入 strip 之前，增加一行高级防御：
# 利用 file 命令精准识别，只有真正的 "ELF" 二进制文件才允许执行 strip。
# 这能完美过滤掉形如 libgcc_s.so 的文本链接脚本以及任何潜伏的文本文件。
for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg ! -name \*.py) \
         $(find /usr/lib -type f -name \*.a)                                \
         $(find /usr/{bin,sbin,libexec} -type f); do
    
    # 终极防御：如果不是 ELF 二进制文件，直接跳过，防止 strip 报错
    if ! file "$i" | grep -q "ELF"; then
        continue
    fi

    case "$online_usrbin $online_usrlib $save_usrlib" in
        *$(basename "$i")* )
            ;;
        * ) 
            strip --strip-debug "$i"
            ;;
    esac
done

# 清理不必要的局部变量
unset BIN LIB save_usrlib online_usrbin online_usrlib

# 4. 官方标准的最后清理阶段
rm -rf /tmp/{*,.*} 2>/dev/null || true
find /usr/lib /usr/libexec -name \*.la -delete
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf 2>/dev/null || true



(lfs chroot) root:/sources# bash installing_basic_system_software.sh


```






# 系统配置
```shell
# 屏蔽 udev 的.link默认策略文件
(lfs chroot) root:/usr/lib# ln -s /dev/null /etc/systemd/network/99-default.link


# 一般网络配置
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
    inet 172.16.186.128/24 brd 172.16.186.255 scope global dynamic noprefixroute ens33
       valid_lft 1509sec preferred_lft 1509sec
    inet6 fe80::20c:29ff:fe93:9028/64 scope link proto kernel_ll 
       valid_lft forever preferred_lft forever

释义：
上述在 chroot 中能看到 ens33 并且已经有 IP（172.16.186.128），这是因为 chroot 环境共享了宿主机（Ubuntu）的内核和网络堆栈
虽然现在看着有网，但这只是“借用”宿主机的成果。为了让你脱离宿主机独立启动 LFS 后网络依然正常，你需要按照刚才看到的 ens33 这个名字来编写配置文件


1. 编写LFS独立的网络配置
请直接在当前 chroot 环境下执行以下命令（针对你的ens33）：
# 创建网络配置目录（以防万一还没创建）
(lfs chroot) root:/usr/lib# mkdir -pv /etc/systemd/network
# 编写DHCP配置文件（本次使用该配置文件）
(lfs chroot) root:/usr/lib# vim /etc/systemd/network/10-eth-dhcp.network
[Match]
# 匹配所有以e开头的网卡（覆盖eth0, ens33, enp0s3等）
Name=e*
 
[Network]
DHCP=ipv4

注意: dhcp和静态IP可以同时存在，但(1)文件名的开头不要相同，在systemd-networkd中文件是按文件名字符顺序加载的，并且一旦匹配到网卡名称，后续的逻辑可能会发生冲突或叠加
为什么155没生效？
原因主要有两个：
文件冲突：你同时拥有 10-eth-dhcp.network 和 10-eth-static.network。由于它们都匹配 Name=ens33，systemd-networkd 可能同时启动了 DHCP 客户端并尝试设置静态地址。在很多情况下，DHCP 获取到的地址(1) 会覆盖或与静态地址共存，但你的 DHCP 显然先拿到了 .141
(2) 加载顺序：两个文件名都以 10- 开头，加载顺序是不确定的

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
# ===============================================================================
 
2. 为什么你在 chroot 里看到的是“借来的”网络？
在 Linux 中，网络接口是由内核管理的。由于 chroot 只是改变了进程看到的根目录，并没有隔离内核空间，所以：
宿主机 Ubuntu 的内核已经驱动了 ens33
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
请完全忽略这个报错。 这是因为 chroot 环境的 PID 1 依然是宿主机的 init。只要你把上面的 .network 文件写对了，当你真正从硬盘启动LFS系统时，
LFS自己的systemd会作为 PID 1 启动，它会自动扫描 /etc/systemd/network/ 目录并拉起网络
 
 
配置系统主机名
(lfs chroot) root:/usr/lib# echo lfs > /etc/hostname
 
自定义 /etc/hosts 文件
(lfs chroot) root:/usr/lib# cat > /etc/hosts << "EOF"
127.0.0.1  localhost lfs
::1        localhost
EOF



# 配置Linux控制台             https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/console.html
(lfs chroot) root:/usr/lib# echo FONT=Lat2-Terminus16 > /etc/vconsole.conf
(lfs chroot) root:/usr/lib# cat > /etc/vconsole.conf << "EOF"
KEYMAP=us
FONT=Lat2-Terminus16
EOF
 
确保重启后这个字体能真的加载出来，请务必在 chroot 里执行一下这个命令检查文件是否存在：
(lfs chroot) root:/usr/lib# ls /usr/share/consolefonts/Lat2-Terminus16.psfu.gz          # 下一行是回显
/usr/share/consolefonts/Lat2-Terminus16.psfu.gz  
# 试着手动加载它（即使在 chroot 里没效果，但能测试命令是否报错）
(lfs chroot) root:/usr/lib# setfont Lat2-Terminus16


# 配置系统区域设置
生成Locale（区域定义）
(lfs chroot) root:/usr/lib# localedef -i en_US -f UTF-8 en_US.UTF-8
 
创建配置文件（此时这里不要用中文，因为很有可能会出错）
(lfs chroot) root:/usr/lib# cat > /etc/locale.conf << "EOF"
LANG=en_US.UTF-8
EOF

# 查看当前生成的全部区域
(lfs chroot) root:/usr/lib# localectl list-locales          # 这个命令会报错，没影响
 
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
 
 
获取Glibc支持的所有语言环境列表：
(lfs chroot) root:/usr/lib# locale -a


# 和官方的有不同，请注意
(lfs chroot) root:/usr/lib# cat > /etc/profile << "EOF"
# Begin /etc/profile
# --- 基础路径配置 ---
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
# --- 提示符配置  ---
export PS1='[\u@\h \w]\$ '
 
for i in $(locale); do
  unset ${i%=*}
done
 
if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
# 只有文件存在时才加载，防止报错
  if [ -f /etc/locale.conf ]; then
    source /etc/locale.conf
  fi
 
  for i in $(locale); do
    key=${i%=*}
    if [[ -v $key ]]; then
      export $key
    fi
  done
fi
# --- 终端颜色支持 (可选) ---
if [ "$TERM" != "linux" ]; then
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
fi
# End /etc/profile
EOF
 

# 创建/etc/inputrc文件
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
 
 
 
# 创建/etc/shells文件
(lfs chroot) root:/usr/lib# cat > /etc/shells << "EOF"
# Begin /etc/shells
 
/bin/sh
/bin/bash
# End /etc/shells
EOF
 


# Systemd 的使用和配置          https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/systemd-custom.html
强烈建议跳过（不执行）
如果你执行了这一步：你的网卡会变回 eth0，那么你之前写的那个 10-eth-dhcp.network 文件（里面写的是 Name=ens33）就会失效，导致你进系统后没网
如果你不执行：一切保持原样，符合现代 Linux 的标准


```





# 使LFS系统可启动
```shell
(lfs chroot) root:/usr/lib# fdisk -l /dev/sdb
Disk /dev/sdb: 60 GiB, 64424509440 bytes, 125829120 sectors
Disk model: VMware Virtual S
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 74A3069F-DE1F-444F-A4E6-CDBA993C3D1D

Device        Start       End   Sectors Size Type
/dev/sdb1      2048     12287     10240   5M BIOS boot
/dev/sdb2     12288  12595199  12582912   6G Linux swap
/dev/sdb3  12595200 125827071 113231872  54G Linux filesystem



(lfs chroot) root:/usr/lib# blkid | grep sdb
/dev/sdb2: UUID="c5cc11f1-b799-4a1b-8753-ba875c179dc8" TYPE="swap" PARTUUID="d79069db-7141-4e91-a05e-99c403fe2a1d"
/dev/sdb3: UUID="dd9c60f6-dff7-43c0-a91d-c6776f586015" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="abe29ce0-62fe-4fb3-a384-aeec9368d302"
/dev/sdb1: PARTUUID="e770c400-bdc2-46f7-912f-104fd512043a"
 
释义：
分区信息分析
/dev/sdb1: BIOS boot占位符，等着GRUB往里灌二进制代码
/dev/sdb2: 这是你的交换分区 (Swap)
/dev/sdb3：已经正确挂载在 /（在chroot环境下）
 
# 编写/etc/fstab
(lfs chroot) root:usr/lib/# mkdir -pv /proc /sys /dev/pts /run /dev/shm
 

在chroot环境下，执行以下命令来创建这个至关重要的文件。为了系统的稳定性，我们直接使用
(lfs chroot) root:/usr/lib# cat > /etc/fstab << "EOF"
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=dd9c60f6-dff7-43c0-a91d-c6776f586015  /    ext4 defaults 1 1
UUID=c5cc11f1-b799-4a1b-8753-ba875c179dc8  swap swap defaults 0 0
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
-rw-r--r-- 1 root root 560 May 12 12:26 /etc/fstab
 


```





# 安装内核前有必要做个快照
```shell
这里我没做快照


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





# Linux-6.18.10内核安装
```shell
在 6.18.10 这种极新的现代内核里，用斜杠键 / 搜索符号名（如 WIREGUARD 或 IMA_WRITE_POLICY）是你人肉硬核定制内核时的无双利器
只要看清搜索结果里 Depends on: 后面哪个带了 [=n]，就说明是那个前置依赖卡住了它。顺着去把那个 [=n] 的家伙改成 [=y]，你要的选项就都显示出来了


(lfs chroot) root:/usr/lib# cd /sources/
(lfs chroot) root:/sources# tar xvf linux-6.18.10.tar.xz 
(lfs chroot) root:/sources# cd linux-6.18.10
(lfs chroot) root:/sources/linux-6.18.10# make mrproper
(lfs chroot) root:/sources/linux-6.18.10# make menuconfig
# 基础构架与 Systemd 强制要求
General setup --->
  CPU/Task time and stats accounting --->
      [*] Pressure stall information tracking                                [PSI]
      [ ]   Require boot parameter to enable pressure stall information tracking
            ...  [PSI_DEFAULT_DISABLED]
  < > Enable kernel headers through /sys/kernel/kheaders.tar.xz      [IKHEADERS]
  [*] Control Group support --->                                       [CGROUPS]
     [*]   Memory controller                                             [MEMCG]
     [*] CPU controller --->                                    [CGROUP_SCHED]
        # This may cause some systemd features malfunction:
        [ ] Group scheduling for SCHED_RR/FIFO                [RT_GROUP_SCHED]
  [*] Configure standard kernel features (expert users) --->            [EXPERT]
  [*] Initial RAM filesystem and RAM disk (initramfs/initrd) support  # 必须开启，用于加载签名密钥

Processor type and features --->
  [*] Build a relocatable kernel                                   [RELOCATABLE]
  [*]   Randomize the address of the kernel image (KASLR)        [RANDOMIZE_BASE]
 
General architecture-dependent options --->
  [*] Stack Protector buffer overflow detection                 [STACKPROTECTOR]
  [*]   Strong Stack Protector                           [STACKPROTECTOR_STRONG]


# 隐身网络（WireGuard）与核心安全（IMA/EVM）
[*] Networking support --->                                                [NET]
   Networking options --->
      [*] TCP/IP networking                                               [INET]
      <*> IP: tunneling
      <*>   The IPv6 protocol --->                                         [IPV6]
   Network device support--->
      <*> Network core driver support 
           [*] WireGuard secure network tunnel

-*- Cryptographic API --->
    Hashes, digests, and MACs  --->
         < > BLAKE2b
         -*- CMAC (Cipher-based MAC)
         -*- GHASH
         -*- HMAC (Keyed-Hash MAC)
         < > MD4
         -*- MD5
         < > Michael MIC
         < > RIPEMD-160
         -*- SHA-1
         -*- SHA-224 and SHA-256
         -*- SHA-384 and SHA-512
         -*- SHA-3
         < > SM3 (ShangMi 3)
         < > Streebog
         < > Whirlpool
         < > XCBC-MAC (Extended Cipher Block Chaining MAC)
         < > xxHash
    [*] Hardware crypto devices  --->
    -*- Asymmetric (public-key cryptographic) key type  --->
         -*- Asymmetric public-key crypto algorithm subtype  
         -*- X.509 certificate parser 
         < >   PKCS#8 private key parser
         -*- PKCS#7 message parser
         < >   PKCS#7 testing key type
         [ ]   Support for PE file signature verification
         < >   Run FIPS selftests on the X.509+PKCS7 signature verification

     Certificates for signature checking  --->
         [*] Provide system-wide ring of trusted keys          [SYSTEM_TRUSTED_KEYRING]
           ( ) Additional X.509 keys for default system keyring        # 留空不用填
Cryptographic API
	Userspace interface
		<*> Hash algorithms
		<*> Symmetric key cipher algorithms
		< > RNG (random number generator) algorithms
		<*> AEAD cipher algorithms  
		[*] Obsolete cryptographic algorithms (NEW)

-> Cryptographic API 
	Random number generation中的三项我没动
		< > ANSI PRNG (Pseudo Random Number Generator)
		-*- NIST SP800-90A DRBG (Deterministic Random Bit Generator)  --->
		-*- CPU Jitter Non-Deterministic RNG (Random Number Generator)
                                                     
-> Cryptographic API (CRYPTO [=y])
    -> Random number generation 
         -> NIST SP800-90A DRBG (Deterministic Random Bit Generator) (CRYPTO_DRBG_MENU [=y])
   				-> CTR_DRBG (CRYPTO_DRBG_CTR [=y])              # 打开

-> Cryptographic API (CRYPTO [=y])
    -> Userspace interface
        -> Hash algorithms (CRYPTO_USER_API_HASH [=n]) 

-> Cryptographic API (CRYPTO [=y])
    -> Userspace interface
        -> AEAD cipher algorithms (CRYPTO_USER_API_AEAD [=n]) 



Security options--->
	[*] Enable different security models
	[*] Integrity subsystem
    [*]   Integrity Measurement Architecture(IMA)
	[*]     Enable multiple writes to the IMA policy
    [*]   EVM support

# 设备驱动与固件
Device Drivers --->
  Generic Driver Options --->
    [ ] Support for uevent helper                             [UEVENT_HELPER]
    [*] Maintain a devtmpfs filesystem to mount at /dev               [DEVTMPFS]
    [*]   Automount devtmpfs at /dev, after the kernel mounted the rootfs
                                                                 ...  [DEVTMPFS_MOUNT]
  Firmware Drivers --->
    [*] Export DMI identification via sysfs to userspace                 [DMIID]
    [*] Mark VGA/VBE/EFI FB as generic system framebuffer       [SYSFB_SIMPLEFB]
  Graphics support --->
    <*> Direct Rendering Manager (XFree86 4.1.0 and higher DRI support) ---> 
         [*] Display a user-friendly message when a kernel panic occurs
             (user)   Panic screen formatter         [DRM_PANIC_SCREEN]
         Supported DRM clients ---> 
            [*] Enable legacy fbdev support for your modesetting driver
                                                              ...  [DRM_FBDEV_EMULATION]
         Drivers for system framebuffers --->
            <*> Simple framebuffer driver                              [DRM_SIMPLEDRM]
  Console display driver support --->
    [*] Framebuffer Console support                      [FRAMEBUFFER_CONSOLE]


# 显卡、控制台与文件系统
Device Drivers --->
  NVME Support --->
    <*> NVM Express block device                         [BLK_DEV_NVME]            # 如果LFS系统的分区位于NVME SSD上
 
Device Drivers -> -*- SCSI device support
                  <*> SCSI disk support
                  [*] SCSI low-level drivers ->
                      # 修正：只要开启 PCI 支持，该项在 6.18.10 的低级驱动菜单里就能正常勾选
                      <*>   VMware PVSCSI driver support      
                      <*>   virtio-scsi support
                  [*] Fusion MPT device support  ---->
                      <*>   Fusion MPT ScsiHost drivers for SPI 
                      <*>   Fusion MPT ScsiHost drivers for SAS

# 文件系统
File systems --->
  [*] Inotify support for userspace                               [INOTIFY_USER]
  Pseudo filesystems --->
      [*] Tmpfs virtual memory file system support (former shm fs)         [TMPFS]
      [*]   Tmpfs POSIX Access Control Lists                    [TMPFS_POSIX_ACL]
  <*> The Extended 4 (ext4) filesystem
  <*> Ext4 POSIX Access Control Lists

# 如果您正在构建64位 system，请启用以下一些附加功能
Processor type and features --->
  [*] x2APIC interrupt controller architecture support              [X86_X2APIC]
 
Device Drivers --->
  [*] PCI support --->                                                     [PCI]
    [*] Message Signaled Interrupts (MSI and MSI-X)                    [PCI_MSI]
  [*] IOMMU Hardware Support --->                                [IOMMU_SUPPORT]
    [*] Support for Interrupt Remapping                              [IRQ_REMAP]


你现在的内核如果是针对虚拟机优化的，换台实体机可能连硬盘都扫不出来,所以需要:
开启通用驱动：确保开启了 AHCI (SATA)、NVMe、USB 3.0 (xHCI) 以及常见的各种文件系统支持
显卡驱动：至少开启 Vesa FB 或 EFI FB，否则启动后会黑屏


# 1. 废除警告当错误和孤儿段错误
sed -i 's/CONFIG_WERROR=y/# CONFIG_WERROR is not set/' .config
sed -i 's/CONFIG_LD_ORPHAN_WARN_LEVEL="error"/CONFIG_LD_ORPHAN_WARN_LEVEL="warn"/' .config

# 2. 彻底废除导致加密/证书提取死锁的完整性审计子系统
sed -i 's/CONFIG_INTEGRITY=y/# CONFIG_INTEGRITY is not set/' .config
sed -i 's/CONFIG_IMA=y/# CONFIG_IMA is not set/' .config
sed -i 's/CONFIG_IMA_MEASURE_ASYMMETRIC_KEYS=y/# CONFIG_IMA_MEASURE_ASYMMETRIC_KEYS is not set/' .config
sed -i 's/CONFIG_IMA_QUEUE_EARLY_BOOT_KEYS=y/# CONFIG_IMA_QUEUE_EARLY_BOOT_KEYS is not set/' .config
sed -i 's/CONFIG_IMA_LSM_RULES=y/# CONFIG_IMA_LSM_RULES is not set/' .config
sed -i 's/CONFIG_EVM=y/# CONFIG_EVM is not set/' .config
sed -i 's/CONFIG_EVM_ATTR_FSUUID=y/# CONFIG_EVM_ATTR_FSUUID is not set/' .config

# 3. 废除空壳网络文件系统总开关
sed -i 's/CONFIG_NETWORK_FILESYSTEMS=y/# CONFIG_NETWORK_FILESYSTEMS is not set/' .config

# 强行在编译内核时，给宿主机工具的链接器注入“允许未定义符号”和“关闭CFI丢弃”的硬核参数
[root@ub24-1 /sources/linux-6.18.10]# export HOSTLDFLAGS="-Wl,--allow-shlib-undefined"

# 直接修改内核处理宿主机工具的核心 Makefile，把允许未定义符号强行追加进去
sed -i 's/^HOSTLDFLAGS.*/& -Wl,--allow-shlib-undefined/g' scripts/Makefile.host

# 如果你的内核版本 Makefile 结构有微调，也可以直接焊死在这个证书目录的 Makefile 里
sed -i 's/hostprogs-y/HOSTLDFLAGS_extract-cert += -Wl,--allow-shlib-undefined\n&/' certs/Makefile


(lfs chroot) root:/sources/linux-6.18.10# make -j$(nproc)
注：核心越多，编译越快。如果只有1核，可能需要等半小时以上；如果是4核或更多，10分钟左右就能搞定
....
  ....
  AS      arch/x86/boot/header.o
  LD      arch/x86/boot/setup.elf
  OBJCOPY arch/x86/boot/setup.bin
  BUILD   arch/x86/boot/bzImage
Kernel: arch/x86/boot/bzImage is ready  (#1)
 
 
编译完成后，先安装模块（这会放到 /lib/modules 目录下
(lfs chroot) root:/sources/linux-6.13.4# make modules_install
 
手动安装内核镜像到/boot
(lfs chroot) root:/sources/linux-6.18.10# cp -iv arch/x86/boot/bzImage  /boot/vmlinuz-6.18.10-lfs-13.0-systemd
 
安装 System.map（调试用）
(lfs chroot) root:/sources/linux-6.18.10# cp -iv System.map /boot/System.map-6.18.10
 
备份你的辛苦成果（下次编译时可以基于此配置）
(lfs chroot) root:/sources/linux-6.18.10# cp -iv .config /boot/config-6.18.10
 
安装 Linux 内核文档
(lfs chroot) root:/sources/linux-6.18.10# cp -r Documentation -T /usr/share/doc/linux-6.18.10
 
 



# 使用GRUB设置启动过程              https://linuxfromscratch.org/lfs/view/stable-systemd/chapter10/grub.html
# 自动生成grub.cfg  (和下述手动生成 二选一)
(lfs chroot) root:/sources/linux-6.18.10# mkdir -pv /boot/grub
(lfs chroot) root:/sources/linux-6.18.10# grub-install --target=i386-pc /dev/sdb
(lfs chroot) root:/sources/linux-6.18.10# grub-mkconfig -o /boot/grub/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.18.10-lfs-13.0-systemd
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
# 最后的最后：确认配置文件
在重启之前，请务必最后一次确认你的 /boot/grub/grub.cfg 内容是否正确。这一步写错，开机就会进入黑乎乎的 grub> 命令行
 

# ===================================================================================
(lfs chroot) root:/sources/linux-6.18.10# grub-install /dev/sdb
Installing for i386-pc platform.
Installation finished. No error reported.

# 创建GRUB配置文件
(lfs chroot) root:/sources/linux-6.18.10# cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5
 
insmod part_gpt
insmod ext2
set root=(hd0,2)
set gfxpayload=1024x768x32
 
menuentry "GNU/Linux, Linux 6.18.10-lfs-13.0-systemd" {
        linux   /boot/vmlinuz-6.18.10-lfs-13.0-systemd root=/dev/sdb3 ro
}
EOF
 
注意：更建议写成PARTUUID的方式   ---> 本次使用该方式
(lfs chroot) root:/sources/linux-6.18.10# blkid /dev/sdb3
/dev/sdb3: UUID="38fd2557-e2fe-4607-8704-11def760107f" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="08c243f4-113e-4dae-9fe5-5bc70bcd7a92"
 
(lfs chroot) root:/sources/linux-6.18.10# cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5
 
insmod part_gpt
insmod ext2
set root=(hd0,2)
set gfxpayload=1024x768x32
 
menuentry "GNU/Linux, Linux 6.18.10-lfs-13.0-systemd" {
        linux   /boot/vmlinuz-6.18.10-lfs-13.0-systemd root=PARTUUID=08c243f4-113e-4dae-9fe5-5bc70bcd7a92 ro
}
EOF
# ===================================================================================


```



# 最后
```shell
(lfs chroot) root:/sources/linux-6.18.10# echo 13.0-systemd > /etc/lfs-release
 
(lfs chroot) root:/sources/linux-6.18.10# cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="13.0-systemd"
DISTRIB_CODENAME="rambo"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF
 
(lfs chroot) root:/sources/linux-6.18.10# cat > /etc/os-release << "EOF"
NAME="Linux From Scratch"
VERSION="13.0-systemd"
ID=lfs
PRETTY_NAME="Linux From Scratch 13.0-systemd"
VERSION_CODENAME="rambo"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
RELEASE_TYPE="stable"
EOF
 



# 重启系统
(lfs chroot) root:/sources/linux-6.18.10# cd /
(lfs chroot) root:/# logout
 
# 按照挂载的逆序进行卸载
root@ub24-1:/mnt/lfs/sources# cd /
root@ub24-1:/# 
umount -v $LFS/dev/pts
mountpoint -q $LFS/dev/shm && umount -v $LFS/dev/shm
umount -v $LFS/dev
umount -v $LFS/run
umount -v $LFS/proc
umount -v $LFS/sys
umount -l $LFS/dev
umount -v $LFS
 
 
root@ub24-1:~# poweroff

```
![image](https://img2024.cnblogs.com/blog/1139005/202605/1139005-20260517143600011-107020641.png)
![image](https://img2024.cnblogs.com/blog/1139005/202605/1139005-20260517144701738-829607473.png)




# 验证


## 编写并验证wireguard
```shell
# 安装wireguard
root@ub24-1:/mnt/lfs/sources# wget -O wireguard-tools_v1.0.20260223.tar.gz  https://github.com/WireGuard/wireguard-tools/archive/refs/tags/v1.0.20260223.tar.gz
cd wireguard-tools_v1.0.20260223
make -C src -j$(nproc) && make -C src install



终极实战验证：现场手搓一个隐形隧道
# 1. 现场物理生成私钥和公钥（验证 Curve25519 纯净的数学运算）
wg genkey | tee /tmp/privatekey | wg pubkey > /tmp/publickey

# 2. 查看生成的密钥对（只要不是空文件且出了 Base64 字符串，说明加解密一切正常）
cat /tmp/privatekey   /tmp/publickey

# 3. 现场物理拉起一个名叫 wg0 的虚拟网络接口
ip link add dev wg0 type wireguard

# 3. 现场物理生成一个测试私钥，并直接通过 wg 命令强制钉进 wg0 接口里！
#（这一步是关键！赋予它加密身份，内核才会对它完全放开限制）
wg genkey > /tmp/wg_test.key
wg set wg0 private-key /tmp/wg_test.key

# 4. 检查网络接口是否成功钉入 Linux 内核网络栈
ip link show wg0
注意：能看到wg0: <POINTOPOINT,NOARP> mtu 1420 ... 的网络，但是没有IP且是DOWN状态

现场物理唤醒：怎么给它灌入 IP 并拉起(UP)
# 1. 强行给 wg0 接口物理绑定一个内网私有 IP（比如 10.0.0.1/24）
ip address add 10.0.0.1/24 dev wg0

# 2. 物理执行上线命令，把它的状态从 DOWN 强行改成 UP！
ip link set mtu 1420 up dev wg0

# 3. 再次执行你刚才的检查命令，状态将变成有IP且变成up
ip addr show wg0                

验证爽了之后，别忘了执行最后一步把它物理回收，不留一丝垃圾：
ip link delete dev wg0 && rm -f /tmp/wg_test.key             # 一切都将收回

如何确保重启后 WireGuard 自动保持 UP 且带 IP？
1、物理固件：固定你的密钥对
# 创建配置目录
mkdir -pv /etc/systemd/network

# 生成私钥并存入安全文件
wg genkey > /etc/systemd/network/wg0.key
# 顺便看一下公钥，拿小本本记下来，待会儿你远程连它时要用到：
wg pubkey < /etc/systemd/network/wg0.key > /etc/systemd/network/wg0.pub
cat /etc/systemd/network/wg0.pub

2、编写网络虚拟接口描述文件 (.netdev)
告诉 systemd-networkd，开机时在内核里自动创建一个名为 wg0 的 WireGuard 类型网卡，并注入你的私钥文件：
cat > /etc/systemd/network/25-wg0.netdev << "EOF"
[NetDev]
Name=wg0
Kind=wireguard

[WireGuard]
PrivateKeyFile=/etc/systemd/network/wg0.key
ListenPort=51820
EOF

3、编写网络地址与路由描述文件 (.network)
告诉系统当 wg0 网卡创建出来后，自动把 10.0.0.1/24 这个 IP 挂上去，并保持 UP 状态
cat > /etc/systemd/network/25-wg0.network << "EOF"
[Match]
Name=wg0

[Network]
Address=10.0.0.1/24
EOF


# 网络服务配置
1. 创建服务重写目录
Systemd 允许我们通过 override.conf（也叫 Drop-in 文件）在不破坏原本服务文件的前提下，强行塞入我们自己的私人命令。
mkdir -pv /etc/systemd/system/systemd-networkd.service.d
2. 强行注入预启动命令（ExecStartPre）
我们要告诉 systemd-networkd：在你正式创建网卡之前，必须、绝对要先在内核里执行一遍 modprobe wireguard！
cat > /etc/systemd/system/systemd-networkd.service.d/override.conf << "EOF"
[Service]
# ExecStartPre 代表在服务核心动作启动前强制执行的命令
# 前面加个减号 "-" 代表即使这个命令报错（比如模块已经加载过了），服务也继续往下走，不卡死
ExecStartPre=-/usr/sbin/modprobe wireguard
EOF
3. 顺便对齐一下密钥文件的权限组（防止网络服务由于权限读取失败）
刚才也提到过，网络大总管需要读取你的私钥，我们顺手把它的所有权划给 systemd-network 账户：
chown root:systemd-network /etc/systemd/network/wg0.key
chmod 640 /etc/systemd/network/wg0.key
4. 刷新 Systemd 引擎并现场硬核测试
配置写完后，我们让 Systemd 重新装载所有配置文件，并直接重启网络服务：
# 1. 让 systemd 重新扫描你刚刚写进去的 override.conf 补丁
systemctl daemon-reload

# 2. 强行重启网络大总管
systemctl restart systemd-networkd
systemctl restart systemd-networkd

# 3. 现场肉眼核对，看看 wg0 出来了没有
ip addr show wg0
注意：reboot后也依然在




# 客户端端连接













```

