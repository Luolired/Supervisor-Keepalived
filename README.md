#Supervisor-Keepalived 【解决了用户的停机困扰互为主备高可用】 

##免费开源，适合互联网运维公司,比起昂贵的F5、vSphere和vCenter、英方容灾高可用、分部署存储客户端权限过高等

###Supervisor管理服务与Keeppalived高可用实施(已运营到生产)
![img](https://github.com/Luolired/Supervisor-Keepalived/blob/master/supervisor/QQ截图20170217112636.jpg)

###概要：通过实时监控应用的状态，当应用异常或生产系统出现各类异常（如服务器停止、网络异常、硬件故障、生产系统宕机维护）而导致系统不可用时，高可用解决方案将相关的应用立即切换到灾备服务器上，由灾备服务器接管所有应用来提供服务，保证业务的连续性。

### 解决的问题：
####1.A主机应用程序服务器启动后如何24小时不间断守护服务？自己写守护进程管理？==>监控而且还守护
####2.A主机应用程序服务器非常多如何管理启动，而且程序启动有优先顺序？如何自动？人工一个一个启动？ ====>一个配置自动实现，而且还提供web
####3.A主机应用程序服务因为系统过保随时宕机，应用程序服务又不能中断，如何在备机B接管 A的程序业务？ ===>Rsync 同步非结构化数据+keepalived健康检测
####4.A主机为主，B主机为备。A主机和B主机现阶段都跑有业务，如何新加入主备切换vip、同步等，不影响现有业务？===>加入lock 锁机制,人工干预维护
      
      以上问题解决方案：Supervisor(python)
        
        
        1.单点主机在故障时（服务器宕机）高可用keepalived，如何接管故障主机的应用服务（比如故障机开了什么服务？运行了多少进程？）
        
        
        综上: Supervisor+Keepalived+Rsync+inotify-tools 
        基础条件：每个应用程序启动运行都需要标准化
        
        （何为标准化？1./sup_run.sh start/restart/stop/update 2.每个应用程序自带程序信息卡prgram.ini）
        
        原理解读：我们通过实时同步Supervisor启动配置文件，在主机故障时，keepalived启动接管响应notif_master事件，启动主机应用程序。
        因为superviosr应用程序启动停止只是从内存中remove,哪我们怎么把主机开了哪些服务告诉备机呢？
        两种解决方案：
        1.封装改写supervisorctl 只要程序停止了，启动配置文件默认从conf.d移除，这样就能保证程序不多不少在备机接管开启。
        2.实时将supervisorctl status 状态同步给备机，备机在实时的加载到内存里。（此方法比较复杂：先要导出主机stauts状态，比较难实现备机的stauts状态与主机保持一致）
        
        因此，我们选择了 封装改写supervisorctl。
        好处有两个：
       1.supervisorctl command stop/remove 移除对应程序配置,以达到supervisor目录下,高可用同步Shell script
       2.过滤禁止执行一些危险的命令例如 stop all/shutdown

一、标题：Sup应用管理可行性方案探讨-lizx-20160620

二、简介：
    Supervisor 是由python语言编写、基于linux操作系统的一款服务器管理工具，用以监控服务器的运行，发现问题能立即自动预警及自动重启等功能。
    1.程序的多进程启动，可以配置同时启动的进程数，而不需要一个个启动
    2.程序的退出码，可以根据程序的退出码来判断是否需要自动重启
    3.程序所产生日志的处理
    4.进程初始化的环境，包括目录，用户，umask，关闭进程所需要的信号等等
    5.手动管理进程(开始，启动，重启，查看进程状态)的web界面，和xmlrpc接口
    【关键字】：进程管理工具、自动守护重启、二次开发
    
三、需求：

        【现状】：每台主机上配备一个包含本机运行的pid目录（我们称为PID报备中心),每一个运行的程序因为有了标准化的启动脚本，都会在PID报备中心里，增删改pid文件。

        【高可用】：PID报备中心实时同步到备机，主机故障时keepalived切换，接管对端机PID报备中心，开启对端机程序。

         【缺陷】：

                         1. SOC不按标准化管理应用程序，直接kill进程，虽然程序停止，但是PID报备中心，没有移除此PID。高可用时，将启动程序。因此，人为非标准化，会带来隐患

                        2. 在报备中心PID程序监控，我们可以进行监控守护每一个进程，因为我们PID数众多，所以守护进程的资源开销将非常大（需要对比存储新旧PID变化）。因此，我们只监控了进程总数的监控。

        对比Sup: 解决监控守护每一个进程+程序管理入口需要统一和规范+接口API

