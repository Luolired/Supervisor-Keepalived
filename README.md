# Supervisor-Keepalived
Supervisor应用程序管理与Keepalived高可用切换解决方案


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


        4.4 Sup报备中心同步  -----待续

        4.5.keepalived与Sup报备中心衔接调度         -----待续

五、模拟测试

      5.1 apps运行supervisorctl    

        apps@22app121p:/etc/supervisor$ /etc/init.d/supervisor --help 标准化启动sup服务

        Usage: /etc/init.d/supervisord {start|stop|restart|force-reload|status|force-stop}


     5.2 supervisorctl 封装

        New_supervisor  新的sup入口。拒绝shutdown命令，stop应用时，把conf相对的应用从conf.d目录移到/tmp/supervisor_conf.bak

        

      5.3 run.sh 模板标准化的改写

        [Info] eg:/usr/local/007ka/BankInterface/BOBB2CServer/sup_run.sh start|stop|restart|update|help

        完成对应用程序额的单独管理，新增介入到sup报备中心，从报备中心创建conf 启动 & stop 停止服务，移除conf & 重启服务 & 更新在Sup里面的缓存

       .

       5.4 守护进程样例

        #supervisorctl maintail     看守护日志

             

       一般用户下的测试：

        lizx01@22app121p:~$ supervisorctl 

        New_supervisor> help

    default commands (type help <topic>):

    =====================================

    add    clear  fg        open  quit    remove  restart   start   stop  update 

    avail  exit   maintail  pid   reload  reread  shutdown  status  tail  version


    New_supervisor> pid

    58517

    New_supervisor> avail

    BOBB2CServer                     in use    manual    999:999

    New_supervisor> status

    BOBB2CServer                     RUNNING    pid 61138, uptime 0:11:23

    New_supervisor> exit

    GoodBye Soc

        （Tips: 执行管理进程就必须在Sup平台里面进行管理应用程序，kill将再次守护执行启动）

            SO:管理进程有两种方法：

                A.客户端入口模式：supervisorctl

                B.应用run.sh模式: run.sh stop/start/restart

        5.4 Sup报备中心同步  -----待续

        5.5.keepalived与Sup报备中心衔接调度         -----待续
