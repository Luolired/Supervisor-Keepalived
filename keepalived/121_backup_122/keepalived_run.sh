#!/bin/bash

#***************************************************************************
# * 
# * @file:keepalived_run.sh 
# * @author:soc
# * @date:2016-01-05 16:26 
# * @version 0.1
# * @description: keepalived_env_install 
# * @Copyright (c) 007ka all right reserved 
# * @updatelog: 
# *             1.更新程序标准化逻辑性
#**************************************************************************/

export LANG=zh_CN.GBK

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

KEEPALIVED_PATH=/etc/keepalived
Priority_Normal_Master=120
Priority_Normal_Backup=80

#程序启动配置配置文件
PRO_CFG_PATH=$(dirname $0)
PRO_CFG="${PRO_CFG_PATH}/keepalived_supervisord.ini"
#Keepalived主备切换功能开启锁文件,存在将不进行切换,不存在可切换,即加锁不同步
KEEPALIVED_SWITCH_LOCK_FILE="${PRO_CFG_PATH}/keepalived_switch.lock"
#同步锁文件,存在不进行同步,不存在则进行同步,即加锁不同步
RSYNC_PID_LOCK_FILE="${PRO_CFG_PATH}/rsync_sup_conf.lock"

#若配置路径是/$则进行剔除最后/字符,保证路径正确性
echo $KEEPALIVED_PATH | grep -q '/$' && KEEPALIVED_PATH=$(echo $KEEPALIVED_PATH|sed 's/\/$//')

### Logding PRO_CFG
G_LOG_FILE=$(grep -Pw "^PROGRAM_PATH" $PRO_CFG |awk -F 'PROGRAM_PATH=' '{print $NF}'|awk -F '[/]+' '{print $NF}')
###LOG_PATH
###程序运行all日志输出路径
g_s_LOG_PATH=/var/applog/${G_LOG_FILE}
mkdir -p $g_s_LOG_PATH
g_s_LOGDATE=`date +"%F"`
#执行脚本生成的日志
g_s_LOGFILE="${g_s_LOG_PATH}/keepalived_run.${g_s_LOGDATE}.log"
### LOG to file  eg:g_fn_LOG "Test"
g_fn_LOG()
{
    s_Ddate=`date +"%F %H:%M:%S"`
    echo "[$s_Ddate] $*" >> $g_s_LOGFILE
}

### Print error messges eg:  _err "This is error"
function _err()
{
    echo -e "\033[1;31m[ERROR] $@\033[0m"
}

### Print notice messages eg: _info "This is Info"
function _info()
{
    echo -e "\033[1;32m[Info] $@\033[0m"
}

