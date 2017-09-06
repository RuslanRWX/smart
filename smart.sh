#!/bin/sh
disk=$1
parm=$2
PATH="/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/sbin:/usr/local/bin"
hostname=`uname`

tmpdir='/etc/zabbix/tmp'

FindFunc () {
find /tmp/smartres.$disk -mmin +30 -exec rm '{}' \; > /dev/null  2>&1
}

SmartStart () {
case $hostname in
    "FreeBSD")
	      flags="-a";
        if [ ! -f /tmp/smartres.$disk ]; then { 
	    smartctl $flags /dev/$disk > /tmp/smartres.$disk
	        if [ "$?" -ne 0 ]; then
	    {	
		if [ "`grep -w 'd sat' /tmp/smartres.$disk`" != "" ]; then
		{
		smartctl $flags -d sat /dev/$disk > /tmp/smartres.$disk
    		}
	            fi
	    }
	        fi
     }; fi
;;
    "Linux")
                if [ "`lspci`" = "RAID" ]
            then {  
	  echo "1"
#	 if [ ! -f /tmp/smartres.$disk ]; then { smartctl -a -d aacraid,0,0,$disk  /dev/sda  > /tmp/smartres.$disk; }; fi

    	     }
    	else { 
     if [ ! -f /tmp/smartres.$disk ]; then { smartctl -a /dev/$disk > /tmp/smartres.$disk;  }; fi
                 } 
              fi
     
#                smartctl -a -d aacraid,0,0,$disk  /dev/sda  > /tmp/smartres.$disk
#		smartctl -a   /dev/sdb  > /tmp/smartres.sdb
#		smartctl -a   /dev/sdc  > /tmp/smartres.sdc
        ;;
esac
}

CreateDisk () {
case $hostname in
    "FreeBSD")
	if [ -c "/dev/mfid0" ]
	then { 
	     kldstat | grep mfip.ko >> /dev/null ||  kldload mfip.ko
	     ls /dev/pass* | awk -F'/' 'BEGIN { print "\{\n \"data\":[" }  { print  "\{\"{#DISK}\":\""$3"\"},"  }  END  { print " ]\n\}" }' > ${tmpdir}/disk.smart.txt
	     }
	else {
geom disk list | grep 'Geom name' | sed "s/\ //g" | awk -F":" 'BEGIN { print "\{\n \"data\":[" }  { print  "\{\"{#DISK}\":\""$2"\"},"  }  END  { print " ]\n\}" }' > ${tmpdir}/disk.smart.txt
                     }
	fi
;;
    "Linux")
                if [ "`lspci | grep -i "RAID MegaRAID"`" != "" ]
            then {  
           megacli -pdlist -a0 | grep 'Device Id' | awk 'BEGIN { print "{\n \"data\":[" }  { print  "{\"{#DISK}\":\""$3"\"},"  }  END  { print " ]\n}" }'  > ${tmpdir}/disk.smart.txt && echo 0 || echo 1
    	     }
              elif [ "`lspci | grep -i Adaptec`" != "" ]
            then {  
           megacli -pdlist -a0 | grep 'Device Id' | awk 'BEGIN { print "{\n \"data\":[" }  { print  "{\"{#DISK}\":\""$3"\"},"  }  END  { print " ]\n}" }'  > ${tmpdir}/disk.smart.txt  && echo 0 || echo 1
	         }
    	else {
                      dcount=`ls -1 /dev | egrep '^sa[a-z]$|^sd[a-z]$' | wc -l` 
                      line=`expr $dcount + 2`
       ls -1 /dev | egrep '^sa[a-z]$|^sd[a-z]$' | awk 'BEGIN { print "{\n \"data\":[" }  { print  "{\"{#DISK}\":\""$1"\"},"  }  END  { print " ]\n}" }' | sed "${line}s/,//"  > ${tmpdir}/disk.smart.txt && echo 0 || echo 1

                 } 
              fi
 exit 0 
        ;;
esac
chown zabbix:zabbix  ${tmpdir}/disk.smart.txt
echo 0
exit 0
}

ShowParm () {

if [ "`grep -w 'Transport protocol' /tmp/smartres.$disk | awk '{ print $3 }'`" = "SAS"  ]
    then {
case $parm in
    "Vendor")
    result=`grep -w "Vendor" /tmp/smartres.$disk | awk '{ print $2 }'` 
;;
    "Product")
    result=`grep -w "Product" /tmp/smartres.$disk | awk -F":" '{ print $2 }'` 
;;
    "Health")
    result=`grep -w "SMART Health Status" /tmp/smartres.$disk | awk '{ print $2 }'` 
;;
    "read")
    result=`grep -w "read:" /tmp/smartres.$disk | awk '{ print $8 }'` 
;;

esac
    }
    else {
case $parm in
    "Serial")
    result=`grep -w "Serial Number" /tmp/smartres.$disk | awk '{ print $3 }'` 
;;
    "Model")
    result=`grep -w "Device Model" /tmp/smartres.$disk | awk -F":" '{ print $2 }'` 
;;
    "ATAErrorCount")
    result=`grep -w "ATA Error Count" /tmp/smartres.$disk | awk '{ print $4 }'` 
;;
    *)
    result=`grep -w $parm /tmp/smartres.$disk | awk '{ print $10 }'` 
;;

esac
    }
fi
echo $result
#if  [ ! -z $result ]; then { echo $result;  }; else { "error "$disk;  } fi

}

FindFunc
if [ $1 = "create"  ]; then 
    {
CreateDisk 
} fi

SmartStart
ShowParm

exit 0