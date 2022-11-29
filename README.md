# lineinfile-sh
One command to add/change/remove a "line" in a config file. Useful for scripting as well.  The goal is to build a bash/busybox compatible version of ansible-lineinfile (originaly writen in python)


lineinfile  --firstmatch  --regexp="PasswordAuthentication" --line="#PasswordAuthentication yes"  --state=present  /etc/ssh/sshd_config 
```
Filename: '/etc/ssh/sshd_config'
Line found
  56-
  57-   # To disable tunneled clear text passwords, change to no here!
  58:   #PasswordAuthentication yes
  59-   #PermitEmptyPasswords no
  60-
  
$ echo "$?"
0

```

lineinfile --backup --firstmatch --regexp="PasswordAuthentication" --line="PasswordAuthentication without-password"  /etc/ssh/sshd_config
```
Backup file -/etc/ssh/sshd_config- to -/etc/ssh/sshd_config.2022-11-29T16:37:39+01:00-
Filename: '/etc/ssh/sshd_config'
before
  56-
  57-   # To disable tunneled clear text passwords, change to no here!
  58:   #PasswordAuthentication yes
  59-   #PermitEmptyPasswords no
  60-
Filename: '/etc/ssh/sshd_config'
after
  56-
  57-   # To disable tunneled clear text passwords, change to no here!
  58:   PasswordAuthentication without-password
  59-   #PermitEmptyPasswords no
  60-
```

lineinfile --firstmatch --regexp="PasswordAuthentication" --line="PasswordAuthentication no"  /etc/ssh/sshd_config
```
Filename: 'sshd_config'
before
  56-
  57-   # To disable tunneled clear text passwords, change to no here!
  58:   PasswordAuthentication without-password
  59-   #PermitEmptyPasswords no
  60-
Filename: 'sshd_config'
after
  56-
  57-   # To disable tunneled clear text passwords, change to no here!
  58:   PasswordAuthentication no
  59-   #PermitEmptyPasswords no
  60-

```

lineinfile  --regexp="PasswordAuthentication"  --state=absent  /etc/ssh/sshd_config
```
Filename: 'sshd_config'
Remove the Line
  56-
  57-   # To disable tunneled clear text passwords, change to no here!
  58:   PasswordAuthentication no
  59-   #PermitEmptyPasswords no
  60-

```
lineinfile  --regexp="PasswordAuthentication"  --state=absent  /etc/ssh/sshd_config
```
Nothing to do. Line does not exist

$ echo "$?"
0
```

lineinfile  --firstmatch  --regexp="PasswordAuthentication" --line="#PasswordAuthentication yes"  --state=present   /etc/ssh/sshd_config
```
Line not found. Line is missing.

$ echo "$?"
1
```

lineinfile  --firstmatch  --regexp="PasswordAuthentication" --line="PasswordAuthentication yes"  --state=present  --insertbefore=EOF  /etc/ssh/sshd_config 
```
Filename: 'sshd_config'
Insert before at $
 119-   #       PermitTTY no
 120-   #       ForceCommand cvs server
 121:   PasswordAuthentication yes
 
$ echo "/etc/ssh/sshd_config"
0
```
