# 部署postfix+Dovecot+Rspamd
## 前奏
```shell
# 在lfs13中先安装postfix+Dovecot+Rspamd和cloudflared客户端
postfix源码包：
http://ftp.porcupine.org/mirrors/postfix-release/index.html
http://ftp.porcupine.org/mirrors/postfix-release/official/postfix-3.11.2.tar.gz

Dovecot源码包：
https://dovecot.org/releases/
https://dovecot.org/releases/2.4/dovecot-2.4.4.tar.gz

Rspamd源码包：
https://github.com/rspamd/rspamd/archive/refs/tags/4.0.1.tar.gz

要在lfs13上手动构建这套"企业级邮件底座"，对源码编译的顺序和依赖处理有极高的要求
核心预警：编译顺序
在 LFS 中，你必须先解决加密与验证库。编译顺序必须是：
OpenSSL (LFS内置) -> SQLite/MariaDB -> ICU -> Ragel -> Libusb (之前已做) -> Postfix -> Dovecot -> Rspamd

```



## 安装部署
```shell
# 先安装syslogd
# ======================================================
顺带安装了以下的包，你可以不安装 # === 中的部分
libfastjson: 必须安装，否则编译报错
libestr: 必须安装，用于字符串处理
libuuid: 通常由 util-linux 提供

# libuuid是已经安装好了的
[root@lfs ~/build_mail]# find /usr/lib /lib -name "libuuid*"
/usr/lib/libuuid.so.1.3.0
/usr/lib/libuuid.so.1
/usr/lib/libuuid.so
[root@lfs ~/build_mail]# ldconfig -p | grep uuid
	libuuid.so.1 (libc6,x86-64) => /usr/lib/libuuid.so.1
	libuuid.so (libc6,x86-64) => /usr/lib/libuuid.so


[root@lfs ~/build_mail]# wget2 https://github.com/troglobit/sysklogd/releases/download/v2.7.2/sysklogd-2.7.2.tar.gz
[root@lfs ~/build_mail]# wget2 -O libestr_v0.1.11.tar.gz https://github.com/rsyslog/libestr/archive/refs/tags/v0.1.11.tar.gz
[root@lfs ~/build_mail]# wget2 -O liblogging_v1.0.8.tar.gz https://github.com/rsyslog/liblogging/archive/refs/tags/v1.0.8.tar.gz

[root@lfs ~/build_mail]# tar zxvf libfastjson_v1.2304.0.tar.gz
[root@lfs ~/build_mail]# cd libfastjson-1.2304.0/
[root@lfs ~/build_mail/libfastjson-1.2304.0]# sh autogen.sh
[root@lfs ~/build_mail/libfastjson-1.2304.0]# ./configure --prefix=/usr --disable-static && make -j$(nproc) && make install
[root@lfs ~/build_mail/libfastjson-1.2304.0]# cd .. && rm -rf libfastjson-1.2304.0

[root@lfs ~/build_mail]# tar -zxvf libestr_v0.1.11.tar.gz
[root@lfs ~/build_mail]# cd libestr-0.1.11/
[root@lfs ~/build_mail/libestr-0.1.11]# sh autogen.sh && ./configure --prefix=/usr --disable-static && make -j$(nproc) && make install
[root@lfs ~/build_mail/libestr-0.1.11]# cd .. && rm -rf libestr-0.1.11

[root@lfs ~/build_mail]# tar zxvf liblogging_v1.0.8.tar.gz
[root@lfs ~/build_mail]# cd liblogging-1.0.8/
[root@lfs ~/build_mail/liblogging-1.0.8]# sh autogen.sh --disable-man-pages && ./configure --prefix=/usr --disable-journal --disable-man-pages && make -j$(nproc) && make install
[root@lfs ~/build_mail/liblogging-1.0.8]# cd ..

[root@lfs ~/build_mail]# ldconfig

[root@lfs ~/build_mail]# tar zxvf sysklogd-2.7.2.tar.gz
[root@lfs ~/build_mail]# cd sysklogd-2.7.2
[root@lfs ~/build_mail/sysklogd-2.7.2]# ./configure --prefix=/usr --sysconfdir=/etc && make && make install
[root@lfs ~/build_mail/sysklogd-2.7.2]# cd .. && rm -rf sysklogd-2.7.2
把sysklogd做成服务
[root@lfs ~/build_mail]# cat > /usr/lib/systemd/system/sysklogd.service << "EOF"
[Unit]
Description=System and Kernel Logging Service
Documentation=man:sysklogd(8)
After=network.target

[Service]
Type=forking
# -n 避免后台运行以便 systemd 跟踪（取决于版本，建议先用默认）
ExecStart=/usr/sbin/syslogd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF


[root@lfs ~/build_mail]# systemctl daemon-reload
[root@lfs ~/build_mail]# mkdir -p /etc/syslog.d
[root@lfs ~/build_mail]# cat > /etc/syslog.conf << "EOF"
# 记录邮件日志
mail.* /var/log/maillog

# 记录系统消息
*.info;mail.none;authpriv.none          /var/log/messages

# 记录认证信息
authpriv.* /var/log/auth.log

# 记录紧急信息
*.emerg                                 *
EOF

[root@lfs ~/build_mail]# systemctl enable sysklogd && systemctl restart sysklogd
[root@lfs ~/build_mail]# systemctl status sysklogd
● sysklogd.service - System and Kernel Logging Service
     Loaded: loaded (/usr/lib/systemd/system/sysklogd.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-05-14 08:28:58 UTC; 1min 9s ago
 Invocation: e28defae51314cb7931f0990391d61cf
       Docs: man:sysklogd(8)
    Process: 415753 ExecStart=/usr/sbin/syslogd (code=exited, status=0/SUCCESS)
   Main PID: 415754 (syslogd)
      Tasks: 1 (limit: 19179)
     Memory: 1M (peak: 2M)
        CPU: 181ms
     CGroup: /system.slice/sysklogd.service
             └─415754 /usr/sbin/syslogd

May 14 08:28:58 lfs systemd[1]: Starting System and Kernel Logging Service...
May 14 08:28:58 lfs systemd[1]: Started System and Kernel Logging Service.

# 人为制造一点日志，看看文件会不会动
[root@lfs ~/build_mail]# ls -l /var/log/maillog
-rw-r--r-- 1 root root 0 May 14 08:27 /var/log/maillog
[root@lfs ~/build_mail]# logger -p mail.info "Testing maillog for LFS测试项目"
[root@lfs ~/build_mail]# ls -l /var/log/maillog
-rw-r--r-- 1 root root 80 May 14 08:30 /var/log/maillog




# Postfix3.11.2：发信核心
Postfix依赖Cyrus-SASL来进行用户认证. 所以需要lfs13先安装cyrus-sasl
[root@lfs ~]# mkdir build_mail && cd build_mail

因为postfix是和LMDB搭配，在编译Postfix之前，系统里必须先有LMDB的头文件和库文件    
[root@lfs ~/build_mail]# https://github.com/LMDB/lmdb/archive/refs/tags/LMDB_0.9.35.tar.gz
[root@lfs ~/build_mail]# tar zxvf LMDB_0.9.35.tar.gz
[root@lfs ~/build_mail]# cd lmdb-LMDB_0.9.35/libraries/liblmdb
[root@lfs ~/build_mail/lmdb-LMDB_0.9.35/libraries/liblmdb]# make && make prefix=/usr install
[root@lfs ~/build_mail/lmdb-LMDB_0.9.35/libraries/liblmdb]# ldconfig           # 刷新一下系统的动态库缓存
[root@lfs ~/build_mail/lmdb-LMDB_0.9.35/libraries/liblmdb]# cd ../../..
[root@lfs ~/build_mail]# rm -rf lmdb-LMDB_0.9.35
[root@lfs ~/build_mail]# find / -name liblmdb.so
/usr/lib/liblmdb.so





[root@lfs ~/build_mail]# wget2 http://ftp.porcupine.org/mirrors/postfix-release/official/postfix-3.11.2.tar.gz
[root@lfs ~/build_mail]# tar -xvf postfix-3.11.2.tar.gz && cd postfix-3.11.2
[root@lfs ~/build_mail/postfix-3.11.2]# groupadd -g 32 postfix
[root@lfs ~/build_mail/postfix-3.11.2]# groupadd -g 33 postdrop
[root@lfs ~/build_mail/postfix-3.11.2]# useradd -c "Postfix Daemon User" -d /var/spool/postfix -g postfix -s /bin/false -u 32 postfix
useradd warning: postfix's uid 32 outside of the UID_MIN 1000 and UID_MAX 60000 range.     # 该行需要核查

#生成带有LMDB支持的Makefile
# CCARGS定义加密和数据库支持；AUXLIBS指定链接库
[root@lfs ~/build_mail/postfix-3.11.2]# make makefiles \
    CCARGS="-DDEF_COMMAND_DIR='\"/usr/sbin\"' \
            -DDEF_CONFIG_DIR='\"/etc/postfix\"' \
            -DDEF_DAEMON_DIR='\"/usr/libexec/postfix\"' \
            -DHAS_SSL -I/usr/include/openssl \
            -DHAS_SQLITE -I/usr/include \
            -DHAS_LMDB -I/usr/include \
            -DNO_DB \
            -DUSE_SASL_AUTH -DUSE_CYRUS_SASL -I/usr/include/sasl" \
    AUXLIBS="-lssl -lcrypto -lsqlite3 -llmdb -lpthread -lsasl2" \
    default_database_type=lmdb \
    default_cache_db_type=lmdb
参数释义:
-DUSE_SASL_AUTH: 告诉 Postfix "你要支持认证功能"
-DUSE_CYRUS_SASL: 告诉Postfix"我们要使用Cyrus-SASL 这个插件框架"(即便你后端用 Dovecot，Postfix 内部也是通过 Cyrus 框架去调用的)
-I/usr/include/sasl: 告诉编译器去哪找sasl.h 头文件(在lfs13中通常在这里)
-lsasl2: 最关键的一步。告诉链接器把libsasl2.so 编进 Postfix 程序里。没有它，你依然会看到 SASL support is not compiled in 的警

[root@lfs ~/build_mail/postfix-3.11.2]# make -j$(nproc)
# 如果是第一次在lfs13中安装Postfix，或者你想重新配置所有路径,我是第一次安装所以执行该命令
[root@lfs ~/build_mail/postfix-3.11.2]# sh postfix-install -non-interactive
# 如果你之前已经安装过，现在只是想升级(保持旧配置不变)
sh postfix-install upgrade-package

# 查看postfix版本
[root@lfs ~/build_mail/postfix-3.11.2]# postconf -d mail_version
mail_version = 3.11.2

[root@lfs ~/build_mail/postfix-3.11.2]# cd ..



# 显式禁用NIS
[root@lfs ~/build_mail/postfix-3.11.2]# vim /etc/postfix/main.cf
mydestination = $myhostname, localhost.$mydomain, localhost         # 一会儿本地测试时要用
设置邮件存储位置(Maildir 格式)
home_mailbox = Maildir/
alias_maps = lmdb:/etc/aliases
alias_database = lmdb:/etc/aliases
local_recipient_maps = proxy:unix:passwd.byname $alias_maps
强制使用LMTP投递
mailbox_transport = lmtp:unix:private/dovecot-lmtp


创建一个真实的系统用户测试(最快方案)
[root@lfs ~/build_mail/postfix-3.11.2]# useradd -m -s /bin/false test && chown -R test:test /home/test

数据库缺失: 别名表未初始化
# 创建空的别名文件（如果不存在）
[root@lfs ~/build_mail]# [ ! -f /etc/aliases ] && touch /etc/aliases

# 生成lmdb格式的数据库文件 (postfix 3.x 默认使用 lmdb), 同样也是更新别名数据库
[root@lfs ~/build_mail]# newaliases

# 把postfix做成服务
[root@lfs ~/build_mail]# vim /usr/lib/systemd/system/postfix.service
[Unit]
Description=Postfix Mail Transport Agent
After=network.target redis.service rspamd.service

[Service]
Type=forking
ExecStart=/usr/sbin/postfix start
ExecStop=/usr/sbin/postfix stop
ExecReload=/usr/sbin/postfix reload
Restart=always

[Install]
WantedBy=multi-user.target



[root@lfs ~/build_mail]# systemctl daemon-reload
[root@lfs ~/build_mail]# systemctl enable postfix && systemctl restart postfix
[root@lfs ~/build_mail/redis-8.6.3]# systemctl status postfix
● postfix.service - Postfix Mail Transport Agent
     Loaded: loaded (/usr/lib/systemd/system/postfix.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-05-14 05:27:05 UTC; 20s ago
 Invocation: 6797b5e3bbc641998498b02a7c0d0e1a
    Process: 386745 ExecStart=/usr/sbin/postfix start (code=exited, status=0/SUCCESS)
   Main PID: 386818 (master)
      Tasks: 3 (limit: 19179)
     Memory: 5.8M (peak: 5.9M)
        CPU: 598ms
     CGroup: /system.slice/postfix.service
             ├─386818 /usr/libexec/postfix/master -w
             ├─386819 pickup -l -t unix -u
             └─386820 qmgr -l -t unix -u

May 14 05:27:05 lfs systemd[1]: Starting Postfix Mail Transport Agent...
May 14 05:27:05 lfs postfix[386816]: postfix/postlog: starting the Postfix mail system
May 14 05:27:05 lfs postfix/postfix-script[386816]: starting the Postfix mail system
May 14 05:27:05 lfs postfix/master[386818]: daemon started -- version 3.11.2, configuration /etc/postfix
May 14 05:27:05 lfs systemd[1]: Started Postfix Mail Transport Agent.




# Dovecot 2.4.4：收信与存储
Dovecot2.4相比2.3版本有很大变动，它现在对内核的AIO(异步IO)支持要求更明确
[root@lfs ~/build_mail]# wget2 https://dovecot.org/releases/2.4/dovecot-2.4.4.tar.gz
[root@lfs ~/build_mail]# tar -xvf dovecot-2.4.4.tar.gz && cd dovecot-2.4.4

# 创建用户
# Dovecot需要两个用户:
dovecot: 用于处理邮件索引和管理(低权限)
dovenull: 用于非受信任的登录进程(隔离权限)

[root@lfs ~/build_mail/dovecot-2.4.4]# groupadd -g 36 dovecot && groupadd -g 37 dovenull
# ================ 有可能报的错 ====================
groupadd: GID '36' already exists
解决
[root@lfs ~/build_mail/dovecot-2.4.4]# grep ':36:' /etc/group
mail:x:34:
修改组ID即可
groupadd -g 38 dovecot && groupadd -g 39 dovenull
# ==================================================
[root@lfs ~/build_mail/dovecot-2.4.4]# useradd -c "Dovecot User" -d /dev/null -g dovecot -s /bin/false -u 36 dovecot
[root@lfs ~/build_mail/dovecot-2.4.4]# useradd -c "Dovecot Login User" -d /dev/null -g dovenull -s /bin/false -u 37 dovenull

# 如执行./configure时报错则需要清除原来的报错后重新来，make distclean
[root@lfs ~/build_mail/dovecot-2.4.4]# ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var  --with-sqlite
以下是回显
....
    ....
config.status: executing depfiles commands
config.status: executing libtool commands

Install prefix . : /usr
File offsets ... : 64bit
I/O polling .... : epoll
I/O notifys .... : inotify
SSL ............ : openssl
GSSAPI ......... : no
passdbs ........ : static passwd passwd-file pam sql
                 : -bsdauth -ldap
userdbs ........ : static prefetch passwd passwd-file sql
                 : -ldap
CFLAGS ......... :  -fstack-protector-strong -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -mfunction-return=keep -mindirect-branch=keep -std=gnu11 -Wall -W -Wmissing-prototypes -Wmissing-declarations -Wpointer-arith -Wchar-subscripts -Wformat=2 -Wbad-function-cast -fno-builtin-strftime -Wstrict-aliasing=2 -DTEST_DIR=\"\$(abs_top_builddir)/.test\"  -g -O2 
LDFLAGS ........ :  $(NOPLUGIN_LDFLAGS)    
BINARY CFLAGS .. : -fPIE -DPIE
BINARY LDFLAGS . : -pie -Wl,-z -Wl,relro -Wl,-z -Wl,now
SYSTEMD ........ : notify - /usr/lib/systemd/system/dovecot.service
SQL drivers .... : sqlite
                 : -pgsql -mysql -cassandra
Full text search :
                 : -solr


# 先确定有无wget,如有wget2则需要做个软连接(make clean)
[root@lfs ~/build_mail/dovecot-2.4.4]# ln -sf /usr/bin/wget2  /usr/bin/wget
[root@lfs ~/build_mail/dovecot-2.4.4]# wget --version          # 如有则可执行make
[root@lfs ~/build_mail/dovecot-2.4.4]# make -j$(nproc) && make install
[root@lfs ~/build_mail/dovecot-2.4.4]# dovecot --version
2.4.4 ()

[root@lfs ~/build_mail/dovecot-2.4.4]# cd ..


# devecot已经自带了服务
[root@lfs ~/build_mail]# vim /usr/lib/systemd/system/dovecot.service


# 创建虚拟邮件用户组和用户
groupadd -g 5000 vmail
useradd -c "Virtual Mail User" -d /srv/mail -g vmail -s /bin/false -u 5000 vmail
mkdir -p /var/vmail
chown vmail:vmail /var/vmail

# 创建并授权邮件存储目录
mkdir -p /srv/mail
chown -R vmail:vmail /srv/mail
chmod 700 /srv/mail

我现在只想先让服务跑起来，所以我临时生成一对自签名证书
openssl req -new -x509 -nodes -out /etc/dovecot/ssl-cert.pem -keyout /etc/dovecot/ssl-key.pem -days 365
按需填写,实际中的证书都有这些信息

# 修改dovecot.conf启用协议
protocols {
  imap = yes
  lmtp = yes     # 确保这一项在
  pop3 = yes     # 该项如现在不需要可注释掉
}


# 检查配置语法
[root@lfs ~/build_mail]# dovecot -n
# 2.4.4 (): /etc/dovecot/dovecot.conf
# OS: Linux 6.18.10 x86_64 Linux From Scratch 
# Hostname: localhost
dovecot_config_version = 2.4.4
dovecot_storage_version = 2.4.4
mail_driver = sdbox          # 新版推荐的高性能格式，比传统的Maildir效率更高
mail_gid = vmail
mail_home = /srv/mail/%{user}
mail_path = ~/mail
mail_uid = vmail
protocols {
  imap = yes
  lmtp = yes
  pop3 = yes
}
namespace inbox {
  inbox = yes
  separator = /
}
passdb pam {
}
ssl_server {
  cert_file = /etc/dovecot/ssl-cert.pem
  key_file = /etc/dovecot/ssl-key.pem
}


[root@lfs ~/build_mail]# systemctl daemon-reload
[root@lfs ~/build_mail]# sysytemd enable devecot && systemctl restart dovecot
[root@lfs ~/build_mail]# systemctl status dovecot
● dovecot.service - Dovecot IMAP/POP3 email server
     Loaded: loaded (/usr/lib/systemd/system/dovecot.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-05-14 05:48:40 UTC; 13s ago
 Invocation: 5fbfeb2c613b4037bddf7ddd338f83bd
       Docs: man:dovecot(1)
             https://doc.dovecot.org/
   Main PID: 387406 (dovecot)
     Status: "v2.4.4 () running"
      Tasks: 4 (limit: 19179)
     Memory: 6M (peak: 7.9M)
        CPU: 81ms
     CGroup: /system.slice/dovecot.service
             ├─387406 /usr/sbin/dovecot -F
             ├─387407 dovecot/anvil
             ├─387408 dovecot/log
             └─387409 dovecot/config

May 14 05:48:40 lfs systemd[1]: Starting Dovecot IMAP/POP3 email server...
May 14 05:48:40 lfs dovecot[387406]: master: Dovecot v2.4.4 () starting up for imap, lmtp
May 14 05:48:40 lfs systemd[1]: Started Dovecot IMAP/POP3 email server.


# 如需排错
journalctl -u dovecot -f



```





