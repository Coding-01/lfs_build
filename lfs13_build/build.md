[toc]


[13.0-systemd document](https://linuxfromscratch.org/lfs/view/stable-systemd/)

# 前奏
```shell
Ubuntu24
8u/16G/80G(系统)/60G(做lfs)
172.16.186.128/24

```




# 构建准备
## 准备主机系统
```shell
# 分区
rambo@ub24-1:~$ sudo fdisk -l | grep "Disk /dev/sd"
Disk /dev/sda: 80 GiB, 85899345920 bytes, 167772160 sectors      # Storage Ubutu system
Disk /dev/sdb: 60 GiB, 64424509440 bytes, 125829120 sectors      # Storage lfs



rambo@ub24-1:~$ sudo fdisk /dev/sdb
# 创建GPT分区表
Command (m for help): g
Created a new GPT disklabel (GUID: E5F65F01-0075-4D89-A774-DEBB7486F7BF).
# 创建bios boot分区
Command (m for help): n
Partition number (1-128, default 1): 
First sector (2048-125829086, default 2048): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-125829086, default 125827071): +5M
# 修改分区类型
Command (m for help): t
Selected partition 1
Partition type or alias (type L to list all): 4
Changed type of partition 'Linux filesystem' to 'BIOS boot'.
# 制作swap分区
Command (m for help): n
Partition number (2-128, default 2): 
First sector (12288-125829086, default 12288): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (12288-125829086, default 125827071): +6G
# 修改分区类型
Command (m for help): t
Partition number (1,2, default 2): 
Partition type or alias (type L to list all): 19
Changed type of partition 'Linux filesystem' to 'Linux swap'.
# 剩余的分区全部给根
Command (m for help): n
Partition number (3-128, default 3): 
First sector (12595200-125829086, default 12595200): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (12595200-125829086, default 125827071): 
Created a new partition 3 of type 'Linux filesystem' and of size 54 GiB.

Command (m for help): w


rambo@ub24-1:~$ sudo mkfs.ext4 /dev/sdb3
# 初始化Swap(sdb2)
rambo@ub24-1:~$ sudo mkswap /dev/sdb2
# 启用Swap(这样编译时内存更充裕)
rambo@ub24-1:~$ sudo swapon -v /dev/sdb2






# 主机系统要求
# 更新源
rambo@ub24-1:~$ cat /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: noble noble-updates noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
 

# 先关掉自动升级
rambo@ub24-1:~$ ps aux | grep unattended
root        1339  0.0  0.1 120904 22912 ?        Ssl  19:00   0:00 /usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal
root        2346 99.9  0.7 367148 119744 ?       RNl  19:04   9:34 /usr/bin/python3 /usr/bin/unattended-upgrade
释义：2346就是在升级的服务，直接杀掉


rambo@ub24-1:~$ sudo kill -9 2346
rambo@ub24-1:~$ sudo systemctl daemon-reload && sudo systemctl stop unattended-upgrades && sudo systemctl disable unattended-upgrades

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


rambo@ub24-1:~$ bash version-check.sh




# 分阶段构建LFS
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
├─sdb2 swap   1           9cefc2c2-4e9d-41fa-aaee-f2fee31b885e                [SWAP]
└─sdb3 ext4   1.0         40a5b6af-35e5-4406-b419-0db595431618                

 
 
rambo@ub24-1:~$ echo 'UUID=40a5b6af-35e5-4406-b419-0db595431618   /mnt/lfs   ext4  defaults 0 0' | sudo tee -a /etc/fstab
 
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
# 需要单独下载的包
rambo@ub24-1:/mnt/lfs/sources$ wget https://mirrors.aliyun.com/openssh/portable/openssh-10.1p1.tar.gz \
https://www.thrysoee.dk/editline/libedit-20251016-3.1.tar.gz
 
注意：
如果需要创建好的LFS有更多的功能，需要单独下载并安装包，这里就只做备用和测试
openssh-10.1p1.tar.gz中的p1代表Portable，这是 Linux 系统专用的版本
# =====================================================================


rambo@ub24-1:/mnt/lfs/sources$ wget https://linuxfromscratch.org/lfs/view/stable-systemd/wget-list-systemd https://linuxfromscratch.org/lfs/view/stable-systemd/md5sums
rambo@ub24-1:/mnt/lfs/sources$ wget --input-file=wget-list-systemd --continue --directory-prefix=$LFS/sources
注意：请在干净的网络环境下进行，如使用了特殊网络则需要先去除
 
# 检查所有软件包的正确性
rambo@ub24-1:/mnt/lfs/sources$ pushd $LFS/sources; md5sum -c md5sums; popd
注意：可能出现报错，如出现包没有的情况则需要执行以下命令
rambo@ub24-1:/mnt/lfs/sources$ wget -nc -i wget-list-systemd -P $LFS/sources          # 如还有No such file or directory则需要再次执行该命令
# 再来检查所有软件包的正确性
rambo@ub24-1:/mnt/lfs/sources$ pushd $LFS/sources; md5sum -c md5sums; popd





# 在LFS文件系统中创建有限目录布局
rambo@ub24-1:/mnt/lfs/sources$ sudo mkdir -p $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}
 
rambo@ub24-1:/mnt/lfs/sources$ for i in bin lib sbin;do sudo ln -s usr/$i $LFS/$i;done
 
rambo@ub24-1:/mnt/lfs/sources$ case $(uname -m) in  x86_64) sudo mkdir -p  $LFS/lib64 ;;esac
# 创建交叉编译的目录
rambo@ub24-1:/mnt/lfs/sources$ sudo mkdir -p $LFS/tools
rambo@ub24-1:/mnt/lfs/sources$ sudo ln -sfv $LFS/tools  /        # 这一步没错，就是要挂载到宿主机的/上
rambo@ub24-1:~$ ls -ld  /tools
lrwxrwxrwx 1 root root 14 Apr 19 16:37 /tools -> /mnt/lfs/tools
 
 
# 添加LFS用户
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


# 环境搭建   https://linuxfromscratch.org/lfs/view/stable-systemd/chapter04/settingenvironment.html
lfs@ub24-1:/mnt/lfs/sources$ cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
 
 
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
## [编译交叉工具链](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter05/binutils-pass1.html)
```shell
# binutils-2.46编译
lfs@ub24-1:/mnt/lfs/sources$ tar -xvf binutils-2.46.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46$ mkdir build && cd build
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
 



# GCC-15.2.0 - 第一阶段
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
 
 
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ ../configure \
--target=$LFS_TGT --prefix=$LFS/tools --with-glibc-version=2.41 \
--with-sysroot=$LFS --with-newlib --without-headers --enable-default-pie \
--enable-default-ssp --disable-nls --disable-shared --disable-multilib \
--disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath \
--disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++


lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ make -j$(nproc) && make install
 
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ cd ..
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h

lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gcc-15.2.0
 


# linux-6.13.4 API头文件
lfs@ub24-1:/mnt/lfs/sources$ tar xvf linux-6.13.4.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd linux-6.13.4
lfs@ub24-1:/mnt/lfs/sources/linux-6.13.4$ make mrproper
lfs@ub24-1:/mnt/lfs/sources/linux-6.13.4$ make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include  $LFS/usr
 
lfs@ub24-1:/mnt/lfs/sources/linux-6.13.4$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf linux-6.13.4
 
 


# Linux-6.18.10 API 头文件
lfs@ub24-1:/mnt/lfs/sources$ tar xvf linux-6.18.10.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd linux-6.18.10
lfs@ub24-1:/mnt/lfs/sources/linux-6.18.10$ make mrproper
lfs@ub24-1:/mnt/lfs/sources/linux-6.18.4$ make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include  $LFS/usr


lfs@ub24-1:/mnt/lfs/sources/linux-6.18.10$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf linux-6.18.10



# glibc-2.41
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
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ ../configure --prefix=/usr --host=$LFS_TGT \
--build=$(../scripts/config.guess) --disable-nscd libc_cv_slibdir=/usr/lib --enable-kernel=5.4

lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/glibc-2.43/build$ cd ../.. && rm -rf glibc-2.43




# GCC-15.2.0 的 Libstdc++
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gcc-15.2.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ../libstdc++-v3/configure \
--host=$LFS_TGT --build=$(../config.guess) --prefix=/usr \
--disable-multilib --disable-nls --disable-libstdcxx-pch \
--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0

lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la       # 删除libtool归档文件，因为它们对交叉编译有害
lfs@ub24-1:/mnt/lfs/sources/gcc-14.2.0/build$ cd ../..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gcc-14.2.0


```




## 交叉编译临时工具
```shell
# M4-1.4.21
lfs@ub24-1:/mnt/lfs/sources$ tar xvf m4-1.4.21.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd m4-1.4.21
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.21$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.21$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/m4-1.4.21$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf m4-1.4.21


# ncurses-6.6
lfs@ub24-1:/mnt/lfs/sources$ tar xvf ncurses-6.6.tar.gz
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ mkdir build
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ pushd build
  ../configure AWK=gawk
  make -C include
  make -C progs tic
popd

lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ ./configure --prefix=/usr \
--host=$LFS_TGT --build=$(./config.guess) --mandir=/usr/share/man \
--with-manpage-format=normal --with-shared --without-normal \
--with-cxx-shared --without-debug --without-ada --disable-stripping  AWK=gawk

lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ make -j$(nproc) && make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ sed -e 's/^#if.*XOPEN.*$/#if 1/'  -i $LFS/usr/include/curses.h
lfs@ub24-1:/mnt/lfs/sources/ncurses-6.6$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf ncurses-6.6



# bash-5.2.37
lfs@ub24-1:/mnt/lfs/sources$ tar -zxvf  bash-5.3.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd bash-5.3
lfs@ub24-1:/mnt/lfs/sources/bash-5.3$ ./configure --prefix=/usr --build=$(sh support/config.guess) --host=$LFS_TGT --without-bash-malloc

lfs@ub24-1:/mnt/lfs/sources/bash-5.3$ make -j$(nproc)  && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/bash-5.3$ ln -sv bash  $LFS/bin/sh
lfs@ub24-1:/mnt/lfs/sources/bash-5.3$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf bash-5.3




# coreutils-9.10
lfs@ub24-1:/mnt/lfs/sources$ tar xvf coreutils-9.10.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd coreutils-9.10
lfs@ub24-1:/mnt/lfs/sources/coreutils-9.10$ ./configure --prefix=/usr \
--host=$LFS_TGT --build=$(build-aux/config.guess) \
--enable-install-program=hostname --enable-no-install-program=kill,uptime


lfs@ub24-1:/mnt/lfs/sources/coreutils-9.10$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/coreutils-9.10$ 
mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8

lfs@ub24-1:/mnt/lfs/sources/coreutils-9.10$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf coreutils-9.10




# diffutils-3.12
lfs@ub24-1:/mnt/lfs/sources$ tar xvf diffutils-3.12.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd diffutils-3.12
lfs@ub24-1:/mnt/lfs/sources/diffutils-3.12$ ./configure --prefix=/usr --host=$LFS_TGT \
gl_cv_func_strcasecmp_works=y --build=$(./build-aux/config.guess)

lfs@ub24-1:/mnt/lfs/sources/diffutils-3.12$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/diffutils-3.12$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf diffutils-3.12



# file-5.46
lfs@ub24-1:/mnt/lfs/sources$ tar zxvf file-5.46.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd file-5.46
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ mkdir build
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ pushd build
  ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
  make
popd

lfs@ub24-1:/mnt/lfs/sources/file-5.46$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) 
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ make FILE_COMPILE=$(pwd)/build/src/file && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ rm -v $LFS/usr/lib/libmagic.la
lfs@ub24-1:/mnt/lfs/sources/file-5.46$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf file-5.46