四、可行性探索

        测试环境：10.22.10.121

        测试应用：  /usr/local/007ka/BankInterface/BOBB2CServer 等

        supervisorctl version  3.0a8

         规范：

                   A: 应用程序与目录保持一致 

                   B:多开程序遵循多开原则，多开程序编号命名

                   C:软链接版本切换更新迭代

                    D：日志标准化

        4.1 supervisord 服务apps运行。管理应用程序，其他用户支持进入管理程序

              修改supervisord.conf配置即可，测试可行。
        4.2 supervisorctl 封装

        supervisorctl 重新命名为===》 supzcli

        我们把 supervisorctl 进行了封装，拒绝一些危险的命令，单独处理一些特定命令，让它额外完成conf配置的移除。

         a.禁止执行shutdown命令（一般用户操作若执行则supervisorctl 将退出，所管理的程序退出）

         b.supervisorctl stop $Prgram_Server_Name  。执行stop时，我们希望$Prgram_Server_Name从sup内存和从/etc/supervisor/conf.d/Prgram_Server_Name.conf  把文件移除

        why？ 为什么需要将Prgram_Server_Name.conf  移除？

       因为我们需要建立高可用主备切换，主备服务的接管。接管哪些？通过rsync+inotify 同步/etc/supervisor/conf.d/ 下的所有程序conf配置，同步到备机。

        当主机故障时，备机keepalived 加载同步过来的conf配置，supervisorctl start all

        /etc/supervisor/conf.d/ 等同于PID报备中心，我们称为Sup报备中心

        4.3 run.sh 模板标准化的改写 

         改写每个程序下的run.sh，考虑两方面原则，既要支持program.ini 又要支持start|stop|restart 操作supervisor 对应语法。

         /usr/local/007ka/BankInterface/BOBB2CServer/sup_run.sh start|stop|restart|update|help


