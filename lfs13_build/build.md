# 前奏
```shell
8u/16G
80G: linux system
60G: LFS
172.16.186.128/24

以下会使用root用户进行操作，使用普通用户执行命令时部分会出问题


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



## 设置$LFS变量和Umask
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
├─sdb2 swap   1           26b2d0a0-736c-45bd-a327-2b616daf6b78                [SWAP]
└─sdb3 ext4   1.0         4469f1c7-6775-489d-b83c-57df7cc185f4        
        
root@ub24-1:~# echo 'UUID=4469f1c7-6775-489d-b83c-57df7cc185f4  /mnt/lfs  ext4  defaults 0 0' | tee -a /etc/fstab 
root@ub24-1:~# systemctl daemon-reload
root@ub24-1:~# mount -a
root@ub24-1:~# df -Th /mnt/lfs/
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/sdb3      ext4   53G   24K   51G   1% /mnt/lfs

将$LFS目录 (即为LFS系统新创建的文件系统的根目录) 的所有者设为root，访问权限设为755，以防个别宿主发行版中mkfs被配置为使用与此不同的默认值
root@ub24-1:~$ chown root:root $LFS && sudo chmod 755 $LFS


```



## 软件包和补丁
```shell
root@ub24-1:~$ mkdir $LFS/sources && chmod  a+wt $LFS/sources
root@ub24-1:~$ cd $LFS/sources/
root@ub24-1:/mnt/lfs/sources# 


# ================== 这部分不在官方文档中 ================================
# 需要单独下载的包
root@ub24-1:/mnt/lfs/sources$ wget https://mirrors.aliyun.com/openssh/portable/openssh-10.1p1.tar.gz \
https://www.thrysoee.dk/editline/libedit-20251016-3.1.tar.gz
 
注意：
如果需要创建好的LFS有更多的功能，需要单独下载并安装包，这里就只做备用和测试
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


```




## [最后准备工作](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter04/chapter04.html)
```shell
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
## 编译交叉工具链
```shell
# Binutils-2.46.0 - 第1遍
lfs@ub24-1:/mnt/lfs/sources$ tar xvf binutils-2.46.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ ../configure --prefix=$LFS/tools \
 --with-sysroot=$LFS \
 --target=$LFS_TGT   \
 --disable-nls       \
 --enable-gprofng=no \
 --disable-werror    \
 --enable-new-dtags  \
 --enable-default-hash-style=gnu

lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ make -j$(nproc) && make install
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
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ../configure                  \
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


lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ make -j$(nproc) && make install

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


lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ make -j$(nproc) && make DESTDIR=$LFS install

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
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
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

lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ make -j$(nproc) && make DESTDIR=$LFS install
删除 libtool 归档文件，因为它们对交叉编译有害：
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la

lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ cd ../.. && rm -rf gcc-15.2.0


```




## 交叉编译临时工具
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
lfs@ub24-1:/mnt/lfs/sources/xz-5.8.2$ ./configure --prefix=/usr \
--host=$LFS_TGT                   \
--build=$(build-aux/config.guess) \
--disable-static                  \
--docdir=/usr/share/doc/xz-5.8.2

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

lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ make -j$(nproc) && make DESTDIR=$LFS install
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

lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ln -sv gcc $LFS/usr/bin/cc
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ cd ../.. && rm -rf gcc-15.2.0


```




## 进入Chroot环境并构建额外的临时工具
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





## [进入Chroot环境](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter07/chroot.html)
```shell
root@ub24-1:/mnt/lfs/sources# chroot "$LFS" /usr/bin/env -i \
HOME=/root                  \
TERM="$TERM"                \
PS1='(lfs chroot) \u:\w\$ ' \
PATH=/usr/bin:/usr/sbin     \
MAKEFLAGS="-j$(nproc)"      \
TESTSUITEFLAGS="-j$(nproc)" \
/bin/bash --login

```


## [创建目录](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter07/creatingdirs.html)
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

(lfs chroot) root:/sources/perl-5.42.0# make -j$(nproc) && make install
(lfs chroot) root:/sources/perl-5.42.0# cd .. && rm -rf perl-5.42.0


# Python-3.14.3
(lfs chroot) root:/sources# tar -xvf Python-3.14.3.tar.xz
(lfs chroot) root:/sources# cd Python-3.14.3
(lfs chroot) root:/sources/Python-3.14.3# ./configure --prefix=/usr --enable-shared --without-ensurepip --without-static-libpython && make -j$(nproc) && make install
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




## [清理和保存临时系统](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter07/cleanup.html)
```shell
(lfs chroot) root:/sources# rm -rf /usr/share/{info,man,doc}/*

在现代 Linux 系统中，libtool 的 .la 文件仅对libltdl有用。libltdl不会加载LFS中的任何库，而且已知某些.la文件会导致BLFS包加载失败。删除这些文件：
(lfs chroot) root:/sources# find /usr/{lib,libexec} -name \*.la -delete

当前系统大小约为3GB，但 /tools 目录已不再需要。它占用约 1 GB 的磁盘空间。请立即删除它：
(lfs chroot) root:/sources# rm -rf /tools


这里我没备份


```





