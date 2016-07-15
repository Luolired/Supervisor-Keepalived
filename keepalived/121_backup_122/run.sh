#!/bin/bash

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

#-----------------------------首次配置有5处-------------------------------
#程序启动配置配置文件
PRO_CFG_PATH=$(dirname $0)
PRO_CFG="${PRO_CFG_PATH}/keepalived_supervisord.ini"
#-----------------------------------------------------------------------

### Logding PRO_CFG
#. $PROGRAM_INI
PROGRAM_NAME="rsync_sup_conf.sh"
PROGRAM_PATH=`grep -Pw "^PROGRAM_PATH" $PRO_CFG |awk -F 'PROGRAM_PATH=' '{print $NF}'`

### Print error messges eg:  _err "This is error"
function _err()
{
    #echo -e "\033[1;31m[ERROR] $@\033[0m" >&2
    echo -e "\033[1;31m[ERROR] $@\033[0m"
}

### Print notice messages eg: _info "This is Info"
function _info()
{
    #echo -e "\033[1;32m[Info] $@\033[0m" >&2
    echo -e "\033[1;32m[Info] $@\033[0m"
}

### pid storage file ip_last_three
ip_last=$(ip addr | grep 'inet' | grep "10\.2" | grep -vw 'secondary' | awk -F['/'' '.]+ 'NR==1 {print $6}')
if [ -z $ip_last ]
then
        _err "ip_last not found!please check bond0"
        exit 1
fi
#PID storage path eg：112_pid ${PROGRAM_NAME%.*} 删除后缀
#PID_FILE="/var/applog/${ip_last}_pid/${PROGRAM_NAME%.*}.pid"

### Check $PROGRAM_PATH
if [ ! -d $PROGRAM_PATH ];then
	_err "$PROGRAM_PATH is not a directory,please check"
	exit 1
fi

### Check ${PROGRAM_PATH}/${PROGRAM_NAME}
if [ ! -f ${PROGRAM_PATH}/${PROGRAM_NAME} ];then
	_err "${PROGRAM_PATH}/${PROGRAM_NAME} is not a file,please check"
	exit 1
fi

#[ `whoami` = "apps" ] || {
#        _err "用户非apps,退出!"
#        exit 1
#}

### ReStart Program function
ReStart()
{
        Old_pid=`ps aux|grep -w $PROGRAM_NAME|grep ^apps|grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh" |awk '{print $2}'`
        Exist_count=`ps aux|grep -w $PROGRAM_NAME|grep ^apps|grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh" |awk '{print $2}'|wc -l`
        _info "old PID: $Old_pid "
        if [ $Exist_count -ne 0 ];then
                sudo -u apps /bin/kill $Old_pid &>/dev/null
		sudo -u apps /bin/kill `pgrep -u apps -f "close_write,delete,create,attrib,move /var/applog/${ip_last}_pid"` &>/dev/null
        fi
        if [ $? -eq 0 ];then
		#请配置 04
		cd $PROGRAM_PATH 
		sudo -u apps /usr/bin/nohup ${PROGRAM_PATH}/${PROGRAM_NAME} &>/dev/null &
		#1.C程序:sudo -u apps /usr/bin/nohup ./$PROGRAM_NAME &>/dev/null &
		#2.JAVA程序:sudo -u apps /usr/bin/nohup java -jar -Xms128m -Xmx128m $PROGRAM_NAME &>/dev/null &
		#3.PHP程序:sudo -u apps /usr/bin/nohup php $PROGRAM_NAME &>/dev/null &
		Last_pid=$!
                _info "Last_pid:root $Last_pid"
                sleep 1
		New_pid=`ps aux|grep -w $PROGRAM_NAME|grep ^apps|grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh" |awk '{print $2}'|xargs -n5`
		_info "ReStarting OK New Pid:$New_pid"
		#echo -e "PID=$New_pid\nPATH=$PROGRAM_PATH" > $PID_FILE
		exit $STATE_OK
        else
                _err "$PROGRAM_NAME stopping failed!!!"
		exit $STATE_CRITICAL
        fi
}

