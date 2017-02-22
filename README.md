# Supervisor-Keepalived 

##一、标题【互为主备高可用解决了用户的停机困扰】 
		免费开源，适合一般互联网运维公司, 比起昂贵的F5、vSphere和vCenter、
		[英方容灾高可用](http://www.info2soft.com/solutions/rzgky)<br />
		分部署存储客户端权限过高等问题

###二、Supervisor管理服务与Keeppalived高可用案例(已运营到生产)
![img](https://github.com/Luolired/Supervisor-Keepalived/blob/master/supervisor/QQ截图20170217112636.jpg)

###三、描述概要：
		通过实时监控应用的状态，当应用异常或生产系统出现各类异常（如服务器停止、网络异常、硬件故障、生产系统宕机维护）而导致系统不可用时，高可用解决方案将相关的应用立即切换到灾备服务器上，由灾备服务器接管所有应用来提供服务，保证业务的连续性。

###四、解决的问题：
#####1.A主机应用程序服务器启动后如何24小时不间断守护服务？自己写守护进程管理？==>Supevisor监控而且还守护拉起服务。还能独立帮你logrotate日志
#####2.A主机应用程序服务器非常多如何管理启动，而且程序启动有优先顺序？如何自动？人工一个一个启动？ ====>一个配置自动实现，而且还提供web
#####3.A主机应用程序服务因为系统过保随时宕机，应用程序服务又不能中断，如何在备机B接管 A的程序业务？ ===>Rsync 同步非结构化数据+keepalived健康检测
#####4.A主机为主，B主机为备。A主机和B主机现阶段都跑有业务，如何新加入主备切换vip、同步等，不影响现有业务？===>加入lock 锁机制,人工干预维护
##### 加我微信一起讨论：
![img](https://github.com/Luolired/Supervisor-Keepalived/blob/master/supervisor/QQ截图20170217115759.jpg)

####五、实现：Supervisor+Keepalived+Rsync+inotify-tools 
####5.1.业务标准规范化
		任何一个节点都是不可靠的，主机在故障时（服务器宕机）高可用keepalived，如何接管故障主机的应用服务（比如故障机开了什么服务？运行了多少进程？)假设主机宕机，不清楚跑了什么业务，涉及哪些业务面？都是两眼一抹黑那就谈不及自动化，我们先得梳理清楚业务，规范统一它们自己的关系。运维应该对业务面、拓扑、程序监控、运行服务都应该了如指掌，即使不清楚，也要能可查cmdb。

####5.2.启动配置集中
		每个应用程序或服务的启动我们需要报备，需要一个可以集中管理的地方，集中在一起，我们才能方便的去管理和维护，我们需要把启动的程序用supervisor管理若干program,如：我们将supervisor的配置集中在'''/etc/supervisor/conf.d/*.conf''' 
>   举几个例子：
  如：
      #cat /etc/supervisor/conf.d/CdkeyBalancer.conf
      [program:CdkeyBalancer]
    directory=/usr/local/007ka/CdkeyBalancer
    command=java -server -Xms256m -Xmx512m -jar /usr/local/007ka/CdkeyBalancer/CdkeyBalancer.jar
    startsecs=5       
    autostart=false    
    autorestart=true
    startretries=3 
    user=apps
    priority=999
    stdout_logfile=NONE

> 关键字：集中、统一、程序改造接入supervisor

###5.3启动服务标准模板化
		supervisor目录集中统一后我们需要将程序的启动形成标准或形成一个模板，通用的只需要修改Program.ini,就能进行直接生成对应的程序的CdkeyBalancer.conf
		举个例子，技术人员把CdkeyBalancer程序开发好后需要启动服务，我们首先需要创建一个program.ini.program.ini是一个程序应用信息卡片.卡片里包含有程序的程序名称、启动目录、启动路径参数、优先级、程序版本信息等等。

    /usr/local/007ka/CdkeyBalancer$ cat program.ini 
    #程序run.sh启动配置文件
    #注意不是程序目录,是实际应用程序,有后缀的带后缀,必须配置 01
    PROGRAM_NAME=CdkeyBalancer.jar
    
    #程序路径,PROGRAM_PATH,实际应用程序上一级目录,必须配置 02
    PROGRAM_PATH=/usr/local/007ka/CdkeyBalancer
    
    #程序可能用到的配置文件,若需要,请配置 03
    #PROGRAM_INI=/usr/local/007ka/etc/oemsrv_for_PingAn.ini
    
    #程序可能用到的配置文件,必须配置PROGRAM_NAME 04
    PROGRAM_RUN=java -server -Xms256m -Xmx512m -jar /usr/local/007ka/CdkeyBalancer/CdkeyBalancer.jar
    #1.C程序:./oemsrv_pa /usr/local/007ka/etc/oemsrv_for_PingAn.ini
    #2.JAVA程序:java -server -Xms128m -Xmx128m -jar oemsrv_pa.jar
    #3.PHP程序:php oemsrv_pa.php

		如上，运维人员只需要修改对应程序的实际情况即可。接着我们有一个sup_run.sh 启动模板脚本。脚本能识别当前目录下的program.ini配置参数，创建/etc/supervisor/conf.d/CdkeyBalancer.conf 还能支持CdkeyBalancer程序的启动star\stop/restart/update。
		
> 总结：每个程序都具备一个各自对应的program.ini,也有一个大家都一样的启动模板程序sup_run.sh. 
  sup_run.sh路径：

###5.4 应用管理状态页面与supervisorctl封装
    supervisorctl status能看到当前supervisor守护的程序管理对象有哪些，在这里我们能清楚看到当前管理程序的状态,启动时间。如：
    orderVerify_7021                 RUNNING    pid 23486, uptime 149 days, 14:16:03
    OrderVerify_7022                 RUNNING    pid 24164, uptime 149 days, 14:15:38
    PhoneInfoSrv                     STOPPED    Nov 16 09:43 AM
    PhoneInfoSrv_1                   RUNNING    pid 3433, uptime 149 days, 14:01:58

启动多个程序：supervisorctl rderVerify_7021 OrderVerify_7022 PhoneInfoSrv CdkeyBalancer
重启所有服务：supervisorctl restart all
停止所有服务：supervisorctl stop all

等等命令，如果你操作管理要求比较高，则需要封装改写supervisorctl进行过滤禁止执行一些危险的命令例如 stop all/shutdown

###5.5 消除不一致性,实时同步
我们需要把A与B主机需要实时同步的对象进行罗列分解：
#### 同步1.A服务器应用程序环境配置同步到B主机
#### 同步2.A服务器supervisorctl status 状态同步到B主机
#### 同步3.A服务器对外提供访问的vip需要转移到B主机
#### 同步4.keepalived+supervisord 程序管理环境的一致

##### 同步1.应用程序：参考我的【案例脚本】
    rsync_007ka_install 自动化安装同步007ka应用 【一键安装、自动建立实时同步关系】
    【需求】：将rsync与inotify 实时同步一键安装封装包
    【复杂度】：两星
    【技巧】：
        1.自动安装而且帮你配置好配置，你只需要告诉他从哪里同步到哪里
        2.带同步实时记录日志
        3.自动交互安装，即使你是小白不懂rsync与inotify
        4.不仅带过滤监控的文件，而且还有不同步文件的白名单如*.log\*.log.tar.gz
		
##### 同步3与同步4 标准化安装配置即可
		我们有Supervisor_install.tar.gz keepalived_env_install.tar.gz 分布在A和B各自解压,执行install.sh 交互输入A服务器和B服务器互为对方地址，So Easy.

##### 同步2.A服务器supervisorctl status 状态同步到B主机
		我们这里提供了两种方案：

> 方案一： rsync与inotify实时 导出supervisorctl status状态，脚本分割过滤取的需要启动RUNNING 列表,和STOPPED列表.eg:all_program_state.txt 

> 方案二： 使用封装supervisorctl（1.拒绝危险命令2.supervisorctl stop CdkeyBalancer 后将CdkeyBalancer.conf从conf.d目录移走mv ）,然后同步rsync与inotify/etc/supervisor/conf.d目录文件变化状态。

		我们选择的是方案二，通过我们封装过后的/usr/bin/supervisorctl 无论是在终端还是sup_run.sh对程序的stop管理，都能将对应的程序启动配置文件从conf.d移除。

		为什么要移除？为了避免在高可用切换后明明在A服务器关闭的业务，切换到B主机后被开启，这不是我们想看到的，所以，我们需要将程序的关停状态要准确无误。


### 5.6 keepalived切换与加lock锁机制
		当A服务器宕机故障后，B服务器 keepalvied 心跳健康检测发现需要接管A服务器业务，B主机有backup角色升级到Master角色，主备事件角色替换，notify_backup和notify_master事件被触发。

    节点提升为master调用的脚本 notify_master "/etc/keepalived/scripts/150_backup_111/sup_run_all.sh"
    节点降级为backup调用的脚本 notify_backup "/etc/keepalived/scripts/150_backup_111/sup_backup_all.sh"
    节点降级为stop调用的脚本 notify_stop "/etc/keepalived/scripts/150_backup_111/sup_stop_all.sh"
    
> sup_run_all.sh 包行了关键操作：/etc/init.d/supervisor start 与supervisorctl update && supervisorctl -c /etc/supervisord.conf start all

 		sup_run_all.sh与sup_backup_all.sh和sup_stop_all.sh 脚本中都加入keepalived_switch.lock
		Keepalived主备切换功能开启锁文件,存在将不进行切换,不存在可切换,即加锁不同步,同步锁文件,存在不进行同步,不存在则进行同步,即加锁不同步这样我们就可以想让keepalved切换superviosr程序就切换，不需要则加个锁进去，就不会影响现有业务。

> 待续.... lizx 20170217 