# [构建LFS系统](https://linuxfromscratch.org/lfs/view/stable-systemd/part4.html)
## [安装基本系统软件](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter08/chapter08.html)
```shell
# man-page-6.17
(lfs chroot) root:/sources# tar -xvf man-pages-6.17.tar.xz
(lfs chroot) root:/sources# cd man-pages-6.17
(lfs chroot) root:/sources/man-pages-6.17# rm man3/crypt*
(lfs chroot) root:/sources/man-pages-6.17# make -R GIT=false prefix=/usr install
(lfs chroot) root:/sources/man-pages-6.17# cd .. && rm -rf man-pages-6.17


# iana-Etc-20260202
(lfs chroot) root:/sources# tar -zxvf iana-etc-20260202.tar.gz
(lfs chroot) root:/sources# cd iana-etc-20260202
(lfs chroot) root:/sources/iana-etc-20260202# cp -v services protocols /etc
(lfs chroot) root:/sources/iana-etc-20260202# cd .. && rm -rf iana-etc-20260202


# Glibc-2.43
刷新环境
(lfs chroot) root:/sources# hash -r

(lfs chroot) root:/sources# tar xvf glibc-2.43.tar.xz
(lfs chroot) root:/sources# cd glibc-2.43
(lfs chroot) root:/sources/glibc-2.43# patch -Np1 -i ../glibc-fhs-1.patch
(lfs chroot) root:/sources/glibc-2.43# mkdir build && cd build
(lfs chroot) root:/sources/glibc-2.43/build# echo "rootsbindir=/usr/sbin" > configparms
(lfs chroot) root:/sources/glibc-2.43/build# ../configure --prefix=/usr \
--disable-werror                \
--disable-nscd                  \
libc_cv_slibdir=/usr/lib        \
--enable-stack-protector=strong \
--enable-kernel=5.4

(lfs chroot) root:/sources/glibc-2.43/build# make -j$(nproc) && touch /etc/ld.so.conf && sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile && make install

(lfs chroot) root:/sources/glibc-2.43/build# sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

用localedef程序 安装单个语言环境
(lfs chroot) root:/sources/glibc-2.43/build#             # 本次使用该方式
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


安装文件中列出的所有语言环境
(lfs chroot) root:/sources/glibc-2.43/build# make localedata/install-locales


# 配置Glibc
# 添加nsswitch.conf
(lfs chroot) root:/sources/glibc-2.43/build# cat > /etc/nsswitch.conf << "EOF"
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
(lfs chroot) root:/sources/glibc-2.43/build# tar -xf ../../tzdata2025c.tar.gz
(lfs chroot) root:/sources/glibc-2.43/build#
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


# 配置动态加载器
(lfs chroot) root:/sources/glibc-2.43/build# cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF

(lfs chroot) root:/sources/glibc-2.43/build# cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF
mkdir -pv /etc/ld.so.conf.d

(lfs chroot) root:/sources/glibc-2.43/build# cd ../.. && rm -rf glibc-2.43



# Zlib-1.3.2
(lfs chroot) root:/sources# tar zxvf zlib-1.3.2.tar.gz
(lfs chroot) root:/sources# cd zlib-1.3.2
(lfs chroot) root:/sources/zlib-1.3.2# ./configure --prefix=/usr && make -j$(nproc) && make install && rm -fv /usr/lib/libz.a
(lfs chroot) root:/sources/zlib-1.3.2# cd .. && rm -rf zlib-1.3.2


# Bzip2-1.0.8
(lfs chroot) root:/sources# tar zxvf bzip2-1.0.8.tar.gz
(lfs chroot) root:/sources# cd bzip2-1.0.8
(lfs chroot) root:/sources/bzip2-1.0.8# patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
(lfs chroot) root:/sources/bzip2-1.0.8# sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
(lfs chroot) root:/sources/bzip2-1.0.8# sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
(lfs chroot) root:/sources/bzip2-1.0.8# make -f Makefile-libbz2_so
(lfs chroot) root:/sources/bzip2-1.0.8# make clean
(lfs chroot) root:/sources/bzip2-1.0.8# make -j$(nproc) && make PREFIX=/usr install
(lfs chroot) root:/sources/bzip2-1.0.8# 
安装共享库：
cp -av libbz2.so.* /usr/lib
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so

(lfs chroot) root:/sources/bzip2-1.0.8# ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1
(lfs chroot) root:/sources/bzip2-1.0.8# cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
(lfs chroot) root:/sources/bzip2-1.0.8# rm -fv /usr/lib/libbz2.a
(lfs chroot) root:/sources/bzip2-1.0.8# cd .. && rm -rf bzip2-1.0.8


# Xz-5.8.2
(lfs chroot) root:/sources# tar xvf xz-5.8.2.tar.xz
(lfs chroot) root:/sources# cd xz-5.8.2
(lfs chroot) root:/sources/xz-5.8.2# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/xz-5.8.2 && make -j$(nproc) && make install
(lfs chroot) root:/sources/xz-5.8.2# cd .. && rm -rf xz-5.8.2


# lz4-1.10.0
(lfs chroot) root:/sources# tar zxvf lz4-1.10.0.tar.gz
(lfs chroot) root:/sources# cd lz4-1.10.0
(lfs chroot) root:/sources/lz4-1.10.0# make BUILD_STATIC=no PREFIX=/usr && make BUILD_STATIC=no PREFIX=/usr install
(lfs chroot) root:/sources/lz4-1.10.0# cd .. && rm -rf lz4-1.10.0


# zstd-1.5.7
(lfs chroot) root:/sources# tar zxvf zstd-1.5.7.tar.gz
(lfs chroot) root:/sources# cd zstd-1.5.7
(lfs chroot) root:/sources/zstd-1.5.7# make prefix=/usr && make -j$(nproc) prefix=/usr install && rm -v /usr/lib/libzstd.a
(lfs chroot) root:/sources/zstd-1.5.7# cd .. && rm -rf zstd-1.5.7


# file-5.46
(lfs chroot) root:/sources# tar zxvf file-5.46.tar.gz
(lfs chroot) root:/sources# cd file-5.46
(lfs chroot) root:/sources/file-5.46# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/file-5.46# cd .. && rm -rf file-5.46


# Readline-8.3
(lfs chroot) root:/sources# tar zxvf readline-8.3.tar.gz
(lfs chroot) root:/sources# cd readline-8.3
(lfs chroot) root:/sources/readline-8.3# 
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
sed -e '270a\
     else\
       chars_avail = 1;'      \
    -e '288i\   result = -1;' \
    -i.orig input.c
(lfs chroot) root:/sources/readline-8.3# ./configure --prefix=/usr --disable-static --with-curses --docdir=/usr/share/doc/readline-8.3

(lfs chroot) root:/sources/readline-8.3# 
make SHLIB_LIBS="-lncursesw" && make install
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3

(lfs chroot) root:/sources/readline-8.3# cd .. && rm -rf readline-8.3



# Pcre2-10.47
(lfs chroot) root:/sources# tar jxvf pcre2-10.47.tar.bz2
(lfs chroot) root:/sources# cd pcre2-10.47
(lfs chroot) root:/sources/pcre2-10.47# ./configure --prefix=/usr \
--docdir=/usr/share/doc/pcre2-10.47 \
--enable-unicode                    \
--enable-jit                        \
--enable-pcre2-16                   \
--enable-pcre2-32                   \
--enable-pcre2grep-libz             \
--enable-pcre2grep-libbz2           \
--enable-pcre2test-libreadline      \
--disable-static

(lfs chroot) root:/sources/pcre2-10.47# make -j$(nproc) && make install
(lfs chroot) root:/sources/pcre2-10.47# cd .. && rm -rf pcre2-10.47


# M4-1.4.21
(lfs chroot) root:/sources# tar xvf m4-1.4.21.tar.xz
(lfs chroot) root:/sources# cd m4-1.4.21
(lfs chroot) root:/sources/m4-1.4.21# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/m4-1.4.21# cd .. && rm -rf m4-1.4.21


# Bc-7.0.3
(lfs chroot) root:/sources# tar xvf bc-7.0.3.tar.xz
(lfs chroot) root:/sources# cd bc-7.0.3
(lfs chroot) root:/sources/bc-7.0.3# CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
(lfs chroot) root:/sources/bc-7.0.3# make -j$(nproc) && make install
(lfs chroot) root:/sources/bc-7.0.3# cd .. && rm -rf bc-7.0.3


# Flex-2.6.4
(lfs chroot) root:/sources# tar zxvf flex-2.6.4.tar.gz 
(lfs chroot) root:/sources# cd flex-2.6.4
(lfs chroot) root:/sources/flex-2.6.4# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/flex-2.6.4 && make -j$(nproc) && make install
(lfs chroot) root:/sources/flex-2.6.4# ln -sv flex   /usr/bin/lex && ln -sv flex.1 /usr/share/man/man1/lex.1
(lfs chroot) root:/sources/flex-2.6.4# cd .. && rm -rf flex-2.6.4


# Tcl-8.6.17
(lfs chroot) root:/sources# tar zxvf tcl8.6.17-src.tar.gz
(lfs chroot) root:/sources# cd tcl8.6.17
(lfs chroot) root:/sources/tcl8.6.17# SRCDIR=$(pwd)
(lfs chroot) root:/sources/tcl8.6.17# cd unix/
(lfs chroot) root:/sources/tcl8.6.17/unix# ./configure --prefix=/usr --mandir=/usr/share/man --disable-rpath
(lfs chroot) root:/sources/tcl8.6.17/unix# make -j$(nproc)

sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.12|/usr/lib/tdbc1.1.12|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12/generic|/usr/include|"     \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12/library|/usr/lib/tcl8.6|"  \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12|/usr/include|"             \
    -i pkgs/tdbc1.1.12/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.4|/usr/lib/itcl4.3.4|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.4/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.3.4|/usr/include|"            \
    -i pkgs/itcl4.3.4/itclConfig.sh

(lfs chroot) root:/sources/tcl8.6.17/unix# unset SRCDIR
(lfs chroot) root:/sources/tcl8.6.17/unix# make install && chmod 644 /usr/lib/libtclstub8.6.a

(lfs chroot) root:/sources/tcl8.6.17/unix# 
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
mv -v /usr/share/man/man3/{Thread,Tcl_Thread}.3

(lfs chroot) root:/sources/tcl8.6.17/unix# cd ..
(lfs chroot) root:/sources/tcl8.6.17# 
tar -xf ../tcl8.6.17-html.tar.gz --strip-components=1
mkdir -v -p /usr/share/doc/tcl-8.6.17
cp -v -r  ./html/* /usr/share/doc/tcl-8.6.17

(lfs chroot) root:/sources/tcl8.6.17# cd .. && rm -rf tcl8.6.17



# Expect-5.45.4
(lfs chroot) root:/sources# tar zxvf expect5.45.4.tar.gz
(lfs chroot) root:/sources# cd expect5.45.4
(lfs chroot) root:/sources/expect5.45.4# python3 -c 'from pty import spawn; spawn(["echo", "ok"])'
(lfs chroot) root:/sources/expect5.45.4# patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
(lfs chroot) root:/sources/expect5.45.4# ./configure --prefix=/usr \
--with-tcl=/usr/lib     \
--enable-shared         \
--disable-rpath         \
--mandir=/usr/share/man \
--with-tclinclude=/usr/include

(lfs chroot) root:/sources/expect5.45.4# make -j$(nproc) && make install
(lfs chroot) root:/sources/expect5.45.4# ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
(lfs chroot) root:/sources/expect5.45.4# cd .. && rm -rf expect5.45.4


# DejaGNU-1.6.3
(lfs chroot) root:/sources# tar zxvf dejagnu-1.6.3.tar.gz
(lfs chroot) root:/sources# cd dejagnu-1.6.3
(lfs chroot) root:/sources/dejagnu-1.6.3# mkdir build && cd build
(lfs chroot) root:/sources/dejagnu-1.6.3/build# ../configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi

(lfs chroot) root:/sources/dejagnu-1.6.3/build# make install
(lfs chroot) root:/sources/dejagnu-1.6.3/build# 
install -v -dm755  /usr/share/doc/dejagnu-1.6.3
install -v -m644   doc/dejagnu.{html,txt}  /usr/share/doc/dejagnu-1.6.3

(lfs chroot) root:/sources/dejagnu-1.6.3/build# cd ../.. && rm -rf dejagnu-1.6.3



# Pkgconf-2.5.1
(lfs chroot) root:/sources# tar xvf pkgconf-2.5.1.tar.xz
(lfs chroot) root:/sources# cd pkgconf-2.5.1
(lfs chroot) root:/sources/pkgconf-2.5.1# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/pkgconf-2.5.1 && make -j$(nproc) && make install

(lfs chroot) root:/sources/pkgconf-2.5.1# 
ln -sv pkgconf   /usr/bin/pkg-config
ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1

(lfs chroot) root:/sources/pkgconf-2.5.1# cd .. && rm -rf pkgconf-2.5.1



# Binutils-2.46.0
(lfs chroot) root:/sources# tar xvf binutils-2.46.0.tar.xz
(lfs chroot) root:/sources# cd binutils-2.46.0
(lfs chroot) root:/sources/binutils-2.46.0# mkdir build && cd build
(lfs chroot) root:/sources/binutils-2.46.0/build# ../configure --prefix=/usr \
--sysconfdir=/etc   \
--enable-ld=default \
--enable-plugins    \
--enable-shared     \
--disable-werror    \
--enable-64-bit-bfd \
--enable-new-dtags  \
--with-system-zlib  \
--enable-default-hash-style=gnu

(lfs chroot) root:/sources/binutils-2.46.0/build# make tooldir=/usr && grep '^FAIL:' $(find -name '*.log')
(lfs chroot) root:/sources/binutils-2.46.0/build# make tooldir=/usr install
(lfs chroot) root:/sources/binutils-2.46.0/build# rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a   /usr/share/doc/gprofng/
(lfs chroot) root:/sources/binutils-2.46.0/build# cd ../.. && rm -rf binutils-2.46.0


# GMP-6.3.0
(lfs chroot) root:/sources# tar xvf gmp-6.3.0.tar.xz
(lfs chroot) root:/sources# cd gmp-6.3.0
(lfs chroot) root:/sources/gmp-6.3.0# sed -i '/long long t1;/,+1s/()/(...)/' configure
(lfs chroot) root:/sources/gmp-6.3.0# ./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.3.0
(lfs chroot) root:/sources/gmp-6.3.0# make -j$(nproc) && make html
检验结果：
(lfs chroot) root:/sources/gmp-6.3.0# make check 2>&1 | tee gmp-check-log
(lfs chroot) root:/sources/gmp-6.3.0# awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
(lfs chroot) root:/sources/gmp-6.3.0# make install && make install-html
(lfs chroot) root:/sources/gmp-6.3.0# cd .. && rm -rf gmp-6.3.0


# MPFR-4.2.2
(lfs chroot) root:/sources# tar xvf mpfr-4.2.2.tar.xz
(lfs chroot) root:/sources# cd mpfr-4.2.2
(lfs chroot) root:/sources/mpfr-4.2.2# ./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.2 && \
make -j$(nproc) && make html && make install&& make install-html

(lfs chroot) root:/sources/mpfr-4.2.2# cd .. && rm -rf mpfr-4.2.2



# MPC-1.3.1
(lfs chroot) root:/sources# tar zxvf mpc-1.3.1.tar.gz
(lfs chroot) root:/sources# cd mpc-1.3.1
(lfs chroot) root:/sources/mpc-1.3.1# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpc-1.3.1
(lfs chroot) root:/sources/mpc-1.3.1# make -j$(nproc) && make html && make install && make install-html
(lfs chroot) root:/sources/mpc-1.3.1# cd .. && rm -rf mpc-1.3.1



# Attr-2.5.2
(lfs chroot) root:/sources# tar zxvf attr-2.5.2.tar.gz
(lfs chroot) root:/sources# cd attr-2.5.2
(lfs chroot) root:/sources/attr-2.5.2# ./configure --prefix=/usr --disable-static  \
--sysconfdir=/etc --docdir=/usr/share/doc/attr-2.5.2 && make -j$(nproc) && make install
(lfs chroot) root:/sources/attr-2.5.2# cd .. && rm -rf attr-2.5.2


# Acl-2.3.2
(lfs chroot) root:/sources# tar xvf acl-2.3.2.tar.xz
(lfs chroot) root:/sources# cd acl-2.3.2
(lfs chroot) root:/sources/acl-2.3.2# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/acl-2.3.2 && make -j$(nproc) && make install
(lfs chroot) root:/sources/acl-2.3.2# cd .. && rm -rf acl-2.3.2


# Libcap-2.77
(lfs chroot) root:/sources# tar xvf libcap-2.77.tar.xz 
(lfs chroot) root:/sources# cd libcap-2.77
(lfs chroot) root:/sources/libcap-2.77# sed -i '/install -m.*STA/d' libcap/Makefile
(lfs chroot) root:/sources/libcap-2.77# make prefix=/usr lib=lib && make prefix=/usr lib=lib install
(lfs chroot) root:/sources/libcap-2.77# cd .. && rm -rf libcap-2.77


# Libxcrypt-4.5.2
(lfs chroot) root:/sources# tar xvf libxcrypt-4.5.2.tar.xz 
(lfs chroot) root:/sources# cd libxcrypt-4.5.2
(lfs chroot) root:/sources/libxcrypt-4.5.2# sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c
(lfs chroot) root:/sources/libxcrypt-4.5.2# ./configure --prefix=/usr --enable-hashes=strong,glibc \
--enable-obsolete-api=no --disable-static --disable-failure-tokens
(lfs chroot) root:/sources/libxcrypt-4.5.2# make -j$(nproc) && make install
(lfs chroot) root:/sources/libxcrypt-4.5.2# cd .. && rm -rf libxcrypt-4.5.2


# Shadow-4.19.3
(lfs chroot) root:/sources# tar xvf shadow-4.19.3.tar.xz
(lfs chroot) root:/sources# cd shadow-4.19.3
(lfs chroot) root:/sources/shadow-4.19.3# 
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;


(lfs chroot) root:/sources/shadow-4.19.3# sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs

(lfs chroot) root:/sources/shadow-4.19.3# touch /usr/bin/passwd
(lfs chroot) root:/sources/shadow-4.19.3# ./configure --sysconfdir=/etc --disable-static --with-{b,yes}crypt \
--without-libbsd  --disable-logind  --with-group-name-max-length=32

(lfs chroot) root:/sources/shadow-4.19.3# make -j$(nproc) && make exec_prefix=/usr install && make -C man install-man
(lfs chroot) root:/sources/shadow-4.19.3# pwconv && grpconv
(lfs chroot) root:/sources/shadow-4.19.3# mkdir -p /etc/default && useradd -D --gid 999
(lfs chroot) root:/sources/shadow-4.19.3# passwd root             # 密码是6a
(lfs chroot) root:/sources/shadow-4.19.3# cd .. && rm -rf shadow-4.19.3



# GCC-15.2.0
(lfs chroot) root:/sources# tar xvf gcc-15.2.0.tar.xz
(lfs chroot) root:/sources# cd gcc-15.2.0
(lfs chroot) root:/sources/gcc-15.2.0# sed -i 's/char [*]q/const &/' libgomp/affinity-fmt.c

如果在 x86_64 平台上构建，请将 64 位库的默认目录名称更改为"lib"：
(lfs chroot) root:/sources/gcc-15.2.0# case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

(lfs chroot) root:/sources/gcc-15.2.0# mkdir build && cd build
(lfs chroot) root:/sources/gcc-15.2.0/build# ../configure --prefix=/usr  LD=ld --enable-languages=c,c++ \
--enable-default-pie --enable-default-ssp --enable-host-pie --disable-multilib --disable-bootstrap --disable-fixincludes --with-system-zlib

(lfs chroot) root:/sources/gcc-15.2.0/build# make -j$(nproc) 
(lfs chroot) root:/sources/gcc-15.2.0/build# ulimit -s -H unlimited
(lfs chroot) root:/sources/gcc-15.2.0/build# sed -e '/cpython/d' -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp
(lfs chroot) root:/sources/gcc-15.2.0/build# make install
GCC 构建目录tester目前属于某个用户，而已安装的头文件目录（及其内容）的所有权不正确。请将所有权更改为指定root的用户和组：
(lfs chroot) root:/sources/gcc-15.2.0/build# chown -v -R root:root  /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include{,-fixed}

创建FHS出于"历史"原因 要求的符号链接
(lfs chroot) root:/sources/gcc-15.2.0/build# ln -svr /usr/bin/cpp /usr/lib

许多软件包使用cc 这个名称来调用 C 编译器。我们已经在gcc-pass2中创建了cc的符号链接，也请将其手册页创建为符号链接：
(lfs chroot) root:/sources/gcc-15.2.0/build# ln -sv gcc.1 /usr/share/man/man1/cc.1

添加兼容性符号链接，以启用使用链接时优化 (LTO) 构建程序：
(lfs chroot) root:/sources/gcc-15.2.0/build# ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/15.2.0/liblto_plugin.so /usr/lib/bfd-plugins/

现在工具链已经就绪，接下来需要再次确保编译和链接能够按预期工作。为此，我们执行一些健全性检查：
(lfs chroot) root:/sources/gcc-15.2.0/build# echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
(lfs chroot) root:/sources/gcc-15.2.0/build# readelf -l a.out | grep ': /lib'
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]               # 该行是输出

确保已设置好要使用正确的启动文件(重点是gcc是否已在/usr/lib目录下找到所有三个crt*.o文件)
(lfs chroot) root:/sources/gcc-15.2.0/build# grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log      # 以下三行是输出
/usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/../../../../lib/Scrt1.o succeeded
/usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/../../../../lib/crti.o succeeded
/usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/../../../../lib/crtn.o succeeded

验证编译器是否正在查找正确的头文件：
(lfs chroot) root:/sources/gcc-15.2.0/build# grep -B4 '^ /usr/include' dummy.log
#include <...> search starts here:
 /usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/include
 /usr/local/include
 /usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/include-fixed
 /usr/include
注意：根据您的系统架构，以目标三元组命名的目录可能与上述目录不同


验证新链接器是否使用了正确的搜索路径：
(lfs chroot) root:/sources/gcc-15.2.0/build# grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib64")
SEARCH_DIR("/usr/local/lib64")
SEARCH_DIR("/lib64")
SEARCH_DIR("/usr/lib64")
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib")
SEARCH_DIR("/usr/local/lib")
SEARCH_DIR("/lib")
SEARCH_DIR("/usr/lib");

确保我们使用的是正确的libc库：
(lfs chroot) root:/sources/gcc-15.2.0/build# grep "/lib.*/libc.so.6 " dummy.log
attempt to open /usr/lib/libc.so.6 succeeded               # 输出应该是这个

确保GCC使用的是正确的动态链接器：
(lfs chroot) root:/sources/gcc-15.2.0/build# grep found dummy.log
found ld-linux-x86-64.so.2 at /usr/lib/ld-linux-x86-64.so.2                # 动态链接器名称可能因平台而异

一切运行正常后，清理测试文件：
(lfs chroot) root:/sources/gcc-15.2.0/build# rm -v a.out dummy.log
最后，移动一个放错位置的文件：
(lfs chroot) root:/sources/gcc-15.2.0/build# 
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

(lfs chroot) root:/sources/gcc-15.2.0/build# cd ../.. && rm -rf gcc-15.2.0



# Ncurses-6.6
(lfs chroot) root:/sources# tar zxvf ncurses-6.6.tar.gz
(lfs chroot) root:/sources# cd ncurses-6.6
(lfs chroot) root:/sources/ncurses-6.6# ./configure --prefix=/usr  \
--mandir=/usr/share/man \
--with-shared           \
--without-debug         \
--without-normal        \
--with-cxx-shared       \
--enable-pc-files       \
--with-pkg-config-libdir=/usr/lib/pkgconfig

(lfs chroot) root:/sources/ncurses-6.6# make -j$(nproc) && make DESTDIR=$PWD/dest install
(lfs chroot) root:/sources/ncurses-6.6# sed -e 's/^#if.*XOPEN.*$/#if 1/' -i dest/usr/include/curses.h
(lfs chroot) root:/sources/ncurses-6.6# cp --remove-destination -av dest/*  /
(lfs chroot) root:/sources/ncurses-6.6# 
for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done

(lfs chroot) root:/sources/ncurses-6.6# ln -sfv libncursesw.so /usr/lib/libcurses.so
(lfs chroot) root:/sources/ncurses-6.6# cp -v -R doc -T /usr/share/doc/ncurses-6.6
(lfs chroot) root:/sources/ncurses-6.6# cd .. && rm -rf ncurses-6.6


# Sed-4.9
(lfs chroot) root:/sources# tar xvf sed-4.9.tar.xz
(lfs chroot) root:/sources# cd sed-4.9
(lfs chroot) root:/sources/sed-4.9# ./configure --prefix=/usr && make -j$(nproc) && make html && make install
(lfs chroot) root:/sources/sed-4.9# 
install -d -m755           /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9

(lfs chroot) root:/sources/sed-4.9# cd .. && rm -rf sed-4.9


# Psmisc-23.7
(lfs chroot) root:/sources# tar xvf psmisc-23.7.tar.xz
(lfs chroot) root:/sources# cd psmisc-23.7
(lfs chroot) root:/sources/psmisc-23.7# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/psmisc-23.7# cd .. && rm -rf psmisc-23.7


# Gettext-1.0
(lfs chroot) root:/sources# tar xvf gettext-1.0.tar.xz
(lfs chroot) root:/sources# cd gettext-1.0
(lfs chroot) root:/sources/gettext-1.0# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/gettext-1.0 && make -j$(nproc) && make install
(lfs chroot) root:/sources/gettext-1.0# chmod -v 0755 /usr/lib/preloadable_libintl.so
(lfs chroot) root:/sources/gettext-1.0# cd .. && rm -rf gettext-1.0


# Bison-3.8.2
(lfs chroot) root:/sources# tar xvf bison-3.8.2.tar.gz
(lfs chroot) root:/sources# cd bison-3.8.2 
(lfs chroot) root:/sources/bison-3.8.2# ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2 && make -j$(nproc) && make install
(lfs chroot) root:/sources/bison-3.8.2# cd .. && rm -rf bison-3.8.2 


# Grep-3.12
(lfs chroot) root:/sources# tar xvf grep-3.12.tar.xz
(lfs chroot) root:/sources# cd grep-3.12
(lfs chroot) root:/sources/grep-3.12# sed -i "s/echo/#echo/" src/egrep.sh
(lfs chroot) root:/sources/grep-3.12# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/grep-3.12# cd .. && rm -rf grep-3.12


# Bash-5.3
(lfs chroot) root:/sources# tar zxvf bash-5.3.tar.gz
(lfs chroot) root:/sources# cd bash-5.3
(lfs chroot) root:/sources/bash-5.3# ./configure --prefix=/usr --without-bash-malloc --with-installed-readline --docdir=/usr/share/doc/bash-5.3
(lfs chroot) root:/sources/bash-5.3# make -j$(nproc) && make install
运行新编译的bash程序（替换当前正在执行的程序）：
(lfs chroot) root:/sources/bash-5.3# exec /usr/bin/bash --login
(lfs chroot) root:/sources/bash-5.3# cd .. && rm -rf bash-5.3


# Libtool-2.5.4
(lfs chroot) root:/sources# tar xvf libtool-2.5.4.tar.xz
(lfs chroot) root:/sources# cd libtool-2.5.4
(lfs chroot) root:/sources/libtool-2.5.4# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/libtool-2.5.4# cd .. && rm -rf libtool-2.5.4


# GDBM-1.26
(lfs chroot) root:/sources# tar zxvf gdbm-1.26.tar.gz
(lfs chroot) root:/sources# cd gdbm-1.26
(lfs chroot) root:/sources/gdbm-1.26# ./configure --prefix=/usr --disable-static --enable-libgdbm-compat && make -j$(nproc) && make install
(lfs chroot) root:/sources/gdbm-1.26# cd .. && rm -rf gdbm-1.26


# Gperf-3.3
(lfs chroot) root:/sources# tar zxvf gperf-3.3.tar.gz
(lfs chroot) root:/sources# cd gperf-3.3
(lfs chroot) root:/sources/gperf-3.3# ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3 && make -j$(nproc) && make install
(lfs chroot) root:/sources/gperf-3.3# cd .. && rm -rf gperf-3.3


# Expat-2.7.4
(lfs chroot) root:/sources# tar xvf expat-2.7.4.tar.xz
(lfs chroot) root:/sources# cd expat-2.7.4
(lfs chroot) root:/sources/expat-2.7.4# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/expat-2.7.4 && make -j$(nproc) && make install
(lfs chroot) root:/sources/expat-2.7.4# install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.4
(lfs chroot) root:/sources/expat-2.7.4# cd .. && rm -rf expat-2.7.4


# Inetutils-2.7
(lfs chroot) root:/sources# tar zxvf inetutils-2.7.tar.gz
(lfs chroot) root:/sources# cd inetutils-2.7
(lfs chroot) root:/sources/inetutils-2.7# sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
(lfs chroot) root:/sources/inetutils-2.7# ./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var \
--disable-logger     \
--disable-whois      \
--disable-rcp        \
--disable-rexec      \
--disable-rlogin     \
--disable-rsh        \
--disable-servers

(lfs chroot) root:/sources/inetutils-2.7# make -j$(nproc) && make install
(lfs chroot) root:/sources/inetutils-2.7# mv -v /usr/{,s}bin/ifconfig
(lfs chroot) root:/sources/inetutils-2.7# cd .. && rm -rf  inetutils-2.7


# Less-692
(lfs chroot) root:/sources# tar zxvf less-692.tar.gz
(lfs chroot) root:/sources# cd less-692
(lfs chroot) root:/sources/less-692# ./configure --prefix=/usr --sysconfdir=/etc && make -j$(nproc) && make install
(lfs chroot) root:/sources/less-692# cd .. && rm -rf less-692


# Perl-5.42.0
(lfs chroot) root:/sources# tar xvf perl-5.42.0.tar.xz 
Perl 会使用内部源代码副本进行构建。要使 Perl 使用系统上已安装的库，请执行以下命令：
(lfs chroot) root:/sources# cd perl-5.42.0
(lfs chroot) root:/sources/perl-5.42.0# export BUILD_ZLIB=False && export BUILD_BZIP2=0
(lfs chroot) root:/sources/perl-5.42.0# sh Configure -des   \
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

(lfs chroot) root:/sources/perl-5.42.0# make -j$(nproc) && make install
(lfs chroot) root:/sources/perl-5.42.0# unset BUILD_ZLIB BUILD_BZIP2
(lfs chroot) root:/sources/perl-5.42.0# cd .. && rm -rf perl-5.42.0


# XML::Parser-2.47
(lfs chroot) root:/sources# tar zxvf XML-Parser-2.47.tar.gz
(lfs chroot) root:/sources# cd XML-Parser-2.47
(lfs chroot) root:/sources/XML-Parser-2.47# perl Makefile.PL && make -j$(nproc) && make install
(lfs chroot) root:/sources/XML-Parser-2.47# cd .. && rm -rf XML-Parser-2.47


# Intltool-0.51.0
(lfs chroot) root:/sources# tar zxvf intltool-0.51.0.tar.gz
(lfs chroot) root:/sources# cd intltool-0.51.0
(lfs chroot) root:/sources/intltool-0.51.0# sed -i 's:\\\${:\\\$\\{:' intltool-update.in
(lfs chroot) root:/sources/intltool-0.51.0# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/intltool-0.51.0# install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
(lfs chroot) root:/sources/intltool-0.51.0# cd .. && rm -rf intltool-0.51.0


# Autoconf-2.72
(lfs chroot) root:/sources# tar xvf autoconf-2.72.tar.xz
(lfs chroot) root:/sources# cd autoconf-2.72
(lfs chroot) root:/sources/autoconf-2.72# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/autoconf-2.72# cd .. && rm -rf autoconf-2.72


# Automake-1.18.1
(lfs chroot) root:/sources# tar xvf automake-1.18.1.tar.xz
(lfs chroot) root:/sources# cd automake-1.18.1
(lfs chroot) root:/sources/automake-1.18.1# ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1 && make -j$(nproc) && make install
(lfs chroot) root:/sources/automake-1.18.1# cd .. && rm -rf automake-1.18.1


# OpenSSL-3.6.1
(lfs chroot) root:/sources# tar zxvf openssl-3.6.1.tar.gz
(lfs chroot) root:/sources# cd openssl-3.6.1
(lfs chroot) root:/sources/openssl-3.6.1# ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
(lfs chroot) root:/sources/openssl-3.6.1# make -j$(nproc)
(lfs chroot) root:/sources/openssl-3.6.1# sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
(lfs chroot) root:/sources/openssl-3.6.1# make MANSUFFIX=ssl install
(lfs chroot) root:/sources/openssl-3.6.1# mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.6.1
(lfs chroot) root:/sources/openssl-3.6.1# cp -vfr doc/* /usr/share/doc/openssl-3.6.1
(lfs chroot) root:/sources/openssl-3.6.1# cd .. && rm -rf openssl-3.6.1


# Libelf from Elfutils-0.194
(lfs chroot) root:/sources# tar jxvf elfutils-0.194.tar.bz2 
(lfs chroot) root:/sources# cd elfutils-0.194
(lfs chroot) root:/sources/elfutils-0.194# ./configure --prefix=/usr --disable-debuginfod --enable-libdebuginfod=dummy
(lfs chroot) root:/sources/elfutils-0.194# make -C lib && make -C libelf
(lfs chroot) root:/sources/elfutils-0.194# 
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
(lfs chroot) root:/sources/elfutils-0.194# cd .. && rm -rf elfutils-0.194


# Libffi-3.5.2
(lfs chroot) root:/sources# tar zxvf libffi-3.5.2.tar.gz 
(lfs chroot) root:/sources# cd libffi-3.5.2
(lfs chroot) root:/sources/libffi-3.5.2# ./configure --prefix=/usr --disable-static --with-gcc-arch=native && make -j$(nproc) && make install
(lfs chroot) root:/sources/libffi-3.5.2# cd .. && rm -rf libffi-3.5.2


# Sqlite-3510200
(lfs chroot) root:/sources# tar zxvf sqlite-autoconf-3510200.tar.gz
(lfs chroot) root:/sources# cd sqlite-autoconf-3510200
(lfs chroot) root:/sources/sqlite-autoconf-3510200# tar -xf ../sqlite-doc-3510200.tar.xz
(lfs chroot) root:/sources/sqlite-autoconf-3510200# ./configure --prefix=/usr \
            --disable-static  \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                      -D SQLITE_SECURE_DELETE=1"

(lfs chroot) root:/sources/sqlite-autoconf-3510200# make LDFLAGS.rpath="" && make install
(lfs chroot) root:/sources/sqlite-autoconf-3510200# 
install -v -m755 -d /usr/share/doc/sqlite-3.51.2
cp -v -R sqlite-doc-3510200/* /usr/share/doc/sqlite-3.51.2

(lfs chroot) root:/sources/sqlite-autoconf-3510200# cd .. && rm -rf sqlite-autoconf-3510200


# Python-3.14.3
(lfs chroot) root:/sources# tar xvf Python-3.14.3.tar.xz
(lfs chroot) root:/sources# cd Python-3.14.3
(lfs chroot) root:/sources/Python-3.14.3# ./configure --prefix=/usr \
--enable-shared        \
--with-system-expat    \
--enable-optimizations \
--without-static-libpython

(lfs chroot) root:/sources/Python-3.14.3# make -j$(nproc) && make install
(lfs chroot) root:/sources/Python-3.14.3# cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

(lfs chroot) root:/sources/Python-3.14.3# install -v -dm755 /usr/share/doc/python-3.14.3/html
(lfs chroot) root:/sources/Python-3.14.3# tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.14.3/html \
    -xvf ../python-3.14.3-docs-html.tar.bz2

(lfs chroot) root:/sources/Python-3.14.3# cd .. && rm -rf Python-3.14.3



# Flit-Core-3.12.0
(lfs chroot) root:/sources# tar zxvf flit_core-3.12.0.tar.gz
(lfs chroot) root:/sources# cd flit_core-3.12.0
(lfs chroot) root:/sources/flit_core-3.12.0# 
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist flit_core

(lfs chroot) root:/sources/flit_core-3.12.0# cd .. && rm -rf flit_core-3.12.0


# Packaging-26.0
(lfs chroot) root:/sources# tar zxvf packaging-26.0.tar.gz 
(lfs chroot) root:/sources# cd packaging-26.0
(lfs chroot) root:/sources/packaging-26.0# 
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist packaging

(lfs chroot) root:/sources/packaging-26.0# cd .. && rm -rf packaging-26.0


# Wheel-0.46.3
(lfs chroot) root:/sources# tar zxvf wheel-0.46.3.tar.gz 
(lfs chroot) root:/sources# cd wheel-0.46.3
(lfs chroot) root:/sources/wheel-0.46.3# 
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist wheel

(lfs chroot) root:/sources/wheel-0.46.3# cd .. && wheel-0.46.3


# Setuptools-82.0.0
(lfs chroot) root:/sources# tar zxvf setuptools-82.0.0.tar.gz
(lfs chroot) root:/sources# cd setuptools-82.0.0
(lfs chroot) root:/sources/setuptools-82.0.0# 
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist setuptools

(lfs chroot) root:/sources/setuptools-82.0.0# cd .. && rm -rf setuptools-82.0.0


# Ninja-1.13.2
(lfs chroot) root:/sources# tar zxvf ninja-1.13.2.tar.gz
(lfs chroot) root:/sources# cd ninja-1.13.2
(lfs chroot) root:/sources/ninja-1.13.2# export NINJAJOBS=4
(lfs chroot) root:/sources/ninja-1.13.2# sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc

(lfs chroot) root:/sources/ninja-1.13.2# python3 configure.py --bootstrap --verbose
(lfs chroot) root:/sources/ninja-1.13.2# 
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

(lfs chroot) root:/sources/ninja-1.13.2# cd .. && rm -rf ninja-1.13.2



# Meson-1.10.1
(lfs chroot) root:/sources# tar zxvf meson-1.10.1.tar.gz
(lfs chroot) root:/sources# cd meson-1.10.1
(lfs chroot) root:/sources/meson-1.10.1# 
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson

(lfs chroot) root:/sources/meson-1.10.1# cd .. && rm -rf meson-1.10.1


# Kmod-34.2
(lfs chroot) root:/sources# tar xvf kmod-34.2.tar.xz
(lfs chroot) root:/sources# cd kmod-34.2
(lfs chroot) root:/sources/kmod-34.2# mkdir build && cd build
(lfs chroot) root:/sources/kmod-34.2# meson setup --prefix=/usr .. --buildtype=release -D manpages=false
(lfs chroot) root:/sources/kmod-34.2/build# ninja && ninja install
(lfs chroot) root:/sources/kmod-34.2/build# cd ../.. && rm -rf kmod-34.2


# Coreutils-9.10
(lfs chroot) root:/sources# tar xvf coreutils-9.10.tar.xz
(lfs chroot) root:/sources# cd coreutils-9.10
(lfs chroot) root:/sources/coreutils-9.10# patch -Np1 -i ../coreutils-9.10-i18n-1.patch
(lfs chroot) root:/sources/coreutils-9.10# autoreconf -fv && automake -af
(lfs chroot) root:/sources/coreutils-9.10# FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/coreutils-9.10# 
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8

(lfs chroot) root:/sources/coreutils-9.10# cd .. && rm -rf coreutils-9.10


# Diffutils-3.12
(lfs chroot) root:/sources# tar xvf diffutils-3.12.tar.xz
(lfs chroot) root:/sources# cd diffutils-3.12
(lfs chroot) root:/sources/diffutils-3.12# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/diffutils-3.12# cd .. && rm -rf diffutils-3.12


# Gawk-5.3.2
(lfs chroot) root:/sources# tar xvf gawk-5.3.2.tar.xz 
(lfs chroot) root:/sources# cd gawk-5.3.2
(lfs chroot) root:/sources/gawk-5.3.2# sed -i 's/extras//'  Makefile.in
(lfs chroot) root:/sources/gawk-5.3.2# ./configure --prefix=/usr && make -j$(nproc) && rm -f /usr/bin/gawk-5.3.2 && make install
(lfs chroot) root:/sources/gawk-5.3.2# ln -sv gawk.1 /usr/share/man/man1/awk.1
(lfs chroot) root:/sources/gawk-5.3.2# install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.2
(lfs chroot) root:/sources/gawk-5.3.2# cd .. && rm -rf gawk-5.3.2


# Findutils-4.10.0
(lfs chroot) root:/sources# tar xvf findutils-4.10.0.tar.xz
(lfs chroot) root:/sources# cd findutils-4.10.0
(lfs chroot) root:/sources/findutils-4.10.0# ./configure --prefix=/usr --localstatedir=/var/lib/locate && make -j$(nproc) && make install
(lfs chroot) root:/sources/findutils-4.10.0# cd .. && rm -rf findutils-4.10.0


# Groff-1.23.0
(lfs chroot) root:/sources# tar zxvf groff-1.23.0.tar.gz
(lfs chroot) root:/sources# cd groff-1.23.0
(lfs chroot) root:/sources/groff-1.23.0# PAGE=A4 ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/groff-1.23.0# cd .. && rm -rf groff-1.23.0


# GRUB-2.14
(lfs chroot) root:/sources# unset {C,CPP,CXX,LD}FLAGS          # 取消设置任何可能影响构建的环境变量
(lfs chroot) root:/sources# tar xvf grub-2.14.tar.xz 
(lfs chroot) root:/sources# cd grub-2.14
(lfs chroot) root:/sources/grub-2.14# sed 's/--image-base/--nonexist-linker-option/' -i configure
(lfs chroot) root:/sources/grub-2.14# ./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror && make -j$(nproc) && make install
(lfs chroot) root:/sources/grub-2.14# cd .. && rm -rf grub-2.14


# Gzip-1.14
(lfs chroot) root:/sources# tar xvf gzip-1.14.tar.xz
(lfs chroot) root:/sources# cd gzip-1.14
(lfs chroot) root:/sources/gzip-1.14# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/gzip-1.14# cd .. && rm -rf gzip-1.14


# IPRoute2-6.18.0
(lfs chroot) root:/sources# tar xvf iproute2-6.18.0.tar.xz 
(lfs chroot) root:/sources# cd iproute2-6.18.0
(lfs chroot) root:/sources/iproute2-6.18.0# sed -i /ARPD/d Makefile && rm -fv man/man8/arpd.8
(lfs chroot) root:/sources/iproute2-6.18.0# make NETNS_RUN_DIR=/run/netns && make SBINDIR=/usr/sbin install
(lfs chroot) root:/sources/iproute2-6.18.0# install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.18.0
(lfs chroot) root:/sources/iproute2-6.18.0# cd .. && rm -rf iproute2-6.18.0


# Kbd-2.9.0
(lfs chroot) root:/sources# tar xvf kbd-2.9.0.tar.xz
(lfs chroot) root:/sources# cd kbd-2.9.0
(lfs chroot) root:/sources/kbd-2.9.0# patch -Np1 -i ../kbd-2.9.0-backspace-1.patch
(lfs chroot) root:/sources/kbd-2.9.0# 
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

(lfs chroot) root:/sources/kbd-2.9.0# ./configure --prefix=/usr --disable-vlock && make -j$(nproc) && make install && cp -R -v docs/doc -T /usr/share/doc/kbd-2.9.0
(lfs chroot) root:/sources/kbd-2.9.0# cd .. && rm -rf kbd-2.9.0


# Libpipeline-1.5.8
(lfs chroot) root:/sources# tar zxvf libpipeline-1.5.8.tar.gz
(lfs chroot) root:/sources# cd libpipeline-1.5.8
(lfs chroot) root:/sources/libpipeline-1.5.8# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/libpipeline-1.5.8# cd .. && rm -rf libpipeline-1.5.8


# Make-4.4.1
(lfs chroot) root:/sources# tar zxvf make-4.4.1.tar.gz
(lfs chroot) root:/sources# cd make-4.4.1
(lfs chroot) root:/sources/make-4.4.1# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/make-4.4.1# cd .. && rm -rf make-4.4.1


# Patch-2.8
(lfs chroot) root:/sources# tar xvf patch-2.8.tar.xz 
(lfs chroot) root:/sources# cd patch-2.8
(lfs chroot) root:/sources/patch-2.8# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/patch-2.8# cd .. && rm -rf patch-2.8


# Tar-1.35
(lfs chroot) root:/sources# tar xvf tar-1.35.tar.xz 
(lfs chroot) root:/sources# cd tar-1.35
(lfs chroot) root:/sources/tar-1.35# FORCE_UNSAFE_CONFIGURE=1  ./configure --prefix=/usr
(lfs chroot) root:/sources/tar-1.35# make -j$(nproc) && make install && make -C doc install-html docdir=/usr/share/doc/tar-1.35
(lfs chroot) root:/sources/tar-1.35# cd .. && rm -rf tar-1.35


# Texinfo-7.2
(lfs chroot) root:/sources# tar xvf texinfo-7.2.tar.xz
(lfs chroot) root:/sources# cd texinfo-7.2
(lfs chroot) root:/sources/texinfo-7.2# sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm
(lfs chroot) root:/sources/texinfo-7.2# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/texinfo-7.2# make TEXMF=/usr/share/texmf install-tex
(lfs chroot) root:/sources/texinfo-7.2# cd .. && rm -rf texinfo-7.2


# Vim-9.2.0078
(lfs chroot) root:/sources# tar zxvf vim-9.2.0078.tar.gz
(lfs chroot) root:/sources# cd vim-9.2.0078
(lfs chroot) root:/sources/vim-9.2.0078# echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
(lfs chroot) root:/sources/vim-9.2.0078# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/vim-9.2.0078# ln -sv vim /usr/bin/vi
(lfs chroot) root:/sources/vim-9.2.0078# for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done

(lfs chroot) root:/sources/vim-9.2.0078# ln -sv ../vim/vim92/doc /usr/share/doc/vim-9.2.0078
(lfs chroot) root:/sources/vim-9.2.0078# cat > /etc/vimrc << "EOF"
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

(lfs chroot) root:/sources/vim-9.2.0078# cd .. && rm -rf vim-9.2.0078


# MarkupSafe-3.0.3
(lfs chroot) root:/sources# tar zxvf markupsafe-3.0.3.tar.gz
(lfs chroot) root:/sources# cd markupsafe-3.0.3
(lfs chroot) root:/sources/markupsafe-3.0.3# 
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist Markupsafe

(lfs chroot) root:/sources/markupsafe-3.0.3# cd .. && rm -rf markupsafe-3.0.3


# Jinja2-3.1.6
(lfs chroot) root:/sources# tar zxvf jinja2-3.1.6.tar.gz
(lfs chroot) root:/sources# cd jinja2-3.1.6
(lfs chroot) root:/sources/jinja2-3.1.6# 
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist Jinja2

(lfs chroot) root:/sources/jinja2-3.1.6# cd .. && rm -rf jinja2-3.1.6



# Systemd-259.1
(lfs chroot) root:/sources# tar zxvf systemd-259.1.tar.gz 
(lfs chroot) root:/sources# cd systemd-259.1
(lfs chroot) root:/sources/systemd-259.1# sed -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' -i rules.d/50-udev-default.rules.in
(lfs chroot) root:/sources/systemd-259.1# mkdir build && cd build
(lfs chroot) root:/sources/systemd-259.1/build# meson setup .. \
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
      -D docdir=/usr/share/doc/systemd-259.1

(lfs chroot) root:/sources/systemd-259.1/build# ninja
(lfs chroot) root:/sources/systemd-259.1/build# echo 'NAME="Linux From Scratch"' > /etc/os-release
(lfs chroot) root:/sources/systemd-259.1/build# ninja install
(lfs chroot) root:/sources/systemd-259.1/build# tar -xf ../../systemd-man-pages-259.1.tar.xz --no-same-owner --strip-components=1 -C /usr/share/man
(lfs chroot) root:/sources/systemd-259.1/build# systemd-machine-id-setup && systemctl preset-all
(lfs chroot) root:/sources/systemd-259.1/build# cd ../.. && rm -rf systemd-259.1


# D-Bus-1.16.2
(lfs chroot) root:/sources# tar xvf dbus-1.16.2.tar.xz
(lfs chroot) root:/sources# cd dbus-1.16.2
(lfs chroot) root:/sources/dbus-1.16.2/build# mkdir build && cd build
(lfs chroot) root:/sources/dbus-1.16.2/build# meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
(lfs chroot) root:/sources/dbus-1.16.2/build# ninja && ninja install && ln -sfv /etc/machine-id /var/lib/dbus
(lfs chroot) root:/sources/dbus-1.16.2/build# cd ../.. && rm -rf dbus-1.16.2


# Man-DB-2.13.1
(lfs chroot) root:/sources# tar xvf man-db-2.13.1.tar.xz
(lfs chroot) root:/sources# cd man-db-2.13.1
(lfs chroot) root:/sources/man-db-2.13.1# ./configure --prefix=/usr  \
--docdir=/usr/share/doc/man-db-2.13.1 \
--sysconfdir=/etc                     \
--disable-setuid                      \
--enable-cache-owner=bin              \
--with-browser=/usr/bin/lynx          \
--with-vgrind=/usr/bin/vgrind         \
--with-grap=/usr/bin/grap

(lfs chroot) root:/sources/man-db-2.13.1# make -j$(nproc) && make install
(lfs chroot) root:/sources/man-db-2.13.1# cd .. && rm -rf man-db-2.13.1


# Procps-ng-4.0.6
(lfs chroot) root:/sources# tar xvf procps-ng-4.0.6.tar.xz 
(lfs chroot) root:/sources# cd procps-ng-4.0.6
(lfs chroot) root:/sources/procps-ng-4.0.6# ./configure --prefix=/usr \
--docdir=/usr/share/doc/procps-ng-4.0.6 \
--disable-static                        \
--disable-kill                          \
--enable-watch8bit                      \
--with-systemd

(lfs chroot) root:/sources/procps-ng-4.0.6# make -j$(nproc) && make install
(lfs chroot) root:/sources/procps-ng-4.0.6# cd .. && rm -rf procps-ng-4.0.6


# Util-linux-2.41.3
(lfs chroot) root:/sources# tar xvf util-linux-2.41.3.tar.xz 
(lfs chroot) root:/sources# cd util-linux-2.41.3
(lfs chroot) root:/sources/util-linux-2.41.3# ./configure --bindir=/usr/bin --libdir=/usr/lib   --runstatedir=/run \
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

(lfs chroot) root:/sources/util-linux-2.41.3# make -j$(nproc) && touch /etc/fstab && make install
(lfs chroot) root:/sources/util-linux-2.41.3# cd .. && rm -rf util-linux-2.41.3


# E2fsprogs-1.47.3
(lfs chroot) root:/sources# tar zxvf e2fsprogs-1.47.3.tar.gz 
(lfs chroot) root:/sources# cd e2fsprogs-1.47.3
(lfs chroot) root:/sources/e2fsprogs-1.47.3# mkdir build && cd build
(lfs chroot) root:/sources/e2fsprogs-1.47.3/build# ../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs --disable-libblkid --disable-libuuid --disable-uuidd --disable-fsck

(lfs chroot) root:/sources/e2fsprogs-1.47.3/build# make -j$(nproc) && make install
(lfs chroot) root:/sources/e2fsprogs-1.47.3/build# 
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf

(lfs chroot) root:/sources/e2fsprogs-1.47.3/build# cd ../.. && rm -rf e2fsprogs-1.47.3







# 剥离      https://linuxfromscratch.org/lfs/view/stable-systemd/chapter08/stripping.html
(lfs chroot) root:/sources# save_usrlib="$(cd /usr/lib; ls ld-linux*[^g])
             libc.so.6
             libthread_db.so.1
             libquadmath.so.0.0.0
             libstdc++.so.6.0.34
             libitm.so.1.0.0
             libatomic.so.1.2.0"

(lfs chroot) root:/sources# cd /usr/lib
(lfs chroot) root:/usr/lib# 
for LIB in $save_usrlib; do
    objcopy --only-keep-debug --compress-debug-sections=zstd $LIB $LIB.dbg
    cp $LIB /tmp/$LIB
    strip --strip-debug /tmp/$LIB
    objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

online_usrbin="bash find strip"
online_usrlib="libbfd-2.46.0.20260210.so
               libsframe.so.3.0.0
               libhistory.so.8.3
               libncursesw.so.6.6
               libm.so.6
               libreadline.so.8.3
               libz.so.1.3.2
               libzstd.so.1.5.7
               $(cd /usr/lib; find libnss*.so* -type f)"

for BIN in $online_usrbin; do
    cp /usr/bin/$BIN /tmp/$BIN
    strip --strip-debug /tmp/$BIN
    install -vm755 /tmp/$BIN /usr/bin
    rm /tmp/$BIN
done

for LIB in $online_usrlib; do
    cp /usr/lib/$LIB /tmp/$LIB
    strip --strip-debug /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
         $(find /usr/lib -type f -name \*.a)                 \
         $(find /usr/{bin,sbin,libexec} -type f); do
    case "$online_usrbin $online_usrlib $save_usrlib" in
        *$(basename $i)* )
            ;;
        * ) strip --strip-debug $i
            ;;
    esac
done

(lfs chroot) root:/usr/lib# unset BIN LIB save_usrlib online_usrbin online_usrlib




# 清理            https://linuxfromscratch.org/lfs/view/stable-systemd/chapter08/cleanup.html
(lfs chroot) root:/usr/lib# 
rm -rf /tmp/{*,.*}
find /usr/lib /usr/libexec -name \*.la -delete
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf



```



## [系统配置](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/chapter09.html)
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
       valid_lft 1498sec preferred_lft 1498sec
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
Name=ens33
 
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
 

获取 Glibc 支持的所有语言环境列表：
(lfs chroot) root:/usr/lib# locale -a

# 和官方提供的profile基础上加了一部分东西
(lfs chroot) root:/usr/lib# cat > /etc/profile << "EOF"
# Begin /etc/profile

# --- 基础路径配置 ---
export PATH=/usr/bin:/usr/sbin:/bin:/sbin

# --- 提示符配置  ---
export PS1='[\u@\h \w]\$ '

# --- 语言环境自动化处理 (保留官方的配置) ---
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
Disk identifier: 93621A1E-CFA1-40FD-8DBD-B029932F42B7

Device        Start       End   Sectors Size Type
/dev/sdb1      2048     12287     10240   5M BIOS boot
/dev/sdb2     12288  12595199  12582912   6G Linux swap
/dev/sdb3  12595200 125827071 113231872  54G Linux filesystem


(lfs chroot) root:/usr/lib# blkid | grep sdb
/dev/sdb2: UUID="26b2d0a0-736c-45bd-a327-2b616daf6b78" TYPE="swap" PARTUUID="0ce1c0aa-7349-4d16-8e1f-3d1bb08e55e7"
/dev/sdb3: UUID="4469f1c7-6775-489d-b83c-57df7cc185f4" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="f1e0f1a6-1fe8-4266-9a57-9a1d31170f5b"
/dev/sdb1: PARTUUID="54ddd1d1-becb-4fb8-93e4-5e02185c50f2"

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
UUID=4469f1c7-6775-489d-b83c-57df7cc185f4  /    ext4 defaults 1 1
UUID=26b2d0a0-736c-45bd-a327-2b616daf6b78  swap swap defaults 0 0
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
-rw-r--r-- 1 root root 555 May  3 18:16 /etc/fstab
 