# Rspamd 4.0.1：现代扫描引擎
## 核心依赖检查
```shell
在开始之前需要确保你的lfs系统中已经安装了以下关键组件。Rspamd对这些库的版本要求非常严格:
CMake (3.18+): 必须
LuaJIT (2.1): Rspamd的核心逻辑跑在 LuaJIT 上，不要用普通的Lua
Ragel (6.x): 必不可少，用于生成协议解析状态机
Hyperscan: 如果你的 CPU 支持（Intel），建议安装，它能极大提升正则匹配速度
Glibc (2.35+): LFS 13 默认已经满足
ICU: 用于处理 Unicode 字符


[root@lfs ~/build_mail]# 
wget2 https://github.com/Kitware/CMake/releases/download/v3.31.12/cmake-3.31.12.tar.gz \
https://www.colm.net/files/ragel/ragel-6.10.tar.gz \
https://github.com/unicode-org/icu/releases/download/release-78.3/icu4c-78.3-sources.tgz \
https://archives.boost.io/release/1.81.0/source/boost_1_81_0.tar.gz

wget2 -O LuaJIT_v2.1.ROLLING.tar.gz https://github.com/LuaJIT/LuaJIT/archive/refs/tags/v2.1.ROLLING.tar.gz
wget2 -O  hyperscan_v5.4.1.tar.gz https://github.com/intel/hyperscan/archive/refs/tags/v5.4.1.tar.gz


# 安装cmake
[root@lfs ~/build_mail]# tar zxvf cmake-3.31.12.tar.gz
[root@lfs ~/build_mail]# cd cmake-3.31.12
[root@lfs ~/build_mail/cmake-3.31.12]# ./bootstrap --prefix=/usr \
--mandir=/share/man --docdir=/share/doc/cmake-3.31.2 \
--no-system-jsoncpp --no-system-librhash \
--no-system-libuv --no-system-cppdap

[root@lfs ~/build_mail/cmake-3.31.12]# make -j$(nproc) && make install
[root@lfs ~/build_mail/cmake-3.31.12]# cmake --version
cmake version 3.31.12
[root@lfs ~/build_mail/cmake-3.31.12]# cd .. && rm -rf cmake-3.31.12


# Ragel 6.10
Ragel是Rspamd解析协议状态机的核心工具。它非常小巧但必不可少
[root@lfs ~/build_mail]# tar -xvf ragel-6.10.tar.gz && cd ragel-6.10
[root@lfs ~/build_mail/ragel-6.10]# ./configure --prefix=/usr && make -j$(nproc) && make install
[root@lfs ~/build_mail/ragel-6.10]# cd .. && rm -rf ragel-6.10
[root@lfs ~/build_mail]# ragel -v
Ragel State Machine Compiler version 6.10 March 2017
Copyright (c) 2001-2009 by Adrian Thurston
[root@lfs ~/build_mail]# ls /usr/bin/ragel 
/usr/bin/ragel


# ICU4C 76.1 (Unicode 支持)
ICU的源码包结构比较特殊，必须进入source目录执行配置
[root@lfs ~/build_mail]# tar -xvf icu4c-78.3-sources.tgz && cd icu/source
[root@lfs ~/build_mail/icu/source]# ./configure --prefix=/usr && make -j$(nproc) && make install
[root@lfs ~/build_mail/icu/source]# cd ../.. && rm -rf icu
[root@lfs ~/build_mail]# uconv -V
uconv v2.1  ICU 78.3
[root@lfs ~/build_mail]# icu-config --version
78.3
[root@lfs ~/build_mail]# ls /usr/include/unicode/uversion.h
/usr/include/unicode/uversion.h
[root@lfs ~/build_mail]# ls -l /usr/lib/libicuuc.so
lrwxrwxrwx 1 root root 16 May 14 02:19 /usr/lib/libicuuc.so -> libicuuc.so.78.3


# LuaJIT 2.1 (Rolling)
Rspamd的性能高度依赖LuaJIT。注意: lfs环境下我们需要确保生成的是共享库
[root@lfs ~/build_mail]# tar zxvf LuaJIT_v2.1.ROLLING.tar.gz
[root@lfs ~/build_mail]# cd LuaJIT-2.1.ROLLING
[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# make PREFIX=/usr -j$(nproc)
[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# make install PREFIX=/usr         # 确保路径正确以便Rspamd的CMake能找到

# lfs关键一步：建立软链接，因为很多程序会找lua5.1
[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# ln -sf /usr/bin/luajit-2.1.* /usr/bin/luajit
[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# ln -sf luajit /usr/bin/lua
[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# ldconfig     # 刷新动态链接库缓存
# 验证
[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# luajit -v
LuaJIT 2.1.ROLLING -- Copyright (C) 2005-2023 Mike Pall. https://luajit.org/
[root@lfs ~/build_mail]# ls -l /usr/lib/libluajit-5.1.so       # 库检查(Rspamd 编译时会寻找这个动态库)
lrwxrwxrwx 1 root root 21 May 14 02:23 /usr/lib/libluajit-5.1.so -> libluajit-5.1.so.2.1.

[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# ls /usr/lib/pkgconfig/luajit.pc 
/usr/lib/pkgconfig/luajit.pc
[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# pkg-config --cflags --libs luajit
-I/usr/include/luajit-2.1 -lluajit-5.1
Note:
如果pkg-config报错找不到luajit，你可能需要手动设置一下环境变量(在lfs13中建议永久加入/etc/profile):
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib/pkgconfig

[root@lfs ~/build_mail/LuaJIT-2.1.ROLLING]# cd .. && rm -rf LuaJIT-2.1.ROLLING


# Hyperscan 5.4.1 (高性能正则)
[root@lfs ~/build_mail]# tar zxvf boost_1_81_0.tar.gz
[root@lfs ~/build_mail]# cd boost_1_81_0
[root@lfs ~/build_mail/boost_1_81_0]# ./bootstrap.sh --prefix=/usr
[root@lfs ~/build_mail/boost_1_81_0]# ./b2 install --with-headers

[root@lfs ~/build_mail]# tar zxvf hyperscan_v5.4.1.tar.gz
[root@lfs ~/build_mail]# cd hyperscan-5.4.1/
[root@lfs ~/build_mail/hyperscan-5.4.1]# mkdir build && cd build
[root@lfs ~/build_mail/hyperscan-5.4.1/build]# cmake -DCMAKE_INSTALL_PREFIX=/usr \
-DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release ..

[root@lfs ~/build_mail/hyperscan-5.4.1/build]# make -j$(nproc) && make install

[root@lfs ~/build_mail]# find /usr -name libhs.pc
/usr/lib64/pkgconfig/libhs.pc

[root@lfs ~/build_mail]# mkdir -p /usr/lib/pkgconfig
[root@lfs ~/build_mail]# cp /usr/lib64/pkgconfig/libhs.pc  /usr/lib/pkgconfig/

验证Hyperscan
Hyperscan 和 Boost 主要是以库文件形式存在，没有直接的可执行程序，我们需要检查 pkg-config 信息和库路径
[root@lfs ~/build_mail]# pkg-config --modversion libhs
5.4.1

Note:
关于 Hyperscan 的硬件限制：Hyperscan 极其吃CPU指令集。如果你的lfs跑在老旧硬件或某些虚拟机上，它可能因为不支持SSSE3而编译失败
如果失败，可以考虑跳过这个包(Rspamd依然能跑，只是正则过滤会变慢)

动态链接库刷新：每安装完一个库，记得运行一次 ldconfig

开发头文件：在lfs中没有devel包的概念，源码安装会自动把 .h 放入 /usr/include。但请检查 LuaJIT 的头文件是否在 /usr/include/luajit-2.1/ 下
如果是，后面编译 Rspamd 时可能需要手动指定该路径


# 安装pcre2
[root@lfs ~/build_mail]# wget2 https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.46/pcre2-10.46.tar.gz
[root@lfs ~/build_mail]# tar zxvf pcre2-10.46.tar.gz
[root@lfs ~/build_mail]# cd pcre2-10.46
[root@lfs ~/build_mail/pcre2-10.46]# ./configure --prefix=/usr \
--docdir=/usr/share/doc/pcre2-10.42 \
--enable-unicode --enable-jit \
--enable-pcre2-16 \
--enable-pcre2-32 \
--enable-pcre2grep-libz \
--enable-pcre2grep-libbz2 \
--disable-static

[root@lfs ~/build_mail/pcre2-10.46]# make -j$(nproc) && make install
[root@lfs ~/build_mail/pcre2-10.46]# cd .. && rm -rf pcre2-10.46
[root@lfs ~/build_mail]# pcre2-config --version
10.46



# 安装libffi
[root@lfs ~/build_mail]# wget2 https://github.com/libffi/libffi/releases/download/v3.5.1/libffi-3.5.1.tar.gz
[root@lfs ~/build_mail]# tar zxvf libffi-3.5.1.tar.gz
[root@lfs ~/build_mail]# cd libffi-3.5.1
[root@lfs ~/build_mail/libffi-3.5.1]# ./configure --prefix=/usr --disable-static --with-gcc-arch=native
[root@lfs ~/build_mail/libffi-3.5.1]# make -j$(nproc) && make install
[root@lfs ~/build_mail/libffi-3.5.1]# cd .. && rm -rf libffi-3.5.1



# 安装glib(必须大于2.80版本)
[root@lfs ~/build_mail]# for i in python3 meson ninja;do $i --version;done          # 这3个应该已经有了
Python 3.14.3
1.10.1
1.13.2

[root@lfs ~/build_mail]# wget2 https://download.gnome.org/sources/glib/2.88/glib-2.88.0.tar.xz
[root@lfs ~/build_mail]# tar xvf glib-2.88.0.tar.xz
[root@lfs ~/build_mail]# cd glib-2.88.0/
[root@lfs ~/build_mail/glib-2.88.0]# mkdir build && cd build
[root@lfs ~/build_mail/glib-2.88.0/build]# meson setup --prefix=/usr --buildtype=release -Dman=false ..
[root@lfs ~/build_mail/glib-2.88.0/build]# ninja && ninja install
[root@lfs ~/build_mail/glib-2.88.0/build]# ldconfig        # 刷新动态库
验证
[root@lfs ~/build_mail/glib-2.88.0/build]# export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib64/pkgconfig
[root@lfs ~/build_mail/glib-2.88.0/build]# pkg-config --modversion glib-2.0
2.88.0


# 安装libsodium 1.0.22
[root@lfs ~/build_mail]# wget2 https://download.libsodium.org/libsodium/releases/libsodium-1.0.22.tar.gz
[root@lfs ~/build_mail]# tar zxvf libsodium-1.0.22.tar.gz
[root@lfs ~/build_mail]# cd libsodium-1.0.22
[root@lfs ~/build_mail/libsodium-1.0.22]# ./configure --prefix=/usr --disable-static
[root@lfs ~/build_mail/libsodium-1.0.22]# make -j$(nproc) && make install
[root@lfs ~/build_mail/libsodium-1.0.22]# ldconfig
验证
[root@lfs ~/build_mail/libsodium-1.0.22]# pkg-config --modversion libsodium


```







