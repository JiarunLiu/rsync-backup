# Rsync time backup for servers

This script offers **incremental backups** of **a list of server directorys**. The backup module is based on [this proj](https://github.com/laurent22/rsync-time-backup) and rsync. Specifically, our code only support on Linux.

## Installation

	git clone https://github.com/JiarunLiu/rsync-time-backup

## Usage

### Step-1: Verify ssh public key connection

Our backup between servers is based on the ssh connection with public key. You can set up the ssh connection following this [link](https://www.cnblogs.com/Hi-blog/p/9482418.html) or any ssh setup guide.

### Step-2: Edit your backup Servers with an backup list file

Add your servers and directories in the `backup_list.txt` following this format:

```shell
# FORMAT
{USER_NAME}@{IP_ADDR}:{TARGET_DIR}
# SAMPLES
usename@192.168.1.1:/file/folder
```

The scripts will backup all the files in `backup_list.txt`. Notablly, the backup list file support comment by "#". 

### Step-3: Add backup scripts to crontab

 We use crontab to backup file automatically in Linux or MaxOS. [The instruction of crontab.](https://www.runoob.com/linux/linux-comm-crontab.html)

#### 3.1 Create an logging directory

Switch to the `${PATH_TO_PROJECT}` and `mkdir logs` to create an logging directory.

#### 3.2 Edit crontab tasks

Edit the crontab tasks by `crontab -e`. Then add the scripts (absolute path) to the end of crontab tasks:

```shell
# back up all servers at 1:00 am each day
0 1 * * * bash ${PATH_TO_PROJECT}/backup_all_servers.sh >> "${PATH_TO_PROJECT}/logs/$(date | sed  -e 's/ [ ]*/_/g' ).log"
```



## Introduction of Original Project

You can see the [original introduction](https://github.com/laurent22/rsync-time-backup/blob/master/README.md) of our base project.