### 启动标准化检查
function _CheckAccess()
{
	_info "Welcome 开始进入检查启动合理性!"
	g_fn_LOG "Welcome 开始进入检查启动合理性!"
	[ `whoami` = "root" ] || {
	#[ `whoami` = "apps" ] || {
	        _err "用户非root,退出!"
		g_fn_LOG "[ERROR] 用户非root,退出!"
	        exit $STATE_CRITICAL
	}
	
	### 启动前PID数记录
	Local_ip_last=$(ip addr | grep 'inet' | grep "10\.2" | grep -vw 'secondary' | awk -F['/'' '.]+ 'NR==1 {print $6}')
	if [ -z $Local_ip_last ]
	then
        	_err "Local_ip_last not found!please check bond0"
        	exit 1
	fi
	Local_Pid_Dir=/var/applog/${Local_ip_last}_pid
	Before_Run_Pid_Total=$(find ${Local_Pid_Dir} -type f -name "*.pid"  |wc -l)
	_info "现本机$Local_ip_last PID目录下运行程序数为:${Before_Run_Pid_Total}"	
	g_fn_LOG "现本机$Local_ip_last PID目录下运行程序数为:${Before_Run_Pid_Total}"	

	### Check $KEEPALIVED_PATH
	if [ ! -d $KEEPALIVED_PATH ];then
	        _err "$KEEPALIVED_PATH is not a directory,please check"
	        g_fn_LOG "[ERROR] $KEEPALIVED_PATH is not a directory,please check"
	        exit $STATE_CRITICAL
	else
		### keepalived.conf 配置文件检查
		if [ -f ${KEEPALIVED_PATH}/keepalived.conf ];then
			grep -q "nopreempt" ${KEEPALIVED_PATH}/keepalived.conf || {
				_err "keepalived.conf 没有设置非抢占，请检查"
				g_fn_LOG "[ERROR] keepalived.conf 没有设置非抢占，请检查"
				exit $STATE_CRITICAL
			}
		fi
		### *_backup_* 目录标准化检测 
		if [[ "$(find $KEEPALIVED_PATH -type d -name "*backup*" |wc -l)" != "1" ]];then
	        	_err "Keepalived 非标准化安装,请通知业务组部署install.sh $KEEPALIVED_PATH下没有一个_backup_目录"
	        	g_fn_LOG "[ERROR] Keepalived 非标准化安装,请通知业务组部署install.sh $KEEPALIVED_PATH下没有一个_backup_目录"
	       		 exit $STATE_CRITICAL
		else
			keepalived_sys_dir=$(grep "_backup_" ${KEEPALIVED_PATH}/keepalived.conf | grep -v '#'|head -n1 | awk -F '/' '{print $5}')
			PRO_CFG_PATH=$(find /etc/keepalived/ -type d -name "*backup*" |head -n1)
			#Keepalived主备切换功能开启锁文件，文件存在将进行切换,不存在则不进行切换
			KEEPALIVED_SWITCH_LOCK_FILE="${PRO_CFG_PATH}/keepalived_switch.lock"
			#同步锁状态文件,文件存在将进行同步,不存在则不同步
			RSYNC_PID_LOCK_FILE="${PRO_CFG_PATH}/rsync_sup_conf.lock"
			
			### Check notify_master notify_backup notify_stop 
			notify_master_shell=$(grep "_backup_" ${KEEPALIVED_PATH}/keepalived.conf |grep -v "#"| grep notify_master |sed 's/\"//g'|awk '{print $2}')
			if [ -f "$notify_master_shell" ];then
				grep -q "KEEPALIVED_SWITCH_LOCK_FILE" $notify_master_shell && _info "1.notify_master 事件脚本OK包含锁" || {
					_err "keepalived.conf notify_master 脚本不存在主备切换锁"
					g_fn_LOG "[ERROR] keepalived.conf notify_master 脚本不存在主备切换锁"
					exit $STATE_CRITICAL
				}
			else
				_err "keepalived.conf notify_master 脚本不存在"
				g_fn_LOG "[ERROR] keepalived.conf notify_master 脚本不存在"
				exit $STATE_CRITICAL
			fi
			notify_backup_shell=$(grep "_backup_" ${KEEPALIVED_PATH}/keepalived.conf |grep -v "#"| grep notify_backup | sed 's/\"//g'|awk '{print $2}')
			if [ -f "$notify_backup_shell" ];then
                                grep -q "KEEPALIVED_SWITCH_LOCK_FILE" $notify_backup_shell && _info "2.notify_backup 事件脚本OK包含锁" || {
                                        _err "keepalived.conf notify_backup 脚本不存在主备切换锁"
                                        g_fn_LOG "[ERROR] keepalived.conf notify_backup 脚本不存在主备切换锁"
                                        exit $STATE_CRITICAL
                                }
                        else
                                _err "keepalived.conf notify_backup 脚本不存在"
                                g_fn_LOG "[ERROR] keepalived.conf notify_backup 脚本不存在"
                                exit $STATE_CRITICAL
                        fi
			notify_stop_shell=$(grep "_backup_" ${KEEPALIVED_PATH}/keepalived.conf | grep -v "#"|grep notify_stop|sed 's/\"//g' |awk '{print $2}')
			if [ -f "$notify_stop_shell" ];then
                                grep -q "KEEPALIVED_SWITCH_LOCK_FILE" $notify_stop_shell && _info "3.notify_stop  事件脚本OK包含锁" || {
                                        _err "keepalived.conf notify_stop 脚本不存在主备切换锁"
                                        g_fn_LOG "[ERROR] keepalived.conf notify_stop 脚本不存在主备切换锁"
                                        exit $STATE_CRITICAL          
                                }
                        else
                                _err "keepalived.conf notify_stop 脚本不存在"
                                g_fn_LOG "[ERROR] keepalived.conf notify_stop 脚本不存在"
                                exit $STATE_CRITICAL
                        fi
			### 检查Inotify实时监控同步PID脚本
			if [ $(pgrep -u apps -f "rsync_pid.sh"|wc -l) -eq 2 ];then
				if [ -f "$RSYNC_PID_LOCK_FILE" ];then
					_err "$RSYNC_PID_LOCK_FILE 同步锁不存在,请联系业务运维"
					g_fn_LOG "[ERROR] $RSYNC_PID_LOCK_FILE 同步锁不存在,请联系业务运维"
					exit $STATE_CRITICAL
				else
					_info "4.rsync_pid.sh 同步功能OK开启中"
				fi
			else
				_err "rsync_pid.sh 同步PID脚本未开启,请联系业务组启动"
				g_fn_LOG "[ERROR] rsync_pid.sh 同步PID脚本未开启,请联系业务组启动"
				exit $STATE_CRITICAL
			fi
			### 判断是否已经运行了keepalived
			if [ $(pgrep -u root -f "/usr/sbin/keepalived"|wc -l) -eq 3 ];then
			#if [ $(pgrep -u apps -f "/usr/sbin/keepalived"|wc -l) -eq 3 ];then
				_err "keepalived 已经开启,将退出脚本"
				g_fn_LOG "[ERROR] keepalived 已经开启,将退出脚本"
				exit $STATE_WARNING
			fi
			### 首次启动必须要保证锁文件的存在
			touch $KEEPALIVED_SWITCH_LOCK_FILE &> /dev/null	 
			g_fn_LOG "$KEEPALIVED_SWITCH_LOCK_FILE 首次启动锁文件的创建OK"
		fi
	fi
	g_fn_LOG "=============== _CheckAccess 检测 keepalived_run End ======================"
}

