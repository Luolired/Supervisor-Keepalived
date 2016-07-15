#!/bin/bash

# ***************************************************************************
# * 
# * @file:run.sh 
# * @author:Luolired
# * @date:2016-06-16 09:47 
# * @version 1.0.1  
# * @description: supervisorctl Manage Program Standy Run Shell script 
# * @usrage: run.sh start|stop|restart|update|help
# * @Copyright (c) 007ka all right reserved 
# * @UpdateLog:
# *            1.增加sup默认模板,优先级priority、stdout_logfile 不输出
#**************************************************************************/ 

export LANG=zh_CN.GBK

#set -x
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

#程序启动配置配置文件
PRO_CFG_PATH=$(dirname $0)
PRO_CFG="${PRO_CFG_PATH}/program.ini"
PRO_SUPERVISORCTL_BIN=/usr/bin/supervisorctl
G_Sup_Conf_Path=/etc/supervisor/conf.d
G_Sup_Conf_Template=/etc/supervisor/conf.d/Template.j2

### Logding PRO_CFG
#. $PROGRAM_INI
PROGRAM_NAME=`grep -Pw "^PROGRAM_NAME" $PRO_CFG |awk -F 'PROGRAM_NAME=' '{print $NF}'`
PROGRAM_PATH=`grep -Pw "^PROGRAM_PATH" $PRO_CFG |awk -F 'PROGRAM_PATH=' '{print $NF}'`
PROGRAM_INI=`grep -Pw "^PROGRAM_INI" $PRO_CFG |awk -F 'PROGRAM_INI=' '{print $NF}'`
PROGRAM_RUN=`grep -Pw "^PROGRAM_RUN" $PRO_CFG |awk -F 'PROGRAM_RUN=' '{print $NF}'`
#PROGRAM_USER=`grep -Pw "^PROGRAM_USER" $PRO_CFG |awk -F 'PROGRAM_USER=' '{print $NF}'`
PROGRAM_USER=apps

### Print error messges eg:  _err "This is error"
function _err()
{
    echo -e "\033[1;31m[ERROR] $@\033[0m" >&2
}

### Print notice messages eg: _info "This is Info"
function _info()
{
    echo -e "\033[1;32m[Info] $@\033[0m" >&2
}

### Check $PROGRAM_PATH
if [ ! -d $PROGRAM_PATH ];then
	_err "$PROGRAM_PATH is not a directory,please check"
	exit $STATE_OK
fi

### Check ${PROGRAM_PATH}/${PROGRAM_NAME}
if [ ! -f ${PROGRAM_PATH}/${PROGRAM_NAME} ];then
	_err "${PROGRAM_PATH}/${PROGRAM_NAME} is not a file,please check"
	exit $STATE_OK
fi

### Check supervisord is online
ps -A | grep -q "supervisord" || {
	_err "supervisord process is not exist,please: apps /etc/init.d/supervisor start"
	exit $STATE_CRITICAL
}

### supervisor conf Path
PROGRAM_SERVER_NAME=$(echo ${PROGRAM_NAME%.*})
PROGRAM_SUP_CONF="${G_Sup_Conf_Path}/${PROGRAM_SERVER_NAME}.conf"

### Supervisor conf Templates
g_fn_Supervisor()
{
cat <<EOF
[program:${PROGRAM_SERVER_NAME}]
directory=${PROGRAM_PATH}
command=${PROGRAM_RUN}
startsecs=5       
autostart=false    
autorestart=true
startretries=3 
user=${PROGRAM_USER}
priority=999
stdout_logfile=NONE
EOF
}