#停止程序
Stop()
{
        PID=`ps aux|grep -w $PROGRAM_NAME|grep ^apps|grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh" |awk '{print $2}'`
        Exist_count=`ps aux|grep -w $PROGRAM_NAME|grep ^apps|grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh" |awk '{print $2}'|wc -l`
        if [ $Exist_count -ne 0 ];then
                sudo -u apps kill $PID &> /dev/null
		sudo -u apps /bin/kill `pgrep -u apps -f "close_write,delete,create,attrib,move /var/applog/${ip_last}_pid"` &>/dev/null
                if [ $? -eq 0 ];then
			#将停止程序pid移走
			#sudo -u apps mv $PID_FILE /home/apps/lost_pid/
                	_info "$PROGRAM_NAME Success Stopped!"
			exit $STATE_OK
                else
                	_err "$PROGRAM_NAME Stopping Failed!"
			exit $STATE_CRITICAL
                fi
        else
        	_err "$PROGRAM_NAME does not exist,process is not running!"
		exit $STATE_WARNING
        fi
}

#启动程序
Start()
{
	ps aux | grep -w $PROGRAM_NAME | grep ^apps | grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh"
	RETVAL=$?
	if [ $RETVAL -eq 0 ]
	then
		_err "$PROGRAM_NAME is already running.exiting..."
		exit $STATE_WARNING
	else
        	cd $PROGRAM_PATH 
		#请配置 05
		sudo -u apps /usr/bin/nohup ${PROGRAM_PATH}/${PROGRAM_NAME} &>/dev/null &
		#1.C程序:sudo -u apps /usr/bin/nohup ./$PROGRAM_NAME &>/dev/null &
		#2.JAVA程序:sudo -u apps /usr/bin/nohup java -jar -Xms128m -Xmx128m $PROGRAM_NAME &>/dev/null &
		#3.PHP程序:sudo -u apps /usr/bin/nohup php $PROGRAM_NAME &>/dev/null &
		Last_pid=$!
		_info "Last_pid:root $Last_pid"
                ps aux | grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh" |grep -q "$Last_pid" 
                if [ $? -eq 0 ];then              
			sleep 1
			New_pid=`ps aux|grep -w $PROGRAM_NAME|grep ^apps|grep -vw "grep\|vim\|vi\|mv\|cp\|scp\|cat\|dd\|tail\|head\|script\|ls\|echo\|sys_log\|logger\|tar\|rsync\|ssh" |awk '{print $2}'|xargs -n5`
                        _info "Starting OK New Pid:$New_pid" 
                        #echo -e "PID=$New_pid\nPATH=$PROGRAM_PATH" > $PID_FILE
			exit $STATE_OK
                else
                         _err "$PROGRAM_NAME Start Failed!!!"
			exit $STATE_CRITICAL
                fi
	fi
}

#获取帮助信息
Help()
{
cat <<EOF
==== `basename $0`           #启动程序====
==== `basename $0` restart   #重启程序====
==== `basename $0` stop      #停止程序====
==== `basename $0` start     #启动程序====     
==== `basename $0` -h|--help #获取帮助====
==== `basename $0` -v|-V     #获取帮助====
EOF
exit $STATE_OK
}


#读取参数值
TEMP=$1
if [ "$TEMP" = "" ];then
        Start
        exit 0
else
        case $1 in
        restart|Restart)
                ReStart
                exit 0;;
        stop|Stop)
                Stop
                exit 0;;
        start|Start)
                Start
                exit 0;;
        -h|--help|help)
                Help
                exit 0;;
	-V|-v)
		_info "Create Time:2015-08-20,Author:007ka-soc,V1.0"
		_info "Modified Time:2015-09-11,V1.1,Add Read PRO_CFG"
		exit 0;;
        *)
		_err "Error input argument $1"
		_info "eg:${PROGRAM_PATH}/`basename $0` start|stop|restart|help"
                exit 0;;
        esac
fi