## 安装rspamd4.0.1
```shell
Rspamd是基于C/C++和Lua的。它需要Ragel(状态机生成器) 和 ICU(国际化库)
[root@lfs ~/build_mail]# wget2 -O rspamd.4.0.1.tar.gz https://github.com/rspamd/rspamd/archive/refs/tags/4.0.1.tar.gz
[root@lfs ~/build_mail]# tar -xvf 4.0.1.tar.gz && cd rspamd-4.0.1
[root@lfs ~/build_mail/rspamd-4.0.1]# mkdir build && cd build

# CMake配置 (Rspamd 使用CMake)
# 注意：Rspamd默认需要Jemalloc内存管理，若lfs没装可先禁用
# 带上路径变量
[root@lfs ~/build_mail/rspamd-4.0.1/build]# export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib64/pkgconfig
[root@lfs ~/build_mail/rspamd-4.0.1/build]# 
cmake -DCMAKE_INSTALL_PREFIX=/usr \
-DCONFDIR=/etc/rspamd -DENABLE_LUAJIT=ON \
-DENABLE_SQLITE=ON -DENABLE_HYPERSCAN=ON \
-DENABLE_OPTIMIZATION=ON -DRSPAMD_USER=rspamd \
-DRSPAMD_GROUP=rspamd ..
成功的标志
-- Rspamd will be installed in the following directories:
--   - Binaries: /usr/bin
--   - Configuration: /etc/rspamd
--   - Rules: /usr/share/rspamd/rules
--   - Lua libraries: /usr/share/rspamd/lualib
--   - Plugins: /usr/share/rspamd/plugins
--   - Shared data: /usr/share/rspamd
--   - Web UI: /usr/share/rspamd/www
-- PVS-Studio analyzer not found. Static analysis disabled.
-- Configuring done (19.0s)
-- Generating done (0.3s)
CMake Warning:
  Manually-specified variables were not used by the project:

    ENABLE_SQLITE
    RSPAMD_GROUP

-- Build files have been written to: /root/build_mail/rspamd-4.0.1/build



[root@lfs ~/build_mail/rspamd-4.0.1/build]# make -j$(nproc) && make install

验证
[root@lfs ~/build_mail/rspamd-4.0.1/build]# rspamd --version
Rspamd daemon version 4.0.1

CPU architecture x86_64; features: avx2, avx, sse2, sse3, ssse3, sse4.1, sse4.2, rdrand
Hyperscan enabled: TRUE
Jemalloc enabled: FALSE
LuaJIT enabled: TRUE (LuaJIT version: LuaJIT 2.1.ROLLING)
ASAN enabled: FALSE
BLAS enabled: FALSE
Fasttext enabled: TRUE (built-in)
释义：
显示不仅正常，而且是高性能状态：
Hyperscan enabled: TRUE：这是最难啃的骨头,这意味着正则扫描速度比普通版本快10倍以上
CPU features (avx2, sse4.2)：Rspamd识别到了我的硬件指令集，它会利用这些指令集进行高效的向量运算
LuaJIT enabled: TRUE：核心逻辑将以接近C的速度运行



# 创建rspamd用户和组(不给家目录和不给shell登录权限)
[root@lfs ~/build_mail/redis-8.6.3]# groupadd -g 38 rspamd
[root@lfs ~/build_mail/redis-8.6.3]# useradd -c "Rspamd Daemon" -d /var/lib/rspamd -g rspamd -s /bin/false -u 38 rspamd
[root@lfs ~/build_mail/redis-8.6.3]# grep rspamd /etc/passwd
rspamd:x:38:38:Rspamd Daemon:/var/lib/rspamd:/bin/false

# 前台启动rspamd服务
[root@lfs ~/build_mail/redis-8.6.3]# mkdir /var/log/rspamd
[root@lfs ~/build_mail/redis-8.6.3]# rspamd -u rspamd -g rspamd -c /etc/rspamd/rspamd.conf
[root@lfs ~/build_mail/redis-8.6.3]# ls -alh /var/log/rspamd/
total 48K
-rw-r--r-- 1 rspamd rspamd  38K May 14 05:18 rspamd.log

# 把rapamd做成服务(Rspamd必须在Redis之后启动)
[root@lfs ~/build_mail/redis-8.6.3]# vim /usr/lib/systemd/system/rspamd.service
[Unit]
Description=Rapid Spam Filtering System
After=network.target redis.service
Wants=redis.service

[Service]
Type=forking
PIDFile=/run/rspamd/rspamd.pid
ExecStartPre=/usr/bin/mkdir -p /run/rspamd
ExecStartPre=/usr/bin/chown rspamd:rspamd /run/rspamd
ExecStart=/usr/bin/rspamd -u rspamd -g rspamd -c /etc/rspamd/rspamd.conf
ExecReload=/usr/bin/rspamadm control reload
Restart=always

[Install]
WantedBy=multi-user.target





# 开启Redis(基础前提)
[root@lfs ~/build_mail]# wget2 -O redis_8.6.3.tar.gz https://github.com/redis/redis/archive/refs/tags/8.6.3.tar.gz
[root@lfs ~/build_mail]# cd redis-8.6.3/
[root@lfs ~/build_mail/redis-8.6.3]# make MALLOC=jemalloc -j$(nproc)
[root@lfs ~/build_mail/redis-8.6.3]# make PREFIX=/usr install

# 设置持久化(RDB/AOF)安全性
[root@lfs ~/build_mail/redis-8.6.3]# echo "vm.overcommit_memory = 1" | tee -a /etc/sysctl.conf
[root@lfs ~/build_mail/redis-8.6.3]# sysctl -p

在lfs中需要手动配置它的存放位置
[root@lfs ~/build_mail/redis-8.6.3]# mkdir -pv /etc/redis /var/lib/redis
[root@lfs ~/build_mail/redis-8.6.3]# cp redis.conf /etc/redis/
[root@lfs ~/build_mail/redis-8.6.3]# grep ^dir /etc/redis/redis.conf 
dir ./
[root@lfs ~/build_mail/redis-8.6.3]# vim /etc/redis/redis.conf 
[root@lfs ~/build_mail/redis-8.6.3]# egrep '^(daemonize|dir)' /etc/redis/redis.conf
daemonize no
dir  /var/lib/redis

验证
[root@lfs ~/build_mail/redis-8.6.3]# ps -ef|grep redis
root      386553       1  0 04:58 ?        00:00:01 redis-server 127.0.0.1:6379

# 把前台启动的redis杀掉
[root@lfs ~/build_mail/redis-8.6.3]# pkill -9 redis-server


# 新建redis.conf
[root@lfs ~/build_mail/redis-8.6.3]# vim /etc/rspamd/local.d/redis.conf
servers = "127.0.0.1:6379";      # 指向你的Redis地址

# 把redis做成服务
[root@lfs ~/build_mail/redis-8.6.3]# vim /usr/lib/systemd/system/redis.service
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/bin/redis-cli shutdown
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target


[root@lfs ~/build_mail/redis-8.6.2]# systemctl daemon-reload
[root@lfs ~/build_mail/redis-8.6.3]# systemctl enable redis && systemctl restart redis
[root@lfs ~/build_mail/redis-8.6.3]# systemctl status redis
● redis.service - Redis In-Memory Data Store
     Loaded: loaded (/usr/lib/systemd/system/redis.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-05-14 05:38:48 UTC; 50s ago
 Invocation: 70229172aec0453d89fe21b0f7d7739b
   Main PID: 387127 (redis-server)
      Tasks: 6 (limit: 19179)
     Memory: 3.5M (peak: 3.9M)
        CPU: 252ms
     CGroup: /system.slice/redis.service
             └─387127 "/usr/bin/redis-server 127.0.0.1:6379"

May 14 05:38:48 lfs systemd[1]: Started Redis In-Memory Data Store.
May 14 05:38:48 lfs redis-server[387127]: 387127:C 14 May 2026 05:38:48.645 * oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
May 14 05:38:48 lfs redis-server[387127]: 387127:C 14 May 2026 05:38:48.645 * Redis version=8.6.3, bits=64, commit=00000000, modified=0, pid=387127, just started
May 14 05:38:48 lfs redis-server[387127]: 387127:C 14 May 2026 05:38:48.645 * Configuration loaded
May 14 05:38:48 lfs redis-server[387127]: 387127:M 14 May 2026 05:38:48.645 * Increased maximum number of open files to 10032 (it was originally set to 1024).
May 14 05:38:48 lfs redis-server[387127]: 387127:M 14 May 2026 05:38:48.645 * monotonic clock: POSIX clock_gettime
May 14 05:38:48 lfs redis-server[387127]: 387127:M 14 May 2026 05:38:48.647 * Running mode=standalone, port=6379.
May 14 05:38:48 lfs redis-server[387127]: 387127:M 14 May 2026 05:38:48.647 * Server initialized
May 14 05:38:48 lfs redis-server[387127]: 387127:M 14 May 2026 05:38:48.647 * Ready to accept connections tcp
May 14 05:38:48 lfs redis-server[387127]: 387127:M 14 May 2026 05:38:48.647 # WARNING: Redis does not require authentication. Redis will accept connections from any local client.

# 现在再启动rspamd服务
[root@lfs ~/build_mail/rspamd-4.0.1/build]# systemctl restart rspamd
[root@lfs ~/build_mail/redis-8.6.3]# systemctl status rspamd
● rspamd.service - Rapid Spam Filtering System
     Loaded: loaded (/usr/lib/systemd/system/rspamd.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-05-14 05:29:12 UTC; 38s ago
 Invocation: 9a4cde8c7034428883336cfec33a48f8
    Process: 386891 ExecStartPre=/usr/bin/mkdir -p /run/rspamd (code=exited, status=0/SUCCESS)
    Process: 386893 ExecStartPre=/usr/bin/chown rspamd:rspamd /run/rspamd (code=exited, status=0/SUCCESS)
    Process: 386895 ExecStart=/usr/bin/rspamd -u rspamd -g rspamd -c /etc/rspamd/rspamd.conf (code=exited, status=0/SUCCESS)
   Main PID: 386902 (rspamd)
      Tasks: 8 (limit: 19179)
     Memory: 465.7M (peak: 465.7M)
        CPU: 27.123s
     CGroup: /system.slice/rspamd.service
             ├─386902 "rspamd: main process"
             ├─386903 "rspamd: hs_helper process"
             ├─386904 "rspamd: rspamd_proxy process (localhost:11332)"
             ├─386906 "rspamd: controller process (localhost:11334)"
             ├─386907 "rspamd: normal process (localhost:11333)"
             ├─386908 "rspamd: normal process (localhost:11333)"
             ├─386909 "rspamd: normal process (localhost:11333)"
             └─386910 "rspamd: normal process (localhost:11333)"

May 14 05:29:11 lfs systemd[1]: Starting Rapid Spam Filtering System...
May 14 05:29:11 lfs rspamd[386895]: 2026-05-14 05:29:11 #386895(main) <f0cb08>; main; main: rspamd 4.0.1 is loading configuration, build id: release
May 14 05:29:12 lfs systemd[1]: Started Rapid Spam Filtering System.



# 开启神经网络(Neural)
[root@lfs ~/build_mail/rspamd-4.0.1/build]# vim /etc/rspamd/local.d/neural.conf       # 新建该文件
enabled = true;              # 原理:它会根据邮件评分不断训练模型，在Redis中存储权值

# 开启缓存(Classifier)
通常指的是贝叶斯过滤器的缓存
[root@lfs ~/build_mail/redis-8.6.3]# vim  /etc/rspamd/local.d/classifier-static.conf:



```



## 配置Postfix与Rspamd对接
```shell
这是最关键的"通车"步骤。Postfix 通过 Milter (Mail Filter) 协议与Rspamd通讯
1. 配置 Rspamd 监听 Milter 端口
[root@lfs ~/build_mail/redis-8.6.3]# vim /etc/rspamd/local.d/worker-proxy.inc
# Rspamd 默认会在 11332 端口开启 Milter 服务
bind_socket = "localhost:11332";

2. 配置Postfix
[root@lfs ~/build_mail/redis-8.6.3]# vim /etc/postfix/main.cf            # 在最后面追加以下内容
# 开启Rspamd联动(Milter配置)
smtpd_milters = inet:localhost:11332
non_smtpd_milters = $smtpd_milters

# 当 Rspamd 挂掉时的处理策略：accept 表示继续投递（不拒信）
milter_default_action = accept

# Milter 协议版本
milter_protocol = 6


# 设置postfix和Rspamd联动
[root@lfs ~/build_mail]# vim /etc/postfix/master.cf
smtp      inet  n       -       n       -       -       smtpd
  -o smtpd_milters=inet:127.0.0.1:11332
注意：这里有个隐蔽的坑，所有的-o参数必须缩进(前面留空格,本次我留了2个)，否则会被Postfix认为是一行新的服务定义，从而直接忽略







# 查看所有服务状态
[root@lfs ~/build_mail]# for i in redis rspamd postfix dovecot;do systemctl  restart $i;done
[root@lfs ~/build_mail]# for i in redis rspamd postfix dovecot;do systemctl  status $i | grep Active;done
     Active: active (running) since Thu 2026-05-14 05:55:01 UTC; 9s ago
     Active: active (running) since Thu 2026-05-14 05:55:02 UTC; 8s ago
     Active: active (running) since Thu 2026-05-14 05:55:02 UTC; 8s ago
     Active: active (running) since Thu 2026-05-14 05:55:02 UTC; 8s ago


```












