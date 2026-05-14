# 邮件内容释义
```shell
[root@lfs ~/build_mail]# ls -alh /var/vmail/test/mail/mailboxes/
total 12K
drwx------ 3 vmail vmail 4.0K May 14 11:02 .
drwx------ 3 vmail vmail 4.0K May 14 11:02 ..
drwx------ 3 vmail vmail 4.0K May 14 11:02 INBOX
[root@lfs ~/build_mail]# ls -alh /var/vmail/test/mail/mailboxes/INBOX/dbox-Mails/
total 20K
drwx------ 2 vmail vmail 4.0K May 14 11:02 .
drwx------ 3 vmail vmail 4.0K May 14 11:02 ..
-rw------- 1 vmail vmail 1.1K May 14 11:02 dovecot.index.cache
-rw------- 1 vmail vmail  496 May 14 11:02 dovecot.index.log
-rw------- 1 vmail vmail  752 May 14 11:02 u.1
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




# u.1文件拆解
sdbox 格式为了性能，在邮件正文前面加了一层精简的元数据头

第一行 2 M1e C6a05aba9
    2: 这是 sdbox 的文件版本号
    M1e: 邮件的十六进制大小(0x1e = 30 字节左右，这指的是 Dovecot 额外记录的元数据长度)
    C6a05aba9: 这是一个 Unix 时间戳的十六进制表示，记录了这封邮件的写入时间或 Create ID

第二行 N 000000000000028C
    N: 代表 Next Offset 或物理偏移量
    000000000000028C: 指的是这封邮件正文在文件中的起始位置(十六进制)

中间的 Return-Path 到 X-Mailer
    这就是标准的 RFC 5322 邮件头
    Received: from ... by localhost with LMTP: 这一行最关键，它记录了邮件是怎么进来的。with LMTP 证明了 Dovecot LMTP 服务 工作正常

结尾的 R6a05aba9, V2a0, Gfa39051...
这些是 Dovecot 内部的校验和（GUID）和状态位（比如是否已读、是否草稿）


服务组件           状态诊断              证据
Postfix (smtpd)      正常    swaks 连上 25 端口并拿到了 250 Ok，说明 Postfix 正在监听并接收指令
Dovecot (auth)       正常    投递成功说明 Postfix 成功通过 /var/spool/postfix/private/auth 确认了用户 test 是存在的
Dovecot (lmtp)       正常    日志里显示的 relay=...[private/dovecot-lmtp]，证明 LMTP 进程接手了 Postfix 扔过来的球
vmail 用户/权限      正常    u.1 的属主是 vmail 且能成功写入 /var/vmail，说明文件系统的权限降权逻辑完美


看看 Dovecot 内部是怎么评价这封信的:
# 检查 Dovecot 索引和邮件状态
[root@lfs ~/build_mail]# doveadm fetch -u test@localhost "guid flags mailbox" all
guid: fa39051ea9ab056ad05c0600d09efc50
flags: \Recent $HasNoAttachment
mailbox: INBOX


````