#停止程序
g_fn_Stop()
{
	Program_PID=$(pgrep -u ${PROGRAM_USER} -fl "${PROGRAM_NAME}"| grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh\|run\|sup_run" | awk '{print $1}')
        Exist_count=$(echo ${Program_PID} |wc -l)
	if [[ ${Exist_count} -ne 0 ]];then
		_info "${PRO_SUPERVISORCTL_BIN} stop ${PROGRAM_SERVER_NAME}"
		${PRO_SUPERVISORCTL_BIN} stop ${PROGRAM_SERVER_NAME}
		${PRO_SUPERVISORCTL_BIN} remove ${PROGRAM_SERVER_NAME}
                if ps aux | grep ^${PROGRAM_USER} |grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh\|run\|sup_run" |grep -q "${PROGRAM_USER}"
		then
                	_info "$PROGRAM_NAME Success Stopped!"
			exit $STATE_OK
                else
                	_err "$PROGRAM_NAME Stopping Failed!"
			exit $STATE_CRITICAL
                fi
        else
        	_err "$PROGRAM_NAME does not exist,process is not running!"
		exit $STATE_UNKNOWN
        fi
}

#启动程序
g_fn_Start()
{
	Program_PID=$(pgrep -u ${PROGRAM_USER} -fl "${PROGRAM_NAME}"| grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh\|run\|sup_run" | awk '{print $1}')
	if [ -n "${Program_PID}" ];then
		_err "$PROGRAM_NAME is already running.exiting..."
		exit $STATE_WARNING
	else
		g_fn_Supervisor > /tmp/supervisor.tmp
		sudo -u ${PROGRAM_USER} cp /tmp/supervisor.tmp ${PROGRAM_SUP_CONF}
		if [ -f "${PROGRAM_SUP_CONF}" ];then
			_info "${PRO_SUPERVISORCTL_BIN} reread ${PROGRAM_SERVER_NAME}"
			${PRO_SUPERVISORCTL_BIN} reread ${PROGRAM_SERVER_NAME} 
			if [ $? -eq 0 ];then              
				_info "${PRO_SUPERVISORCTL_BIN} add ${PROGRAM_SERVER_NAME}"
				${PRO_SUPERVISORCTL_BIN} add ${PROGRAM_SERVER_NAME} 
				[ $? -eq 0 ] && ${PRO_SUPERVISORCTL_BIN} start ${PROGRAM_SERVER_NAME}
                		if ps aux | grep ^${PROGRAM_USER} |grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh\|run\|sup_run" |grep -q "${PROGRAM_USER}";then
        	                	_info "$PROGRAM_NAME Starting OK!!!" 
					${PRO_SUPERVISORCTL_BIN} status
					exit $STATE_OK
                		else
                			_err "$PROGRAM_NAME Starting Failed,Falut By Supervisor Add/Start ${PROGRAM_SERVER_NAME}!!!"
					exit $STATE_CRITICAL
                		fi
        	        else
        	                _err "$PROGRAM_NAME Start Failed,Fault By Supervisor Reread ${PROGRAM_SERVER_NAME}!!!"
				exit $STATE_CRITICAL 
        	        fi
		else
			_err "${PROGRAM_SUP_CONF} is not Found,Please Check Cp File!"
			exit $STATE_CRITICAL
		fi
	fi
}

### ReStart Program function
g_fn_ReStart()
{
	${PRO_SUPERVISORCTL_BIN} status |grep "RUNNING" |grep "${PROGRAM_SERVER_NAME}"
	if ${PRO_SUPERVISORCTL_BIN} status |grep "RUNNING" |grep -q "${PROGRAM_SERVER_NAME}";then
		${PRO_SUPERVISORCTL_BIN} restart ${PROGRAM_SERVER_NAME}
		if [ $? -eq 0 ];then
			_info "${PROGRAM_SERVER_NAME} ReStarting OK!!!"
			${PRO_SUPERVISORCTL_BIN} status
			exit $STATE_OK
		else
			_err "${PROGRAM_SERVER_NAME} ReStarting Failed!!!"
			exit $STATE_CRITICAL
		fi
	else
		_err "${PROGRAM_SERVER_NAME} does not exist,process is not running!"
		exit $STATE_UNKNOWN
	fi
}

#停止程序,且将程序从sup内存中移除(彻底清理)
g_fn_Update()
{
	if ${PRO_SUPERVISORCTL_BIN} status |grep -q "${PROGRAM_SERVER_NAME}";then
		${PRO_SUPERVISORCTL_BIN} stop ${PROGRAM_SERVER_NAME}
		${PRO_SUPERVISORCTL_BIN} remove ${PROGRAM_SERVER_NAME}
	fi
	_info "${PROGRAM_SERVER_NAME} Update Success Ok!!!"
}

#获取帮助信息
g_fn_Help()
{
	_info "eg:${PROGRAM_PATH}/`basename $0` start|stop|restart|update|help"
}

#版本函数
g_fn_Version()
{
	_info "Create Time:2016-07-15,Author:007ka-soc,V1.0.1"
	_info "Modified Time:2016-07-15,V1.0.1"
}

Temp_Argument=$1
#主函数
main(){
	#读取参数值
	if [ "${Temp_Argument}" = "" ];then
	        g_fn_Start
	        exit 0
	else
	        case "${Temp_Argument}" in
	       		 restart|Restart)
	       		        g_fn_ReStart;;
	       		 stop|Stop)
	       		        g_fn_Stop;;
	       		 start|Start)
	       		        g_fn_Start;;
			 update|Update)
				g_fn_Update;;
	       		 -h|--help|help)
	       		        g_fn_Help
				g_fn_Version
	       		        exit $STATE_OK;;
	       		 -V|-v)
				g_fn_Version
	       		 	exit $STATE_OK;;
	       		 *)
	       		 	_err "Error input argument $1,Please Check"
	       		        g_fn_Help
	       		        exit $STATE_WARNING;;
	        esac
	fi
	rm -rf /tmp/supervisor.tmp &>/dev/null
}

main