# findutils-4.10.0
lfs@ub24-1:/mnt/lfs/sources$ tar xvf findutils-4.10.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd findutils-4.10.0
lfs@ub24-1:/mnt/lfs/sources/findutils-4.10.0$ ./configure --prefix=/usr \
--localstatedir=/var/lib/locate --host=$LFS_TGT --build=$(build-aux/config.guess)

lfs@ub24-1:/mnt/lfs/sources/findutils-4.10.0$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources$ cd .. && rm -rf findutils-4.10.0



# Gawk-5.3.2            https://linuxfromscratch.org/lfs/view/stable-systemd/chapter06/gawk.html
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gawk-5.3.2.tar.xz 
lfs@ub24-1:/mnt/lfs/sources$ cd gawk-5.3.2
lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.2$ sed -i 's/extras//' Makefile.in
lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.2$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && make -j$(nproc) && make DESTDIR=$LFS install
 
lfs@ub24-1:/mnt/lfs/sources/gawk-5.3.2$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gawk-5.3.2



# grep-3.12
lfs@ub24-1:/mnt/lfs/sources$ tar xvf grep-3.12.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd grep-3.12 
lfs@ub24-1:/mnt/lfs/sources/grep-3.12$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
lfs@ub24-1:/mnt/lfs/sources/grep-3.12$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/grep-3.12$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf grep-3.12



# gzip-1.14
lfs@ub24-1:/mnt/lfs/sources$ tar xvf gzip-1.14.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd gzip-1.14
lfs@ub24-1:/mnt/lfs/sources/gzip-1.14$ ./configure --prefix=/usr --host=$LFS_TGT
lfs@ub24-1:/mnt/lfs/sources/gzip-1.14$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/gzip-1.14$ cd ..
lfs@ub24-1:/mnt/lfs/sources$ rm -rf gzip-1.14



# make-4.4.1
lfs@ub24-1:/mnt/lfs/sources$ tar xvf make-4.4.1.tar.gz
lfs@ub24-1:/mnt/lfs/sources$ cd make-4.4.1
lfs@ub24-1:/mnt/lfs/sources/make-4.4.1$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
lfs@ub24-1:/mnt/lfs/sources/make-4.4.1$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources$ cd .. && rm -rf make-4.4.1




# patch-2.8
lfs@ub24-1:/mnt/lfs/sources$ tar xvf patch-2.8.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd patch-2.8
lfs@ub24-1:/mnt/lfs/sources/patch-2.8$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
lfs@ub24-1:/mnt/lfs/sources/patch-2.8$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources$ cd .. && rm -rf patch-2.8



# sed-4.9
lfs@ub24-1:/mnt/lfs/sources$ tar xvf sed-4.9.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd sed-4.9
lfs@ub24-1:/mnt/lfs/sources/sed-4.9$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
lfs@ub24-1:/mnt/lfs/sources/sed-4.9$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources$ cd .. && rm -rf sed-4.9



# tar-1.35
lfs@ub24-1:/mnt/lfs/sources$ tar -xvf tar-1.35.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd tar-1.35
lfs@ub24-1:/mnt/lfs/sources/tar-1.35$ ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
lfs@ub24-1:/mnt/lfs/sources/tar-1.35$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources$ cd .. && rm -rf tar-1.35




# xz-5.8.2
lfs@ub24-1:/mnt/lfs/sources$ tar xvf xz-5.8.2.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd xz-5.8.2
lfs@ub24-1:/mnt/lfs/sources/xz-5.8.2$ ./configure --prefix=/usr --host=$LFS_TGT \
--build=$(build-aux/config.guess) --disable-static --docdir=/usr/share/doc/xz-5.8.2

lfs@ub24-1:/mnt/lfs/sources/xz-5.8.2$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources$ cd .. && rm -rf xz-5.8.2








# Binutils-2.46.0 - 第2阶段
lfs@ub24-1:/mnt/lfs/sources$ tar xvf binutils-2.46.0.tar.xz
lfs@ub24-1:/mnt/lfs/sources$ cd binutils-2.46.0
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0$ mkdir build && cd build
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ ../configure --prefix=/usr --build=$(../config.guess) \
--host=$LFS_TGT --disable-nls --enable-shared --enable-gprofng=no --disable-werror --enable-64-bit-bfd \
--enable-new-dtags --enable-default-hash-style=gnu

lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ make -j$(nproc) && make DESTDIR=$LFS install
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
lfs@ub24-1:/mnt/lfs/sources/binutils-2.46.0/build$ cd ../.. && rm -rf binutils-2.46.0



# gcc-15.2.0 - 第2阶段
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
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ../configure --build=$(../config.guess) \
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
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ ln -sv gcc  $LFS/usr/bin/cc
lfs@ub24-1:/mnt/lfs/sources/gcc-15.2.0/build$ cd ../../ && rm -rf gcc-15.2.0



```





# 进入 Chroot 环境并构建额外的临时工具
```shell
# 所有权变更        https://linuxfromscratch.org/lfs/view/stable-systemd/chapter07/changingowner.html
lfs@ub24-1:/mnt/lfs/sources$ exit
exit
rambo@ub24-1:/mnt/lfs/sources$ echo $LFS
/mnt/lfs

rambo@ub24-1:/mnt/lfs/sources$ sudo chown --from lfs -R root:root $LFS/{usr,var,etc,tools}
lfs@ub24-1:/mnt/lfs/sources$ case $(uname -m) in
  x86_64) sudo chown --from lfs -R root:root $LFS/lib64 ;;
esac




# 准备虚拟内核文件系统
rambo@ub24-1:/mnt/lfs/sources$ sudo su -
root@ub24-1:~# export LFS=/mnt/lfs
root@ub24-1:~# echo $LFS
/mnt/lfs


# 务必要切到root, 不要使用sudo
# 创建这些虚拟文件系统将挂载到的目录
root@ub24-1:~$ mkdir -pv $LFS/{dev,proc,sys,run}
注意：文档要求挂载这些目录，是为了让你在接下来的 chroot 环境里拥有像“真系统”一样的能力：
/dev：让新系统里的 GCC 能找到 /dev/null
/proc & /sys：让编译程序知道你 CPU 有几个核心（用于 make -jX）

# 挂载和填充/dev，即挂载物理设备目录
root@ub24-1:~$ mount -v --bind /dev $LFS/dev
 
# 挂载虚拟内核文件系统
root@ub24-1:~# mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
root@ub24-1:~# mount -vt proc proc $LFS/proc
root@ub24-1:~# mount -vt sysfs sysfs $LFS/sys                    # 解决见下方
mount: /mnt/lfs/sys: sysfs already mounted on /sys.
       dmesg(1) may have more information after failed mount system call.
root@ub24-1:~# mount -vt tmpfs tmpfs $LFS/run
释义：
/sys挂载异常时需要卸载掉重新挂载
root@ub24-1:~# umount -v $LFS/sys
root@ub24-1:~# mount -vt sysfs sysfs $LFS/sys

释义：
挂载点            目的
$LFS/dev       访问硬盘、键盘等硬件设备
$LFS/dev/pts   支持终端多窗口（虚拟终端）
$LFS/proc      访问进程信息
$LFS/sys       访问内核定义的系统信息
$LFS/run       存放系统运行时的临时数据



处理/dev/shm的建议操作
root@ub24-1:~$ 
if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
else
  mount -vt tmpfs shm $LFS/dev/shm
fi





# 进入Chroot环境
root@ub24-1:~# chroot "$LFS" /usr/bin/env -i \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    MAKEFLAGS="-j$(nproc)"      \
    TESTSUITEFLAGS="-j$(nproc)" \
    /bin/bash --login




# 在LFS文件系统中创建完整的目录结构
FHS合规说明 https://refspecs.linuxfoundation.org/fhs.shtml

创建一些不在前面所要求的有限目录中的根级目录
(lfs chroot) I have no name!:/# mkdir -pv /{boot,home,mnt,opt,srv}

# 在根目录下创建所需的子目录集：
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


为了使用户 root 能够登录并识别“root”这个名称，/etc/passwd 和 /etc/group 文件中必须包含相关的条目。
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
 






# Gettext-1.0安装
Gettext 软件包包含用于国际化和本地化的实用程序。这些实用程序允许使用 NLS（本地语言支持）编译程序，从而使程序能够以用户的母语输出消息
在chroot环境里，你就是最高权限，所有的命令直接输入即可
依然在chroot里的 /sources 目录下（对应宿主机的 /mnt/lfs/sources）进行解压和编译
(lfs chroot) root:/# cd /sources/
(lfs chroot) root:/sources# tar xvf gettext-1.0.tar.xz
(lfs chroot) root:/sources# cd gettext-1.0
(lfs chroot) root:/sources/gettext-1.0# ./configure --disable-shared
(lfs chroot) root:/sources/gettext-1.0# make -j$(nproc) && cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
(lfs chroot) root:/sources/gettext-1.0# cd .. && rm -rf gettext-1.0




# bison-3.8.2
(lfs chroot) root:/sources# tar xvf bison-3.8.2.tar.xz
(lfs chroot) root:/sources# cd bison-3.8.2
(lfs chroot) root:/sources/bison-3.8.2# ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
(lfs chroot) root:/sources/bison-3.8.2# make -j$(nproc) && make install
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
(lfs chroot) root:/sources# tar xvf Python-3.14.3.tar.xz
(lfs chroot) root:/sources# cd Python-3.14.3
(lfs chroot) root:/sources/Python-3.14.3# ./configure --prefix=/usr --enable-shared \
--without-ensurepip --without-static-libpython
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
/dev/sdb3 on /mnt/lfs type ext4 (rw,relatime)
 
root@ub24-1:~# cat /proc/mounts | grep "$LFS"
/dev/sdb3 /mnt/lfs ext4 rw,relatime 0 0
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
root@ub24-1:/mnt/lfs# tar -cvpf ../lfs-temp-tools-13.0.tar.xz --exclude='./sources' --use-compress-program="xz -T0" .
释义：
-c: 创建
-p: 保留所有权限（极其重要，否则恢复后系统会瘫痪）
-f: 指定文件名
-T0：使用所有可用的CPU核心
--exclude：排除掉某个目录
.: 代表当前目录
 
# 查看备份完成的包
root@ub24-1:/mnt/lfs# ls -alh ../lfs-temp-tools-13.0.tar.xz 
-rw-r--r-- 1 root root 500M Apr 30 01:28 ../lfs-temp-tools-13.0.tar.xz
 
 
 
# 恢复（因为备份的时候就是在$LFS中进行的，所以恢复时也要在该目录中执行）
如果操作失误需要重新开始，可用此备份来恢复系统，从而节省恢复时间。由于源代码位于$LFS目录下，因此也包含在备份存档中，无需再次下载。确认$LFS设置正确后，可用以下命令来恢复备份：
root@ub24-1:~# export LFS=/mnt/lfs
root@ub24-1:~# mkdir -pv $LFS
root@ub24-1:~# mount /dev/sdb1 $LFS
root@ub24-1:~# cd $LFS
root@ub24-1:/mnt/lfs# rm -rf ./*
root@ub24-1:/mnt/lfs# tar -xJvpf ../lfs-temp-tools-13.0-systemd.tar.xz
 