```



## 安装内核前有必要做个快照
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






# Linux-6.18.10内核安装
```shell
(lfs chroot) root:/usr/lib# cd /sources/
(lfs chroot) root:/sources# tar xvf linux-6.18.10.tar.xz 
(lfs chroot) root:/sources# cd linux-6.18.10
(lfs chroot) root:/sources/linux-6.18.10# make mrproper
(lfs chroot) root:/sources/linux-6.18.10# make menuconfig
General setup --->
  CPU/Task time and stats accounting --->
    [*] Pressure stall information tracking                                [PSI]
    [ ]   Require boot parameter to enable pressure stall information tracking
                                                     ...  [PSI_DEFAULT_DISABLED]
  < > Enable kernel headers through /sys/kernel/kheaders.tar.xz      [IKHEADERS]
  [*] Control Group support --->                                       [CGROUPS]
    [*]   Memory controller                                              [MEMCG]
    [ /*] CPU controller --->                                     [CGROUP_SCHED]
      # This may cause some systemd features malfunction:
      [ ] Group scheduling for SCHED_RR/FIFO                    [RT_GROUP_SCHED]
  [ ] Configure standard kernel features (expert users) --->            [EXPERT]

Processor type and features --->
  [*] Build a relocatable kernel                                   [RELOCATABLE]
  [*]   Randomize the address of the kernel image (KASLR)       [RANDOMIZE_BASE]

General architecture-dependent options --->
  [*] Stack Protector buffer overflow detection                 [STACKPROTECTOR]
  [*]   Strong Stack Protector                           [STACKPROTECTOR_STRONG]

[*] Networking support --->                                                [NET]
  Networking options --->
    [*] TCP/IP networking                                                 [INET]
    <*>   The IPv6 protocol --->                                          [IPV6]

Device Drivers --->
  Generic Driver Options --->
    [ ] Support for uevent helper                                [UEVENT_HELPER]
    [*] Maintain a devtmpfs filesystem to mount at /dev               [DEVTMPFS]
    [*]   Automount devtmpfs at /dev, after the kernel mounted the rootfs
                                                           ...  [DEVTMPFS_MOUNT]
    Firmware loader --->
      < /*> Firmware loading facility                                [FW_LOADER]
      [ ]   Enable the firmware sysfs fallback mechanism [FW_LOADER_USER_HELPER]
  Firmware Drivers --->
    [*] Export DMI identification via sysfs to userspace                 [DMIID]
    [*] Mark VGA/VBE/EFI FB as generic system framebuffer       [SYSFB_SIMPLEFB]
  Graphics support --->
    <*> Direct Rendering Manager (XFree86 4.1.0 and higher DRI support) ---> [*] Display a user-friendly message when a kernel panic occurs
                                                                               (user)   Panic screen formatter         [DRM_PANIC_SCREEN]
      Supported DRM clients ---> 
      [*] Enable legacy fbdev support for your modesetting driver
                                                      ...  [DRM_FBDEV_EMULATION]
      Drivers for system framebuffers --->
        <*> Simple framebuffer driver                              [DRM_SIMPLEDRM]
    Console display driver support --->
      [*] Framebuffer Console support                      [FRAMEBUFFER_CONSOLE]

File systems --->
  [*] Inotify support for userspace                               [INOTIFY_USER]
  Pseudo filesystems --->
    [*] Tmpfs virtual memory file system support (former shm fs)         [TMPFS]
    [*]   Tmpfs POSIX Access Control Lists                     [TMPFS_POSIX_ACL]
    [*]   Ext4 POSIX Access Control Lists

# 如果您正在构建64位系统，请启用以下一些附加功能
Processor type and features --->
  [*] x2APIC interrupt controller architecture support              [X86_X2APIC]

Device Drivers --->
  [*] PCI support --->                                                     [PCI]
    [*] Message Signaled Interrupts (MSI and MSI-X)                    [PCI_MSI]
  [*] IOMMU Hardware Support --->                                [IOMMU_SUPPORT]
    [*] Support for Interrupt Remapping                              [IRQ_REMAP]


# 如果LFS系统的分区位于NVME SSD上
Device Drivers --->
  NVME Support --->
    <*> NVM Express block device                                  [BLK_DEV_NVME]



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
(lfs chroot) root:/sources/linux-6.18.10# cp -iv arch/x86/boot/bzImage /boot/vmlinuz-6.18.10-lfs-13.0-systemd

安装 System.map（调试用）
(lfs chroot) root:/sources/linux-6.18.10# cp -iv System.map /boot/System.map-6.18.10
 
备份你的辛苦成果（下次编译时可以基于此配置）
(lfs chroot) root:/sources/linux-6.18.10# cp -iv .config /boot/config-6.18.10
 
安装 Linux 内核文档
(lfs chroot) root:/sources/linux-6.18.10# cp -r Documentation -T /usr/share/doc/linux-6.18.10
 





# 使用GRUB设置启动过程              https://linuxfromscratch.org/lfs/view/stable-systemd/chapter10/grub.html
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

注意：更建议写成UUID的方式   ---> 本次使用该方式
(lfs chroot) root:/sources/linux-6.18.10# blkid /dev/sdb3
/dev/sdb3: UUID="4469f1c7-6775-489d-b83c-57df7cc185f4" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="f1e0f1a6-1fe8-4266-9a57-9a1d31170f5b"
注意：上一行末尾的PARTUUID，下一行的grub.cfg中要用

(lfs chroot) root:/sources/linux-6.18.10# cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod part_gpt
insmod ext2
set root=(hd0,2)
set gfxpayload=1024x768x32

menuentry "GNU/Linux, Linux 6.18.10-lfs-13.0-systemd" {
        linux   /boot/vmlinuz-6.18.10-lfs-13.0-systemd root=PARTUUID=f1e0f1a6-1fe8-4266-9a57-9a1d31170f5b ro
}
EOF
注：
标准的LFS内核(通过Linux-6.18.10内核安装章节直接编译出的 bzImage)通常不具备直接解析 root=UUID=... 的能力。这种解析能力通常由 initramfs（初始化内存文件系统）提供
只有在使用initramfs时内核才能识别root=UUID=...如果你没有制作initramfs，内核会因为看不懂 UUID=... 而报错 unable to mount root fs
建议改为使用 root=PARTUUID=... 内核对 PARTUUID 的支持通常比 UUID 更底层，无需 initramfs 也有很大机会成功



# 重新自动生成grub.cfg
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


```





# 最后
```shellshell
(lfs chroot) root:/sources/linux-6.18.10# echo 13.0-systemd > /etc/lfs-release

(lfs chroot) root:/sources/linux-6.18.10# cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="13.0-systemd"
DISTRIB_CODENAME="<your name here>"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF

(lfs chroot) root:/sources/linux-6.18.10# cat > /etc/os-release << "EOF"
NAME="Linux From Scratch"
VERSION="13.0-systemd"
ID=lfs
PRETTY_NAME="Linux From Scratch 13.0-systemd"
VERSION_CODENAME="<your name here>"
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

root@ub24-1:~# umount -l $LFS/dev
root@ub24-1:~# umount -v $LFS


root@ub24-1:~# poweroff


```
![image](https://img2024.cnblogs.com/blog/1139005/202605/1139005-20260504110615258-1462060489.png)
![image](https://img2024.cnblogs.com/blog/1139005/202605/1139005-20260504111825551-1858461897.png)
![image](https://img2024.cnblogs.com/blog/1139005/202605/1139005-20260504111836920-880299010.png)
