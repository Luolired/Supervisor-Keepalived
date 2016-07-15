#!/bin/bash

#***************************************************************************
# * 
# * @file:rsync_sup_conf.sh
# * @author:soc
# * @date:2016-01-25 16:26 
# * @version 0.2
# * @description: Inotify实时监控同步PID脚本
# *     1.主备机Pid目录的同步
# * @Copyright (c) 007ka all right reserved 
# * @updatelog: 
# *             1.更新程序标准化逻辑性,PID同步
#*************************************************************************** 

export LANG=zh_CN.GBK

#程序启动配置配置文件
PRO_CFG_PATH=$(dirname $0)
PRO_CFG="${PRO_CFG_PATH}/keepalived_supervisord.ini"
RSYNC_PID_LOCK_FILE="${PRO_CFG_PATH}/rsync_sup_conf.lock"

### Logding PRO_CFG
G_MOVE_IP=$(grep -Pw "^G_MOVE_IP" $PRO_CFG |awk -F 'G_MOVE_IP=' '{print $NF}')
G_MOVE_SUP_BAK_PATH=$(grep -Pw "^G_MOVE_SUP_BAK_PATH" $PRO_CFG |awk -F 'G_MOVE_SUP_BAK_PATH=' '{print $NF}')
G_VIP_IP=$(grep -Pw "^G_VIP_IP" $PRO_CFG |awk -F 'G_VIP_IP=' '{print $NF}')
G_LOG_FILE=$(grep -Pw "^PROGRAM_PATH" $PRO_CFG |awk -F 'PROGRAM_PATH=' '{print $NF}'|awk -F '[/]+' '{print $NF}')
G_LOCAL_IP=$(ip addr | grep 'inet' | grep "10\.2" | grep -vw 'secondary' | awk -F ['/ ']+ 'NR==1 {print $3}')
PROGRAM_PATH=$(grep -Pw "^PROGRAM_PATH" $PRO_CFG |awk -F 'PROGRAM_PATH=' '{print $NF}')

#若配置路径是/$则进行剔除最后/字符,保证路径正确性
echo $PROGRAM_PATH | grep -q '/$' && PROGRAM_PATH=$(echo $PROGRAM_PATH|sed 's/\/$//')

if [ -z $G_LOCAL_IP ]
then
        echo "G_LOCAL_IP not found!please check bond0"
        exit 1
fi

###LOG_PATH
###程序运行all日志输出路径
g_s_LOG_PATH=/var/applog/${G_LOG_FILE}

mkdir -p $g_s_LOG_PATH
g_s_LOGDATE=`date +"%F"`
#执行脚本生成的日志
g_s_LOGFILE="${g_s_LOG_PATH}/rsync_sup_conf.${g_s_LOGDATE}.log"
### LOG to file  eg:g_fn_LOG "Test"
g_fn_LOG()
{
    s_Ddate=`date +"%F %H:%M:%S"`
    echo "[$s_Ddate] $*" >> $g_s_LOGFILE
}

[ `whoami` = "apps" ] || {
        echo "用户非apps,退出!"
        exit 1
}

#本机sup conf文件存储路径
LOCAL_DIR=/etc/supervisor/conf.d

#开启监控前先同步一次
g_fn_LOG "| 开始监控前的第一次同步 First"
rsync -vzrtopgHl --progress --delete ${LOCAL_DIR}/* apps@${G_MOVE_IP}:${G_MOVE_SUP_BAK_PATH}/ >> $g_s_LOGFILE

g_fn_LOG "| 开始监控 ${LOCAL_DIR} 变化 Welcome"
#同步锁文件若存在则不进行同步,不存在则同步,且只同步*.conf文件
/usr/bin/inotifywait -mrq --timefmt '%y-%m-%d %H:%M' --format '%T %w%f %e' --exclude '(^.+\.[^conf]$|.*/*\.swp|.*/*\.svn|.*/*\.log|.*/*\.swx|.*/*\.col|.*/*\.bak|.*/*~|.*/log/.*|.*/hist.log/.*|.*/logs/.*)' -e close_write,delete,create,attrib,move ${LOCAL_DIR} |while read file
do
	if [ ! -f ${RSYNC_PID_LOCK_FILE} ];then
                g_fn_LOG "| EVENT $file 监控到文件有变化,且同步锁不存在,准备开始同步"
                for Tmp_Ip in $G_MOVE_IP
                do
                        g_fn_LOG "| START SEND TO ${Tmp_Ip}"
                        rsync -vzrtopgHl --progress --delete ${LOCAL_DIR}/* apps@${Tmp_Ip}:${G_MOVE_SUP_BAK_PATH}/ >> $g_s_LOGFILE
			#rsync -vzrtopgHl --progress --rsync-path="mkdir -p ${LOCAL_DIR} && rsync" --delete ${LOCAL_DIR}/*.conf apps@${Tmp_Ip}:${LOCAL_DIR} >> $g_s_LOGFILE
                        g_fn_LOG "| END SEND TO ${Tmp_Ip}"
                done
	else
        	g_fn_LOG "| ${RSYNC_PID_LOCK_FILE} 同步锁文件存在,将退出同步 GoodBye"
        	exit 1
	fi
done
exit 0