function Master()
{
	grep -q "priority ${Priority_Normal_Master}" ${KEEPALIVED_PATH}/keepalived.conf || {
		_err "你选择Master角色启动,但keepalived.conf priority配置却非Master优先级${Priority_Normal_Master},请检查"
		g_fn_LOG "[ERROR] 你选择Master角色启动,但keepalived.conf priority配置却非Master优先级${Priority_Normal_Master},请检查"
		exit $STATE_CRITICAL
	}
	echo -e "\n\033[1;35m确认执行启动操作,请确认Y|N:(\033[0m\033[33m\033[01mQ\033[0m\033[1;35m退出)：\033[0m\033[33m\033[01m\c"
        read INPUT_Temp_confirm
	echo -e "\033[0m"
	case "$INPUT_Temp_confirm" in
		Y|y)
			if [ -f "$KEEPALIVED_SWITCH_LOCK_FILE" ];then
				_info "/etc/init.d/keepalived start"
				g_fn_LOG "/etc/init.d/keepalived start"
				/etc/init.d/keepalived start
				
				### 判断是否已经运行了keepalived
				#cp /home/apps/state.txt /etc/keepalived/
				echo -e "\033[1;31m[ 稍等片刻,启动后需要预判和选取Master.... ^_^ @Create_by:SOC ]  \033[0m" | awk  'END{a=length($0);i=1;printf "\n\t";while(i<=a){printf substr($0,i,1) "\a";i++;system("sleep  0.1")};printf "\n\n" }'
				sleep 2
                	        if [ $(pgrep -u root -f "/usr/sbin/keepalived"|wc -l) -eq 3 ];then
					if [ -f ${KEEPALIVED_PATH}/state.txt ];then
						State_ROLE=$(tail -n 1 ${KEEPALIVED_PATH}/state.txt|awk '{print $NF}')
						if [[ "$State_ROLE" == "master" ]];then
							After_Run_Pid_Total=$(find ${Local_Pid_Dir} -type f -name "*.pid"  |wc -l)
							g_fn_LOG "现本机$Local_ip_last PID目录下运行程序数为:${After_Run_Pid_Total}"
							if [ "$Before_Run_Pid_Total" -eq "$After_Run_Pid_Total" ];then
								_info "祝贺:启动成功"
								echo -e "\n\033[1;35m 检查完毕后,将移除锁,请确认Y|N:(\033[0m\033[33m\033[01mQ\033[0m\033[1;35m退出)：\033[0m\033[33m\033[01m\c"
							        read INPUT_Temp_confirm
        							echo -e "\033[0m"
      								case "$INPUT_Temp_confirm" in
               								Y|y)
										rm $KEEPALIVED_SWITCH_LOCK_FILE 
										#rm $KEEPALIVED_SWITCH_LOCK_FILE &> /dev/null
										_info "锁移除完毕,主备切换生效Success Keepalived 启动所有操作执行完毕!!!"
										g_fn_LOG "[SUCCESS] 锁移除完毕,主备切换生效Success Keepalived 启动所有操作执行完毕!!!"
									;;
									q|N|n|Q)
                	  							_info "提醒:请注意移除锁$KEEPALIVED_SWITCH_LOCK_FILE GoodBye !"
                	  							g_fn_LOG "提醒:请注意移除锁$KEEPALIVED_SWITCH_LOCK_FILE GoodBye !"
                	      							exit $STATE_OK
                	        					;;
           							     	*)
										_err "确认指令不存在,必须为:Y|N"
										exit $STATE_UNKNOWN
									;;
								esac

							else
								_err "注意:启动后程序PID总数不一致,请核实"
								exit $STATE_WARNING
							fi	
						else
							_err "警告:启动后,主备角色不一致,请立刻检查/var/log/syslog,并联系业务组!!!"
							g_fn_LOG "[ERROR] 警告:启动后,主备角色不一致,请立刻检查/var/log/syslog,并联系业务组!!!"
							exit $STATE_CRITICAL
						fi
					else
						_err "警告:启动后${KEEPALIVED_PATH}/state.txt 未创建,未调用到notify_backup,请立刻检查/var/log/syslog"
						g_fn_LOG "[ERROR] 警告:启动后${KEEPALIVED_PATH}/state.txt 未创建,未调用到notify_backup,请立刻检查/var/log/syslog"
						exit $STATE_CRITICAL	
					fi
				else
                	                _err "keepalived 启动失败,请检查/var/log/syslog"
                	                g_fn_LOG "[ERROR] keepalived 启动失败,请检查/var/log/syslog"
                	                exit $STATE_WARNING
                	        fi
			else	
				_err "$KEEPALIVED_SWITCH_LOCK_FILE 请先加锁再启动 touch $KEEPALIVED_SWITCH_LOCK_FILE"
				g_fn_LOG "$KEEPALIVED_SWITCH_LOCK_FILE 请先加锁再启动 touch $KEEPALIVED_SWITCH_LOCK_FILE"
				exit 1
			fi
			;;
		q|N|n|Q)
			_info "GoodBye !"
			exit 0
			;;
		*)
			_err "确认指令不存在,必须为:Y|N"
			exit 1
			;;
	esac
	g_fn_LOG "=============== Master 执行keepalived_run End ======================"
}

function Backup()
{
	grep -q "priority ${Priority_Normal_Backup}" ${KEEPALIVED_PATH}/keepalived.conf || {
		_err "你选择Backup角色启动,但keepalived.conf priority配置却非Backup优先级${Priority_Normal_Backup},请检查"
		g_fn_LOG "[ERROR] 你选择Backup角色启动,但keepalived.conf priority配置却非Backup优先级${Priority_Normal_Backup},请检查"
		exit $STATE_CRITICAL
	}
	echo -e "\n\033[1;35m确认执行启动操作,请确认Y|N:(\033[0m\033[33m\033[01mQ\033[0m\033[1;35m退出)：\033[0m\033[33m\033[01m\c"
        read INPUT_Temp_confirm
	echo -e "\033[0m"
	case "$INPUT_Temp_confirm" in
		Y|y)
			if [ -f "$KEEPALIVED_SWITCH_LOCK_FILE" ];then
				_info "/etc/init.d/keepalived start"
				/etc/init.d/keepalived start
				
				#cp /home/apps/state.txt /etc/keepalived/
				### 判断是否已经运行了keepalived
				echo -e "\033[1;31m[ 稍等片刻,启动后需要预判和选取Master.... ^_^ @Create_by:SOC ]  \033[0m" | awk  'END{a=length($0);i=1;printf "\n\t";while(i<=a){printf substr($0,i,1) "\a";i++;system("sleep  0.1")};printf "\n\n" }'
				sleep 2
                	        if [ $(pgrep -u root -f "/usr/sbin/keepalived"|wc -l) -eq 3 ];then
					if [ -f ${KEEPALIVED_PATH}/state.txt ];then
						State_ROLE=$(tail -n 1 ${KEEPALIVED_PATH}/state.txt|awk '{print $NF}')
						if [[ "$State_ROLE" == "backup" ]];then
							After_Run_Pid_Total=$(find ${Local_Pid_Dir} -type f -name "*.pid"  |wc -l)
							g_fn_LOG "现本机$Local_ip_last PID目录下运行程序数为:${After_Run_Pid_Total}"
							if [ "$Before_Run_Pid_Total" -eq "$After_Run_Pid_Total" ];then
								_info "祝贺:启动成功"
								echo -e "\n\033[1;35m 检查完毕后,将移除锁,请确认Y|N:(\033[0m\033[33m\033[01mQ\033[0m\033[1;35m退出)：\033[0m\033[33m\033[01m\c"
							        read INPUT_Temp_confirm
        							echo -e "\033[0m"
      								case "$INPUT_Temp_confirm" in
               								Y|y)
										rm $KEEPALIVED_SWITCH_LOCK_FILE
										#rm $KEEPALIVED_SWITCH_LOCK_FILE &> /dev/null
										_info "锁移除完毕,主备切换生效 Success Keepalived 启动所有操作执行完毕!!!"
										g_fn_LOG "[SUCCEESS] 锁移除完毕,主备切换生效 Success Keepalived 启动所有操作执行完毕!!!"
									;;
									q|N|n|Q)
                	  							_info "提醒:请注意移除锁$KEEPALIVED_SWITCH_LOCK_FILE GoodBye !"
                	  							g_fn_LOG "提醒:请注意移除锁$KEEPALIVED_SWITCH_LOCK_FILE GoodBye !"
                	      							exit $STATE_OK
                	        					;;
           							     	*)
										_err "确认指令不存在,必须为:Y|N"
										exit $STATE_UNKNOWN
									;;
								esac

							else
								_err "注意:启动后程序PID总数不一致,请核实"
								g_fn_LOG "[ERROR] 注意:启动后程序PID总数不一致,请核实"
								exit $STATE_WARNING
							fi	
						else
							_err "警告:启动后,主备角色不一致,请立刻检查/var/log/syslog,并联系业务组!!!"
							g_fn_LOG "[ERROR] 警告:启动后,主备角色不一致,请立刻检查/var/log/syslog,并联系业务组!!!"
							exit $STATE_CRITICAL
						fi	
					else
						_err "警告:启动后${KEEPALIVED_PATH}/state.txt 未创建,未调用到notify_backup,请立刻检查/var/log/syslog"
						g_fn_LOG "[ERROR] 警告:启动后${KEEPALIVED_PATH}/state.txt 未创建,未调用到notify_backup,请立刻检查/var/log/syslog"
						exit $STATE_CRITICAL
					fi
				else
                	                _err "keepalived 启动失败,请检查/var/log/syslog"
                	                g_fn_LOG "[ERROR] keepalived 启动失败,请检查/var/log/syslog"
                	                exit $STATE_WARNING
                	        fi
			else
				_err "$KEEPALIVED_SWITCH_LOCK_FILE 请先加锁再启动 touch $KEEPALIVED_SWITCH_LOCK_FILE"
				g_fn_LOG "[ERROR] $KEEPALIVED_SWITCH_LOCK_FILE 请先加锁再启动 touch $KEEPALIVED_SWITCH_LOCK_FILE"
				exit $STATE_CRITICAL
			fi
			;;
		q|N|n|Q)
			_info "GoodBye !"
			exit 0
			;;
		*)
			_err "确认指令不存在,必须为:Y|N"
			exit 1
			;;
	esac
	g_fn_LOG "=============== Backup 执行keepalived_run End ======================"
}