```






# 构建LFS系统
```shell
绝对不能在宿主机的rambo或宿主机的root用户下执行
由于之前退出了chroot所以需要重新登录
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
# Man-pages-6.17
(lfs chroot) root:/sources# tar xvf man-pages-6.17.tar.xz
(lfs chroot) root:/sources# cd man-pages-6.17
(lfs chroot) root:/sources/man-pages-6.17# rm -v man3/crypt*
(lfs chroot) root:/sources/man-pages-6.17# make -R GIT=false prefix=/usr install
(lfs chroot) root:/sources/man-pages-6.17# cd .. && rm -rf man-pages-6.17


# Iana-Etc-20260202
(lfs chroot) root:/sources# tar xvf iana-etc-20260202.tar.gz
(lfs chroot) root:/sources# cd iana-etc-20260202
(lfs chroot) root:/sources/iana-etc-20260202# cp -v services protocols /etc
(lfs chroot) root:/sources/iana-etc-20260202# cd .. && rm -rf iana-etc-20260202


# Glibc-2.43
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

(lfs chroot) root:/sources/glibc-2.43/build# make -j$(nproc) && touch /etc/ld.so.conf
(lfs chroot) root:/sources/glibc-2.43/build# sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
(lfs chroot) root:/sources/glibc-2.43/build# make install
(lfs chroot) root:/sources/glibc-2.43/build# sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
 

可以使用 localedef 程序安装单个语言环境。
例如下面的第二个 localedef 命令将/usr/share/i18n/locales/cs_CZ字符集无关语言环境定义与/usr/share/i18n/charmaps/UTF-8.gz字符映射定义合并，并将结果追加到 /usr/lib/locale/locale-archive文件中
以下说明将安装测试覆盖率达到最佳所需的最小语言环境集：
(lfs chroot) root:/sources/glibc-2.43/build# 
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
或者可用以下耗时的命令一次性安装 glibc-2.43/localedata/SUPPORTED 文件中列出的所有区域设置（其中包含上述所有区域设置以及更多其他区域设置）：
(lfs chroot) root:/sources/glibc-2.43/build# make localedata/install-locales
 
然后当需要时可用 localedef 命令创建并安装 glibc-2.43/localedata/SUPPORTED 文件中未列出的语言环境。例如，本章后面的一些测试需要以下两个语言环境：
(lfs chroot) root:/sources/glibc-2.43/build# localedef -i C -f UTF-8 C.UTF-8 && localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true


# 配置Glibc
需要先创建/etc/nsswitch.conf，因为Glibc的默认设置无法在网络环境下正常工作
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

(lfs chroot) root:/sources/glibc-2.43/build# 
for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

(lfs chroot) root:/sources/glibc-2.43/build# 
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p Asia/Shanghai
unset ZONEINFO tz
 
确定本地时区的一种方法是运行以下脚本：tzselect
然后创建文件：ln -sfv /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime
 
# 配置动态加载器
创建/etc/ld.so.conf新文件：
(lfs chroot) root:/sources/glibc-2.43/build# cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF
 
(lfs chroot) root:/sources/glibc-2.43/build# cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF
 
(lfs chroot) root:/sources/glibc-2.43/build# mkdir -p /etc/ld.so.conf.d
 
(lfs chroot) root:/sources/glibc-2.43/build# cd ../.. && rm -rf glibc-2.43



# zlib-1.3.2
(lfs chroot) root:/sources# tar zxvf zlib-1.3.2.tar.gz
(lfs chroot) root:/sources# cd zlib-1.3.2
(lfs chroot) root:/sources/zlib-1.3.2# ./configure --prefix=/usr && make -j$(nporc) && make check && make install
删除无用的静态库：
(lfs chroot) root:/sources/zlib-1.3.2# rm -fv /usr/lib/libz.a
(lfs chroot) root:/sources/zlib-1.3.2# cd .. && rm -rf zlib-1.3.2



# Bzip2-1.0.8
(lfs chroot) root:/sources# tar zxvf bzip2-1.0.8.tar.gz
(lfs chroot) root:/sources# cd bzip2-1.0.8
(lfs chroot) root:/sources/bzip2-1.0.8# patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
(lfs chroot) root:/sources/bzip2-1.0.8# sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
(lfs chroot) root:/sources/bzip2-1.0.8# sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
(lfs chroot) root:/sources/bzip2-1.0.8# make -f Makefile-libbz2_so
(lfs chroot) root:/sources/bzip2-1.0.8# make clean
(lfs chroot) root:/sources/bzip2-1.0.8# make -j$(nporc) && make PREFIX=/usr install
安装共享库：
(lfs chroot) root:/sources/bzip2-1.0.8# 
cp -av libbz2.so.* /usr/lib
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
共享库的名称没有统一标准，不同发行版使用的库名称可能不同。上面的说明已经安装了库libbz2.so.1.0，但某些应用程序（例如 Kbd）需要libbz2.so.1使用其他发行版使用的名称。请为它们创建一个兼容性符号链接：
(lfs chroot) root:/sources/bzip2-1.0.8# ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1

将共享的bzip2二进制文件 安装到 目录中，并将两个bzip2/usr/bin副本替换为符号链接：
(lfs chroot) root:/sources/bzip2-1.0.8# 
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done

删除无用的静态库：
(lfs chroot) root:/sources/bzip2-1.0.8# rm -fv /usr/lib/libbz2.a

(lfs chroot) root:/sources/bzip2-1.0.8# cd .. && rm -rf bzip2-1.0.8



# Xz-5.8.2
(lfs chroot) root:/sources# tar xvf xz-5.8.2.tar.xz
(lfs chroot) root:/sources# cd xz-5.8.2
(lfs chroot) root:/sources/xz-5.8.2# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/xz-5.8.2
(lfs chroot) root:/sources/xz-5.8.2# make -j$(nporc) && make check && make install
(lfs chroot) root:/sources/xz-5.8.2# cd .. && rm -rf xz-5.8.2



# lz4-1.10.0
(lfs chroot) root:/sources# tar zxvf lz4-1.10.0.tar.gz
(lfs chroot) root:/sources# cd lz4-1.10.0
(lfs chroot) root:/sources/lz4-1.10.0# make BUILD_STATIC=no PREFIX=/usr && make BUILD_STATIC=no PREFIX=/usr install
(lfs chroot) root:/sources/lz4-1.10.0# cd .. && rm -rf lz4-1.10



# zstd-1.5.7
(lfs chroot) root:/sources# tar zxvf zstd-1.5.7.tar.gz 
(lfs chroot) root:/sources# cd zstd-1.5.7
(lfs chroot) root:/sources/zstd-1.5.7# make prefix=/usr && make prefix=/usr install && rm -v /usr/lib/libzstd.a
(lfs chroot) root:/sources/zstd-1.5.7# cd .. && rm -rf zstd-1.5.7



# file-5.46
(lfs chroot) root:/sources# tar zxvf file-5.46.tar.gz
(lfs chroot) root:/sources# cd file-5.46
(lfs chroot) root:/sources/file-5.46# ./configure --prefix=/usr && make -j$(nporc) && make install
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
(lfs chroot) root:/sources/readline-8.3# make SHLIB_LIBS="-lncursesw" && make install
(lfs chroot) root:/sources/readline-8.3# install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3
(lfs chroot) root:/sources/readline-8.3# cd .. && rm -rf readline-8.3


# pcre2-10.47
(lfs chroot) root:/sources# tar jxvf pcre2-10.47.tar.bz2
(lfs chroot) root:/sources# cd pcre2-10.47
(lfs chroot) root:/sources/pcre2-10.47# ./configure --prefix=/usr  --docdir=/usr/share/doc/pcre2-10.47 \
--enable-unicode  --enable-jit  --enable-pcre2-16  --enable-pcre2-32  --enable-pcre2grep-libz   
--enable-pcre2grep-libbz2  --enable-pcre2test-libreadline   --disable-static
(lfs chroot) root:/sources/pcre2-10.47# make -j$(nporc) && make install
(lfs chroot) root:/sources/pcre2-10.47# cd .. && rm -rf pcre2-10.47


# M4-1.4.21
(lfs chroot) root:/sources# tar xvf m4-1.4.21.tar.xz
(lfs chroot) root:/sources# cd m4-1.4.21
(lfs chroot) root:/sources/m4-1.4.21# ./configure --prefix=/usr && make -j$(nporc) && make install
(lfs chroot) root:/sources/m4-1.4.21# cd .. && rm -rf m4-1.4.21


# bc-7.0.3
(lfs chroot) root:/sources# tar xvf bc-7.0.3.tar.xz 
(lfs chroot) root:/sources# cd bc-7.0.3
(lfs chroot) root:/sources/bc-7.0.3# CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
(lfs chroot) root:/sources/bc-7.0.3# make -j$(nporc) && make install
(lfs chroot) root:/sources/bc-7.0.3# cd .. && rm -rf bc-7.0.3


# flex-2.6.4
(lfs chroot) root:/sources# tar zxvf flex-2.6.4.tar.gz
(lfs chroot) root:/sources# cd flex-2.6.4
(lfs chroot) root:/sources/flex-2.6.4# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/flex-2.6.4
(lfs chroot) root:/sources/flex-2.6.4# make -j$(nporc) && make install
(lfs chroot) root:/sources/flex-2.6.4# ln -sv  flex   /usr/bin/lex && ln -sv  flex.1  /usr/share/man/man1/lex.1
(lfs chroot) root:/sources/flex-2.6.4# cd .. && rm -rf flex-2.6.4


# tcl-8.6.17
(lfs chroot) root:/sources# tar zxvf tcl8.6.17-src.tar.gz
(lfs chroot) root:/sources# cd tcl8.6.17
(lfs chroot) root:/sources/tcl8.6.17# SRCDIR=$(pwd) && cd unix
(lfs chroot) root:/sources/tcl8.6.17/unix# ./configure --prefix=/usr --mandir=/usr/share/man --disable-rpath
(lfs chroot) root:/sources/tcl8.6.17/unix# make -j$(nporc)
(lfs chroot) root:/sources/tcl8.6.17/unix#
sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

