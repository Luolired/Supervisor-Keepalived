sup解读 (安装过程中变启动：ps aux |grep supervisor)


sup封装
pip install supervisor
apt-get -y install supervisor

我们知道应用程序不应要root启动，下面将用apps用户来运行程序。因此sup，也需要修改默认配置让apps用户组的成员都可以直接操作管理

```
# chown -R apps:apps /etc/supervisor
#/etc/init.d/supervisor stop
# vi /etc/init.d/supervisor
修改成下面的：
LOGDIR=/var/applog/supervisor  
PIDFILE=/var/applog/supervisor/$NAME.pid
# chown apps:apps /etc/init.d/supervisor
# sudo -u apps mkdir -p /var/applog/supervisor
# mv /usr/bin/supervisorctl /usr/bin/supzcli          #supervisorctl 将被重命名为supcli
# cp supervisorctl封装后的 /usr/bin/supervisorctl
# chmod 755 /usr/bin/supervisorctl
# mkdir -p /tmp/supervisor_conf.bak/
# chown -R apps:apps /tmp/supervisor_conf.bak/
## sudo -u apps mkdir -p /etc/supervisor/G_Move_conf.d
# sudo -u apps vi /etc/supervisor/supervisord.conf
logfile=/var/applog/supervisor/supervisord.log ; (main log file;default $CWD/supervisord.log)
pidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
childlogdir=/var/applog/supervisor            ; ('AUTO' child log dir, default $TEMP)
serverurl=unix:///var/applog/supervisor//supervisor.sock 
user=apps
#chmod=0760                       ; sockef file mode (default 0700)
[include]         重大bug files不能写成两行，写在同一行，用空格分开，否则conf无法加载avail
files=/etc/supervisor/conf.d/*.conf /etc/supervisor/G_Move_conf.d/*.conf
用空格分开多个目录。否则下图第二个files将覆盖第一个！！！
```
