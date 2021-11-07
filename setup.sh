#! /bin/bash
# Wing FTP Server 2003-2021 wftpserver.com All Rights Reserved 
# SETUP SCRIPT FOR LINUX

portvalid="0"
adminport="5466"
username="administrator"
password="wingftp"

INITD_WFTP="/etc/init.d/wftpserver"
SYSTEMD_WFTP="/etc/systemd/system/wftpserver.service"

APPNAME="$0"
while [ -h "$APPNAME" ]; do
        LINK=`ls -ld "$APPNAME"`
        LINK=`expr "$LINK" : '.*-> \(.*\)'`
        if [ "`expr "$link" : '/.*'`" = 0 ]; then
                DIR=`dirname "$APPNAME"`
                APPNAME="$DIR/$LINK"
        else
                APPNAME="$LINK"
        fi
done
WING_HOME=`dirname $APPNAME`
WING_HOME=`cd $WING_HOME && pwd`


alert() {
	echo -n "$1? [y/N]: "
	read MESSAGE
	expr "$MESSAGE" : ' *[yY].*' > /dev/null
}


if [ "$UID" -ne "0" ]; then
  echo "The setup script is required to run under root privileges."
  echo "Please try again like this:  sudo ./setup.sh"
  exit
fi


echo "Welcome to the Wing FTP Server setup wizard!"
echo "Please setup administrator account for Wing FTP Server."
echo "This account is very important as it will be used to administrate your server."
echo -n "Enter your administrator name: "
read username
while [ -z "$username" ]; do
   echo "Admin name can not be empty!"
   echo ""
   echo -n "Enter your administrator name: "
   read username
done
echo -n "Enter your administrator password: "
read password
while [ -z "$password" ] || [ "`expr length $password`" -lt "8" ]; do
   echo "Admin password must have 8 or more characters!"
   echo ""
   echo -n "Enter your administrator password: "
   read password
done

echo ""
echo "Please specify a port that web based administration will be listening to."
echo -n "Enter the listener port(default is 5466): "
read adminport
if [ -z "$adminport" ]; then
    adminport="5466"
fi


#check whether adminport is a valid port
netstat -ln |awk '/^tcp/ {print $4}' |grep -q ":$adminport$" || portvalid="1" 1>/dev/null 2>&1
echo "$adminport" |grep -Eq '[^0-9]' && portvalid="0" 1>/dev/null 2>&1
while [ -z "$adminport" ] || [ "$portvalid" -eq "0" ] || [ "$adminport" -lt "1" ] || [ "$adminport" -gt "65535" ]; do
    echo "Port $adminport is a invalid port or being used, please stop WingFTP service first."
    echo ""
    echo -n "Enter the listener port(default is 5466): "
    read adminport
    if [ -z "$adminport" ]; then
        adminport="5466"
    fi
    portvalid="0"
    netstat -ln |awk '/^tcp/ {print $4}' |grep -q ":$adminport$" || portvalid="1" 1>/dev/null 2>&1
    echo "$adminport" |grep -Eq '[^0-9]' && portvalid="0" 1>/dev/null 2>&1
done

passmd5=`echo -n "$password"|sha256sum|cut -d' ' -f1`

if [ -z "$passmd5" ]; then
    passmd5=`echo -n "$password"|md5sum|cut -d' ' -f1`
fi

#kill the existed wftpserver process
pkill wftpserver & 1>/dev/null 2>&1


if [ ! -f "$WING_HOME/Data/_ADMINISTRATOR/admins.xml" ]; then
mkdir -p "$WING_HOME/Data/_ADMINISTRATOR" 1>/dev/null 2>&1
touch "$WING_HOME/Data/_ADMINISTRATOR/admins.xml"
cat > "$WING_HOME/Data/_ADMINISTRATOR/admins.xml" <<-EOF
<?xml version="1.0" ?>
<ADMIN_ACCOUNTS Description="Wing FTP Server Admin Accounts">
<ADMIN><Admin_Name>$username</Admin_Name><Password>$passmd5</Password><Type>0</Type><Readonly>0</Readonly></ADMIN>
</ADMIN_ACCOUNTS>
EOF
fi

if [ ! -f "$WING_HOME/Data/_ADMINISTRATOR/settings.xml" ]; then
mkdir -p "$WING_HOME/Data/_ADMINISTRATOR" 1>/dev/null 2>&1
touch "$WING_HOME/Data/_ADMINISTRATOR/settings.xml"
cat > "$WING_HOME/Data/_ADMINISTRATOR/settings.xml" <<-EOF
<?xml version="1.0" ?>
<Administrator Description="Wing FTP Server Administrator Options">
    <HttpPort>$adminport</HttpPort>
    <HttpSecure>0</HttpSecure>
    <SSLName>wftp_default_ssl</SSLName>
    <AdminLogfileEnable>1</AdminLogfileEnable>
    <AdminLogfileFileName>Admin-%Y-%M-%D.log</AdminLogfileFileName>
    <AdminLogfileMaxsize>0</AdminLogfileMaxsize>
    <EnablePortUPnP>0</EnablePortUPnP>