(lfs chroot) root:/sources/tcl8.6.17/unix# unset SRCDIR
(lfs chroot) root:/sources/tcl8.6.17/unix# make install && chmod 644 /usr/lib/libtclstub8.6.a
(lfs chroot) root:/sources/tcl8.6.17/unix# chmod -v u+w /usr/lib/libtcl8.6.so
(lfs chroot) root:/sources/tcl8.6.17/unix# make install-private-headers
(lfs chroot) root:/sources/tcl8.6.17/unix# ln -sfv tclsh8.6 /usr/bin/tclsh
(lfs chroot) root:/sources/tcl8.6.17/unix# mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
(lfs chroot) root:/sources/tcl8.6.17/unix# cd ..
(lfs chroot) root:/sources/tcl8.6.17# 
tar -xf ../tcl8.6.17-html.tar.gz --strip-components=1
mkdir -v -p /usr/share/doc/tcl-8.6.17
cp -v -r  ./html/* /usr/share/doc/tcl-8.6.17
(lfs chroot) root:/sources/tcl8.6.17# cd .. && rm -rf tcl8.6.17



# expect-5.45.4
(lfs chroot) root:/sources# tar zxvf expect5.45.4.tar.gz 
(lfs chroot) root:/sources# cd expect5.45.4
(lfs chroot) root:/sources/expect5.45.4# python3 -c 'from pty import spawn; spawn(["echo", "ok"])'
(lfs chroot) root:/sources/expect5.45.4# patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
(lfs chroot) root:/sources/expect5.45.4# ./configure --prefix=/usr --with-tcl=/usr/lib --enable-shared \
--disable-rpath --mandir=/usr/share/man --with-tclinclude=/usr/include

(lfs chroot) root:/sources/expect5.45.4# make -j$(nporc) && make install
(lfs chroot) root:/sources/expect5.45.4# ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
(lfs chroot) root:/sources/expect5.45.4# cd .. && rm -rf expect5.45.4



# dejaGNU-1.6.3
(lfs chroot) root:/sources# tar zxvf dejagnu-1.6.3.tar.gz
(lfs chroot) root:/sources# cd dejagnu-1.6.3
(lfs chroot) root:/sources/dejagnu-1.6.3# mkdir build && cd build
(lfs chroot) root:/sources/dejagnu-1.6.3/build# ../configure --prefix=/usr
(lfs chroot) root:/sources/dejagnu-1.6.3/build# 
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi           # 有可能会报no htmlxref.cnf entry found for `dir'
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
make install
install -v -dm755  /usr/share/doc/dejagnu-1.6.3
install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3

(lfs chroot) root:/sources/dejagnu-1.6.3/build# cd ../.. &&  rm -rf dejagnu-1.6.3



# pkgconf-2.5.1
(lfs chroot) root:/sources# tar xvf pkgconf-2.5.1.tar.xz
(lfs chroot) root:/sources# cd pkgconf-2.5.1
(lfs chroot) root:/sources/pkgconf-2.5.1# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/pkgconf-2.5.1
(lfs chroot) root:/sources/pkgconf-2.5.1# make -j$(nporc) && make install
(lfs chroot) root:/sources/pkgconf-2.5.1# 
ln -sv pkgconf   /usr/bin/pkg-config
ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1

(lfs chroot) root:/sources/pkgconf-2.5.1# cd .. && rm -rf pkgconf-2.5.1



# binutils-2.46.0
(lfs chroot) root:/sources# tar -xvf binutils-2.46.0.tar.xz
(lfs chroot) root:/sources# cd binutils-2.46.0
(lfs chroot) root:/sources/binutils-2.46.0# mkdir build && cd build
(lfs chroot) root:/sources/binutils-2.46.0/build# ../configure --prefix=/usr --sysconfdir=/etc \
--enable-ld=default --enable-plugins   --enable-shared     \
--disable-werror   --enable-64-bit-bfd  --enable-new-dtags  \
--with-system-zlib  --enable-default-hash-style=gnu

(lfs chroot) root:/sources/binutils-2.46.0/build# make tooldir=/usr -j$(nporc) && make tooldir=/usr install
(lfs chroot) root:/sources/binutils-2.46.0/build# rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a  /usr/share/doc/gprofng/
(lfs chroot) root:/sources/binutils-2.46.0/build# cd ../.. && rm -rf binutils-2.46.0



# GMP-6.3.0
(lfs chroot) root:/sources# tar xvf gmp-6.3.0.tar.xz
(lfs chroot) root:/sources# cd gmp-6.3.0
(lfs chroot) root:/sources/gmp-6.3.0# sed -i '/long long t1;/,+1s/()/(...)/' configure
(lfs chroot) root:/sources/gmp-6.3.0# ./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.3.0
(lfs chroot) root:/sources/gmp-6.3.0# make -j$(nporc) && make html
# 检验结果
(lfs chroot) root:/sources/gmp-6.3.0# make check 2>&1 | tee gmp-check-log
(lfs chroot) root:/sources/gmp-6.3.0# awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log      # 确保测试套件中至少有199个测试用例通过
# 安装软件包及其文档
(lfs chroot) root:/sources/gmp-6.3.0# make install && make install-html
(lfs chroot) root:/sources/gmp-6.3.0# cd .. && rm -rf gmp-6.3.0


# MPFR-4.2.2
(lfs chroot) root:/sources# tar xvf mpfr-4.2.2.tar.xz 
(lfs chroot) root:/sources# cd mpfr-4.2.2
(lfs chroot) root:/sources/mpfr-4.2.2# ./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.2
(lfs chroot) root:/sources/mpfr-4.2.2# make -j$(nporc) && make html
(lfs chroot) root:/sources/mpfr-4.2.2# make install && make install-html
(lfs chroot) root:/sources/mpfr-4.2.2# cd .. && rm -rf mpfr-4.2.2


# MPC-1.3.1
(lfs chroot) root:/sources# tar zxvf mpc-1.3.1.tar.gz
(lfs chroot) root:/sources# cd mpc-1.3.1
(lfs chroot) root:/sources/mpc-1.3.1# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpc-1.3.1 && make -j$(nproc) && make html && make check
安装软件包及其文档：
(lfs chroot) root:/sources/mpc-1.3.1# make install && make install-html
(lfs chroot) root:/sources/mpc-1.3.1# cd .. && rm -rf mpc-1.3.1


# attr-2.5.2
(lfs chroot) root:/sources# tar zxvf attr-2.5.2.tar.gz 
(lfs chroot) root:/sources# cd attr-2.5.2
(lfs chroot) root:/sources/attr-2.5.2# ./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/attr-2.5.2
(lfs chroot) root:/sources/attr-2.5.2# make -j$(nporc) && make install
(lfs chroot) root:/sources/attr-2.5.2# cd .. && rm -rf attr-2.5.2


# acl-2.3.2
(lfs chroot) root:/sources# tar xvf acl-2.3.2.tar.xz
(lfs chroot) root:/sources# cd acl-2.3.2
(lfs chroot) root:/sources/acl-2.3.2# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/acl-2.3.2
(lfs chroot) root:/sources/acl-2.3.2# make -j$(nporc) && make install
(lfs chroot) root:/sources/acl-2.3.2# cd .. && rm -rf acl-2.3.2


# libcap-2.77
(lfs chroot) root:/sources# tar xvf libcap-2.77.tar.xz
(lfs chroot) root:/sources# cd libcap-2.77
(lfs chroot) root:/sources/libcap-2.77# sed -i '/install -m.*STA/d' libcap/Makefile
(lfs chroot) root:/sources/libcap-2.77# make prefix=/usr lib=lib
(lfs chroot) root:/sources/libcap-2.77# make prefix=/usr lib=lib install
(lfs chroot) root:/sources/libcap-2.77# cd .. && rm -rf libcap-2.77


# libxcrypt-4.5.2
(lfs chroot) root:/sources# tar xvf libxcrypt-4.5.2.tar.xz
(lfs chroot) root:/sources# cd libxcrypt-4.5.2
(lfs chroot) root:/sources/libxcrypt-4.5.2# sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c
(lfs chroot) root:/sources/libxcrypt-4.5.2# ./configure --prefix=/usr --enable-hashes=strong,glibc --enable-obsolete-api=no \
--disable-static --disable-failure-tokens
(lfs chroot) root:/sources/libxcrypt-4.5.2# make -j$(nporc) && make install
(lfs chroot) root:/sources/libxcrypt-4.5.2# cd .. && rm -rf libxcrypt-4.5.2


# shadow-4.19.3
(lfs chroot) root:/sources# tar xvf shadow-4.19.3.tar.xz 
(lfs chroot) root:/sources# cd shadow-4.19.3
(lfs chroot) root:/sources/shadow-4.19.3# 
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

(lfs chroot) root:/sources/shadow-4.19.3# 
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs

(lfs chroot) root:/sources/shadow-4.19.3# touch /usr/bin/passwd
(lfs chroot) root:/sources/shadow-4.19.3# ./configure --sysconfdir=/etc --disable-static \
--with-{b,yes}crypt --without-libbsd --disable-logind --with-group-name-max-length=32
(lfs chroot) root:/sources/shadow-4.19.3# make -j$(nporc) && make exec_prefix=/usr install && make -C man install-man

要启用隐藏密码
(lfs chroot) root:/sources/shadow-4.19.3# pwconv

要启用隐藏组密码
(lfs chroot) root:/sources/shadow-4.19.3# grpconv

释义：
在没有shadow口令的远古时代，所有的用户信息（包括加密后的密码）都存在 /etc/passwd 里
问题： /etc/passwd 必须对所有用户可读（不然你运行 ls -l 时系统没法把 UID 转换成用户名）。这意味着任何普通用户都能拿到所有人的加密密码，然后带回家进行暴力破解
 
pwconv命令的作用：
它会把加密后的密码从 /etc/passwd 中抽离出来
把它转移到 /etc/shadow 文件中
结果： /etc/passwd 里的密码位变成了x。而 /etc/shadow 权限被设为仅root可读
 
grpconv命令的作用：
同理，它把 /etc/group 里的组密码转移到 /etc/gshadow 中
 
 
要更改默认参数，/etc/default/useradd必须创建并根据您的特定需求定制该文件。创建方法如下：
(lfs chroot) root:/sources/shadow-4.19.3# mkdir -p /etc/default
(lfs chroot) root:/sources/shadow-4.19.3# useradd -D --gid 999
释义：
此参数设置 /etc/group 文件中使用的组编号的起始值。此处的值 999 来自上面的 --gid 参数。您可以将其设置为任何所需的值
请注意，useradd 命令永远不会重复使用 UID 或 GID。如果此参数中指定的编号已被使用，它将使用下一个可用的编号
另请注意，如果您的系统中没有 ID 等于此编号的组，则首次在不使用 -g 参数的情况下使用 useradd 命令时，即使帐户已正确创建，也会生成错误消息“useradd: unknown GID 999”
这就是为什么我们在 7.6 节“创建必要文件和符号链接”中创建了具有此组 ID 的 users 组的原因
 
CREATE_MAIL_SPOOL=yes
此参数使 useradd 为每个新用户创建一个邮箱文件。useradd会将此文件的组所有权分配给具有 0660 权限的邮件组。如不想创建这些文件：
(lfs chroot) root:/sources/shadow-4.19.3# sed -i '/MAIL/s/yes/no/' /etc/default/useradd
 
 
设置root密码
(lfs chroot) root:/sources/shadow-4.19.3# passwd root
Changing password for root
Enter the new password (minimum of 5 characters)                            # 输入新密码(最小5个字符)
Please use a combination of upper and lower case letters and numbers.       # 请使用大小写字母和数字的组合
New password:                    # A星
Re-enter new password: 
passwd: password changed.
 
 
(lfs chroot) root:/sources/shadow-4.19.3# cd .. && rm -rf shadow-4.19.3



# GCC-15.2.0
(lfs chroot) root:/sources# tar xvf gcc-15.2.0.tar.xz
(lfs chroot) root:/sources# cd gcc-15.2.0
(lfs chroot) root:/sources/gcc-15.2.0# sed -i 's/char [*]q/const &/' libgomp/affinity-fmt.c
(lfs chroot) root:/sources/gcc-15.2.0# case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac


(lfs chroot) root:/sources/gcc-15.2.0# mkdir build && cd build
(lfs chroot) root:/sources/gcc-15.2.0/build# ../configure --prefix=/usr  LD=ld \
--enable-languages=c,c++ --enable-default-pie --enable-default-ssp --enable-host-pie \
--disable-multilib --disable-bootstrap --disable-fixincludes --with-system-zlib

(lfs chroot) root:/sources/gcc-15.2.0/build# make -j$(nproc) && make install
 
将栈大小硬限制设置为无限
(lfs chroot) root:/sources/gcc-15.2.0/build# ulimit -s -H unlimited
 
GCC 构建目录tester目前属于某个用户，而已安装的头文件目录（及其内容）的所有权不正确。请将所有权更改为指定root的用户和组：
(lfs chroot) root:/sources/gcc-15.2.0/build# chown -v -R root:root  /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include{,-fixed}

创建FHS 出于“历史”原因 要求的符号链接
(lfs chroot) root:/sources/gcc-15.2.0/build# ln -svr /usr/bin/cpp /usr/lib

许多软件包使用cc 这个名称来调用 C 编译器。我们已经在gcc-pass2中创建了cc的符号链接，也请将其手册页创建为符号链接：
(lfs chroot) root:/sources/gcc-15.2.0/build# ln -sv gcc.1 /usr/share/man/man1/cc.1

添加兼容性符号链接，以启用使用链接时优化 (LTO) 构建程序：
(lfs chroot) root:/sources/gcc-15.2.0/build# ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/15.2.0/liblto_plugin.so  /usr/lib/bfd-plugins/

现在我们的最终工具链已经就绪，接下来需要再次确保编译和链接能够按预期工作。为此，我们执行一些健全性检查：
(lfs chroot) root:/sources/gcc-15.2.0/build# echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
(lfs chroot) root:/sources/gcc-15.2.0/build# readelf -l a.out | grep ': /lib'                             # 以下是回显
[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]

确保我们已设置好要使用正确的启动文件：
(lfs chroot) root:/sources/gcc-15.2.0/build# grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log      # 以下是回显
/usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/../../../../lib/Scrt1.o succeeded
/usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/../../../../lib/crti.o succeeded
/usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/../../../../lib/crtn.o succeeded

# 验证编译器是否正在查找正确的头文件
(lfs chroot) root:/sources/gcc-15.2.0/build# grep -B4 '^ /usr/include' dummy.log      # 以下是回显
#include <...> search starts here:
 /usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/include
 /usr/local/include
 /usr/lib/gcc/x86_64-pc-linux-gnu/15.2.0/include-fixed
 /usr/include

验证新链接器是否使用了正确的搜索路径：
(lfs chroot) root:/sources/gcc-15.2.0/build# grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
应忽略包含“-linux-gnu”组件的路径引用，但除此之外，最后一个命令的输出应为：
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib64")
SEARCH_DIR("/usr/local/lib64")
SEARCH_DIR("/lib64")
SEARCH_DIR("/usr/lib64")
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib")
SEARCH_DIR("/usr/local/lib")
SEARCH_DIR("/lib")
SEARCH_DIR("/usr/lib");

确保我们使用的是正确的 libc 库：
(lfs chroot) root:/sources/gcc-15.2.0/build# grep "/lib.*/libc.so.6 " dummy.log         # 以下是回显
attempt to open /usr/lib/libc.so.6 succeeded