五、模拟测试
        5.4 Sup报备中心同步  -----完成测试

                 现在 22-121 和22-122 sup配置文件是相互同步的。

                 121        conf.d目录下/sup*.conf =======同步=====》 122 conf.d / G_Move_conf.d/    实时同步   

                apps     56198  0.0  0.0  17860  1652 ?        S    Jul07   0:00 /bin/bash /etc/keepalived/scripts/121_backup_122/rsync_sup_conf.sh                   

                  涉及脚本：

                  /etc/keepalived/scripts/121_backup_122/ keepalived_run.sh                   

                  /etc/keepalived/scripts/121_backup_122/keepalived_supervisord.ini



        5.5.keepalived与Sup报备中心衔接调度       

     由：

        

        notify_master "/etc/keepalived/scripts/121_backup_122/pid_run.sh"

        notify_backup "/etc/keepalived/scripts/121_backup_122/pid_backup.sh"

        notify_stop "/etc/keepalived/scripts/121_backup_122/pid_stop.sh

      变化成：                

        notify_master "/etc/keepalived/scripts/121_backup_122/sup_run_all.sh"

        notify_backup "/etc/keepalived/scripts/121_backup_122/sup_backup_all.sh"

        notify_stop "/etc/keepalived/scripts/121_backup_122/sup_stop_all.sh"

            

          原理一致：修改了 程序逻辑，无须判断每个程序的pid文件，遍历每个启动或者停止。使用supervisor语法：  

             supervisorctl -c /etc/supervisor/supervisord.conf start all

             supervisorctl -c /etc/supervisor/supervisord.conf stop all (已测试成功,封装后的sup,会将conf.d目录下conf移走)

    

          5.5 keepalived 测试

            实验成功

            日志如下：

                     cat /etc/keepalived/state.txt 

                       2016年07月11日 星期一 10时23分02秒 backup

                    

                    apps@22app122p:/var/applog/121_backup_122$ cat pid_backup.2016-07-11.log 

                    [2016-07-11 10:23:02] ====================================================================

                    [2016-07-11 10:23:02] 10.22.10.122 节点降级为backup调用的脚本 一键关闭本机程序 Start

                    [2016-07-11 10:23:02] [SUCCESS] /etc/keepalived/scripts/121_backup_122/rsync_sup_conf.lock PID实时同步加锁成功,开启不同步!!!

                    [2016-07-11 10:23:02] supervisorctl -c /etc/supervisor/supervisord.conf stop all

                    [2016-07-11 10:23:02] Sup Stop all 执行成功

                    [2016-07-11 10:23:02] 10.22.10.122 节点降级为backup调用的脚本 一键关闭本机程序 End

                    [2016-07-11 10:23:02] ====================================================================

 

                apps@22app122p:/var/applog/121_backup_122$ supervisorctl status

                BOBB2CServer                     STOPPED    Jul 11 10:04 AM

                BondSendStatisticsService        STOPPED    Jul 11 10:04 AM

                ManageBackStageService           STOPPED    Jul 11 10:04 AM

                RechareSuccForSms                STOPPED    Jul 11 10:04 AM

                SmsSendService                   STOPPED    Jul 11 10:04 AM




                    root@22app121p:/etc/keepalived/scripts/121_backup_122# cat /etc/keepalived/state.txt                

                    2016年07月11日 星期一 10时12分21秒 backup

                    2016年07月11日 星期一 10时23分05秒 master

                    

                root@22app121p:/var/applog/121_backup_122# cat pid_run.2016-07-11.log 

                [2016-07-11 10:23:05] ========================================================================

                [2016-07-11 10:23:05] 10.22.10.121 节点将提升为Master 一键启动程序 Start

                [2016-07-11 10:23:05] [SUCCESS] /etc/keepalived/scripts/121_backup_122/rsync_sup_conf.lock 同步锁不存在,同步功能可使用

                [2016-07-11 10:23:05] supervisorctl -c /etc/supervisord.conf start all

                [2016-07-11 10:23:11] Sup Start all 执行成功

                [2016-07-11 10:23:11] 10.22.10.121 节点将提升为Master 一键启动程序 End

                [2016-07-11 10:23:11] 清除10.22.10.121主机程序残留的fullappname 开始进入

                [2016-07-11 10:23:11] clearfullappname.sh不存在!

                [2016-07-11 10:23:11] 清除10.22.10.121主机程序残留的fullappname 结束完毕

                [2016-07-11 10:23:11] ========================================================================

                    

            root@22app121p:/var/applog/121_backup_122# supervisorctl status

            BOBB2CServer                     RUNNING    pid 1734, uptime 0:23:29

            BondSendStatisticsService        RUNNING    pid 1691, uptime 0:23:29

            ManageBackStageService           RUNNING    pid 1720, uptime 0:23:29

            RechareSuccForSms                RUNNING    pid 1743, uptime 0:23:29

            SmsSendService                   RUNNING    pid 1692, uptime 0:23:29

     

        【总结】：

                        1. 小伙伴在上线应用程序到 121和122时，只需要将 sup_run.sh 上线到应用程序即可将程序加入到sup，就是这么Easy ，program.ini 仍然还是保留。

                         2.新运维技能-Supervisor 管理应用程序常见命令用法eg:
