#!/sbin/busybox sh
set +x
_PATH="$PATH"
export PATH=/sbin

busybox cd /
busybox date >>boot.txt
exec >>boot.txt 2>&1
busybox rm /init

# include device specific vars
source /sbin/bootrec-device

# create directories
busybox mkdir -m 755 -p /dev/block
busybox mkdir -m 755 -p /dev/input
busybox mkdir -m 555 -p /proc
busybox mkdir -m 755 -p /sys

# create device nodes
busybox mknod -m 600 /dev/block/mmcblk0 b 179 0
busybox mknod -m 600 ${BOOTREC_EVENT_NODE}
busybox mknod -m 666 /dev/null c 1 3

# mount filesystems
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys

# trigger vibration
busybox echo 200 > /sys/class/timed_output/vibrator/enable

# trigger amber LED
busybox echo 0 > ${BOOTREC_LED_RED}
busybox echo 127 > ${BOOTREC_LED_GREEN}
busybox echo 255 > ${BOOTREC_LED_BLUE}

# keycheck
busybox cat ${BOOTREC_EVENT} > /dev/keycheck&
busybox sleep 3

# android ramdisk
load_image=/sbin/ramdisk.cpio

# boot decision
if [ -s /dev/keycheck ] || busybox grep -q warmboot=0x77665502 /proc/cmdline ; then
	busybox echo 'RECOVERY BOOT' >>boot.txt
	# orange led for recoveryboot
	busybox echo 255 > ${BOOTREC_LED_RED}
	busybox echo 0 > ${BOOTREC_LED_GREEN}
	busybox echo 255 > ${BOOTREC_LED_BLUE}
	# recovery ramdisk
	# default recovery ramdisk is CWM 
	load_image=/sbin/ramdisk-recovery-cwm.cpio
	if [ -s /dev/keycheck ]
	then
		busybox hexdump < /dev/keycheck > /dev/keycheck1

		export VOLUKEYCHECK=`busybox cat /dev/keycheck1 | busybox grep '0001 0073'`
		export VOLDKEYCHECK=`busybox cat /dev/keycheck1 | busybox grep '0001 0072'`

		busybox rm /dev/keycheck
		busybox rm /dev/keycheck1

		if [ -n "$VOLUKEYCHECK" ]
		then
			#load cwm ramdisk		
			load_image=/sbin/ramdisk-recovery-cwm.cpio
		fi

		if [ -n "$VOLDKEYCHECK" ]
		then
			#load twrp ramdisk
		   load_image=/sbin/ramdisk-recovery-twrp.cpio
		fi
	fi
	busybox mknod -m 600 ${BOOTREC_FOTA_NODE}
	busybox mount -o remount,rw /
	busybox ln -sf /sbin/busybox /sbin/sh
	extract_elf_ramdisk -i ${BOOTREC_FOTA} -o ${load_image} -t / -c
	busybox rm /sbin/sh
else
	busybox echo 'ANDROID BOOT' >>boot.txt
	# poweroff LED
	busybox echo 0 > ${BOOTREC_LED_RED}
	busybox echo 0 > ${BOOTREC_LED_GREEN}
	busybox echo 0 > ${BOOTREC_LED_BLUE}
fi

# kill the keycheck process
busybox pkill -f "busybox cat ${BOOTREC_EVENT}"

# unpack the ramdisk image
busybox cpio -i < ${load_image}

busybox umount /proc
busybox umount /sys

busybox rm -fr /dev/*
busybox date >>boot.txt
export PATH="${_PATH}"
exec /init
