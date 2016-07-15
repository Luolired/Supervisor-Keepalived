#!/bin/bash

#***************************************************************************
# * 
# * @file:sup_stop_all.sh 
# * @author:soc
# * @date:2016-01-05 16:26 
# * @version 0.5
# * @description: 节点降级为stop调用的脚本
# *     1.脚本标准化
# * @Copyright (c) 007ka all right reserved 
# * @updatelog: 
# *             1.更新程序标准化逻辑性
# *             2.修改并增加关闭对端机与本机函数
# *             3.增加同步锁状态标识，用以区分同步开启
# *             4.增加Keepalived主备切换功能开启锁，用以初始化启动抢占操作多开或Stop原有业务
#**************************************************************************/ 

export LANG=zh_CN.GBK

#输出keepalived主备状态
/bin/echo $(date +%c) stop >> /etc/keepalived/state.txt

#程序启动配置配置文件
PRO_CFG_PATH=$(dirname $0)
PRO_CFG="${PRO_CFG_PATH}/keepalived_supervisord.ini"
#Keepalived主备切换功能开启锁文件,存在将不进行切换,不存在可切换,即加锁不同步
KEEPALIVED_SWITCH_LOCK_FILE="${PRO_CFG_PATH}/keepalived_switch.lock"
#同步锁文件,存在不进行同步,不存在则进行同步,即加锁不同步
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
        echo "$G_LOCAL_IP not found!please check bond0"
        exit 1
fi

###LOG_PATH
###程序运行all日志输出路径
g_s_LOG_PATH=/var/applog/${G_LOG_FILE}

mkdir -p $g_s_LOG_PATH
g_s_LOGDATE=`date +"%F"`
#执行脚本生成的日志all
g_s_LOGFILE="${g_s_LOG_PATH}/pid_stop.${g_s_LOGDATE}.log"
### LOG to file  eg:g_fn_LOG "Test"
g_fn_LOG()
{
    s_Ddate=`date +"%F %H:%M:%S"`
    echo "[$s_Ddate] $*" >> $g_s_LOGFILE
}

#本机sup conf文件存储路径
LOCAL_DIR=/etc/supervisor/conf.d

#关闭Stop本机应用
Stop_Local_Prog()
{
        g_fn_LOG "$G_LOCAL_IP 节点降级为stop调用的脚本 一键关闭本机程序 Start"
        #提前加锁不同步
	touch $RSYNC_PID_LOCK_FILE &> /dev/null
        if [ -f $RSYNC_PID_LOCK_FILE ];then
                g_fn_LOG "[SUCCESS] $RSYNC_PID_LOCK_FILE PID实时同步加锁成功,开启不同步!!!"
        else
                g_fn_LOG "[ERROR] $RSYNC_PID_LOCK_FILE PID实时同步加锁失败,仍可同步"
        fi

        if [ ! -d $LOCAL_DIR ];then
                echo -e "\n\033[33m\033[01m$LOCAL_DIR does not exist!\033[0m"
                g_fn_LOG "$LOCAL_DIR does not exist!"
                exit 1
        else
		ps aux |grep -v grep |grep -q "/usr/bin/supervisord" || {
                        g_fn_LOG "/etc/init.d/supervisor start"
                        /etc/init.d/supervisor start
                }
                g_fn_LOG "supervisorctl -c /etc/supervisor/supervisord.conf stop all"
		supervisorctl -c /etc/supervisor/supervisord.conf stop all
                if [ $? -eq 0 ];then
                        g_fn_LOG "Sup Stop all 执行成功"
                else
                        g_fn_LOG "Sup Stop all 执行失败"
                fi
                echo -e '\n'        
	fi
        g_fn_LOG "$G_LOCAL_IP 节点降级为stop调用的脚本 一键关闭本机程序 End"
}

main(){
        g_fn_LOG "===================================================================="
        if [ ! -f "$KEEPALIVED_SWITCH_LOCK_FILE" ];then
		#锁不存在,可以执行切换,本机若为备份(Backup)角色,执行以下脚本进行关闭应用程序
		#notify_stop "/etc/keepalived/scripts/sup_stop_all.sh"
                Stop_Local_Prog
        else
		echo -e "\033[1;31m[ERROR] Keepalived主备切换功能开启锁存在,若需要请移除锁,方可Stop_Local_Prog\033[0m"  
                g_fn_LOG "[ERROR] ${KEEPALIVED_SWITCH_LOCK_FILE} Keepalived主备切换功能开启锁存在,若需要请移除锁,方可Stop_Local_Prog"
        	exit 1
        fi
        g_fn_LOG "===================================================================="
        exit 0
}

main