## 三者如何联动
```shell
1、Postfix联动Rspamd：
在/etc/postfix/main.cf 中添加 smtpd_milters = inet:localhost:11332。这是 Rspamd 监听的端口，所有进入的邮件都会先扔给Rspamd打分
[root@lfs ~/build_mail]# vim /etc/postfix/main.cf
# 告诉Postfix扫描器在哪
smtpd_milters = inet:127.0.0.1:11332
non_smtpd_milters = $smtpd_milters
# 如果扫描器挂了，邮件依然通过(防止拒收正常邮件)
milter_default_action = accept

2、Dovecot联动Postfix,Postfix发信前需要验证用户身份，它直接借用Dovecot的验证机制
在 Dovecot 配置里开启auth-service，让Postfix通过Dovecot的用户数据库来验证发信人身份
[root@lfs ~/build_mail]# vim /etc/postfix/main.cf
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes


[root@lfs ~/build_mail]# mkdir /etc/dovecot/conf.d
[root@lfs ~/build_mail]# vim /etc/dovecot/conf.d/10-master.conf
# 开启 Unix Socket 让 Postfix 能连接
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
service auth {
  # 供postfix认证使用
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }

  # 供Dovecot内部进程也能互相通信
  unix_listener auth-userdb {
    mode = 0660
    user = dovecot    # 如果没有 vmail，先用 dovecot
    group = dovecot
  }
}
# lmtp监听窗口 
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0660
    user = postfix           # 务必确保user 和 group 与 Postfix 进程匹配
    group = postfix
  }
}


[root@lfs ~/build_mail]# vim /etc/dovecot/conf.d/10-auth.conf
# 2.4.4 强制要求在块内处理变量格式
auth_username_format = %{user | username}

passdb passwd-file {
    # 2.4.4 的新参数名，必须叫这个
    passwd_file_path = /etc/dovecot/users
}

userdb passwd-file {
    passwd_file_path = /etc/dovecot/users
}


# 测试语法是否有问题(这里10-auth.conf的格式很严)
[root@lfs ~/build_mail]# doveconf -n > /dev/null
注意：无输出为正确

# 定义虚拟用户数据库数据资产层)
先生成加密密码(比如密码是Flz_3qc123)
[root@lfs ~/build_mail]# doveadm pw -s BLF-CRYPT -p Flz_3qc123
{BLF-CRYPT}$2y$05$F9s0JlyUD1MTWGVe1vIfqeKRWLg8f9H0dntjtme1W38HqQ5TEvzv6

# 创建用户文件,分别创建了test和admin用户，2个用户的密码相同，如需使用不同密码需再执行上述doveadm来生成
[root@lfs ~/build_mail]# cat > /etc/dovecot/users << "EOF"
test:{BLF-CRYPT}$2y$05$uJjhENnYV6ceO73JdKfC4OFsXTTIXC4xM3UZ7LO9hXAbnc448N/Sa:5000:5000::/var/vmail/test
admin:{BLF-CRYPT}$2y$05$uJjhENnYV6ceO73JdKfC4OFsXTTIXC4xM3UZ7LO9hXAbnc448N/Sa:5000:5000::/var/vmail/admin
EOF


# 设置权限(非常重要，防止其他普通用户偷看密码文件)
[root@lfs ~/build_mail]# 
chown vmail:vmail /etc/dovecot/users
chmod 600 /etc/dovecot/users

# 确保存储目录存在且权限正确
mkdir -p /var/vmail/test /var/vmail/admin
chown -R vmail:vmail /var/vmail

[root@lfs ~/build_mail]# systemctl restart dovecot


# 测试test用户
[root@lfs ~/build_mail]# doveadm user test@localhost
field	value
user	test
uid	5000
gid	5000
home	/var/vmail/test




最终投递: LMTP协议
为了性能，Postfix不直接写硬盘，而是通过LMTP把信交给Dovecot存储
[root@lfs ~/build_mail]# vim /etc/postfix/main.cf
virtual_transport = lmtp:unix:private/dovecot-lmtp



# 查看所有服务状态
[root@lfs ~/build_mail]# for i in redis rspamd postfix dovecot;do systemctl  restart $i;done
[root@lfs ~/build_mail]# for i in redis rspamd postfix dovecot;do systemctl  status $i | grep Active;done
     Active: active (running) since Thu 2026-05-14 06:26:20 UTC; 26s ago
     Active: active (running) since Thu 2026-05-14 06:26:21 UTC; 25s ago
     Active: active (running) since Thu 2026-05-14 06:26:22 UTC; 24s ago
     Active: active (running) since Thu 2026-05-14 06:26:22 UTC; 24s ago


# 查看管道文件是否存在, 该文件是 Postfix 和 Dovecot 通讯的"生命线"
[root@lfs ~/build_mail]# ls -al /var/spool/postfix/private/dovecot-lmtp 
srw-rw---- 1 postfix postfix 0 May 14 08:59 /var/spool/postfix/private/dovecot-lmtp



```






# 全链路冒烟测试
```shell
测试1：本地收发流
在 LFS 命令行使用 mail 或 swaks 工具，尝试给 root@localhost 发信
目的: 验证Postfix能不能把信交给 Dovecot 存入 /var/mail

第一阶段：发信链路测试 (Submission & MTA)
验证 Postfix 是否能接收请求，并成功通过 Dovecot 的身份验证
使用swaks工具(lfs必备的邮件瑞士军刀):
[root@lfs ~/build_mail]# wget2 https://www.jetmore.org/john/code/swaks/files/swaks-20240103.0.tar.gz
[root@lfs ~/build_mail]# tar zxvf swaks-20240103.0.tar.gz
[root@lfs ~/build_mail]# cd swaks-20240103.0
[root@lfs ~/build_mail/swaks-20240103.0]# cp swaks /usr/bin/
[root@lfs ~/build_mail/swaks-20240103.0]# chmod +x /usr/bin/swaks
[root@lfs ~/build_mail/swaks-20240103.0]# swaks --version
swaks version 20240103.0

[root@lfs ~/build_mail/swaks-20240103.0]# cd ..

新开一个窗口监控着日志
[root@lfs ~]# tail -f /var/log/maillog

[root@lfs ~/build_mail]# swaks --to test@localhost --from admin@localhost --server localhost --port 25
=== Trying localhost:25...
=== Connected to localhost.
<-  220 lfs.localdomain ESMTP Postfix
 -> EHLO localhost
<-  250-lfs.localdomain
<-  250-PIPELINING
<-  250-SIZE 10240000
<-  250-VRFY
<-  250-ETRN
<-  250-AUTH PLAIN
<-  250-ENHANCEDSTATUSCODES
<-  250-8BITMIME
<-  250-DSN
<-  250-SMTPUTF8
<-  250 CHUNKING
 -> MAIL FROM:<admin@localhost>
<-  250 2.1.0 Ok
 -> RCPT TO:<test@localhost>
<-  250 2.1.5 Ok
 -> DATA
<-  354 End data with <CR><LF>.<CR><LF>
 -> Date: Thu, 14 May 2026 11:02:01 +0000
 -> To: test@localhost
 -> From: admin@localhost
 -> Subject: test Thu, 14 May 2026 11:02:01 +0000
 -> Message-Id: <20260514110201.416966@localhost>
 -> X-Mailer: swaks v20240103.0 jetmore.org/john/code/swaks/
 -> 
 -> This is a test mailing
 -> 
 -> 
 -> .
<-  250 2.0.0 Ok: queued as 612E61E0238
 -> QUIT
<-  221 2.0.0 Bye
=== Connection closed with remote host



# 日志中显示
[root@lfs ~]# tail -f /var/log/maillog
May 14 11:02:01 localhost postfix/smtpd[416967]: connect from localhost[127.0.0.1]
May 14 11:02:01 localhost postfix/smtpd[416967]: 612E61E0238: client=localhost[127.0.0.1]
May 14 11:02:01 localhost postfix/cleanup[416972]: 612E61E0238: message-id=<20260514110201.416966@localhost>
May 14 11:02:01 localhost postfix/qmgr[416285]: 612E61E0238: from=<admin@localhost>, size=467, nrcpt=1 (queue active)
May 14 11:02:01 localhost postfix/smtpd[416967]: disconnect from localhost[127.0.0.1] ehlo=1 mail=1 rcpt=1 data=1 quit=1 commands=5
May 14 11:02:01 localhost postfix/local[416973]: 612E61E0238: passing <test@localhost> to transport=lmtp
May 14 11:02:01 localhost postfix/lmtp[416975]: 612E61E0238: to=<test@localhost>, relay=lfs.localdomain[private/dovecot-lmtp], delay=0.13, delays=0.07/0.01/0.03/0.01, dsn=2.0.0, status=sent (250 2.0.0 <test@localhost> JjRzHamrBWrQXAYA0J78UA Saved)
May 14 11:02:01 localhost postfix/qmgr[416285]: 612E61E0238: removed

# 深度解析这几行日志背后的含金量
passing <test@localhost> to transport=lmtp: Postfix很聪明，它知道这个用户不是系统账户，而是虚拟用户，于是交给了Dovecot的lmtp进程
relay=lfs.localdomain[private/dovecot-lmtp]: 这证明之前的10-master.conf里关于unix_listener的权限和路径配置全对了！Postfix成功写进了Dovecot的Socket
status=sent (250 2.0.0 ... Saved): 这是 Dovecot 回复的。它已经根据你 users 文件里的路径 /var/vmail/test，把信件存进去了


# 查看收信
[root@lfs ~/build_mail]# ls -alh /var/vmail/test/mail/mailboxes/INBOX/dbox-Mails/
total 20K
drwx------ 2 vmail vmail 4.0K May 14 11:02 .
drwx------ 3 vmail vmail 4.0K May 14 11:02 ..
-rw------- 1 vmail vmail 1.1K May 14 11:02 dovecot.index.cache   
-rw------- 1 vmail vmail  496 May 14 11:02 dovecot.index.log
-rw------- 1 vmail vmail  752 May 14 11:02 u.1
释义：
权限对齐: 文件属主是 vmail:vmail，权限600。这说明10-mail.conf 和 10-master.conf 里的权限降权逻辑运行得非常完美
dovecot.index.cache: 刚才投递时Dovecot已经自动为这封信建立了索引。这意味着之后你用手机或电脑连上来时，打开邮件的速度会极快，因为它不需要重新扫描整个u.1
u.1: 这是sdbox的核心数据文件。那个 2 M1e C6a05aba9 是 Dovecot 的内部元数据头

[root@lfs ~/build_mail]# grep -rn 'This is a test mailing' /var/vmail/test/mail/mailboxes/INBOX/dbox-Mails/
/var/vmail/test/mail/mailboxes/INBOX/dbox-Mails/u.1:20:This is a test mailing
[root@lfs ~/build_mail]# cat /var/vmail/test/mail/mailboxes/INBOX/dbox-Mails/u.1 
2 M1e C6a05aba9
N          000000000000028C
Return-Path: <admin@localhost>
Delivered-To: test@localhost
Received: from lfs.localdomain
	by localhost with LMTP
	id JjRzHamrBWrQXAYA0J78UA
	(envelope-from <admin@localhost>)
	for <test@localhost>; Thu, 14 May 2026 11:02:01 +0000
Received: from localhost (localhost [127.0.0.1])
	by lfs.localdomain (Postfix) with ESMTP id 612E61E0238
	for <test@localhost>; Thu, 14 May 2026 11:02:01 +0000 (UTC)
Date: Thu, 14 May 2026 11:02:01 +0000
To: test@localhost
From: admin@localhost
Subject: test Thu, 14 May 2026 11:02:01 +0000
Message-Id: <20260514110201.416966@localhost>
X-Mailer: swaks v20240103.0 jetmore.org/john/code/swaks/

This is a test mailing




R6a05aba9
V2a0
Gfa39051ea9ab056ad05c0600d09efc50

[root@lfs ~/build_mail]# 




# 发一封GTUBE测试码(垃圾邮件万能钥匙)
GTUBE 是一串特殊的字符串，所有的反垃圾引擎（Rspamd, SpamAssassin）只要看到它，就一定会把它标记为垃圾邮件(1000分)
[root@lfs ~/build_mail]# swaks --to test@localhost --from admin@localhost --server localhost --port 25 \
--body "XJS*C4JDBQO6UT65VN6P47WA61N79IKUALT2VQTEU40TVPQ9DHS0HUEQBS#G6L3#T5"
注意：
本地不触发Rspamd，这只是Postfix针对Loopback接口的保护逻辑，不代表系统在公网防御有问题,要测试Rspamd是否在工作:
[root@lfs ~/build_mail]# echo "XJS*C4JDBQO6UT65VN6P47WA61N79IKUALT2VQTEU40TVPQ9DHS0HUEQBS#G6L3#T5" | rspamc
Results for file: stdin (0.105 seconds)
[Metric: default]
Action: reject
Spam: true
Score: 17.40 / 15.00
Symbol: ARC_NA (0.00)
Symbol: DMARC_NA (0.00)[No From header]
Symbol: HFILTER_HOSTNAME_UNKNOWN (2.50)
Symbol: MIME_GOOD (-0.10)[text/plain]
Symbol: MIME_TRACE (0.00)[0:+]
Symbol: MISSING_DATE (1.00)
Symbol: MISSING_ESSENTIAL_HEADERS (7.00)
Symbol: MISSING_FROM (2.00)
Symbol: MISSING_MID (2.50)
Symbol: MISSING_SUBJECT (0.50)
Symbol: MISSING_TO (2.00)
Symbol: MISSING_XM_UA (0.00)
Symbol: RCVD_COUNT_ZERO (0.00)[0]
Symbol: R_DKIM_NA (0.00)
Symbol: R_MISSING_CHARSET (0.00)
Message-ID: undef










测试2：安检审计流
检查 /var/log/maillog 或 journalctl -u rspamd
目的: 确认邮件经过时，Rspamd有没有跳出来打分













```







# 打通互联网
## Cloudflared：内网穿透网关
```shell
cloudflared是用Go语言编写的。在lfs13中，你无法像CentOS那样直接yum install，你必须先安装Go编译器
执行cloudflared tunnel create email-server它会给你一个ID
在Cloudflare官网将你的域名(如 mail.yourdomain.com)指向这个隧道。这样外界的SMTP流量就会穿过隧道直接到达你的N100小主机


# 假设你已经安装了 Go (go version >= 1.21)
# 直接克隆源码编译最稳妥
git clone https://github.com/cloudflare/cloudflared.git
cd cloudflared

# 使用 Go 编译二进制文件
make install

# 验证安装
cloudflared --version

```