#获取帮助信息
Help()
{
        echo -e "\033[0m"
        echo -e "\033[1;35m===============自动化安装Keepalived 脚本检查要素======================\033[1m"
        echo -e "\033[1;35m=============执行请先发QQ信息通知业务组,准备开启keepalived=============\033[1m"
        echo -e "\033[0;35m=== 【语法: `basename $0` 参数】          例子如下: \033[0m"
        echo -e "\033[0;32m[Info]\t ==== `basename $0` 请选择参数 #获取帮助====   \033[0m"
        echo -e "\033[0;32m[Info]\t ==== `basename $0` master     #Master角色启动程序====  \033[0m"
        echo -e "\033[0;32m[Info]\t ==== `basename $0` backup     #Backup角色启动程序====  \033[0m"
        echo -e "\033[0;32m[Info]\t ==== `basename $0` -h|--help  #获取帮助====             \033[0m"
        echo -e "\033[0;32m[Info]\t ==== `basename $0` -v|-V      #获取版本信息====         \033[0m"
        echo -e "\033[1;35m========================================================================\033[1m"
        echo -e "\033[0m"
}

function main(){
#读取参数值
TMP_ROLE=$1
if [ "$TMP_ROLE" = "" ];then
        Help
        exit 0
else	
	g_fn_LOG "===============Welcome 开始执行keepalived_run======================"
	_CheckAccess 
        case "$TMP_ROLE" in
        master|Master|MASTER)
                Master
                exit 0;;
        backup|Backup|BACKUP)
                Backup
                exit 0;;
        -h|--help|help)
                Help
                exit 0;;
        -V|-v)
                _info "Create Time:2016-01-27,Author:007ka-soc,V1.0"
                _info "Modified Time:2016-01-27,V1.1"
                exit 0;;
        *)
                _err "Error input argument $1"
                _info "eg:${KEEPALIVED_PATH}/`basename $0` master|backup|help"
                exit 0;;
        esac
fi

}

main $1