确保 GCC 使用的是正确的动态链接器：
(lfs chroot) root:/sources/gcc-15.2.0/build# grep found dummy.log                       # 以下是回显
found ld-linux-x86-64.so.2 at /usr/lib/ld-linux-x86-64.so.2

如果输出结果与上述所示不符，或者根本没有收到输出，则说明出现了严重问题。请仔细检查并重新执行所有步骤，找出问题所在并加以解决。所有问题都必须在继续操作之前解决。

一切运行正常后，清理测试文件：
(lfs chroot) root:/sources/gcc-15.2.0/build# rm -v a.out dummy.log

移动一个放错位置的文件：
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

(lfs chroot) root:/sources/gcc-15.2.0/build# cd ../.. && rm -rf gcc-15.2.0



# Ncurses-6.6
(lfs chroot) root:/sources# tar zxvf ncurses-6.6.tar.gz
(lfs chroot) root:/sources# cd ncurses-6.6
(lfs chroot) root:/sources/ncurses-6.6# ./configure --prefix=/usr \
--mandir=/usr/share/man \
--with-shared           \
--without-debug         \
--without-normal        \
--with-cxx-shared       \
--enable-pc-files       \
--with-pkg-config-libdir=/usr/lib/pkgconfig

(lfs chroot) root:/sources/ncurses-6.6# make -j$(nproc) 
(lfs chroot) root:/sources/ncurses-6.6# 
make DESTDIR=$PWD/dest install
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i dest/usr/include/curses.h
cp --remove-destination -av dest/*  /

for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done

ln -sfv libncursesw.so /usr/lib/libcurses.so
cp -v -R doc -T /usr/share/doc/ncurses-6.6

(lfs chroot) root:/sources/ncurses-6.6# cd .. && rm -rf ncurses-6.6




# sed-4.9
(lfs chroot) root:/sources# tar xvf sed-4.9.tar.xz
(lfs chroot) root:/sources# ./configure --prefix=/usr && make -j$(nproc) && make html
(lfs chroot) root:/sources# 
make install
install -d -m755           /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9

(lfs chroot) root:/sources/sed-4.9# cd .. && rm -rf sed-4.9



# psmisc-23.7
(lfs chroot) root:/sources# tar xvf psmisc-23.7.tar.xz
(lfs chroot) root:/sources# cd psmisc-23.7
(lfs chroot) root:/sources/psmisc-23.7# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/psmisc-23.7# cd .. && rm -rf psmisc-23.7


# gettext-1.0
(lfs chroot) root:/sources# tar xvf gettext-1.0.tar.xz
(lfs chroot) root:/sources# cd gettext-1.0
(lfs chroot) root:/sources/gettext-1.0# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/gettext-1.0
(lfs chroot) root:/sources/gettext-1.0# make -j$(nproc) && make install && chmod -v 0755 /usr/lib/preloadable_libintl.so
(lfs chroot) root:/sources/gettext-1.0# cd .. && rm -rf gettext-1.0


# bison-3.8.2
(lfs chroot) root:/sources# tar xvf bison-3.8.2.tar.xz
(lfs chroot) root:/sources# cd bison-3.8.2
(lfs chroot) root:/sources/bison-3.8.2# ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2 && make -j$(nproc) && make install
(lfs chroot) root:/sources/bison-3.8.2# cd .. && rm -rf bison-3.8.2


# grep-3.12
(lfs chroot) root:/sources# tar xvf grep-3.12.tar.xz
(lfs chroot) root:/sources# cd grep-3.12
(lfs chroot) root:/sources/grep-3.12# sed -i "s/echo/#echo/" src/egrep.sh
(lfs chroot) root:/sources/grep-3.12# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/grep-3.12# cd .. && rm -rf grep-3.12


# bash-5.3
(lfs chroot) root:/sources# tar xvf bash-5.3.tar.gz 
(lfs chroot) root:/sources# cd bash-5.3
(lfs chroot) root:/sources/bash-5.3# ./configure --prefix=/usr --without-bash-malloc --with-installed-readline --docdir=/usr/share/doc/bash-5.3
(lfs chroot) root:/sources/bash-5.3# make -j$(nproc) && make install
运行新编译的bash程序（替换当前正在执行的程序）：
(lfs chroot) root:/sources/bash-5.3# exec /usr/bin/bash --login         # 还没测怎么验证
(lfs chroot) root:/sources/bash-5.3# cd .. && rm -rf bash-5.3



# libtool-2.5.4
(lfs chroot) root:/sources# tar xvf libtool-2.5.4.tar.xz
(lfs chroot) root:/sources# cd libtool-2.5.4
(lfs chroot) root:/sources/libtool-2.5.4# ./configure --prefix=/usr && make -j$(nproc) && make install && rm -fv /usr/lib/libltdl.a 
(lfs chroot) root:/sources/libtool-2.5.4# cd .. && rm -rf libtool-2.5.4


# GDBM-1.26
(lfs chroot) root:/sources# tar xvf gdbm-1.26.tar.gz
(lfs chroot) root:/sources# cd gdbm-1.26
(lfs chroot) root:/sources/gdbm-1.26# ./configure --prefix=/usr --disable-static --enable-libgdbm-compat
(lfs chroot) root:/sources/gdbm-1.26# make -j$(nproc) && make install 
(lfs chroot) root:/sources/gdbm-1.26# cd .. && rm -rf gdbm-1.26


# gperf-3.3
(lfs chroot) root:/sources# tar zxvf gperf-3.3.tar.gz
(lfs chroot) root:/sources# cd gperf-3.3
(lfs chroot) root:/sources/gperf-3.3# ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3 && make -j$(nproc) && make install
(lfs chroot) root:/sources/gperf-3.3# cd .. && rm -rf gperf-3.3


# expat-2.7.4
(lfs chroot) root:/sources# tar xvf expat-2.7.4.tar.xz
(lfs chroot) root:/sources# cd expat-2.7.4
(lfs chroot) root:/sources/expat-2.7.4# ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/expat-2.7.4 && make -j$(nproc) && make install
(lfs chroot) root:/sources/expat-2.7.4# install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.4
(lfs chroot) root:/sources/expat-2.7.4# cd .. && rm -rf expat-2.7.4


# inetutils-2.7
(lfs chroot) root:/sources# tar zxvf inetutils-2.7.tar.gz
(lfs chroot) root:/sources# cd inetutils-2.7
(lfs chroot) root:/sources/inetutils-2.7# sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
(lfs chroot) root:/sources/inetutils-2.7# ./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var \
--disable-logger --disable-whois --disable-rcp --disable-rexec --disable-rlogin --disable-rsh --disable-servers
(lfs chroot) root:/sources/inetutils-2.7# make -j$(nproc) && make install
(lfs chroot) root:/sources/inetutils-2.7# mv -v /usr/{,s}bin/ifconfig
(lfs chroot) root:/sources/inetutils-2.7# cd .. && rm -rf inetutils-2.7


# less-692
(lfs chroot) root:/sources# tar zxvf less-692.tar.gz
(lfs chroot) root:/sources# cd less-692
(lfs chroot) root:/sources/less-692# ./configure --prefix=/usr --sysconfdir=/etc && make -j$(nproc) && make install
(lfs chroot) root:/sources/less-692# cd .. && rm -rf less-692


# perl-5.42.0               https://linuxfromscratch.org/lfs/view/stable-systemd/chapter08/perl.html
(lfs chroot) root:/sources# tar -xvf perl-5.42.0.tar.xz
(lfs chroot) root:/sources# cd perl-5.42.0
(lfs chroot) root:/sources/perl-5.42.0# export BUILD_ZLIB=False && export BUILD_BZIP2=0
(lfs chroot) root:/sources/perl-5.42.0# sh Configure -des   -D prefix=/usr  -D vendorprefix=/usr \
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
(lfs chroot) root:/sources/perl-5.42.0# cd .. &&  rm -rf perl-5.42



# XML::Parser-2.47
(lfs chroot) root:/sources# tar zxvf XML-Parser-2.47.tar.gz
(lfs chroot) root:/sources# cd XML-Parser-2.47
(lfs chroot) root:/sources/XML-Parser-2.47# perl Makefile.PL && make -j$(nproc) && make install
(lfs chroot) root:/sources/XML-Parser-2.47# cd .. && rm -rf XML-Parser-2.47


# intltool-0.51.0
(lfs chroot) root:/sources# tar -xvf intltool-0.51.0.tar.gz 
(lfs chroot) root:/sources# cd intltool-0.51.0
(lfs chroot) root:/sources/intltool-0.51.0# sed -i 's:\\\${:\\\$\\{:' intltool-update.in
(lfs chroot) root:/sources/intltool-0.51.0# ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/intltool-0.51.0# install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
(lfs chroot) root:/sources/intltool-0.51.0# cd .. && rm -rf intltool-0.51.0


#Autoconf-2.72
(lfs chroot) root:/sources# tar xvf autoconf-2.72.tar.xz
(lfs chroot) root:/sources# cd autoconf-2.72
(lfs chroot) root:/sources/autoconf-2.72# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/autoconf-2.72# cd .. && rm -rf autoconf-2.72


# Automake-1.18.1
(lfs chroot) root:/sources# tar xvf automake-1.17.tar.xz
(lfs chroot) root:/sources# cd automake-1.18
(lfs chroot) root:/sources/automake-1.18# ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18 && make -j$(nproc) && make install
(lfs chroot) root:/sources/automake-1.18# cd .. && rm -rf automake-1.18


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


# Elfutils-0.194                 https://linuxfromscratch.org/lfs/view/stable-systemd/chapter08/libelf.html
(lfs chroot) root:/sources# tar jxvf elfutils-0.194.tar.bz2
(lfs chroot) root:/sources# cd elfutils-0.194
(lfs chroot) root:/sources/elfutils-0.194# ./configure --prefix=/usr --disable-debuginfod --enable-libdebuginfod=dummy
仅编译Libelf：
(lfs chroot) root:/sources/elfutils-0.194# make -C lib && make -C libelf
仅安装 Libelf：
(lfs chroot) root:/sources/elfutils-0.194# 
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a

(lfs chroot) root:/sources/elfutils-0.194# cd .. && rm -rf elfutils-0.194


# libffi-3.5.2
(lfs chroot) root:/sources# tar zxvf libffi-3.5.2.tar.gz
(lfs chroot) root:/sources# cd libffi-3.5.2
(lfs chroot) root:/sources/libffi-3.5.2# ./configure --prefix=/usr --disable-static --with-gcc-arch=native && make -j$(nproc) && make install
(lfs chroot) root:/sources/libffi-3.5.2# cd .. && rm -rf libffi-3.5.2


# SQLite-3510200
(lfs chroot) root:/sources/# tar zxvf sqlite-autoconf-3510200.tar.gz
(lfs chroot) root:/sources# cd sqlite-autoconf-3510200
(lfs chroot) root:/sources/sqlite-autoconf-3510200# tar xvf ../sqlite-doc-3510200.tar.xz
(lfs chroot) root:/sources/sqlite-autoconf-3510200# ./configure --prefix=/usr \
--disable-static --enable-fts{4,5} \
CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 -D SQLITE_ENABLE_UNLOCK_NOTIFY=1 \
-D SQLITE_ENABLE_DBSTAT_VTAB=1  -D SQLITE_SECURE_DELETE=1"

编译并安装软件包
(lfs chroot) root:/sources/sqlite-autoconf-3510200# make LDFLAGS.rpath="" && make install
安装文档
(lfs chroot) root:/sources/sqlite-autoconf-3510200# 
install -v -m755 -d /usr/share/doc/sqlite-3.51.2
cp -v -R sqlite-doc-3510200/* /usr/share/doc/sqlite-3.51.2

(lfs chroot) root:/sources/sqlite-autoconf-3510200# cd .. && rm -rf sqlite-autoconf-3510200



# Python-3.14.3
(lfs chroot) root:/sources# tar xvf Python-3.14.3.tar.xz 
(lfs chroot) root:/sources# cd Python-3.14.3
(lfs chroot) root:/sources/Python-3.14.3# ./configure --prefix=/usr --enable-shared --with-system-expat --enable-optimizations --without-static-libpython
(lfs chroot) root:/sources/Python-3.14.3# make -j$(nproc) && make install
启动 LFS 系统并建立网络连接后，会发出另一个警告，提示用户从PyPI 上的预编译wheel包更新pip3 （如有新版本可用）。
但LFS将pip3视为 Python 3 的一部分，因此不应单独更新。此外，从预编译wheel包更新pip3也偏离了我们的目标(从源代码构建Linux系统)
因此关于pip3新版本的警告 也应忽略。如果您愿意，可以通过运行以下命令来抑制所有这些警告，该命令会创建一个配置文件：
(lfs chroot) root:/sources/Python-3.14.3# cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

按需安装预格式化的文档
(lfs chroot) root:/sources/Python-3.14.3# install -v -dm755 /usr/share/doc/python-3.14.3/html
(lfs chroot) root:/sources/Python-3.14.3# tar --strip-components=1  \
--no-same-owner  --no-same-permissions -C /usr/share/doc/python-3.14.3/html -xvf ../python-3.14.3-docs-html.tar.bz2

(lfs chroot) root:/sources/Python-3.14.3# cd .. && rm -rf Python-3.14.3



# flit-Core-3.12.0
(lfs chroot) root:/sources# tar zxvf flit_core-3.12.0.tar.gz
(lfs chroot) root:/sources# cd flit_core-3.12.0
构建软件包
(lfs chroot) root:/sources/flit_core-3.12.0# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
安装软件包
(lfs chroot) root:/sources/flit_core-3.12.0# pip3 install --no-index --find-links dist flit_core
(lfs chroot) root:/sources/flit_core-3.12.0# cd .. && rm -rf flit_core-3.12.0


# packaging-26.0
(lfs chroot) root:/sources# tar zxvf packaging-26.0.tar.gz
(lfs chroot) root:/sources# cd packaging-26.0
编译软件包：
(lfs chroot) root:/sources/packaging-26.0# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
安装软件包：
(lfs chroot) root:/sources/packaging-26.0# pip3 install --no-index --find-links dist packaging
(lfs chroot) root:/sources/packaging-26.0# cd .. && rm -rf packaging-26.0


# Wheel-0.46.3
(lfs chroot) root:/sources# tar zxvf wheel-0.46.3.tar.gz
(lfs chroot) root:/sources# cd wheel-0.46.3
编译Wheel：
(lfs chroot) root:/sources/wheel-0.46.3# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
安装Wheel
(lfs chroot) root:/sources/wheel-0.46.3# pip3 install --no-index --find-links dist wheel

(lfs chroot) root:/sources/wheel-0.46.3# cd .. && rm -rf wheel-0.46.3


# Setuptools-82.0.0
(lfs chroot) root:/sources# tar zxvf setuptools-82.0.0.tar.gz
(lfs chroot) root:/sources# cd setuptools-82.0.0
(lfs chroot) root:/sources/setuptools-82.0.0# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
(lfs chroot) root:/sources/setuptools-82.0.0# pip3 install --no-index --find-links dist setuptools
(lfs chroot) root:/sources/setuptools-82.0.0# cd .. && rm -rf setuptools-82.0.0


# Ninja-1.13.2
(lfs chroot) root:/sources# tar zxvf ninja-1.13.2.tar.gz
(lfs chroot) root:/sources# cd ninja-1.13.2
可通过环境变量NINJAJOBS限制并行进程的数量
(lfs chroot) root:/sources/ninja-1.13.2# export NINJAJOBS=8
通过运行流编辑器使Ninja识别环境变量 NINJAJOBS：
(lfs chroot) root:/sources/ninja-1.13.2# sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc

构建Ninja
python3 configure.py --bootstrap --verbose
安装软件包
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
(lfs chroot) root:/sources/kmod-34.2/build# meson setup --prefix=/usr ..  --buildtype=release -D manpages=false
(lfs chroot) root:/sources/kmod-34.2/build# ninja && ninja install
(lfs chroot) root:/sources/kmod-34.2/build# cd ../.. && rm -rf kmod-34.2


# Coreutils-9.10
(lfs chroot) root:/sources# tar xvf coreutils-9.10.tar.xz
(lfs chroot) root:/sources# cd coreutils-9.10
(lfs chroot) root:/sources/coreutils-9.10# patch -Np1 -i ../coreutils-9.10-i18n-1.patch
(lfs chroot) root:/sources/coreutils-9.10# autoreconf -fv && automake -af
(lfs chroot) root:/sources/coreutils-9.10# FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
(lfs chroot) root:/sources/coreutils-9.10# make -j$(nproc) && make install
将项目搬迁至FHS指定的地点：
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
(lfs chroot) root:/sources/gawk-5.3.2# sed -i 's/extras//' Makefile.in
(lfs chroot) root:/sources/gawk-5.3.2# ./configure --prefix=/usr && make -j$(nproc)
(lfs chroot) root:/sources/gawk-5.3.2# rm -f /usr/bin/gawk-5.3.2
(lfs chroot) root:/sources/gawk-5.3.2# make install
(lfs chroot) root:/sources/gawk-5.3.2# ln -sv gawk.1 /usr/share/man/man1/awk.1
(lfs chroot) root:/sources/gawk-5.3.2# install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.2
(lfs chroot) root:/sources/gawk-5.3.2# cd .. && rm -rf gawk-5.3.2


# Findutils-4.10.0
(lfs chroot) root:/sources# tar xvf findutils-4.10.0.tar.xz 
(lfs chroot) root:/sources# cd findutils-4.10.0
(lfs chroot) root:/sources/findutils-4.10.0# ./configure --prefix=/usr --localstatedir=/var/lib/locate && make -j$(nproc) && make install
(lfs chroot) root:/sources/findutils-4.10.0# cd .. && rm -rf findutils-4.10.0


# Groff-1.23.0
(lfs chroot) root:/sources# tar -zxvf groff-1.23.0.tar.gz
(lfs chroot) root:/sources# cd groff-1.23.0
(lfs chroot) root:/sources/groff-1.23.0# PAGE=A4 ./configure --prefix=/usr && make -j$(nproc) && make check && make install
(lfs chroot) root:/sources/groff-1.23.0# cd .. && rm -rf groff-1.23.0


# GRUB-2.14
取消设置任何可能影响构建的环境变量：
(lfs chroot) root:/sources# unset {C,CPP,CXX,LD}FLAGS
 
(lfs chroot) root:/sources# tar xvf grub-2.14.tar.xz 
(lfs chroot) root:/sources# cd grub-2.14
添加发布 tar 包中缺失的文件：
(lfs chroot) root:/sources/grub-2.14# echo depends bli part_gpt > grub-core/extra_deps.lst
 
准备GRUB进行编译：
(lfs chroot) root:/sources/grub-2.14# vim Makefile
LDFLAGS_IMAGE = -Wl,-no-rosegment $(LDFLAGS_PLATFORM) -nostdlib $(TARGET_LDFLAGS_OLDMAGIC) -Wl,-S
注意：在LDFLAGS_IMAGE的最前面加上-Wl,-no-rosegment

(lfs chroot) root:/sources/grub-2.14# ./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror
(lfs chroot) root:/sources/grub-2.14# make -j$(nproc) \
    LDFLAGS_IMAGE="-Wl,-no-rosegment -nostdlib -Wl,-S" \
    TARGET_LDFLAGS_OLDMAGIC="-Wl,-Ttext,0x9000"

(lfs chroot) root:/sources/grub-2.14# make install

# 确认BIOS引导时寻找GRUB内核的唯一合法入口
(lfs chroot) root:/sources/grub-2.14# readelf -h /usr/lib/grub/i386-pc/kernel.img | grep "Entry point"
  Entry point address:               0x9000
注意：必须是0x9000，如是其他值则需要停止操作进行排查

(lfs chroot) root:/sources/grub-2.14# cd .. && rm -rf grub-2.14


# Gzip-1.14
(lfs chroot) root:/sources# tar xvf gzip-1.14.tar.xz
(lfs chroot) root:/sources# cd gzip-1.14
(lfs chroot) root:/sources/gzip-1.14# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/gzip-1.14# cd .. && rm -rf gzip-1.14


# IPRoute2-6.18.0
(lfs chroot) root:/sources# tar xvf iproute2-6.18.0.tar.xz
(lfs chroot) root:/sources# cd iproute2-6.18.0
(lfs chroot) root:/sources/iproute2-6.18.0# 
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8

(lfs chroot) root:/sources/iproute2-6.18.0# make NETNS_RUN_DIR=/run/netns && \
make SBINDIR=/usr/sbin install && \
install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.18.0

(lfs chroot) root:/sources/iproute2-6.18.0# cd .. && rm -rf iproute2-6.18.0


# Kbd-2.9.0
(lfs chroot) root:/sources# tar xvf kbd-2.9.0.tar.xz
(lfs chroot) root:/sources# cd kbd-2.9.0
(lfs chroot) root:/sources/kbd-2.9.0# patch -Np1 -i ../kbd-2.9.0-backspace-1.patch
(lfs chroot) root:/sources/kbd-2.9.0# 
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

(lfs chroot) root:/sources/kbd-2.9.0# ./configure --prefix=/usr --disable-vlock && make -j$(nproc) && make install
(lfs chroot) root:/sources/kbd-2.9.0# cd .. && rm -rf kbd-2.9.0


# Libpipeline-1.5.8
(lfs chroot) root:/sources# tar zxvf libpipeline-1.5.8.tar.gz
(lfs chroot) root:/sources# cd libpipeline-1.5.8
(lfs chroot) root:/sources/libpipeline-1.5.8# ./configure --prefix=/usr --disable-vlock && make -j$(nproc) && make install
(lfs chroot) root:/sources/libpipeline-1.5.8# cd .. && rm -rf libpipeline-1.5.8


# Make-4.4.1
(lfs chroot) root:/sources# tar zxvf make-4.4.1.tar.gz
(lfs chroot) root:/sources# cd make-4.4.1
(lfs chroot) root:/sources/make-4.4.1# ./configure --prefix=/usr --disable-vlock && make -j$(nproc) && make install
(lfs chroot) root:/sources/make-4.4.1# cd .. && rm -rf make-4.4.1



# Patch-2.8
(lfs chroot) root:/sources# tar xvf patch-2.8.tar.xz 
(lfs chroot) root:/sources# cd patch-2.8
(lfs chroot) root:/sources/patch-2.8# ./configure --prefix=/usr --disable-vlock && make -j$(nproc) && make install
(lfs chroot) root:/sources/patch-2.8# cd .. && rm -rf patch-2.8


# Tar-1.35
(lfs chroot) root:/sources# tar xvf tar-1.35.tar.xz
(lfs chroot) root:/sources# cd tar-1.35
(lfs chroot) root:/sources/tar-1.35# FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
(lfs chroot) root:/sources/tar-1.35# make -j$(nproc) && make install && make -C doc install-html docdir=/usr/share/doc/tar-1.35
(lfs chroot) root:/sources/tar-1.35# cd .. && rm -rf tar-1.35


# Texinfo-7.2
(lfs chroot) root:/sources# tar xvf texinfo-7.2.tar.xz
(lfs chroot) root:/sources# cd texinfo-7.2
(lfs chroot) root:/sources/texinfo-7.2# sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm
(lfs chroot) root:/sources/texinfo-7.2# ./configure --prefix=/usr && make -j$(nproc) && make install && make TEXMF=/usr/share/texmf install-tex
(lfs chroot) root:/sources/texinfo-7.2# pushd /usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
popd

(lfs chroot) root:/sources/texinfo-7.2# cd .. && rm -rf texinfo-7.2


# Vim-9.2.0078
(lfs chroot) root:/sources# tar zxvf vim-9.2.0078.tar.gz
(lfs chroot) root:/sources# cd vim-9.2.0078
(lfs chroot) root:/sources/vim-9.2.0078# echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
(lfs chroot) root:/sources/vim-9.2.0078# ./configure --prefix=/usr && make -j$(nproc) && make install
(lfs chroot) root:/sources/vim-9.2.0078# 
ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
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
(lfs chroot) root:/sources/jinja2-3.1.6# pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD && pip3 install --no-index --find-links dist Jinja2

(lfs chroot) root:/sources/jinja2-3.1.6# cd .. && rm -rf jinja2-3.1.6



# Systemd-259.1
(lfs chroot) root:/sources# tar zxvf systemd-259.1.tar.gz
(lfs chroot) root:/sources# cd systemd-259.1
(lfs chroot) root:/sources/systemd-259.1# sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //'               \
    -i rules.d/50-udev-default.rules.in

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

(lfs chroot) root:/sources/systemd-259.1/build#
echo 'NAME="Linux From Scratch"' > /etc/os-release
unshare -m ninja test

(lfs chroot) root:/sources/systemd-259.1/build# ninja install
安装手册页
(lfs chroot) root:/sources/systemd-259.1/build# tar -xf ../../systemd-man-pages-259.1.tar.xz \
    --no-same-owner --strip-components=1  -C /usr/share/man

创建systemd-journald/etc/machine-id所需的文件：
(lfs chroot) root:/sources/systemd-259.1/build# systemd-machine-id-setup

建立基本目标结构
(lfs chroot) root:/sources/systemd-259.1/build# systemctl preset-all
(lfs chroot) root:/sources/systemd-259.1/build# cd ../.. && rm -rf systemd-259.1



# D-Bus-1.16.2
(lfs chroot) root:/sources# tar xvf dbus-1.16.2.tar.xz
(lfs chroot) root:/sources/dbus-1.16.2# mkdir build && cd build
(lfs chroot) root:/sources/dbus-1.16.2/build# meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
(lfs chroot) root:/sources/dbus-1.16.2/build# ninja && ninja install
(lfs chroot) root:/sources/dbus-1.16.2/build# ln -sfv /etc/machine-id /var/lib/dbus
(lfs chroot) root:/sources/dbus-1.16.2/build# cd ../.. && rm -rf dbus-1.16.2


# Man-DB-2.13.1
(lfs chroot) root:/sources# tar xvf man-db-2.13.1.tar.xz
(lfs chroot) root:/sources# cd man-db-2.13.1
(lfs chroot) root:/sources/man-db-2.13.1# ./configure --prefix=/usr \
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
(lfs chroot) root:/sources/util-linux-2.41.3# ./configure --bindir=/usr/bin \
            --libdir=/usr/lib     \
            --runstatedir=/run    \
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

(lfs chroot) root:/sources/util-linux-2.41.3# make -j$(nproc) && make install
(lfs chroot) root:/sources/util-linux-2.41.3# cd .. && rm -rf util-linux-2.41.3



# E2fsprogs-1.47.3
(lfs chroot) root:/sources# tar zxvf e2fsprogs-1.47.3.tar.gz
(lfs chroot) root:/sources/e2fsprogs-1.47.3# mkdir build && cd build
(lfs chroot) root:/sources/e2fsprogs-1.47.3/build# ../configure --prefix=/usr \
             --sysconfdir=/etc   \
             --enable-elf-shlibs \
             --disable-libblkid  \
             --disable-libuuid   \
             --disable-uuidd     \
             --disable-fsck

(lfs chroot) root:/sources/e2fsprogs-1.47.3/build# make -j$(nproc) && make install

删除无用的静态库：
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

此软件包安装的是一个 gzip 压缩.info 文件，但不会更新系统级dir文件。请解压缩此文件，然后dir使用以下命令更新系统文件：
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

如果需要，可以通过执行以下命令创建并安装一些其他文档：
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info

# 配置E2fsprogs
sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf

(lfs chroot) root:/sources/e2fsprogs-1.47.3/build# cd ../../
(lfs chroot) root:/sources# rm -rf e2fsprogs-1.47.3



# 剥离
(lfs chroot) root:/sources# save_usrlib="$(cd /usr/lib; ls ld-linux*[^g])
             libc.so.6
             libthread_db.so.1
             libquadmath.so.0.0.0
             libstdc++.so.6.0.34
             libitm.so.1.0.0
             libatomic.so.1.2.0"

(lfs chroot) root:/sources# cd /usr/lib

(lfs chroot) root:/usr/lib# for LIB in $save_usrlib; do
    objcopy --only-keep-debug --compress-debug-sections=zstd $LIB $LIB.dbg
    cp $LIB /tmp/$LIB
    strip --strip-debug /tmp/$LIB
    objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

(lfs chroot) root:/usr/lib# online_usrbin="bash find strip"
(lfs chroot) root:/usr/lib# online_usrlib="libbfd-2.46.0.20260210.so
               libsframe.so.3.0.0
               libhistory.so.8.3
               libncursesw.so.6.6
               libm.so.6
               libreadline.so.8.3
               libz.so.1.3.2
               libzstd.so.1.5.7
               $(cd /usr/lib; find libnss*.so* -type f)"

(lfs chroot) root:/usr/lib# for BIN in $online_usrbin; do
    cp /usr/bin/$BIN /tmp/$BIN
    strip --strip-debug /tmp/$BIN
    install -vm755 /tmp/$BIN /usr/bin
    rm /tmp/$BIN
done

(lfs chroot) root:/usr/lib# for LIB in $online_usrlib; do
    cp /usr/lib/$LIB /tmp/$LIB
    strip --strip-debug /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

(lfs chroot) root:/usr/lib# for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
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



# 清理         https://linuxfromscratch.org/lfs/view/stable-systemd/chapter08/cleanup.html
(lfs chroot) root:/usr/lib# rm -rf /tmp/{*,.*}
(lfs chroot) root:/usr/lib# find /usr/lib /usr/libexec -name \*.la -delete
(lfs chroot) root:/usr/lib# find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
最后，删除上一章开头创建的临时“zhangsan”用户帐户
userdel -r zhangsan



```







# 系统配置
```shell
一般网络配置
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
文件冲突：你同时拥有 10-eth-dhcp.network 和 10-eth-static.network。由于它们都匹配 Name=ens33，systemd-networkd 可能同时启动了 DHCP 客户端并尝试设置静态地址。在很多情况下，DHCP 获取到的地址(1) 会覆盖或与静态地址共存，但你的 DHCP 显然先拿到了 .141。
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
请完全忽略这个报错。 这是因为 chroot 环境的 PID 1 依然是宿主机的 init。只要你把上面的 .network 文件写对了，当你真正从硬盘启动 LFS 系统时，
LFS自己的 systemd 会作为 PID 1 启动，它会自动扫描 /etc/systemd/network/ 目录并拉起网络
 
 
配置系统主机名
(lfs chroot) root:/usr/lib# echo lfs > /etc/hostname
 
自定义 /etc/hosts 文件
(lfs chroot) root:/usr/lib# cat > /etc/hosts << "EOF"
127.0.0.1  localhost lfs
::1        localhost
EOF







# 设备和模块操作概述        https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/symlinks.html
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
 



# 设备管理（直接跳过）       https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/symlinks.html
# 配置系统时钟（直接跳过）   https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/clock.html



# 配置Linux控制台        https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/console.html
(lfs chroot) root:/usr/lib# echo FONT=Lat2-Terminus16 > /etc/vconsole.conf
英文键盘和控制台的示例
(lfs chroot) root:/usr/lib# cat > /etc/vconsole.conf << "EOF"
KEYMAP=us
FONT=Lat2-Terminus16
EOF
 
 
确保重启后这个字体能真的加载出来，请务必在 chroot 里执行一下这个命令检查文件是否存在：
(lfs chroot) root:/usr/lib# ls /usr/share/consolefonts/Lat2-Terminus16.psfu.gz          # 下一行是回显
/usr/share/consolefonts/Lat2-Terminus16.psfu.gz  
# 试着手动加载它（即使在chroot里没效果，但能测试命令是否报错）
(lfs chroot) root:/usr/lib# setfont Lat2-Terminus16
 



配置系统区域设置
生成Locale（区域定义）      https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/locale.html
(lfs chroot) root:/usr/lib# localedef -i en_US -f UTF-8 en_US.UTF-8
 
创建配置文件（此时这里不要用中文，因为很有可能会出错）
(lfs chroot) root:/usr/lib# cat > /etc/locale.conf << "EOF"
LANG=en_US.UTF-8
EOF

# 查看当前生成的全部区域
(lfs chroot) root:/usr/lib# localectl list-locales          # 这个命令会报错，没影响
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down
 
注意：完全符合预期！在chroot环境中看到这个报错是绝对正常的，这恰恰证明你之前的操作没毛病。
1. 为什么会报错？
localectl、hostnamectl、systemctl 这些命令都是 systemd 的管理工具。它们的工作原理是：
 
命令执行后，会去寻找系统中的PID 1（即 systemd 守护进程）
通过一个叫 D-Bus 的“总线”与 systemd 进行通讯
但在 chroot 里：
没有PID 1：你当前环境的“老大”是你的宿主机内核，而不是 LFS 的 systemd
总线没开：LFS 的系统服务还没跑起来，通讯信道（D-Bus）当然是断开的
 
用最原始的底层命令来检查/验证Locale是否生成成功
(lfs chroot) root:/usr/lib# ls -F /usr/lib/locale
locale-archive
注意：
如看到 en_US.utf8 文件夹（或者一个巨大的 locale-archive 文件）：说明你之前的 localedef 命令已经成功把语言包“编译”进系统了
只要文件在：当你以后真正重启进入LFS时，systemd就会识别到它们
 
(lfs chroot) root:/usr/lib# cat > /etc/profile << "EOF"
# Begin /etc/profile

for i in $(locale); do
  unset ${i%=*}
done

if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  source /etc/locale.conf

  for i in $(locale); do
    key=${i%=*}
    if [[ -v $key ]]; then
      export $key
    fi
  done
fi

# End /etc/profile
EOF


(lfs chroot) root:/usr/lib# localectl set-locale LANG="en_US.UTF-8" LC_CTYPE="en_US"





# 创建/etc/inputrc文件              https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/inputrc.html
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




# 创建/etc/shells文件        https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/etcshells.html
(lfs chroot) root:/usr/lib# cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF




# Systemd的使用和配置         https://linuxfromscratch.org/lfs/view/stable-systemd/chapter09/systemd-custom.html
(lfs chroot) root:/usr/lib# mkdir -pv /etc/systemd/system/getty@tty1.service.d

(lfs chroot) root:/usr/lib# cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf << EOF
[Service]
TTYVTDisallocate=no
EOF



```






# 使LFS系统可启动
```shell
(lfs chroot) root:/usr/lib# blkid | grep sdb
/dev/sdb2: UUID="9cefc2c2-4e9d-41fa-aaee-f2fee31b885e" TYPE="swap" PARTUUID="c763b99d-a868-4a57-960b-16e3c4c6a94c"
/dev/sdb3: UUID="40a5b6af-35e5-4406-b419-0db595431618" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="f705231d-f76a-445c-b558-3488ca3d10c5"
/dev/sdb1: PARTUUID="3202d6dd-269b-495c-a1c5-9f20f848968e"

分区信息分析
/dev/sdb1: BIOS boot占位符，等着GRUB往里灌二进制代码
/dev/sdb2: 这是你的交换分区 (Swap)
/dev/sdb3：已经正确挂载在 /（在chroot环境下）


 
# 创建/etc/fstab文件      https://linuxfromscratch.org/lfs/view/stable-systemd/chapter10/fstab.html
# 编写/etc/fstab
(lfs chroot) root:/# mkdir -pv /proc /sys /dev/pts /run /dev/shm
(lfs chroot) root:/usr/lib# vim /etc/fstab
UUID=9cefc2c2-4e9d-41fa-aaee-f2fee31b885e     swap   swap    defaults  1  1
UUID=40a5b6af-35e5-4406-b419-0db595431618      /     ext4     pri=1    1  1


(lfs chroot) root:/usr/lib# ls -alh /etc/fstab
-rw-r--r-- 1 root root 154 May  1 11:50 /etc/fstab


```










# 构建Linux-6.18.10内核
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

root@ub24-1:/mnt/lfs# cd /
root@ub24-1:/# umount -v $LFS
umount: /mnt/lfs: target is busy.

# 排查，查看谁在占用这个目录
root@ub24-1:/# lsof +D /mnt/lfs
lsof: WARNING: can't stat() fuse.portal file system /run/user/120/doc
      Output information may be incomplete.
lsof: WARNING: can't stat() fuse.portal file system /run/user/1000/doc
      Output information may be incomplete.

COMMAND    PID  USER   FD   TYPE DEVICE SIZE/OFF    NODE NAME
bash      2095 rambo  cwd    DIR   8,19     4096 1048577 /mnt/lfs/sources
sudo    512950  root  cwd    DIR   8,19     4096 1048577 /mnt/lfs/sources
sudo    512951  root  cwd    DIR   8,19     4096 1048577 /mnt/lfs/sources
注意：
是rambo用户还在使用着这个目录

root@ub24-1:/# exit

rambo@ub24-1:/mnt/lfs/sources$ cd /

# 再来卸载
rambo@ub24-1:~# umount -v $LFS

关闭宿主机 Ubuntu
rambo@ub24-1:~# sudo poweroff


```




## [内核安装](https://linuxfromscratch.org/lfs/view/stable-systemd/chapter10/kernel.html)
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
 
 
内核是整个LFS项目的“心脏”所在，如果不编译内核，现在做的只是硬盘上的“一堆文件”；编译完内核并配置好引导后，它才真正变成一个“操作系统”
内核源码通常在之前存放所有软件包源码的目录中。根据LFS的标准操作流程，需要在 chroot 环境中进行编译
(lfs chroot) root:/# cd sources/
(lfs chroot) root:/sources# tar xvf linux-6.18.10.tar.xz 
(lfs chroot) root:/sources# cd linux-6.18.10
(lfs chroot) root:/sources/linux-6.18.10# make mrproper

# 核心配置阶段 (make menuconfig)
内核配置中有个“依赖项陷阱”。在 menuconfig 中，如果一个选项的前提条件没有被满足，该选项就会被隐藏，即使你直接搜索能看到它，进入菜单后也是找不到的
 
运行 make menuconfig 后，会弹出一个蓝底菜单。在 VMware 中，请务必确保以下选项被编译进内核（状态为 [*] 而不是 <M>）：
(lfs chroot) root:/sources/linux-6.18.10# make menuconfig
[*] (星号)：表示驱动直接编译进内核二进制文件（bzImage）。内核启动时直接就有这些功能
<M> (字母M)：表示驱动是独立文件。内核启动时需要去硬盘找这些文件
 
A. 必须的处理器与核心选项
Processor type and features ->
[*] EFI runtime service support
 

B. 关键驱动：VMware 硬盘驱动 (漏选则无法开机)
由于你的 LFS 在 /dev/sdb1 (SCSI 设备)，内核必须能认出 VMware 的虚拟硬盘控制器：
 
Device Drivers -> SCSI device support -> SCSI low-level drivers ->
  [*] LSI MPT Fusion SAS 3.0 & SAS 2.0 Device Driver
  [*] VMware PVSCSI driver support (VMware 准虚拟化驱动)

Device Drivers -> NVMe Support -> [*] NVM Express block device     # 如是NVMe硬盘则该项也要打开

Device Drivers -> Fusion MPT device support
[*] Fusion MPT ScsiHost drivers for SPI (必须勾选,针对VMware默认的LSI Logic平行/SAS控制器)

分区表：
Enable the block layer -> Partition Types -> Advanced partition selection -> EFI GUID Partition support (*号选中)

C. 文件系统 (漏选则无法挂载根分区)
File systems -> 
[*] The Extended 4 (ext4) filesystem
[*] Ext4 POSIX POSIX Access Control Lists
[*] Ext4 Security Labels
 
D. Systemd必须的选项
LFS-systemd 版本对内核有特殊要求，请检查：
General setup -> 
  [*] Control Group support
  -*- Namespaces support (容器化和 systemd 安全特性需要)
 
Device Drivers -> Generic Driver Options
  [*] Maintain a devtmpfs filesystem to mount at /dev (这个没选，开机必挂)
  [*] Automount devtmpfs at /dev, after the kernel mounted the rootfs
 
Systemd 对系统时钟有依赖，如果没选，启动时可能会报错
Device Drivers -> Real Time Clock -> [*] PC-style 'CMOS'




# 开始编译（使用-j参数利用所有CPU核心）
(lfs chroot) root:/sources/linux-6.18.10# make -j$(nproc)
注：核心越多，编译越快。如果只有1核，可能需要等半小时以上；如果是4核或更多，10分钟左右就能搞定
....
  ....
   ZOFFSET arch/x86/boot/zoffset.h
  OBJCOPY arch/x86/boot/vmlinux.bin
  AS      arch/x86/boot/header.o
  LD      arch/x86/boot/setup.elf
  OBJCOPY arch/x86/boot/setup.bin
  BUILD   arch/x86/boot/bzImage
Kernel: arch/x86/boot/bzImage is ready  (#1)



 
编译完成后，先安装模块（这会放到 /lib/modules 目录下
(lfs chroot) root:/sources/linux-6.18.10# make modules_install
 
手动安装内核镜像到 /boot
(lfs chroot) root:/sources/linux-6.18.10# cp -iv arch/x86/boot/bzImage  /boot/vmlinuz-6.18.10-lfs-13-systemd
 
安装 System.map（调试用）
(lfs chroot) root:/sources/linux-6.18.10# cp -iv System.map /boot/System.map-6.18.10
 
备份你的辛苦成果（下次编译时可以基于此配置）
(lfs chroot) root:/sources/linux-6.18.10# cp -iv .config /boot/config-6.18.10
 
安装Linux内核文档
(lfs chroot) root:/sources/linux-6.18.10# cp -r Documentation -T /usr/share/doc/linux-6.18.10
 







# 使用GRUB设置启动过程        https://linuxfromscratch.org/lfs/view/stable-systemd/chapter10/grub.html
(lfs chroot) root:/sources/linux-6.18.10# grub-install /dev/sdb
Installing for i386-pc platform.
Installation finished. No error reported.


# 要先获取sdb3的UUID


# 创建GRUB配置文件（这个文件和官方的不怎么一样）
(lfs chroot) root:/sources/linux-6.18.10# cat > /boot/grub/grub.cfg << "EOF"
# 开始 GRUB 配置
set default=0
set timeout=5

insmod part_gpt
insmod ext4

# 这里的 search 是为了让 GRUB 在启动阶段找到 /boot 所在的分区
search --no-floppy --fs-uuid --set=root  40a5b6af-35e5-4406-b419-0db595431618


menuentry "GNU/Linux, Linux 6.18.10-lfs-13-systemd" {
        linux   /boot/vmlinuz-6.18.10-lfs-13-systemd root=UUID=40a5b6af-35e5-4406-b419-0db595431618 ro
}
EOF




```





## 退出 chroot并重启
```shell
(lfs chroot) root:/sources/linux-6.18.10# cd /
(lfs chroot) root:/# logout
root@ub24-1:~# 
umount -v $LFS/dev/pts
umount -v $LFS/dev/shm
umount -v $LFS/dev
umount -v $LFS/run
umount -v $LFS/proc
umount -v $LFS/sys

root@ub24-1:~# umount -v $LFS       # 这个需要最后卸载


# 关机，把第一启动项设置成从60G的磁盘启动
root@ub24-1:~# poweroff


```
![image](https://img2024.cnblogs.com/blog/1139005/202605/1139005-20260501174053172-933680660.png)
![image](https://img2024.cnblogs.com/blog/1139005/202605/1139005-20260501175523825-1460414768.png)