</Administrator>
EOF
fi

sed -i -e "s/<\/ADMIN_ACCOUNTS>/<ADMIN><Admin_Name>$username<\/Admin_Name><Password>$passmd5<\/Password><Type>0<\/Type><Readonly>0<\/Readonly><\/ADMIN><\/ADMIN_ACCOUNTS>/" "$WING_HOME/Data/_ADMINISTRATOR/admins.xml"
sed -i -e "s/\(<HttpPort>\).*\(<\/HttpPort>\)/\1$adminport\2/" "$WING_HOME/Data/_ADMINISTRATOR/settings.xml"
chmod -R 600 "$WING_HOME/Data"

if [ -d "$WING_HOME/session" ]; then
	chmod -R 600 "$WING_HOME/session"
fi

if [ -d "$WING_HOME/session_admin" ]; then
	chmod -R 600 "$WING_HOME/session_admin"
fi

if [ -d "$WING_HOME/Log/Admin" ]; then
	chmod -R 600 "$WING_HOME/Log/Admin"
fi


if [ -d "/etc/systemd/system" ]; then
cat > "$SYSTEMD_WFTP" <<-EOF
[Unit]
Description=Wing FTP Server daemon
After=network.target

[Service]
User=root
Group=root
Type=forking
ExecStart=$WING_HOME/wftpserver
ExecStop=/etc/init.d/wftpserver stop
WorkingDirectory=$WING_HOME

[Install]
WantedBy=multi-user.target
EOF

touch "$SYSTEMD_WFTP"
chmod +x "$SYSTEMD_WFTP"
systemctl enable wftpserver.service 1>/dev/null 2>&1
fi


cat > "$INITD_WFTP" <<-EOF
#!/bin/sh
# Startup script for Wing FTP Server

### BEGIN INIT INFO
# Provides:          wftpserver
# Required-Start:    $local_fs $syslog
# Required-Stop:     $local_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

start()
{
    echo "Starting Wing FTP Server daemon..."
    cd $WING_HOME
    ulimit -c unlimited
    ulimit -n 65535
    ./wftpserver & 1>/dev/null 2>&1
    echo "Wing FTP Server Started."
    exit 0
}
stop()
{
    echo "Stopping Wing FTP Server daemon..."
    #pkill wftpserver & 1>/dev/null 2>&1
    WFTP_PID=\`ps -ef | grep \\.\\/wftpserver | grep -v grep | grep -v service | grep -v init.d | awk '{print \$2}'\`
    if [ ! -z "\$WFTP_PID" ]; then
       kill -9 \$WFTP_PID & 1>/dev/null 2>&1
    fi
    echo "Wing FTP Server Stopped."
    exit 0
}
restart()
{
    echo "Restarting Wing FTP Server daemon..."
    #pkill wftpserver & 1>/dev/null 2>&1
    WFTP_PID=\`ps -ef | grep \\.\\/wftpserver | grep -v grep | grep -v service | grep -v init.d | awk '{print \$2}'\`
    if [ ! -z "\$WFTP_PID" ]; then
       kill -9 \$WFTP_PID & 1>/dev/null 2>&1
    fi
    echo "Wing FTP Server Stopped."
    cd $WING_HOME
    ulimit -c unlimited
    ulimit -n 65535
    ./wftpserver & 1>/dev/null 2>&1
    echo "Wing FTP Server Started."
    exit 0
}

case "\$1" in
start)
    start
    ;;
stop)
    stop
    ;;
restart)
    restart
    ;;
*)
    echo "WingFTPServer Usage: /etc/init.d/wftpserver [start|stop|restart]"
    exit 0
    ;;
esac

EOF

chmod +x "$INITD_WFTP"


if [ -d "/etc/rc0.d" ]; then
set 0 1 6
for i in "$@"; do
	ln -s "$INITD_WFTP" "/etc/rc$i.d/K01wftpserver" 
done
set 2 3 4 5
for i in "$@"; do
	ln -s "$INITD_WFTP" "/etc/rc$i.d/S99wftpserver" 
done
else
set 0 1 6
for i in "$@"; do
	ln -s "$INITD_WFTP" "/etc/init.d/rc$i.d/K01wftpserver" 
done
set 2 3 4 5
for i in "$@"; do
	ln -s "$INITD_WFTP" "/etc/init.d/rc$i.d/S99wftpserver" 
done
fi


echo ""
echo "Wing FTP Server has been installed successfully!"
echo "You can manage your server at http://YourIP:$adminport via web browser."
echo "Server Usage: /etc/init.d/wftpserver [start|stop|restart]"

alert "Do you want to start Wing FTP Server now?"
if [ "$?" -eq "0" ]
then
	cd $WING_HOME
	./wftpserver & 1>/dev/null 2>&1
fi
