#!/bin/sh
# $Id: gmond-admin.init 180 2003-03-07 20:38:36Z sacerdoti $
#
# chkconfig: - 70 40
# description: gmond startup script
#

INSTANCE=`basename $0`

GMOND=/usr/sbin/gmond
PID_FILE=/var/run/$INSTANCE.pid
CONF=/etc/ganglia/$INSTANCE.conf
LOCK=/var/lock/subsys/$INSTANCE

. /etc/rc.d/init.d/functions

RETVAL=0

case "$1" in
   start)
      echo -n "Starting GANGLIA $INSTANCE: "
      [ -f $GMOND ] || exit 1

      daemon --pidfile $PID_FILE $GMOND -p $PID_FILE -c $CONF
      RETVAL=$?
      echo
      [ $RETVAL -eq 0 ] && touch $LOCK
        ;;

  stop)
      echo -n "Shutting down GANGLIA $INSTANCE: "
      killproc -p $PID_FILE gmond
      RETVAL=$?
      echo
      [ $RETVAL -eq 0 ] && rm -f $LOCK
        ;;

  restart|reload)
        $0 stop
        $0 start
        RETVAL=$?
        ;;
  status)
        status -p $PID_FILE gmond
        RETVAL=$?
        ;;
  *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac

exit $RETVAL

