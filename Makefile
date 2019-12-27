#***********************************************************************
#
#  Copyright (c) 2004  Broadcom Corporation
#  All Rights Reserved
#
#***********************************************************************/

# Top-level Makefile     

# Foxconn added start
ifndef PROFILE
export PROFILE=AX6000
endif
# Foxconn added start


BRCM_MAX_JOBS=1


ifndef FW_TYPE
FW_TYPE = WW
endif
export FW_TYPE

ifeq ($(PROFILE),AX11000)
BOARDID_FILE=compatible_ax11000.txt
FW_NAME=AX11000

CFLAGS += -DAX11000
endif

ifeq ($(PROFILE),AX6000)
BOARDID_FILE=compatible_ax6000.txt
FW_NAME=AX6000

CFLAGS += -DAX6000
endif

ifeq ($(PROFILE),R8000P)
BOARDID_FILE=compatible_r8000p.txt
FW_NAME=R8000P
endif


#
# Paths
#

CPU ?=
LINUX_VERSION ?= 4_1_27
MAKE_ARGS ?=
ARCH = arm64
PLT ?= arm64

# Get ARCH from PLT argument
ifneq ($(findstring arm,$(PLT)),)
ARCH := arm64
endif

# uClibc wrapper
ifeq ($(CONFIG_UCLIBC),y)
PLATFORM := $(PLT)-uclibc
else ifeq ($(CONFIG_GLIBC),y)
PLATFORM := $(PLT)-glibc
else
PLATFORM := $(PLT)
endif

export PATH := /opt/toolchains/crosstools-arm-gcc-5.5-linux-4.1-glibc-2.26-binutils-2.28.1/usr/bin/:/opt/toolchains/crosstools-aarch64-gcc-5.5-linux-4.1-glibc-2.26-binutils-2.28.1/usr/bin/::$(PATH)

# Source bases
export PLATFORM LIBDIR USRLIBDIR LINUX_VERSION
export BCM_KVERSIONSTRING := $(subst _,.,$(LINUX_VERSION))

#WLAN_ComponentsInUse := bcmwifi clm ppr olpc
#include ../makefiles/WLAN_Common.mk
#export SRCBASE := $(WLAN_SrcBaseA)
#export BASEDIR := $(WLAN_TreeBaseA)
export TOP := $(shell pwd)
export SRCBASE := $(TOP)/bcmdrivers/broadcom/net/wl/impl51/main/src
export BASEDIR := $(TOP)
export BUILDDIR:= $(TOP)

ifeq (4_1_27,$(LINUX_VERSION))
export 	LINUXDIR := $(TOP)/kernel/linux-4.1
export 	KBUILD_VERBOSE := 1
export	BUILD_MFG := 0
else ifeq (2_6_36,$(LINUX_VERSION))
export 	LINUXDIR := $(BASEDIR)/components/opensource/linux/linux-2.6.36
export 	KBUILD_VERBOSE := 1
export	BUILD_MFG := 0
# for now, only suitable for 2.6.36 router platform
SUBMAKE_SETTINGS = SRCBASE=$(SRCBASE) BASEDIR=$(BASEDIR)
else ifeq (2_6,$(LINUX_VERSION))
export 	LINUXDIR := $(SRCBASE)/linux/linux-2.6
export 	KBUILD_VERBOSE := 1
export	BUILD_MFG := 0
SUBMAKE_SETTINGS  = SRCBASE=$(SRCBASE)
else
export 	LINUXDIR := $(SRCBASE)/linux/linux
SUBMAKE_SETTINGS  = SRCBASE=$(SRCBASE)
endif


CFLAGS += -DREMOTE_SMB_CONF
CFLAGS += -DREMOTE_USER_CONF
CFLAGS += -DUSERSETUP_SUPPORT
CFLAGS += -DXAGENT_CLOUD_SUPPORT
ifeq ($(FW_TYPE),NA)
export CFLAGS += -DFW_VERSION_NA
endif


###########################################
#
# This is the most important target: make all
# This is the first target in the Makefile, so it is also the default target.
# All the other targets are later in this file.
#
############################################

all: acos_link mkenv prebuild_checks all_postcheck1

all_postcheck1: profile_saved_check sanity_check rdp_link \
     create_install pinmuxcheck kernelbuild modbuild \
     parallel_targets gdbserver nvram_3k_kernelbuild buildimage

# These post kernel top level targets can compile concurrently
parallel_targets:
	$(MAKE) -j $(ACTUAL_MAX_JOBS) __parallel_targets

__parallel_targets: trend_iqos userspace hosttools gpl

.PHONY: stress-ng
stress-ng:
	@make -C stress-ng stress-ng

mkenv:
	@echo "############### parallel build environment start ################";
	@echo  "brcm_max_jobs: "$(BRCM_MAX_JOBS)
	@echo  "actual_max_jobs: "$(ACTUAL_MAX_JOBS)
	@echo -n "hostname: "; hostname
	@echo -n "uname: "; uname -a
	@which nproc &> /dev/null && (echo -n "processors: "; nproc) || echo "nproc not available"
	@which vmstat &> /dev/null && vmstat -SM || echo "vmstat is not available"
	@which lscpu &> /dev/null && lscpu || echo "lscpu is not available"
	@echo "################ parallel build environment end ##################"

############################################################################
#
# A lot of the stuff in the original Makefile has been moved over
# to make.common.
#
############################################################################
BUILD_DIR = $(shell pwd)
include $(BUILD_DIR)/make.common


USERAPPS_DIR = $(BUILD_DIR)/userspace
export USERAPPS_DIR
ACOSTOPDIR=$(USERAPPS_DIR)/ap/acos
export ACOSTOPDIR
GPLTOPDIR=$(USERAPPS_DIR)/ap/gpl
export GPLTOPDIR

############################################################################
#
# Make info for voice
#
############################################################################
ifneq ($(strip $(BRCM_VOICE_SUPPORT)),)
export BRCM_VOICE_SUPPORT
BRCM_VOICE_INCLUDE_MAKE_TARGETS=1
include $(BUILD_DIR)/make.voice
endif

############################################################################
#
# Make info for RDP modules
#
############################################################################

rdp_link:
ifneq ($(strip $(RDP_PROJECT)),)
	$(MAKE) -C $(RDPSDK_DIR) PROJECT=$(RDP_PROJECT) rdp_link
endif


rdp_clean:
ifneq ($(strip $(RDP_PROJECT)),)
	$(MAKE) -C $(RDPSDK_DIR) PROJECT=$(RDP_PROJECT) clean
ifneq ($(strip $(RELEASE_BUILD)),)
	$(MAKE) -C $(RDPSDK_DIR) PROJECT=$(RDP_PROJECT) distclean
endif
endif


###########################################################################
#
# dsl, kernel defines
#
############################################################################
ifeq ($(strip $(BUILD_NOR_KERNEL_LZ4)),y)
KERNEL_COMPRESSION=lz4
else
KERNEL_COMPRESSION=lzma
endif 

ifeq ($(strip $(BRCM_KERNEL_KALLSYMS)),y) 
KERNEL_KALLSYMS=1
endif

#Set up ADSL standard
export ADSL=$(BRCM_ADSL_STANDARD)

#Set up ADSL_PHY_MODE  {file | obj}
export ADSL_PHY_MODE=file

#Set up ADSL_SELF_TEST
export ADSL_SELF_TEST=$(BRCM_ADSL_SELF_TEST)

#Set up ADSL_PLN_TEST
export ADSL_PLN_TEST=$(BUILD_TR69_XBRCM)

#WLIMPL command
ifneq ($(strip $(WLIMPL)),)
export WLIMPL

SVN_IMPL:=$(patsubst IMPL%,%,$(WLIMPL))
export SVN_IMPL
#SVNTAG command
ifneq ($(strip $(SVNTAG)),)
WL_BASE := $(BUILD_DIR)/bcmdrivers/broadcom/net/wl
SVNTAG_DIR := $(shell if [ -d $(WL_BASE)/$(SVNTAG)/src ]; then echo 1; else echo 0; fi)
ifeq ($(strip $(SVNTAG_DIR)),1)
$(shell ln -sf $(WL_BASE)/$(SVNTAG)/src $(WL_BASE)/impl$(SVN_IMPL))
else
$(error There is no directory $(WL_BASE)/$(SVNTAG)/src)
endif
endif

endif

ifneq ($(strip $(BRCM_DRIVER_WIRELESS_USBAP)),)
    WLBUS ?= "usbpci"
endif
#default WLBUS for wlan pci driver
WLBUS ?="pci"
export WLBUS                                                                              

#IMAGE_VERSION:=$(BRCM_VERSION)$(BRCM_RELEASE)$(shell echo $(BRCM_EXTRAVERSION) | sed -e "s/\(0\)\([1-9]\)/\2/")$(shell echo $(PROFILE) | sed -e "s/^[0-9]*//")$(shell date '+%j%H%M')

ifneq ($(IMAGE_VERSION_STRING),)
    IMAGE_VERSION:=$(IMAGE_VERSION_STRING)
else
    IMAGE_VERSION:=$(BRCM_VERSION)$(BRCM_RELEASE)$(shell echo $(BRCM_EXTRAVERSION) | sed -e "s/\(0\)\([1-9]\)/\2/")$(shell echo $(PROFILE) | sed -e "s/^[0-9]*//")$(shell date '+%j%H%M')
endif



############################################################################
#
# When there is a directory name with the same name as a Make target,
# make gets confused.  PHONY tells Make to ignore the directory when
# trying to make these targets.
#
############################################################################
.PHONY: userspace unittests data-model hostTools kernellinks kernelbuild pre_kernelbuild



############################################################################
#
# Other Targets. The default target is "all", defined at the top of the file.
#
############################################################################

#
# create a bcm_relversion.h which has our release version number, e.g.
# 4 10 02.  This allows device drivers which support multiple releases
# with a single driver image to test for version numbers.
#
BCM_SWVERSION_FILE := $(KERNEL_DIR)/include/linux/bcm_swversion.h
BCM_VERSION_LEVEL := $(strip $(BRCM_VERSION))
BCM_RELEASE_LEVEL := $(strip $(BRCM_RELEASE))
BCM_RELEASE_LEVEL := $(shell echo $(BCM_RELEASE_LEVEL) | sed -e 's/^0*//')
BCM_PATCH_LEVEL := $(strip $(shell echo $(BRCM_EXTRAVERSION) | cut -c1-2))
BCM_PATCH_LEVEL := $(shell echo $(BCM_PATCH_LEVEL) | sed -e 's/^0*//')

$(BCM_SWVERSION_FILE): $(BUILD_DIR)/$(VERSION_MAKE_FILE)
ifneq ($(RELEASE_BUILD),)
	@if egrep -q '^BRCM_(VERSION|RELEASE|EXTRAVERSION)=.*[^a-zA-Z0-9]' $(VERSION_MAKE_FILE) ; then \
		echo "error ... illegal character detected within version in $(VERSION_MAKE_FILE)" ; \
		exit 1 ; \
	fi
endif
	@echo "creating bcm release version header file"
	@echo "/* IGNORE_BCM_KF_EXCEPTION */" > $(BCM_SWVERSION_FILE)
	@echo "/* this file is automatically generated from top level Makefile */" >> $(BCM_SWVERSION_FILE)
	@echo "#ifndef __BCM_SWVERSION_H__" >> $(BCM_SWVERSION_FILE)
	@echo "#define __BCM_SWVERSION_H__" >> $(BCM_SWVERSION_FILE)
	@echo "#define BCM_REL_VERSION $(BCM_VERSION_LEVEL)" >> $(BCM_SWVERSION_FILE)
	@echo "#define BCM_REL_RELEASE $(BCM_RELEASE_LEVEL)" >> $(BCM_SWVERSION_FILE)
	@echo "#define BCM_REL_PATCH $(BCM_PATCH_LEVEL)" >> $(BCM_SWVERSION_FILE)
	@echo "#define BCM_SW_VERSIONCODE ($(BCM_VERSION_LEVEL)*65536+$(BCM_RELEASE_LEVEL)*256+$(BCM_PATCH_LEVEL))" >> $(BCM_SWVERSION_FILE)
	@echo "#define BCM_SW_VERSION(a,b,c) (((a) << 16) + ((b) << 8) + (c))" >> $(BCM_SWVERSION_FILE)
	@echo "#endif" >> $(BCM_SWVERSION_FILE)

BCM_KF_TXT_FILE := $(BUILD_DIR)/kernel/BcmKernelFeatures.txt
BCM_KF_KCONFIG_FILE := $(KERNEL_DIR)/Kconfig.bcm_kf
MAKEFNOTES_PL := $(HOSTTOOLS_DIR)/makefpatch/makefnotes.pl

havefeatures := $(wildcard $(BCM_KF_TXT_FILE))

ifneq ($(strip $(havefeatures)),)
$(BCM_KF_KCONFIG_FILE) : $(BCM_KF_TXT_FILE)
	perl $(MAKEFNOTES_PL) -kconfig -fl $(BCM_KF_TXT_FILE) > $(BCM_KF_KCONFIG_FILE)
endif

kernelbuild: rdp_link



trend_iqos:
	@echo "TREND IQOS STARTED"
	$(MAKE) -j $(ACTUAL_MAX_JOBS) -C  $(SRCBASE)/../components/vendor/trend/iqos
	$(MAKE) -j $(ACTUAL_MAX_JOBS) -C  $(SRCBASE)/../components/vendor/trend/iqos install
	@echo "TREND IQOS ENDED"


prepare_userspace: sanity_check create_install data-model $(BCM_SWVERSION_FILE) kernellinks 
#userspace: sanity_check create_install data-model $(BCM_SWVERSION_FILE) kernellinks hosttools gpl
.PHONY: prepare_userspace

userspace: prepare_userspace
	@echo "USERSPACE STARTED"
	$(MAKE) -j $(ACTUAL_MAX_JOBS) -C userspace
	@echo "USERSPACE ENDED"
	@echo "USERSPACE STARTED"
	$(MAKE) -j $(ACTUAL_MAX_JOBS) -C userspace
	@echo "USERSPACE ENDED"


acos_link:
ifneq ($(PROFILE),)
	cd $(USERAPPS_DIR)/project/acos/include; rm -f ambitCfg.h; ln -s ambitCfg_$(FW_TYPE)_$(PROFILE).h ambitCfg.h
ifeq ($(PROFILE),AX11000)	
	cd $(USERAPPS_DIR)/ap/acos/include; rm -f ambitCfg.h; ln -s $(USERAPPS_DIR)/project/acos/include/ambitCfg_$(FW_TYPE)_$(PROFILE).h ambitCfg.h
	cd $(LINUXDIR)/include/net ; rm -f MultiSsidControl.h ; ln -s $(USERAPPS_DIR)/ap/acos/multissidcontrol/MultiSsidControl.h MultiSsidControl.h
	cd $(LINUXDIR)/include/net ; rm -f AccessControl.h ; ln -s $(USERAPPS_DIR)/ap/acos/access_control/AccessControl.h AccessControl.h
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc ; rm -f resolv.conf ; ln -fs /tmp/resolv.conf $(TOP)/targets/$(PROFILE)/fs.install/etc/resolv.conf		
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/bmc ; ln -fs bcmmcastctl $(TOP)/targets/$(PROFILE)/fs.install/bin/bmc
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/bpm ; ln -fs bpmctl $(TOP)/targets/$(PROFILE)/fs.install/bin/bpm
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/fc  ; ln -fs fcctl $(TOP)/targets/$(PROFILE)/fs.install/bin/fc
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/mcp ; ln -fs mcpctl $(TOP)/targets/$(PROFILE)/fs.install/bin/mcp
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/pwr ; ln -fs pwrctl $(TOP)/targets/$(PROFILE)/fs.install/bin/pwr
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d ; rm -f S05hndmfg ; ln -fs ../init.d/hndmfg.sh $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d/S05hndmfg
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d ; rm -f S40hndnvram ; ln -fs ../init.d/hndnvram.sh $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d/S40hndnvram
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d ; rm -f S45swmdk ; ln -fs ../init.d/swmdk.sh $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d/S45swmdk
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d ; rm -f S63save-dmesg ; ln -fs ../init.d/save-dmesg.sh $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d/S63save-dmesg
	cd $(TOP)/targets/$(PROFILE)/fs.install/lib ; rm -f libvolume_id.so.0 ; ln -fs libvolume_id.so.0.78.0 $(TOP)/targets/$(PROFILE)/fs.install/lib/libvolume_id.so.0
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f acos_init ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/acos_init
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f acos_init_once ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/acos_init_once
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f api ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/api
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f autoconfig_wan_down ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/autoconfig_wan_down
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f autoconfig_wan_up ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/autoconfig_wan_up
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn5g2pass ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn5g2pass
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn5g2ssid ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn5g2ssid
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn5gpass ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn5gpass
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn5gssid ;  ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn5gssid
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnboardid ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnboardid
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burncode ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burncode
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burndisdefault ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burndisdefault
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burndisfctest ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burndisfctest
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnendefault ;ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnendefault
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnenfctest ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnenfctest
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnethermac ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnethermac
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn_hw_rev ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn_hw_rev
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnhwver ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnhwver
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnpass ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnpass
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnpin ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnpin
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnrf ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnrf
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnsku ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnsku
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnsn ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnsn
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnssid ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnssid
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f dhcp6c_down ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/dhcp6c_down
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f dhcp6c_up ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/dhcp6c_up
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f dlna ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/dlna
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f dumprf ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/dumprf
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f erase ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/erase
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ethctl ; ln -fs ../bin/ethctl $(TOP)/targets/$(PROFILE)/fs.install/sbin/ethctl
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f firewall ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/firewall
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f getchksum  ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/getchksum
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f getopenvpnsum ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/getopenvpnsum
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f hotplug ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/hotplug
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f init ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/init
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f internet ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/internet
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ipv6-conntab ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ipv6-conntab
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ipv6_drop_all_pkt ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ipv6_drop_all_pkt
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ipv6_enable_wan_ping_to_lan ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ipv6_enable_wan_ping_to_lan
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f landown ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/landown
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f lanstatus ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/lanstatus
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f lanup ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/lanup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ledamberup ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ledamberup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f leddown ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/leddown
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ledup ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ledup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ledwhiteup ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ledwhiteup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_isbad ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_isbad
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_markbad ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_markbad
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_read_oob ;ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_read_oob
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_write_oob ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_write_oob
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_write_page ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_write_page
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f nvconfig ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/nvconfig
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f preinit ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/preinit
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f read_bd ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/read_bd
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f reset_no_reboot ;ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/reset_no_reboot
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f restart_all_processes ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/restart_all_processes
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f restore_bin ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/restore_bin
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f routerinfo  ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/routerinfo
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f showconfig ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/showconfig
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f stats ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/stats
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f system ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/system
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f uptime ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/uptime
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f version ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/version
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f wanPhydown ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/wanPhydown
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f wanPhyup ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/wanPhyup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f write ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/write
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libjson-c.so ;ln -fs libjson-c.so.2.0.1 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libjson-c.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libjson-c.so.2 ;ln -fs libjson-c.so.2.0.1 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libjson-c.so.2
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libmnl.so ; ln -fs libmnl.so.0.1.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libmnl.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libmnl.so.0 ; ln -fs libmnl.so.0.1.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libmnl.so.0
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnetfilter_conntrack.so ; ln -fs libnetfilter_conntrack.so.3.4.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnetfilter_conntrack.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnetfilter_conntrack.so.3 ; ln -fs libnetfilter_conntrack.so.3.4.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnetfilter_conntrack.so.3
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnetfilter_queue.so ; ln -fs libnetfilter_queue.so.1.3.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnetfilter_queue.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnetfilter_queue.so.1 ; ln -fs libnetfilter_queue.so.1.3.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnetfilter_queue.so.1
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnfnetlink.so ; ln -fs libnfnetlink.so.0.2.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnfnetlink.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnfnetlink.so.0 ; ln -fs libnfnetlink.so.0.2.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnfnetlink.so.0
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libsqlite3.so.0 ; ln -fs libsqlite3.so.0.8.6 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libsqlite3.so.0
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libvolume_id.so ; ln -fs /udev/lib/libvolume_id.so.0.78.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libvolume_id.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libxml2.so ; ln -fs libxml2.so.2.9.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libxml2.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libxml2.so.2 ; ln -fs libxml2.so.2.9.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libxml2.so.2
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/local/samba/ ; rm -f lock ; ln -fs ../../../var/lock $(TOP)/targets/$(PROFILE)/fs.install/usr/local/samba/lock
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/local/samba/lib ; rm -f smb.conf ; ln -fs ../../../../tmp/samba/private/smb.conf $(TOP)/targets/$(PROFILE)/fs.install/usr/local/samba/lib/smb.conf
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f chkntfs ; ln -fs ufsd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/chkntfs
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f chkufsd ; ln -fs ufsd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/chkufsd
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f mkntfs ; ln -fs ufsd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/mkntfs
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f nvram ; ln -fs /bin/nvram $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/nvram
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f readycloud_unregister ; ln -fs remote_smb_conf $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/readycloud_unregister
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f remote_share_conf ; ln -fs remote_smb_conf $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/remote_share_conf
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f remote_user_conf ; ln -fs remote_smb_conf $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/remote_user_conf
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f wanled ; ln -fs heartbeat $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/wanled
endif	
else
	cd $(USERAPPS_DIR)/project/acos/include; rm -f ambitCfg.h; ln -s ambitCfg_$(FW_TYPE).h ambitCfg.h
endif

ifneq ($(PROFILE),)
	rm $(USERAPPS_DIR)/ap/acos/shared/rf_util.c; ln -s $(USERAPPS_DIR)/project/acos/shared/rf_util_$(PROFILE).c $(USERAPPS_DIR)/ap/acos/shared/rf_util.c
	#rm $(USERAPPS_DIR)/ap/acos/httpd/cgi/mnuCgi.c; ln -s $(USERAPPS_DIR)/project/acos/httpd/cgi/mnuCgi_$(PROFILE).c $(USERAPPS_DIR)/ap/acos/httpd/cgi/mnuCgi.c
	#rm $(USERAPPS_DIR)/ap/acos/www/start.htm; ln -s $(USERAPPS_DIR)/project/acos/www/start_$(PROFILE).htm $(USERAPPS_DIR)/ap/acos/www/start.htm
	#rm $(USERAPPS_DIR)/ap/acos/www/start.htm; ln -s $(USERAPPS_DIR)/project/acos/www/start_$(PROFILE)_noDownloader.htm $(USERAPPS_DIR)/ap/acos/www/start.htm
#TODO for IQOS	
#	ln -fs ../../../src/include/bcmIqosDef.h $(BASEDIR)/ap/acos/include/bcmIqosDef.h
	
	#cp $(USERAPPS_DIR)/project/acos/config_$(PROFILE).in $(USERAPPS_DIR)/project/acos/config.in
	#cp $(USERAPPS_DIR)/project/acos/config_$(PROFILE).mk $(USERAPPS_DIR)/project/acos/config.mk
	#cp $(USERAPPS_DIR)/project/acos/Makefile_$(PROFILE) $(USERAPPS_DIR)/project/acos/Makefile

	#rm -fr $(USERAPPS_DIR)/ap/acos/www/string_table
	#cp -r $(USERAPPS_DIR)/project/acos/strings/$(PROFILE) $(USERAPPS_DIR)/ap/acos/www/string_table

ifneq ($(strip $(BCA_HNDROUTER)),)
	#cp $(USERAPPS_DIR)/project/acos/usbprinter/NetUSB.ko $(USERAPPS_DIR)/ap/acos/usbprinter/NetUSB.ko
	#cp $(USERAPPS_DIR)/project/acos/usbprinter/GPL_NetUSB.ko $(USERAPPS_DIR)/ap/acos/usbprinter/GPL_NetUSB.ko
	#cp $(USERAPPS_DIR)/project/acos/usbprinter/KC_PRINT $(USERAPPS_DIR)/ap/acos/usbprinter/KC_PRINT
	#cp $(USERAPPS_DIR)/project/acos/usbprinter/KC_BONJOUR $(USERAPPS_DIR)/ap/acos/usbprinter/KC_BONJOUR
else
	#cp $(USERAPPS_DIR)/project/acos/usbprinter/NetUSB.ko $(USERAPPS_DIR)/ap/acos/usbprinter/NetUSB_$(PROFILE).ko
	#cp $(USERAPPS_DIR)/project/acos/usbprinter/GPL_NetUSB.ko $(USERAPPS_DIR)/ap/acos/usbprinter/GPL_NetUSB.ko
	#cp $(USERAPPS_DIR)/project/acos/usbprinter/KC_PRINT $(USERAPPS_DIR)/ap/acos/usbprinter/KC_PRINT_$(PROFILE)
	#cp $(USERAPPS_DIR)/project/acos/usbprinter/KC_BONJOUR $(USERAPPS_DIR)/ap/acos/usbprinter/KC_BONJOUR_$(PROFILE)
endif
	#cp $(USERAPPS_DIR)/project/acos/ufsd/ufsd.ko $(USERAPPS_DIR)/ap/acos/ufsd/ufsd.ko
	#cp $(USERAPPS_DIR)/project/acos/ufsd/jnl.ko $(USERAPPS_DIR)/ap/acos/ufsd/jnl.ko
	#cp $(USERAPPS_DIR)/project/acos/ufsd/ufsd $(USERAPPS_DIR)/ap/acos/ufsd/ufsd
	#cp $(USERAPPS_DIR)/project/acos/Ookla/ookla $(USERAPPS_DIR)/ap/acos/Ookla/ookla
	#cp $(LINUXDIR)/.config_$(PROFILE) $(LINUXDIR)/.config
#	cp $(USERAPPS_DIR)/ap/acos/access_control/Makefile_arm $(USERAPPS_DIR)/ap/acos/access_control/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/acos_nat/Makefile_arm $(USERAPPS_DIR)/ap/acos/acos_nat/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/acos_nat/acosnat.lds_arm $(USERAPPS_DIR)/ap/acos/acos_nat/acosnat.lds
#	cp $(USERAPPS_DIR)/ap/acos/acos_nat_cli/Makefile_arm $(USERAPPS_DIR)/ap/acos/acos_nat_cli/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/autoipd/Makefile_arm $(USERAPPS_DIR)/ap/acos/autoipd/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/bd/Makefile_arm $(USERAPPS_DIR)/ap/acos/bd/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/bpa_monitor/Makefile_arm $(USERAPPS_DIR)/ap/acos/bpa_monitor/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/br_dns_hijack/Makefile_arm $(USERAPPS_DIR)/ap/acos/br_dns_hijack/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/check_firmware/Makefile_arm $(USERAPPS_DIR)/ap/acos/check_firmware/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/ddns/Makefile_arm $(USERAPPS_DIR)/ap/acos/ddns/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/dlnad/Makefile_arm $(USERAPPS_DIR)/ap/acos/dlnad/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/dns_redirect/Makefile_arm $(USERAPPS_DIR)/ap/acos/dns_redirect/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/email/Makefile_arm $(USERAPPS_DIR)/ap/acos/email/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/ftpc/Makefile_arm $(USERAPPS_DIR)/ap/acos/ftpc/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/heartbeat/Makefile_arm $(USERAPPS_DIR)/ap/acos/heartbeat/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/httpd/Makefile_arm $(USERAPPS_DIR)/ap/acos/httpd/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/ipv6_spi/Makefile_arm $(USERAPPS_DIR)/ap/acos/ipv6_spi/Makefile
##	cp $(USERAPPS_DIR)/ap/acos/lltd/Makefile_arm $(USERAPPS_DIR)/ap/acos/lltd/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/mevent/Makefile_arm $(USERAPPS_DIR)/ap/acos/mevent/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/mld/Makefile_arm $(BASEDIR)/ap/acos/mld/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/multissidcontrol/Makefile_arm $(BASEDIR)/ap/acos/multissidcontrol/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/opendns/Makefile_arm $(BASEDIR)/ap/acos/opendns/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/output_image/Makefile_arm $(BASEDIR)/ap/acos/output_image/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/parser/Makefile_arm $(BASEDIR)/ap/acos/parser/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/pot/Makefile_arm $(BASEDIR)/ap/acos/pot/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/rc/Makefile_arm $(BASEDIR)/ap/acos/rc/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/rtsol/Makefile_arm $(BASEDIR)/ap/acos/rtsol/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/sche_action/Makefile_arm $(BASEDIR)/ap/acos/sche_action/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/shared/Makefile_arm $(BASEDIR)/ap/acos/shared/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/telnet_enable/Makefile_arm $(BASEDIR)/ap/acos/telnet_enable/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/timesync/Makefile_arm $(BASEDIR)/ap/acos/timesync/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/traffic_meter/Makefile_arm $(BASEDIR)/ap/acos/traffic_meter/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/traffic_meter2/Makefile_arm $(BASEDIR)/ap/acos/traffic_meter2/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/ubd/Makefile_arm $(BASEDIR)/ap/acos/ubd/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/ubdu/Makefile_arm $(BASEDIR)/ap/acos/ubdu/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/ubp/Makefile_arm $(BASEDIR)/ap/acos/ubp/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/upnp_sa/Makefile_arm $(BASEDIR)/ap/acos/upnp_sa/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/wan_debug/Makefile_arm $(BASEDIR)/ap/acos/wan_debug/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/wandetect/Makefile_arm $(BASEDIR)/ap/acos/wandetect/Makefile
#	cp $(USERAPPS_DIR)/ap/acos/wlanconfigd/Makefile_arm $(BASEDIR)/ap/acos/wlanconfigd/Makefile
##	cp $(USERAPPS_DIR)/ap/acos/www/Makefile_arm $(BASEDIR)/ap/acos/www/Makefile
##	cp $(USERAPPS_DIR)/ap/gpl/timemachine/Makefile_arm $(BASEDIR)/ap/gpl/timemachine/Makefile
#ifeq ($(CONFIG_CLOUD_XAGENT_CONF),y)
#	cp $(BASEDIR)/ap/gpl/curl/Makefile_arm $(BASEDIR)/ap/gpl/curl/Makefile
#else	
#	cp $(BASEDIR)/ap/gpl/curl-7.23.1/make_arm.sh $(BASEDIR)/ap/gpl/curl-7.23.1/make.sh
#	cp $(BASEDIR)/ap/gpl/curl-7.23.1/Makefile_arm $(BASEDIR)/ap/gpl/curl-7.23.1/Makefile
#endif	
#	cp $(BASEDIR)/ap/gpl/IGMP-PROXY/Makefile_arm $(BASEDIR)/ap/gpl/IGMP-PROXY/Makefile
#	cp $(BASEDIR)/ap/gpl/iproute2/lib/Makefile_arm $(BASEDIR)/ap/gpl/iproute2/lib/Makefile
#	cp $(BASEDIR)/ap/gpl/l2tpd-0.69/Makefile_arm $(BASEDIR)/ap/gpl/l2tpd-0.69/Makefile
#	cp $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/Makefile_arm $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/Makefile
#	cp $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/include/fuse-lite/Makefile_arm $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/include/fuse-lite/Makefile
#	cp $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/include/ntfs-3g/Makefile_arm $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/include/ntfs-3g/Makefile
#	cp $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/include/Makefile_arm $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/include/Makefile
#	cp $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/libfuse-lite/Makefile_arm $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/libfuse-lite/Makefile
#	cp $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/libntfs-3g/Makefile_arm $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/libntfs-3g/Makefile
#	cp $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/src/Makefile_arm $(BASEDIR)/ap/gpl/ntfs-3g-2009.3.8/src/Makefile
#	#cp $(BASEDIR)/ap/gpl/samba-3.0.13/Makefile_arm $(BASEDIR)/ap/gpl/samba-3.0.13/Makefile
#	cp $(BASEDIR)/ap/gpl/minidlna/Makefile_arm $(BASEDIR)/ap/gpl/minidlna/Makefile
ifeq ($(PROFILE),R8000)
	#cp -f $(BASEDIR)/ap/acos/www/UPNP_media_$(PROFILE).htm $(BASEDIR)/ap/acos/www/UPNP_media.htm 
endif
ifeq ($(PROFILE),AX11000)
	#cp -f $(USERAPPS_DIR)/ap/acos/www/UPNP_media_$(PROFILE).htm $(USERAPPS_DIR)/ap/acos/www/UPNP_media.htm 
# Preload string_table - Chinese, Italian, Germany, Dutch, Korea, French, Swedish
	#$(shell) $(USERAPPS_DIR)/project/acos/strings/gen_stringtable.sh $(USERAPPS_DIR)/project/acos/strings $(PROFILE)
	#cd $(TARGETS_DIR)/fs.src/etc; rm -f string_table*;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*Eng-Language-table $(TARGETS_DIR)/fs.src/etc/Eng_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*SP-Language-table $(TARGETS_DIR)/fs.src/etc/SP_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*PR-Language-table $(TARGETS_DIR)/fs.src/etc/PR_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*FR-Language-table $(TARGETS_DIR)/fs.src/etc/FR_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*GR-Language-table $(TARGETS_DIR)/fs.src/etc/GR_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*IT-Language-table $(TARGETS_DIR)/fs.src/etc/IT_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*NL-Language-table $(TARGETS_DIR)/fs.src/etc/NL_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*KO-Language-table $(TARGETS_DIR)/fs.src/etc/KO_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*SV-Language-table $(TARGETS_DIR)/fs.src/etc/SV_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*RU-Language-table $(TARGETS_DIR)/fs.src/etc/RU_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*PT-Language-table $(TARGETS_DIR)/fs.src/etc/PT_string_table;
	#cp -f $(USERAPPS_DIR)/project/acos/strings/$(PROFILE)-preload-stringtable/*JP-Language-table $(TARGETS_DIR)/fs.src/etc/JP_string_table;
endif	

else
	cp $(USERAPPS_DIR)/project/acos/config_WNR3500v2.in $(USERAPPS_DIR)/project/acos/config.in
	cp $(USERAPPS_DIR)/project/acos/config_WNR3500v2.mk $(USERAPPS_DIR)/project/acos/config.mk
	cp $(USERAPPS_DIR)/project/acos/Makefile_WNR3500v2 $(USERAPPS_DIR)/project/acos/Makefile
	cp $(LINUXDIR)/.config_WNR3500v2 $(LINUXDIR)/.config
	cp $(LINUXDIR)/autoconf.h_WNR3500v2 $(LINUXDIR)/include/linux/autoconf.h
endif
	
gpl: 
	$(MAKE) -C $(USERAPPS_DIR)/ap/gpl CROSS=$(CROSS_COMPILE) STRIPTOOL=$(STRIP)
	$(MAKE) -C $(USERAPPS_DIR)/ap/gpl CROSS=$(CROSS_COMPILE) STRIPTOOL=$(STRIP) INSTALLDIR=$(INSTALLDIR) install

gpl_install:
	$(MAKE) -C $(USERAPPS_DIR)/ap/gpl install

rc:
	$(MAKE) -C $(BUILDDIR)/bcmdrivers/broadcom/net/wl/impl51/main/src/router/rc
rc_clean:
	$(MAKE) -C $(BUILDDIR)/bcmdrivers/broadcom/net/wl/impl51/main/src/router/rc clean

%-all:
	[ ! -d $* ] || $(MAKE) -C $*
%-clean:
	[ ! -d $* ] || $(MAKE) -C $* clean
%-install:
	[ ! -d $* ] || $(MAKE) -C $* install

strip_binaries:
	find $(PROFILE_DIR)/fs.install -name ".svn" | xargs rm -rf	
	-$(STRIP) $(INSTALLDIR)/$(PROFILE_DIR)/fs.install/usr/lib/*.so*
	-$(STRIP) $(INSTALLDIR)/$(PROFILE_DIR)/fs.install/lib/*.so*
	-$(STRIP) $(INSTALLDIR)/$(PROFILE_DIR)/fs.install/lib/modules/4.1.27/extra/*.ko
	-$(STRIP) $(INSTALLDIR)/$(PROFILE_DIR)/fs.install/lib/*.so*
	
	
	

#
# Always run Make in the libcreduction directory.  In most non-voice configs,
# mklibs.py will be invoked to analyze user applications
# and libraries to eliminate unused functions thereby reducing image size.
# However, for voice configs, gdb server, oprofile and maybe some other
# special cases, the libcreduction makefile will just copy unstripped
# system libraries to fs.install for inclusion in the image.
#
libcreduction:
	$(MAKE) -C hostTools/libcreduction install



menuconfig:
	@cd $(INC_KERNEL_BASE); \
	$(MAKE) -C $(HOSTTOOLS_DIR)/scripts/lxdialog HOSTCC=gcc
	$(CONFIG_SHELL) $(HOSTTOOLS_DIR)/scripts/Menuconfig $(TARGETS_DIR)/config.in $(PROFILE)


#
# the userspace apps and libs make their own directories before
# they install, so they don't depend on this target to make the
# directory for them anymore.
#
create_install:
		mkdir -p $(PROFILE_DIR)/fs.install/etc
		mkdir -p $(INSTALL_DIR)/bin
		mkdir -p $(INSTALL_DIR)/lib
		mkdir -p $(INSTALL_DIR)/etc/snmp
		mkdir -p $(INSTALL_DIR)/etc/iproute2
		mkdir -p $(INSTALL_DIR)/opt/bin
		mkdir -p $(INSTALL_DIR)/opt/modules
		mkdir -p $(INSTALL_DIR)/opt/scripts


# By default, let make spawn 1 job per core.
# To set max jobs, specify on command line, BRCM_MAX_JOBS=8
# To also specify a max load, BRCM_MAX_JOBS="6 --max-load=3.0"
# To specify max load without max jobs, BRCM_MAX_JOBS=" --max-load=3.5"
ifneq ($(strip $(BRCM_MAX_JOBS)),)
ACTUAL_MAX_JOBS := $(BRCM_MAX_JOBS)
else
NUM_CORES := $(shell grep processor /proc/cpuinfo | wc -l)
ACTUAL_MAX_JOBS := $(NUM_CORES)
endif
# Since tms driver is called with -j1 and will call its sub-make with -j, 
# We want it to use this value. Although the jobserver is disabled for tms,
# at least tms is compiled with no more than this variable value jobs.
export ACTUAL_MAX_JOBS

kernellinks: $(KERNEL_INCLUDE_LINK) $(KERNEL_MIPS_INCLUDE_LINK) $(KERNEL_ARM_INCLUDE_LINK)

$(KERNEL_INCLUDE_LINK):
	ln -s -f $(KERNEL_DIR)/$(INC_DIR) $(KERNEL_INCLUDE_LINK);

$(KERNEL_MIPS_INCLUDE_LINK):
	ln -s -f $(KERNEL_DIR)/arch/mips/$(INC_DIR) $(KERNEL_MIPS_INCLUDE_LINK);

$(KERNEL_ARM_INCLUDE_LINK):
	ln -s -f $(KERNEL_DIR)/arch/arm/$(INC_DIR) $(KERNEL_ARM_INCLUDE_LINK);

define android_kernel_merge_cfg
cd $(KERNEL_DIR); \
ARCH=${ARCH} scripts/kconfig/merge_config.sh -m arch/$(ARCH)/defconfig android/configs/android-base.cfg android/configs/android-recommended.cfg android/configs/android-bcm-recommended.cfg ;
endef

.PHONY: bcmdrivers_autogen clean_bcmdrivers_autogen


BCMD_AG_MAKEFILE:=Makefile.autogen
BCMD_AG_KCONFIG:=Kconfig.autogen
BCMD_AG_MAKEFILE_TMP:=$(BCMD_AG_MAKEFILE).tmp
BCMD_AG_KCONFIG_TMP:=$(BCMD_AG_KCONFIG).tmp

bcmdrivers_autogen:
ifeq ($(PROFILE),AX11000)
	cp -rf $(BRCMDRIVERS_DIR)/broadcom/net/wl/impl51/sys/src/dongle/bin/43684b0/rtecdc_$(PROFILE).bin $(BRCMDRIVERS_DIR)/broadcom/net/wl/impl51/sys/src/dongle/bin/43684b0/rtecdc.bin 
endif
	@cd $(BRCMDRIVERS_DIR); echo -e "\n# Automatically generated file -- do not modify manually\n\n" > $(BCMD_AG_KCONFIG_TMP)
	@cd $(BRCMDRIVERS_DIR); echo -e "\n# Automatically generated file -- do not modify manually\n\n" > $(BCMD_AG_MAKEFILE_TMP)
	@cd $(BRCMDRIVERS_DIR); echo -e "\n\$$(info READING AG MAKEFILE)\n\n" >> $(BCMD_AG_MAKEFILE_TMP)
	@alldrivers=""; \
	 cd $(BRCMDRIVERS_DIR); \
	 for autodetect in $$(find * -type f -name autodetect); do \
		dir=$${autodetect%/*}; \
		driver=$$(grep -i "^DRIVER\|FEATURE:" $$autodetect | awk -F ': *' '{ print $$2 }'); \
		[ $$driver ] || driver=$${dir##*/}; \
		[ $$(echo $$driver | wc -w) -ne 1 ] && echo "Error parsing $$autodetect" >2 && exit 1; \
		echo "Processing $$driver ($$dir)"; \
		DRIVER=$$(echo "$${driver}" | tr '[:lower:]' '[:upper:]'); \
		echo "\$$(eval \$$(call LN_RULE_AG, CONFIG_BCM_$${DRIVER}, $$dir, \$$(LN_NAME)))" >> $(BCMD_AG_MAKEFILE_TMP); \
		if [ -e $$dir/Kconfig.autodetect ]; then \
			echo "menu \"$${DRIVER}\"" >> $(BCMD_AG_KCONFIG_TMP);\
			echo "source \"../../bcmdrivers/$$dir/Kconfig.autodetect\"" >> $(BCMD_AG_KCONFIG_TMP); \
			echo "endmenu " >> $(BCMD_AG_KCONFIG_TMP); \
			echo "" >> $(BCMD_AG_KCONFIG_TMP);\
		fi; \
		true; \
	 done; \
	 duplicates=$$(echo $$alldrivers | tr " " "\n" | sort | uniq -d | tr "\n" " "); echo $$duplicates; \
	 [ $V ] && echo "alldrivers: $$alldrivers" && echo "duplicates: $$duplicates" || true; \
	 if [ $$duplicates ]; then \
		echo "ERROR: duplicate drivers found in autodetect -- $$duplicates" >&2; \
		exit 1; \
	 fi
	@# only update the $(BCMD_AG_KCONFIG) and makefile.autogen files if they haven't changed (to prevent rebuilding):
	@cd $(BRCMDRIVERS_DIR); [ -e $(BCMD_AG_MAKEFILE) ] && cmp -s $(BCMD_AG_MAKEFILE) $(BCMD_AG_MAKEFILE_TMP) || mv $(BCMD_AG_MAKEFILE_TMP) $(BCMD_AG_MAKEFILE)
	@cd $(BRCMDRIVERS_DIR);[ -e $(BCMD_AG_KCONFIG) ] && cmp -s $(BCMD_AG_KCONFIG) $(BCMD_AG_KCONFIG_TMP) || mv $(BCMD_AG_KCONFIG_TMP) $(BCMD_AG_KCONFIG)
	@cd $(BRCMDRIVERS_DIR); rm -f $(BCMD_AG_MAKEFILE_TMP) $(BCMD_AG_KCONFIG_TMP)

clean: clean_bcmdrivers_autogen

clean_bcmdrivers_autogen:
	rm -f $(BRCMDRIVERS_DIR)/$(BCMD_AG_MAKEFILE_TMP) $(BRCMDRIVERS_DIR)/$(BCMD_AG_KCONFIG_TMP) $(BRCMDRIVERS_DIR)/$(BCMD_AG_MAKEFILE) $(BRCMDRIVERS_DIR)/$(BCMD_AG_KCONFIG)


.PHONY: bcmdrivers_autogen kernellinks

pre_kernelbuild: $(KERNEL_DIR)/.pre_kernelbuild;
	

$(KERNEL_DIR)/.pre_kernelbuild: $(BCM_SWVERSION_FILE) $(BCM_KF_KCONFIG_FILE) bcmdrivers_autogen kernellinks 
	@echo
	@echo -------------------------------------------
	@echo ... starting kernel build at $(KERNEL_DIR)
	@echo PROFILE_KERNEL_VER is $(PROFILE_KERNEL_VER)
	@cd $(INC_KERNEL_BASE); \
	if [ ! -e $(KERNEL_DIR)/.untar_complete ]; then \
		echo "Untarring original Linux kernel source: $(LINUX_ZIP_FILE)"; \
		(tar xkfpj $(LINUX_ZIP_FILE) 2> /dev/null || true); \
		touch $(KERNEL_DIR)/.untar_complete; \
	fi
	$(GENDEFCONFIG_CMD) $(PROFILE_PATH) ${MAKEFLAGS}
	cd $(KERNEL_DIR); \
	cp -f $(KERNEL_DIR)/arch/$(ARCH)/defconfig $(KERNEL_DIR)/.config;
	$(if $(strip $(BRCM_ANDROID)), $(call android_kernel_merge_cfg))
	cd $(KERNEL_DIR); \
	$(MAKE) oldnoconfig;
	touch $@;

kernelbuild:
	CURRENT_ARCH=$(KERNEL_ARCH) TOOLCHAIN_TOP= $(MAKE) inner_kernelbuild 

ifdef BCM_KF
inner_kernelbuild: pre_kernelbuild hnd_dongle
else
inner_kernelbuild: pre_kernelbuild
endif
	rm -rf $(BUILD_DIR)/targets/AX11000/fs.build/public/include/json
	$(MAKE) -C $(KERNEL_DIR)


ifeq ($(strip $(BRCM_CHIP)),63268)
ifneq ($(strip $(BUILD_SECURE_BOOT)),)
export BUILD_NVRAM_3K=n
nvram_3k_kernelbuild: 
	@mv $(KERNEL_DIR)/vmlinux $(KERNEL_DIR)/vmlinux.restore
	cd $(KERNEL_DIR); $(MAKE) nvram_3k -j $(ACTUAL_MAX_JOBS) BUILD_NVRAM_3K=y
nvram_3k_kernelclean:
	@rm -f $(KERNEL_DIR)/vmlinux_secureboot
	@rm -f $(KERNEL_DIR)/vmlinux.restore
else
nvram_3k_kernelbuild: 
	@echo "No 3k nvram build required... "
nvram_3k_kernelclean:
endif
else
nvram_3k_kernelbuild: 
	@echo "No 3k nvram build required... "
nvram_3k_kernelclean:
endif


kernel_config_test: pre_kernelbuild
	@echo
	@echo "Building $(DIR)/config_$(PROFILE)";
	-@mkdir $(DIR) 2> /dev/null || true
	sort $(KERNEL_DIR)/.config | grep -v "^\#.*$$" | grep -v "^[[:space:]]*$$" > $(DIR)/config_$(PROFILE)
	@echo "  ... done building $(DIR)/config_$(PROFILE)";

.PHONY: kernel_config_test

ifneq ($(findstring $(strip $(KERNEL_ARCH)),aarch64 arm mips mipsel),)
.PHONY:dtbs
dtbs:
	CURRENT_ARCH=$(KERNEL_ARCH) TOOLCHAIN_TOP= $(MAKE) inner_dtbs
inner_dtbs:bcmdrivers_autogen
	@echo "Build dts for chip $(BRCM_CHIP)... "
	$(call pre_kernelbuild)
	$(MAKE) -C $(KERNEL_DIR) boot=$(DTS_DIR)  dtbs
DTBS := dtbs

.PHONY:dtbs_clean
dtbs_clean:
	CURRENT_ARCH=$(KERNEL_ARCH) TOOLCHAIN_TOP= $(MAKE) inner_dtbs_clean
inner_dtbs_clean:
	@echo "Clean dts for chip $(BRCM_CHIP)... "
	$(MAKE) -C $(DTS_DIR)/dts/$(BRCM_CHIP) dtbs_clean 
DTBS_CLEAN := dtbs_clean
else
DTBS := 
DTBS_CLEAN :=
endif


kernel: sanity_check create_install kernelbuild hosttools buildimage

modbuild:
	CURRENT_ARCH=$(KERNEL_ARCH) TOOLCHAIN_TOP= $(MAKE) inner_modbuild

inner_modbuild:
	@echo "******************** Starting modbuild ********************";
	cd $(KERNEL_DIR); $(MAKE) -j $(ACTUAL_MAX_JOBS) modules && $(MAKE) modules_install
	@echo "******************** DONE modbuild ********************";

mocamodbuild:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_MOCACFGDRV_PATH) modules 
mocamodclean:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_MOCACFGDRV_PATH) clean

adslmodbuild:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_ADSLDRV_PATH) modules 
adslmodbuildclean:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_ADSLDRV_PATH) clean

spumodbuild:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_SPUDRV_PATH) modules
spumodbuildclean:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_SPUDRV_PATH) clean

pwrmngtmodbuild:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_PWRMNGTDRV_PATH) modules
pwrmngtmodclean:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_PWRMNGTDRV_PATH) clean

enetmodbuild:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_ENETDRV_PATH) modules
enetmodclean:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_ENETDRV_PATH) clean

eponmodbuild:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_EPONDRV_PATH) modules
eponmodclean:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_EPONDRV_PATH) clean

gponmodbuild:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_GPON_PATH) modules
gponmodclean:
	cd $(KERNEL_DIR); $(MAKE) M=$(INC_GPON_PATH) clean

modules: sanity_check create_install modbuild hosttools buildimage

adslmodule: adslmodbuild
adslmoduleclean: adslmodbuildclean

spumodule: spumodbuild
spumoduleclean: spumodbuildclean

pwrmngtmodule: pwrmngtmodbuild
pwrmngtmoduleclean: pwrmngtmodclean

CMS2BBF_APP := cms2bbf
CMS2BBF_DIR := $(HOSTTOOLS_DIR)/$(CMS2BBF_APP)

cms2bbf_build:
ifneq ($(strip $(BUILD_PROFILE_SUPPORTED_DATA_MODEL)),)
ifneq ($(wildcard $(CMS2BBF_DIR)/Makefile),)
	$(MAKE) -C hostTools build_cms2bbf
else
	@echo "Skip $(CMS2BBF_APP) (sources not found)"
endif
else
	@echo "Skip $(CMS2BBF_APP) (not configured)"
endif

data-model:  cms2bbf_build
ifeq ($(strip $(BCA_HNDROUTER)),)
	$(MAKE) -C data-model
else
	# skip for HND router builds
	@true
endif

unittests:
	$(MAKE) -C unittests

unittests_run:
	$(MAKE) -C unittests unittests_run

doxygen_build:
	$(MAKE) -C hostTools build_doxygen

doxygen_docs: doxygen_build
	rm -rf $(BUILD_DIR)/docs/doxygen;
	mkdir $(BUILD_DIR)/docs/doxygen;
	cd hostTools/doxygen/bin; ./doxygen

doxygen_clean:
	-$(MAKE) -C hostTools clean_doxygen



############################################################################
#
# Build user applications depending on if they are
# specified in the profile.  Most of these BUILD_ checks should eventually get
# moved down to the userspace directory.
#
############################################################################

ifneq ($(strip $(BUILD_VCONFIG)),)
export BUILD_VCONFIG=y
endif


ifneq ($(strip $(BUILD_GDBSERVER)),)
gdbserver:
	install -m 755 $(TOOLCHAIN_TOP)/usr/$(TOOLCHAIN_PREFIX)/target_utils/gdbserver $(INSTALL_DIR)/bin
else
gdbserver:
endif

ifneq ($(strip $(BUILD_ETHWAN)),)
export BUILD_ETHWAN=y
endif

ifneq ($(strip $(BUILD_SNMP)),)

ifneq ($(strip $(BUILD_SNMP_SET)),)
export SNMP_SET=1
else
export SNMP_SET=0
endif

ifneq ($(strip $(BUILD_SNMP_ADSL_MIB)),)
export SNMP_ADSL_MIB=1
else
export SNMP_ADSL_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_ATM_MIB)),)
export SNMP_ATM_MIB=1
else
export SNMP_ATM_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_BRIDGE_MIB)),)
export SNMP_BRIDGE_MIB=1
else
export SNMP_BRIDGE_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_AT_MIB)),)
export SNMP_AT_MIB=1
else
export SNMP_AT_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_SYSOR_MIB)),)
export SNMP_SYSOR_MIB=1
else
export SNMP_SYSOR_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_TCP_MIB)),)
export SNMP_TCP_MIB=1
else
export SNMP_TCP_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_UDP_MIB)),)
export SNMP_UDP_MIB=1
else
export SNMP_UDP_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_IP_MIB)),)
export SNMP_IP_MIB=1
else
export SNMP_IP_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_ICMP_MIB)),)
export SNMP_ICMP_MIB=1
else
export SNMP_ICMP_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_SNMP_MIB)),)
export SNMP_SNMP_MIB=1
else
export SNMP_SNMP_MIB=0
endif

ifneq ($(strip $(BUILD_SNMP_ATMFORUM_MIB)),)
export SNMP_ATMFORUM_MIB=1
else
export SNMP_ATMFORUM_MIB=0
endif


ifneq ($(strip $(BUILD_SNMP_CHINA_TELECOM_CPE_MIB)),)
export BUILD_SNMP_CHINA_TELECOM_CPE_MIB=y
endif

ifneq ($(strip $(BUILD_CT_1_39_OPEN)),)
export BUILD_CT_1_39_OPEN=y
endif

ifneq ($(strip $(BUILD_SNMP_CHINA_TELECOM_CPE_MIB_V2)),)
export BUILD_SNMP_CHINA_TELECOM_CPE_MIB_V2=y
endif

ifneq ($(strip $(BUILD_SNMP_BRCM_CPE_MIB)),)
export BUILD_SNMP_BRCM_CPE_MIB=y
endif

ifneq ($(strip $(BUILD_SNMP_UDP)),)
export BUILD_SNMP_UDP=y
endif

ifneq ($(strip $(BUILD_SNMP_EOC)),)
export BUILD_SNMP_EOC=y
endif

ifneq ($(strip $(BUILD_SNMP_AAL5)),)
export BUILD_SNMP_AAL5=y
endif

ifneq ($(strip $(BUILD_SNMP_AUTO)),)
export BUILD_SNMP_AUTO=y
endif

ifneq ($(strip $(BUILD_SNMP_DEBUG)),)
export BUILD_SNMP_DEBUG=y
endif

ifneq ($(strip $(BUILD_SNMP_TRANSPORT_DEBUG)),)
export BUILD_SNMP_TRANSPORT_DEBUG=y
endif

ifneq ($(strip $(BUILD_SNMP_LAYER_DEBUG)),)
export BUILD_SNMP_LAYER_DEBUG=y
endif

endif

ifneq ($(strip $(BUILD_4_LEVEL_QOS)),)
export BUILD_4_LEVEL_QOS=y
endif

ifneq ($(strip $(BCA_HNDROUTER)),)
hnd_dongle: version_info
ifneq ($(strip $(BUILD_HND_NIC)),)
	$(MAKE) -j $(ACTUAL_MAX_JOBS) -C $(BRCMDRIVERS_DIR)/broadcom/net/wl/bcm9$(BRCM_CHIP) version
else 
	$(MAKE) -j $(ACTUAL_MAX_JOBS) -C $(BRCMDRIVERS_DIR)/broadcom/net/wl/bcm9$(BRCM_CHIP) pciefd
endif
else
hnd_dongle:
	@true
endif

# Leave it for the future when soap server is decoupled from cfm
ifneq ($(strip $(BUILD_SOAP)),)
ifeq ($(strip $(BUILD_SOAP_VER)),2)
soapserver:
	$(MAKE) -C $(BROADCOM_DIR)/SoapToolkit/SoapServer $(BUILD_SOAP)
else
soap:
	$(MAKE) -C $(BROADCOM_DIR)/soap $(BUILD_SOAP)
endif
else
soap:
endif



ifneq ($(strip $(BUILD_DIAGAPP)),)
diagapp:
	$(MAKE) -C $(BROADCOM_DIR)/diagapp $(BUILD_DIAGAPP)
else
diagapp:
endif



ifneq ($(strip $(BUILD_IPPD)),)
ippd:
	$(MAKE) -C $(BROADCOM_DIR)/ippd $(BUILD_IPPD)
else
ippd:
endif


ifneq ($(strip $(BUILD_PORT_MIRRORING)),)
export BUILD_PORT_MIRRORING=1
else
export BUILD_PORT_MIRRORING=0
endif

ifeq ($(BRCM_USE_SUDO_IFNOT_ROOT),y)
BRCM_BUILD_USR=$(shell whoami)
BRCM_BUILD_USR1=$(shell sudo touch foo;ls -l foo | awk '{print $$3}';sudo rm -rf foo)
else
BRCM_BUILD_USR=root
endif

hosttools:
ifndef NO_HOSTTOOLS_PARALLEL
	$(MAKE) -j $(ACTUAL_MAX_JOBS) -C $(HOSTTOOLS_DIR)
else
	$(MAKE) -C $(HOSTTOOLS_DIR)
endif

hosttools_nandcfe:
	$(MAKE) -C $(HOSTTOOLS_DIR) perlmods mkjffs2 build_imageutil build_cmplzma build_secbtutils build_mtdutils


############################################################################
#
# IKOS defines
#
############################################################################

CMS_VERSION_FILE=$(BUILD_DIR)/userspace/public/include/version.h

ifeq ($(strip $(BRCM_IKOS)),y)
FS_COMPRESSION=-noD -noI -no-fragments
else
FS_COMPRESSION=
endif

export BRCM_IKOS FS_COMPRESSION



# IKOS Emulator build that does not include the CFE boot loader.
# Edit targets/ikos/ikos and change the chip and board id to desired values.
# Then build: make PROFILE=ikos ikos
ikos:
	@echo -e '#define SOFTWARE_VERSION ""\n#define RELEASE_VERSION ""\n#define PSI_VERSION ""\n' > $(CMS_VERSION_FILE)
	@-mv -f $(FSSRC_DIR)/etc/profile $(FSSRC_DIR)/etc/profile.dontuse >& /dev/null
	@-mv -f $(FSSRC_DIR)/etc/init.d $(FSSRC_DIR)/etc/init.dontuse >& /dev/null
	@-mv -f $(FSSRC_DIR)/etc/inittab $(FSSRC_DIR)/etc/inittab.dontuse >& /dev/null
	@sed -e 's/^::respawn.*sh.*/::respawn:-\/bin\/sh/' $(FSSRC_DIR)/etc/inittab.dontuse > $(FSSRC_DIR)/etc/inittab
	@if [ ! -a $(CFE_FILE) ] ; then echo "no cfe" > $(CFE_FILE); echo "no cfe" > $(CFE_FILE).del; fi
	@-rm $(HOSTTOOLS_DIR)/bcmImageBuilder >& /dev/null
	$(MAKE) PROFILE=$(PROFILE)
	@-rm $(HOSTTOOLS_DIR)/bcmImageBuilder >& /dev/null
	@mv -f $(FSSRC_DIR)/etc/profile.dontuse $(FSSRC_DIR)/etc/profile
	@-mv -f $(FSSRC_DIR)/etc/init.dontuse $(FSSRC_DIR)/etc/init.d >& /dev/null
	@-mv -f $(FSSRC_DIR)/etc/inittab.dontuse $(FSSRC_DIR)/etc/inittab >& /dev/null
	@cd $(PROFILE_DIR); \
	$(KOBJCOPY) --output-target=srec vmlinux vmlinux.srec; \
	xxd $(FS_KERNEL_IMAGE_NAME) | grep "^00000..:" | xxd -r > bcmtag.bin; \
	$(KOBJCOPY) --output-target=srec --input-target=binary --change-addresses=0xb8010000 bcmtag.bin bcmtag.srec; \
	$(KOBJCOPY) --output-target=srec --input-target=binary --change-addresses=0xb8010100 rootfs.img rootfs.srec; \
	rm bcmtag.bin; \
	grep -v "^S7" vmlinux.srec > bcm9$(BRCM_CHIP)_$(PROFILE).srec; \
	grep "^S3" bcmtag.srec >> bcm9$(BRCM_CHIP)_$(PROFILE).srec; \
	grep -v "^S0" rootfs.srec >> bcm9$(BRCM_CHIP)_$(PROFILE).srec
	@if [ ! -a $(CFE_FILE).del ] ; then rm -f $(CFE_FILE) $(CFE_FILE).del; fi
	@echo -e "\nAn image without CFE for the IKOS emulator has been built.  It is named"
	@echo -e "targets/$(PROFILE)/bcm9$(BRCM_CHIP)_$(PROFILE).srec\n"

# IKOS Emulator build that includes the CFE boot loader.
# Both Linux and CFE boot loader toolchains need to be installed.
# Edit targets/ikos/ikos and change the chip and board id to desired values.
# Then build: make PROFILE=ikos ikoscfe
ikoscfe:
	@echo -e '#define SOFTWARE_VERSION ""\n#define RELEASE_VERSION ""\n#define PSI_VERSION ""\n' > $(CMS_VERSION_FILE)
	@-mv -f $(FSSRC_DIR)/etc/profile $(FSSRC_DIR)/etc/profile.dontuse >& /dev/null
	$(MAKE) PROFILE=$(PROFILE)
	@mv -f $(FSSRC_DIR)/etc/profile.dontuse $(FSSRC_DIR)/etc/profile
	$(MAKE) -C $(BL_BUILD_DIR) clean
	$(MAKE) -C $(BL_BUILD_DIR)
	$(MAKE) -C $(BL_BUILD_DIR) ikos_finish
	cd $(PROFILE_DIR); \
	echo -n "** no kernel  **" > kernelfile; \
	$(HOSTTOOLS_DIR)/bcmImageBuilder $(BRCM_ENDIAN_FLAGS) --output $(CFE_FS_KERNEL_IMAGE_NAME) --chip $(BRCM_CHIP) --board $(BRCM_BOARD_ID) --blocksize $(BRCM_FLASHBLK_SIZE) --cfefile $(BL_BUILD_DIR)/cfe$(BRCM_CHIP).bin --rootfsfile rootfs.img --kernelfile kernelfile --dtbfile $(DTB_FILE) --include-cfe; \
	$(HOSTTOOLS_DIR)/createimg.pl --set boardid=$(BRCM_BOARD_ID) voiceboardid=$(BRCM_VOICE_BOARD_ID) numbermac=$(BRCM_NUM_MAC_ADDRESSES) macaddr=$(BRCM_BASE_MAC_ADDRESS) tp=$(BRCM_MAIN_TP_NUM) psisize=$(BRCM_PSI_SIZE) --inputfile=$(CFE_FS_KERNEL_IMAGE_NAME) --outputfile=$(FLASH_IMAGE_NAME) --nvramfile $(HOSTTOOLS_DIR)/nvram.h --nvramdefsfile $(HOSTTOOLS_DIR)/nvram_defaults.h --config=$(HOSTTOOLS_DIR)/local_install/conf/$(TOOLCHAIN_PREFIX).conf;\
	$(HOSTTOOLS_DIR)/addvtoken --endian $(ARCH_ENDIAN) $(FLASH_IMAGE_NAME) $(FLASH_IMAGE_NAME).w; \
	$(KOBJCOPY) --output-target=srec --input-target=binary --change-addresses=0xb8000000 $(FLASH_IMAGE_NAME).w $(FLASH_IMAGE_NAME).srec; \
	$(KOBJCOPY) --output-target=srec vmlinux vmlinux.srec; \
	@rm kernelfile; \
	grep -v "^S7" vmlinux.srec > bcm9$(BRCM_CHIP)_$(PROFILE).srec; \
	grep "^S3" $(BL_BUILD_DIR)/cferam$(BRCM_CHIP).srec >> bcm9$(BRCM_CHIP)_$(PROFILE).srec; \
	grep -v "^S0" $(FLASH_IMAGE_NAME).srec >> bcm9$(BRCM_CHIP)_$(PROFILE).srec; \
	grep -v "^S7" vmlinux.srec > bcm9$(BRCM_CHIP)_$(PROFILE).utram.srec; \
	grep -v "^S0" $(BL_BUILD_DIR)/cferam$(BRCM_CHIP).srec >> bcm9$(BRCM_CHIP)_$(PROFILE).utram.srec;
	@echo -e "\nAn image with CFE for the IKOS emulator has been built.  It is named"
	@echo -e "targets/$(PROFILE)/bcm9$(BRCM_CHIP)_$(PROFILE).srec"
	@echo -e "\nBefore testing with the IKOS emulator, this build can be unit tested"
	@echo -e "with an existing chip and board as follows."
	@echo -e "1. Flash targets/$(PROFILE)/$(FLASH_IMAGE_NAME).w onto an existing board."
	@echo -e "2. Start the EPI EDB debugger.  At the edbice prompt, enter:"
	@echo -e "   edbice> fr m targets/$(PROFILE)/bcm9$(BRCM_CHIP)_$(PROFILE).utram.srec"
	@echo -e "   edbice> r"
	@echo -e "3. Program execution will start at 0xb8000000 (or 0xbfc00000) and,"
	@echo -e "   if successful, will enter the Linux shell.\n"


############################################################################
#
# Generate the credits
#
############################################################################
gen_credits:
	cd $(RELEASE_DIR); \
	if [ -e gen_credits.pl ]; then \
	  perl gen_credits.pl; \
	fi

c:
	echo $(PRE_CFE_ROM)

############################################################################
#
# PinMuxCheck
#
############################################################################
pinmuxcheck:
ifeq ($(wildcard $(HOSTTOOLS_DIR)/PinMuxCheck/Makefile),)
	@echo "No PinMuxCheck needed"
else
	cd $(HOSTTOOLS_DIR); $(MAKE) build_pinmuxcheck;
endif


############################################################################
#
# This is where we build the image
#
############################################################################

execstack_exec=$(shell which execstack)
buildimage: kernelbuild $(DTBS) libcreduction gen_credits strip_binaries
ifneq ($(strip $(BRCM_PERMIT_STDCPP)),)
	@if ls $(PROFILE_DIR)/fs.install/lib/libstdc* 2> /dev/null ; then  \
		echo -e "libstdc++ must be replaced with STLPORT";         \
		echo -e "override with BRCM_PERMIT_STDCPP=1 if ok";         \
		false;                                                     \
	fi
endif
ifeq ($(BUILD_DISABLE_EXEC_STACK),y)
ifneq ($(execstack_exec),)
	@echo no need to build execstack $(execstack_exec)
else
	make -C $(HOSTTOOLS_DIR) build_execstack;
endif
endif
	cd $(TARGETS_DIR); ./buildFS;
ifeq ($(strip $(BRCM_RAMDISK_BOOT_EN)),y)
	cd $(TARGETS_DIR); $(HOSTTOOLS_DIR)/local_install/fakeroot -l $(HOSTTOOLS_DIR)/local_install/lib/libfakeroot.so -f $(HOSTTOOLS_DIR)/local_install/faked ./buildFS_RD
endif
	cd $(TARGETS_DIR); $(HOSTTOOLS_DIR)/local_install/fakeroot -l $(HOSTTOOLS_DIR)/local_install/lib/libfakeroot.so -f $(HOSTTOOLS_DIR)/local_install/faked ./buildFS2

	@mkdir -p $(IMAGES_DIR)

ifeq ($(strip $(BRCM_KERNEL_ROOTFS)),all)
# NAND UBI and JFFS2
#
ifeq ($(strip $(BTRM_BOOT_ONLY)),y)
	@echo -e "No XIP to flash capability. Bootrom boot only. Build unsecure bootrom boot"

ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_16KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --ubifs --bootfs bootfs16kb.img --rootfs ubi_rootfs16kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_16)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_16)_ubi --unsecurehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --squbifs --bootfs bootfs16kb.img --rootfs squbi_rootfs16kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_16)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_16)_squbi --unsecurehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_128KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --ubifs --bootfs bootfs128kb.img --rootfs ubi_rootfs128kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_ubi --unsecurehdr $(PRE_CFE_ROM)
# w/wo CFEROM + UBI CFERAM + UBI VMLINUX + UBIFS
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --rootfs ubi_rootfs128kb_pureubi.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_pureubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_pureubi --ubionlyimage --unsecurehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --rootfs squbi_rootfs128kb_pureubi.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_puresqubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_puresqubi --ubionlyimage --unsecurehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --squbifs --bootfs bootfs128kb.img --rootfs squbi_rootfs128kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_squbi --unsecurehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_256KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB)  --ubifs --bootfs bootfs256kb.img --rootfs ubi_rootfs256kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_256)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_256)_ubi --unsecurehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB)  --squbifs --bootfs bootfs256kb.img --rootfs squbi_rootfs256kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_256)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_256)_squbi --unsecurehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_512KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB)   --ubifs --bootfs bootfs512kb.img --rootfs ubi_rootfs512kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_512)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_512)_ubi --unsecurehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB)   --squbifs --bootfs bootfs512kb.img --rootfs squbi_rootfs512kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_512)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_512)_squbi --unsecurehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_1024KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB)   --ubifs --bootfs bootfs1024kb.img --rootfs ubi_rootfs1024kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_1024)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_1024)_ubi --unsecurehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB)   --squbifs --bootfs bootfs1024kb.img --rootfs squbi_rootfs1024kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_1024)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_1024)_squbi --unsecurehdr $(PRE_CFE_ROM)
endif

else

ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_16KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --ubifs --bootfs bootfs16kb.img --rootfs ubi_rootfs16kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_16)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_16)_ubi $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --squbifs --bootfs bootfs16kb.img --rootfs squbi_rootfs16kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_16)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_16)_squbi $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_128KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --ubifs --bootfs bootfs128kb.img --rootfs ubi_rootfs128kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_ubi $(PRE_CFE_ROM)
#	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --squbifs --bootfs bootfs128kb.img --rootfs squbi_rootfs128kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_squbi $(PRE_CFE_ROM)

# w/wo CFEROM + JFFS2 CFERAM + UBI CFERAM + UBI VMLINUX + UBIFS
#	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --ubifs --bootfs bootfs128kb.img --rootfs ubi_rootfs128kb_pureubi.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_CFEROM+JFFS2_CFERAM+UBI_CFERAM+UBI_VMLINUX+UBIFS_128 --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_no_CFEROM+JFFS2_CFERAM+UBI_CFERAM+UBI_VMLINUX+UBIFS_128 --ubionlyimage $(PRE_CFE_ROM)

# w/wo CFEROM + UBI CFERAM + UBI VMLINUX + UBIFS
#	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --rootfs ubi_rootfs128kb_pureubi.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_pureubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_pureubi --ubionlyimage $(PRE_CFE_ROM)

#	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --rootfs squbi_rootfs128kb_pureubi.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_puresqubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_puresqubi --ubionlyimage $(PRE_CFE_ROM)

endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_256KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB)  --ubifs --bootfs bootfs256kb.img --rootfs ubi_rootfs256kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_256)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_256)_ubi $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB)  --squbifs --bootfs bootfs256kb.img --rootfs squbi_rootfs256kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_256)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_256)_squbi $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_512KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB)   --ubifs --bootfs bootfs512kb.img --rootfs ubi_rootfs512kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_512)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_512)_ubi $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB)   --squbifs --bootfs bootfs512kb.img --rootfs squbi_rootfs512kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_512)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_512)_squbi $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_1024KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB)   --ubifs --bootfs bootfs1024kb.img --rootfs ubi_rootfs1024kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_1024)_ubi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_1024)_ubi $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB)   --squbifs --bootfs bootfs1024kb.img --rootfs squbi_rootfs1024kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_1024)_squbi --fsonly $(FLASH_NAND_FS_IMAGE_NAME_1024)_squbi $(PRE_CFE_ROM)
endif

endif


ifeq ($(strip $(BUILD_SECURE_BOOT)),y)
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_16KB)),y)
ifeq ($(strip $(BRCM_CHIP)),63268)
        # NOTE: 63268 small page nand bootsize is 128KB on purpose (ie $(FLASH_NAND_BLOCK_128KB)).  do not change
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB) --ubifs --bootfs bootfs16kb_secureboot.img --rootfs ubi_rootfs16kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_16)_ubi_secureboot --fsonly $(FLASH_NAND_FS_IMAGE_NAME_16)_ubi_secureboot --securehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB) --squbifs --bootfs bootfs16kb_secureboot.img --rootfs squbi_rootfs16kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_16)_squbi_secureboot --mirroredcfe --fsonly $(FLASH_NAND_FS_IMAGE_NAME_16)_squbi_secureboot --securehdr $(PRE_CFE_ROM)
else
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --ubifs --bootfs bootfs16kb_secureboot.img --rootfs ubi_rootfs16kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_16)_ubi_secureboot --fsonly $(FLASH_NAND_FS_IMAGE_NAME_16)_ubi_secureboot --securehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --squbifs --bootfs bootfs16kb_secureboot.img --rootfs squbi_rootfs16kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_16)_squbi_secureboot --mirroredcfe --fsonly $(FLASH_NAND_FS_IMAGE_NAME_16)_squbi_secureboot --securehdr $(PRE_CFE_ROM)
endif
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_128KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB) --ubifs --bootfs bootfs128kb_secureboot.img --rootfs ubi_rootfs128kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_ubi_secureboot --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_ubi_secureboot --securehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB) --squbifs --bootfs bootfs128kb_secureboot.img --rootfs squbi_rootfs128kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_128)_squbi_secureboot --mirroredcfe --fsonly $(FLASH_NAND_FS_IMAGE_NAME_128)_squbi_secureboot --securehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_256KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB) --ubifs --bootfs bootfs256kb_secureboot.img --rootfs ubi_rootfs256kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_256)_ubi_secureboot --fsonly $(FLASH_NAND_FS_IMAGE_NAME_256)_ubi_secureboot --securehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB) --squbifs --bootfs bootfs256kb_secureboot.img --rootfs squbi_rootfs256kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_256)_squbi_secureboot --mirroredcfe --fsonly $(FLASH_NAND_FS_IMAGE_NAME_256)_squbi_secureboot --securehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_512KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB) --ubifs --bootfs bootfs512kb_secureboot.img --rootfs ubi_rootfs512kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_512)_ubi_secureboot --fsonly $(FLASH_NAND_FS_IMAGE_NAME_512)_ubi_secureboot --securehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB) --squbifs --bootfs bootfs512kb_secureboot.img --rootfs squbi_rootfs512kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_512)_squbi_secureboot --mirroredcfe --fsonly $(FLASH_NAND_FS_IMAGE_NAME_512)_squbi_secureboot --securehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_1024KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB) --ubifs --bootfs bootfs1024kb_secureboot.img --rootfs ubi_rootfs1024kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_1024)_ubi_secureboot --fsonly $(FLASH_NAND_FS_IMAGE_NAME_1024)_ubi_secureboot --securehdr $(PRE_CFE_ROM)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB) --squbifs --bootfs bootfs1024kb_secureboot.img --rootfs squbi_rootfs1024kb.img --image $(FLASH_NAND_CFEROM_FS_IMAGE_NAME_1024)_squbi_secureboot --mirroredcfe --fsonly $(FLASH_NAND_FS_IMAGE_NAME_1024)_squbi_secureboot --securehdr $(PRE_CFE_ROM)
endif

endif

    ifeq ($(strip $(SKIP_TIMESTAMP_IMAGE)),)
# copy images to images directory and add a timestamp
	find $(PROFILE_DIR) -name *_nand_cferom_*.w  -printf "%f\n" | while read name; do cp $(PROFILE_DIR)/$$name $(IMAGES_DIR)/$${name/.w/_$(BRCM_RELEASETAG)-$(shell date '+%y%m%d_%H%M').w}; done
    endif


# Create .chk files for Web UI upgrade
	cd $(PROFILE_DIR) && touch rootfs && \
	$(HOSTTOOLS_DIR)/packet -k $(FLASH_NAND_FS_IMAGE_NAME_128)_squbi.w -b $(BOARDID_FILE) -oall kernel_rootfs_image \
			-i $(USERAPPS_DIR)/ap/acos/include/ambitCfg.h && \
	rm -f rootfs _*.chk && \
	cp kernel_rootfs_image.chk ../../images/$(PROFILE)_$(FW_TYPE)_`date +%m%d%H%M`.chk

	
	@echo
	@echo -e "Done! Image $(PROFILE) has been built in $(PROFILE_DIR)."


endif

#ifneq ($(findstring _$(strip $(BRCM_KERNEL_ROOTFS))_,_all_ _squashfs_),)
# NOR SQUASH
#	cd $(PROFILE_DIR); \
#	cp $(KERNEL_DIR)/vmlinux . ; \
#	$(KSTRIP) --remove-section=.note --remove-section=.comment vmlinux; \
#	$(KOBJCOPY) -O binary vmlinux vmlinux.bin; \
#	$(HOSTTOOLS_DIR)/bcmImageBuilder $(BRCM_ENDIAN_FLAGS) --output $(FS_KERNEL_IMAGE_NAME) --chip $(or $(TAG_OVERRIDE),$(BRCM_CHIP)) --board $(BRCM_BOARD_ID) --blocksize $(BRCM_FLASHBLK_SIZE) --image-version $(IMAGE_VERSION) --cfefile $(CFE_FILE) --rootfsfile rootfs.img --kernelfile vmlinux.lz --dtbfile $(DTB_FILE); \
#	$(HOSTTOOLS_DIR)/bcmImageBuilder $(BRCM_ENDIAN_FLAGS) --output $(CFE_FS_KERNEL_IMAGE_NAME) --chip $(or $(TAG_OVERRIDE),$(BRCM_CHIP)) --board $(BRCM_BOARD_ID) --blocksize $(BRCM_FLASHBLK_SIZE) --image-version $(IMAGE_VERSION) --cfefile $(CFE_FILE) --rootfsfile rootfs.img --kernelfile vmlinux.lz --dtbfile $(DTB_FILE) --include-cfe; \
#	$(HOSTTOOLS_DIR)/createimg.pl --set  boardid=$(BRCM_BOARD_ID) voiceboardid=$(BRCM_VOICE_BOARD_ID) numbermac=$(BRCM_NUM_MAC_ADDRESSES) macaddr=$(BRCM_BASE_MAC_ADDRESS) tp=$(BRCM_MAIN_TP_NUM) psisize=$(BRCM_PSI_SIZE) logsize=$(BRCM_LOG_SECTION_SIZE) auxfsprcnt=$(BRCM_AUXFS_PERCENT) gponsn=$(BRCM_GPON_SERIAL_NUMBER) gponpw=$(BRCM_GPON_PASSWORD) --inputfile=$(CFE_FS_KERNEL_IMAGE_NAME) --outputfile=$(FLASH_IMAGE_NAME) --nvramfile $(HOSTTOOLS_DIR)/nvram.h --nvramdefsfile $(HOSTTOOLS_DIR)/nvram_defaults.h --config=$(HOSTTOOLS_DIR)/local_install/conf/$(TOOLCHAIN_PREFIX).conf; \
#	$(HOSTTOOLS_DIR)/addvtoken --endian $(ARCH_ENDIAN) --chip $(or $(TAG_OVERRIDE),$(BRCM_CHIP)) --flashtype NOR $(FLASH_IMAGE_NAME) $(FLASH_IMAGE_NAME).w


#   ifneq ($(strip $(BTRM_BOOT_ONLY)),y)
#    ifeq ($(strip $(BUILD_SECURE_BOOT)),y)
#    ifneq ($(findstring _$(strip $(BRCM_CHIP))_,_63268_63381_63138_63148_),)
#    ifeq ($(strip $(BRCM_CHIP)),63268)
#	cat $(PROFILE_DIR)/vmlinux_secureboot.lz $(PROFILE_DIR)/vmlinux_secureboot.sig > $(PROFILE_DIR)/vmlinux_secureboot.lz.sig;
#    else
#	cat $(PROFILE_DIR)/vmlinux.lz $(PROFILE_DIR)/vmlinux.sig > $(PROFILE_DIR)/vmlinux_secureboot.lz.sig;
#    endif
#	cd $(PROFILE_DIR); \
#	$(HOSTTOOLS_DIR)/SecureBootUtils/makeSecureBootCfe spi $(BRCM_CHIP) $(PROFILE_DIR) $(SECURE_BOOT_NOR_BOOT_SIZE); \
#	$(HOSTTOOLS_DIR)/bcmImageBuilder $(BRCM_ENDIAN_FLAGS) --output $(CFE_FS_KERNEL_IMAGE_NAME)_secureboot --chip $(or $(TAG_OVERRIDE),$(BRCM_CHIP)) --board $(BRCM_BOARD_ID) --blocksize $(SECURE_BOOT_NOR_BOOT_SIZE) --image-version $(IMAGE_VERSION) --cfefile ../cfe/cfe$(BRCM_CHIP)bi_nor.bin --rootfsfile rootfs.img --kernelfile vmlinux_secureboot.lz.sig --include-cfe --dtbfile $(DTB_FILE); \
#	rm -f ../cfe/cfe$(BRCM_CHIP)bi_nor.bin vmlinux_secureboot.lz.sig; \
#	$(HOSTTOOLS_DIR)/createimg.pl --set boardid=$(BRCM_BOARD_ID) voiceboardid=$(BRCM_VOICE_BOARD_ID) numbermac=$(BRCM_NUM_MAC_ADDRESSES) macaddr=$(BRCM_BASE_MAC_ADDRESS) tp=$(BRCM_MAIN_TP_NUM) psisize=$(BRCM_PSI_SIZE) logsize=$(BRCM_LOG_SECTION_SIZE) auxfsprcnt=$(BRCM_AUXFS_PERCENT) gponsn=$(BRCM_GPON_SERIAL_NUMBER) gponpw=$(BRCM_GPON_PASSWORD) --inputfile=$(CFE_FS_KERNEL_IMAGE_NAME)_secureboot --outputfile=$(FLASH_IMAGE_NAME)_secureboot --nvramfile $(HOSTTOOLS_DIR)/nvram.h --nvramdefsfile $(HOSTTOOLS_DIR)/nvram_defaults.h --config=$(HOSTTOOLS_DIR)/local_install/conf/$(TOOLCHAIN_PREFIX).conf; \
#	$(HOSTTOOLS_DIR)/addvtoken --endian $(ARCH_ENDIAN) --chip $(or $(TAG_OVERRIDE),$(BRCM_CHIP)) --flashtype NOR --btrm 1 $(FLASH_IMAGE_NAME)_secureboot $(FLASH_IMAGE_NAME)_secureboot.w
#    endif
#    endif
#    endif


#    ifeq ($(strip $(SKIP_TIMESTAMP_IMAGE)),)
# copy images to images directory and add a timestamp
#	    @cp $(PROFILE_DIR)/$(FLASH_IMAGE_NAME).w $(IMAGES_DIR)/$(FLASH_IMAGE_NAME)_$(BRCM_RELEASETAG)-$(shell date '+%y%m%d_%H%M').w
#	    @cp $(PROFILE_DIR)/$(CFE_FS_KERNEL_IMAGE_NAME) $(IMAGES_DIR)/$(CFE_FS_KERNEL_IMAGE_NAME)_$(BRCM_RELEASETAG)-$(shell date '+%y%m%d_%H%M')
#    endif

#	@echo
#	    @echo -e "Done! Image $(PROFILE) has been built in $(PROFILE_DIR)."
#endif



nandcfeimage: hosttools_nandcfe
	rm -rf  $(TARGET_FS)/
	mkdir -p $(TARGET_FS)
	cp $(PROFILE_DIR)/../cfe/cfe$(BRCM_CHIP)ram.bin $(TARGET_FS)/cferam.000
	echo -e "/cferam.000" > $(HOSTTOOLS_DIR)/nocomprlist
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_16KB)),y)
#	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_16KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs16kb.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_128KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_128KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs128kb.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_256KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_256KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs256kb.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_512KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_512KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs512kb.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_1024KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_1024KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs1024kb.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif



ifeq ($(strip $(BUILD_SECURE_BOOT)),y)
	$(HOSTTOOLS_DIR)/SecureBootUtils/makeEncryptedCfeRam $(BRCM_CHIP) $(PROFILE_DIR)
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_16KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_16KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs16kb_secureboot.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_128KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_128KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs128kb_secureboot.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_256KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_256KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs256kb_secureboot.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_512KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_512KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs512kb_secureboot.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_1024KB)),y)
	$(HOSTTOOLS_DIR)/mkfs.jffs2 -v $(BRCM_ENDIAN_FLAGS) -p -n -e $(FLASH_NAND_BLOCK_1024KB) -r $(TARGET_FS) -o $(PROFILE_DIR)/rootfs1024kb_secureboot.img -N $(HOSTTOOLS_DIR)/nocomprlist
endif
endif
	rm $(HOSTTOOLS_DIR)/nocomprlist



ifeq ($(strip $(BTRM_BOOT_ONLY)),y)
	@echo -e "No XIP to flash capability. Bootrom boot only. Build unsecure bootrom boot"

ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_16KB)),y)
#	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --rootfs rootfs16kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.16 --unsecurehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_128KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --rootfs rootfs128kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.128 --unsecurehdr $(PRE_CFE_ROM)
	$(TARGETS_DIR)/buildUBI -u $(PROFILE_DIR)/ubi_cfe.ini -m $(TARGET_FS)/../metadata.bin -f $(PROFILE_DIR)/filestruct_cfe.bin -t $(TARGET_FS)
	$(HOSTTOOLS_DIR)/mtd-utils*/ubi-utils/ubinize -v -o $(PROFILE_DIR)/ubi_rootfs128kb_cferam_pureubi.img -m 2048 -p $(FLASH_NAND_BLOCK_128KB) $(PROFILE_DIR)/ubi_cfe.ini
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --rootfs ubi_rootfs128kb_cferam_pureubi.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly_pureubi.128 --unsecurehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_256KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB) --rootfs rootfs256kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.256 --unsecurehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_512KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB)  --rootfs rootfs512kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.512 --unsecurehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_1024KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB)  --rootfs rootfs1024kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.1024 --unsecurehdr $(PRE_CFE_ROM)
endif

else

ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_16KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --rootfs rootfs16kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.16 $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_128KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --rootfs rootfs128kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.128 $(PRE_CFE_ROM)
	$(TARGETS_DIR)/buildUBI -u $(PROFILE_DIR)/ubi_cfe.ini -m $(TARGET_FS)/../metadata.bin -f $(PROFILE_DIR)/filestruct_cfe.bin -t $(TARGET_FS)
	$(HOSTTOOLS_DIR)/mtd-utils*/ubi-utils/ubinize -v -o $(PROFILE_DIR)/ubi_rootfs128kb_cferam_pureubi.img -m 2048 -p $(FLASH_NAND_BLOCK_128KB) $(PROFILE_DIR)/ubi_cfe.ini
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB)  --rootfs ubi_rootfs128kb_cferam_pureubi.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly_pureubi.128 # --fsonly $(FLASH_BASE_IMAGE_NAME)_nand_cferam_only_pureubi.128 $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_256KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB) --rootfs rootfs256kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.256 $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_512KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB)  --rootfs rootfs512kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.512 $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_1024KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB)  --rootfs rootfs1024kb.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly.1024 $(PRE_CFE_ROM)
endif

endif



ifeq ($(strip $(BUILD_SECURE_BOOT)),y)
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_16KB)),y)
ifeq ($(strip $(BRCM_CHIP)),63268)
	# NOTE: 63268 small page nand bootsize is 128K on purpose (ie $(FLASH_NAND_BLOCK_128KB)). Do not change.
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB) --rootfs rootfs16kb_secureboot.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly_secureboot.16 --securehdr $(PRE_CFE_ROM)
else
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_16KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_16KB) --rootfs rootfs16kb_secureboot.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly_secureboot.16 --securehdr $(PRE_CFE_ROM)
endif
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_128KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_128KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_128KB) --rootfs rootfs128kb_secureboot.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly_secureboot.128 --securehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_256KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_256KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_256KB) --rootfs rootfs256kb_secureboot.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly_secureboot.256 --securehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_512KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_512KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_512KB) --rootfs rootfs512kb_secureboot.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly_secureboot.512 --securehdr $(PRE_CFE_ROM)
endif
ifeq ($(strip $(BUILD_NAND_IMG_BLKSIZE_1024KB)),y)
	$(HOSTTOOLS_DIR)/scripts/bcmImageMaker --cferom $(CFE_ROM_FILE) --blocksize $(FLASH_NAND_BLOCK_1024KB) --bootofs $(FLASH_BOOT_OFS) --bootsize $(FLASH_NAND_BLOCK_1024KB) --rootfs rootfs1024kb_secureboot.img --image $(FLASH_BASE_IMAGE_NAME)_nand_cfeonly_secureboot.1024 --securehdr $(PRE_CFE_ROM)
endif
endif

	rm -f  $(TARGET_FS)/cferam.000
	rm -f  $(TARGET_FS)/secram.000
	rm -f  $(TARGET_FS)/secmfg.000



###########################################
#
# System code clean-up
#
###########################################

#
# mwang: since SUBDIRS are no longer defined, the next two targets are not useful anymore.
# how were they used anyways?
#
#subdirs: $(patsubst %, _dir_%, $(SUBDIRS))

#$(patsubst %, _dir_%, $(SUBDIRS)) :
#	$(MAKE) -C $(patsubst _dir_%, %, $@) $(TGT)


clean: gpl_clean bcmdrivers_clean data-model_clean userspace_clean  \
	kernel_clean hosttools_clean nvram_3k_kernelclean target_clean rdp_clean $(DTBS_CLEAN)
	rm -f $(HOSTTOOLS_DIR)/scripts/lxdialog/*.o
	rm -f .tmpconfig*
	-mv -f $(LAST_PROFILE_COOKIE) .check_clean
	rm -f $(LAST_PROFILE_COOKIE)
	rm -f $(HOST_PERLARCH_COOKIE)
	@echo "====start copy prebuild AX11000 to targets/AX11000 folder===="
	rm -rf $(BUILD_DIR)/targets/AX11000
	cp -rf $(BUILD_DIR)/pre-build $(BUILD_DIR)/targets/
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc ; rm -f resolv.conf ; ln -fs /tmp/resolv.conf $(TOP)/targets/$(PROFILE)/fs.install/etc/resolv.conf		
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/bmc ; ln -fs bcmmcastctl $(TOP)/targets/$(PROFILE)/fs.install/bin/bmc
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/bpm ; ln -fs bpmctl $(TOP)/targets/$(PROFILE)/fs.install/bin/bpm
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/fc  ; ln -fs fcctl $(TOP)/targets/$(PROFILE)/fs.install/bin/fc
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/mcp ; ln -fs mcpctl $(TOP)/targets/$(PROFILE)/fs.install/bin/mcp
	rm -f $(TOP)/targets/$(PROFILE)/fs.install/bin/pwr ; ln -fs pwrctl $(TOP)/targets/$(PROFILE)/fs.install/bin/pwr
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d ; rm -f S05hndmfg ; ln -fs ../init.d/hndmfg.sh $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d/S05hndmfg
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d ; rm -f S40hndnvram ; ln -fs ../init.d/hndnvram.sh $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d/S40hndnvram
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d ; rm -f S45swmdk ; ln -fs ../init.d/swmdk.sh $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d/S45swmdk
	cd $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d ; rm -f S63save-dmesg ; ln -fs ../init.d/save-dmesg.sh $(TOP)/targets/$(PROFILE)/fs.install/etc/rc3.d/S63save-dmesg
	cd $(TOP)/targets/$(PROFILE)/fs.install/lib ; rm -f libvolume_id.so.0 ; ln -fs libvolume_id.so.0.78.0 $(TOP)/targets/$(PROFILE)/fs.install/lib/libvolume_id.so.0
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f acos_init ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/acos_init
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f acos_init_once ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/acos_init_once
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f api ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/api
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f autoconfig_wan_down ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/autoconfig_wan_down
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f autoconfig_wan_up ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/autoconfig_wan_up
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn5g2pass ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn5g2pass
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn5g2ssid ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn5g2ssid
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn5gpass ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn5gpass
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn5gssid ;  ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn5gssid
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnboardid ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnboardid
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burncode ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burncode
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burndisdefault ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burndisdefault
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burndisfctest ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burndisfctest
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnendefault ;ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnendefault
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnenfctest ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnenfctest
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnethermac ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnethermac
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burn_hw_rev ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burn_hw_rev
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnhwver ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnhwver
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnpass ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnpass
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnpin ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnpin
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnrf ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnrf
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnsku ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnsku
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnsn ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnsn
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f burnssid ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/burnssid
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f dhcp6c_down ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/dhcp6c_down
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f dhcp6c_up ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/dhcp6c_up
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f dlna ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/dlna
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f dumprf ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/dumprf
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f erase ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/erase
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ethctl ; ln -fs ../bin/ethctl $(TOP)/targets/$(PROFILE)/fs.install/sbin/ethctl
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f firewall ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/firewall
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f getchksum  ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/getchksum
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f getopenvpnsum ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/getopenvpnsum
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f hotplug ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/hotplug
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f init ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/init
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f internet ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/internet
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ipv6-conntab ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ipv6-conntab
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ipv6_drop_all_pkt ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ipv6_drop_all_pkt
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ipv6_enable_wan_ping_to_lan ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ipv6_enable_wan_ping_to_lan
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f landown ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/landown
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f lanstatus ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/lanstatus
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f lanup ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/lanup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ledamberup ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ledamberup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f leddown ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/leddown
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ledup ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ledup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f ledwhiteup ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/ledwhiteup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_isbad ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_isbad
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_markbad ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_markbad
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_read_oob ;ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_read_oob
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_write_oob ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_write_oob
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f mtd_write_page ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/mtd_write_page
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f nvconfig ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/nvconfig
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f preinit ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/preinit
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f read_bd ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/read_bd
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f reset_no_reboot ;ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/reset_no_reboot
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f restart_all_processes ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/restart_all_processes
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f restore_bin ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/restore_bin
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f routerinfo  ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/routerinfo
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f showconfig ; ln -fs bd $(TOP)/targets/$(PROFILE)/fs.install/sbin/showconfig
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f stats ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/stats
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f system ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/system
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f uptime ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/uptime
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f version ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/version
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f wanPhydown ;ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/wanPhydown
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f wanPhyup ; ln -fs acos_service $(TOP)/targets/$(PROFILE)/fs.install/sbin/wanPhyup
	cd $(TOP)/targets/$(PROFILE)/fs.install/sbin ; rm -f write ; ln -fs rc $(TOP)/targets/$(PROFILE)/fs.install/sbin/write
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libjson-c.so ;ln -fs libjson-c.so.2.0.1 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libjson-c.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libjson-c.so.2 ;ln -fs libjson-c.so.2.0.1 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libjson-c.so.2
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libmnl.so ; ln -fs libmnl.so.0.1.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libmnl.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libmnl.so.0 ; ln -fs libmnl.so.0.1.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libmnl.so.0
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnetfilter_conntrack.so ; ln -fs libnetfilter_conntrack.so.3.4.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnetfilter_conntrack.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnetfilter_conntrack.so.3 ; ln -fs libnetfilter_conntrack.so.3.4.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnetfilter_conntrack.so.3
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnetfilter_queue.so ; ln -fs libnetfilter_queue.so.1.3.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnetfilter_queue.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnetfilter_queue.so.1 ; ln -fs libnetfilter_queue.so.1.3.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnetfilter_queue.so.1
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnfnetlink.so ; ln -fs libnfnetlink.so.0.2.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnfnetlink.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libnfnetlink.so.0 ; ln -fs libnfnetlink.so.0.2.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libnfnetlink.so.0
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libsqlite3.so.0 ; ln -fs libsqlite3.so.0.8.6 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libsqlite3.so.0
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libvolume_id.so ; ln -fs /udev/lib/libvolume_id.so.0.78.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libvolume_id.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libxml2.so ; ln -fs libxml2.so.2.9.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libxml2.so
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/lib ; rm -f libxml2.so.2 ; ln -fs libxml2.so.2.9.0 $(TOP)/targets/$(PROFILE)/fs.install/usr/lib/libxml2.so.2
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/local/samba/ ; rm -f lock ; ln -fs ../../../var/lock $(TOP)/targets/$(PROFILE)/fs.install/usr/local/samba/lock
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/local/samba/lib ; rm -f smb.conf ; ln -fs ../../../../tmp/samba/private/smb.conf $(TOP)/targets/$(PROFILE)/fs.install/usr/local/samba/lib/smb.conf
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f chkntfs ; ln -fs ufsd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/chkntfs
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f chkufsd ; ln -fs ufsd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/chkufsd
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f mkntfs ; ln -fs ufsd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/mkntfs
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f nvram ; ln -fs /bin/nvram $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/nvram
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f readycloud_unregister ; ln -fs remote_smb_conf $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/readycloud_unregister
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f remote_share_conf ; ln -fs remote_smb_conf $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/remote_share_conf
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f remote_user_conf ; ln -fs remote_smb_conf $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/remote_user_conf
	cd $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin ; rm -f wanled ; ln -fs heartbeat $(TOP)/targets/$(PROFILE)/fs.install/usr/sbin/wanled
	@echo "====end copy probuild AX11000 ===="
    

cleanall: clean_local_tools clean

clean_local_tools:
	rm -rf $(HOSTTOOLS_DIR)/local_install

check_clean: 
	find . -type f -newer .check_clean -print | $(HOSTTOOLS_DIR)/check_clean.pl -p .check_clean check_clean_whitelist

fssrc_clean:
	rm -fr $(FSSRC_DIR)/bin
	rm -fr $(FSSRC_DIR)/sbin
	rm -fr $(FSSRC_DIR)/lib
	rm -fr $(FSSRC_DIR)/upnp
	rm -fr $(FSSRC_DIR)/docs
	rm -fr $(FSSRC_DIR)/webs
	rm -fr $(FSSRC_DIR)/usr
	rm -fr $(FSSRC_DIR)/linuxrc
	rm -fr $(FSSRC_DIR)/images
	rm -fr $(FSSRC_DIR)/etc/wlan
	rm -fr $(FSSRC_DIR)/etc/certs

kernel_clean: hnd_dongle_clean 
	CURRENT_ARCH=$(KERNEL_ARCH) TOOLCHAIN_TOP= $(MAKE) inner_kernel_clean
inner_kernel_clean: sanity_check
	-$(MAKE) -C $(KERNEL_DIR) mrproper
	rm -f $(KERNEL_DIR)/arch/mips/defconfig
	rm -f $(KERNEL_DIR)/arch/arm/defconfig
	rm -f $(KERNEL_DIR)/arch/arm64/defconfig
	rm -f $(HOSTTOOLS_DIR)/lzma/decompress/*.o
	rm -f $(KERNEL_INCLUDE_LINK)
	rm -f $(KERNEL_MIPS_INCLUDE_LINK)
	rm -f $(KERNEL_ARM_INCLUDE_LINK)
	rm -f $(KERNEL_DIR)/.pre_kernelbuild
ifeq ($(strip $(BCA_HNDROUTER)),)
	find bcmdrivers/broadcom/net/wl -name build -type d -prune -exec rm -rf {} \; 2> /dev/null 
endif

bcmdrivers_clean:
	-$(MAKE) -C bcmdrivers clean

userspace_clean: sanity_check fssrc_clean 
	-rm -fr $(BCM_FSBUILD_DIR)
	-$(MAKE) -C userspace clean

data-model_clean:
ifeq ($(strip $(BCA_HNDROUTER)),)
	-$(MAKE) -C data-model clean
else
	@true
endif

unittests_clean:
	-$(MAKE) -C unittests clean

target_clean: sanity_check
	rm -f $(PROFILE_DIR)/*.img
	rm -f $(PROFILE_DIR)/*.bin
	rm -f $(PROFILE_DIR)/*.ini
	rm -f $(PROFILE_DIR)/rootfs.ubifs
	rm -f $(PROFILE_DIR)/vmlinux*
	rm -f $(PROFILE_DIR)/*.w
	rm -f $(PROFILE_DIR)/*.srec
	rm -f $(PROFILE_DIR)/ramdisk
	rm -f $(PROFILE_DIR)/$(FS_KERNEL_IMAGE_NAME)*
	rm -f $(PROFILE_DIR)/$(CFE_FS_KERNEL_IMAGE_NAME)*
	rm -f $(PROFILE_DIR)/$(FLASH_IMAGE_NAME)*
	rm -fr $(PROFILE_DIR)/modules
	rm -fr $(PROFILE_DIR)/op
	rm -fr $(INSTALL_DIR)
	rm -fr $(BCM_FSBUILD_DIR)
	find targets -name vmlinux -print -exec rm -f "{}" ";"
	rm -fr targets/TEMP
	rm -fr $(TARGET_FS)
	rm -f release/*credits.txt
ifeq ($(strip $(BRCM_KERNEL_ROOTFS)),all)
	rm -fr $(TARGET_BOOTFS)
endif

hosttools_clean:
	-$(MAKE) -C $(HOSTTOOLS_DIR) clean

hnd_dongle_clean:
ifneq ($(strip $(BCA_HNDROUTER)),)
	# need to make sure soft link still exists
	-$(MAKE) -j $(ACTUAL_MAX_JOBS) -C $(BRCMDRIVERS_DIR)/broadcom/net/wl/bcm9$(BRCM_CHIP) clean
else
	@true
endif
gpl_clean:
	$(MAKE) -C $(USERAPPS_DIR)/ap/gpl clean


###########################################
#
# Temporary kernel patching mechanism
#
###########################################

.PHONY: genpatch patch

genpatch:
	@hostTools/kup_tmp/genpatch

patch:
#	@hostTools/kup_tmp/patch

###########################################
#
# Get modules version
#
###########################################
.PHONY: version_info

version_info: sanity_check pre_kernelbuild
	@echo "$(MAKECMDGOALS):";\
	cd $(KERNEL_DIR); $(MAKE) --silent version_info;

###########################################
#
# System-wide exported variables
# (in alphabetical order)
#
###########################################


export \
ACTUAL_MAX_JOBS            \
BRCMAPPS                   \
BRCM_BOARD                 \
BRCM_DRIVER_PCI            \
BRCM_EXTRAVERSION          \
BRCM_KERNEL_NETQOS         \
BRCM_KERNEL_ROOTFS         \
BRCM_KERNEL_AUXFS_JFFS2    \
BRCM_LDX_APP               \
BRCM_MIPS_ONLY_BUILD       \
BRCM_CPU_FREQ_PWRSAVE      \
BRCM_CPU_FREQ_TARGET_LOAD  \
BRCM_PSI_VERSION           \
BRCM_PTHREADS              \
BRCM_RAMDISK_BOOT_EN       \
BRCM_RAMDISK_SIZE          \
BRCM_NFS_MOUNT_EN          \
BRCM_RELEASE               \
BRCM_RELEASETAG            \
BRCM_SNMP                  \
BRCM_VERSION               \
BUILD_CMFCTL               \
BUILD_CMFVIZ               \
BUILD_CMFD                 \
BUILD_XDSLCTL              \
BUILD_XTMCTL               \
BUILD_VLANCTL              \
BUILD_BRCM_VLAN            \
BUILD_BRCTL                \
BUILD_BUSYBOX              \
BUILD_BUSYBOX_BRCM_LITE    \
BUILD_BUSYBOX_BRCM_FULL    \
BUILD_CERT                 \
BUILD_DDNSD                \
BUILD_DEBUG_TOOLS          \
BUILD_DIAGAPP              \
BUILD_DIR                  \
BUILD_DNSPROBE             \
BUILD_DPROXY               \
BUILD_DPROXYWITHPROBE      \
BUILD_DYNAHELPER           \
BUILD_DNSSPOOF             \
BUILD_EBTABLES             \
BUILD_EPITTCP              \
BUILD_ETHWAN               \
BUILD_FTPD                 \
BUILD_FTPD_STORAGE         \
BUILD_MCAST_PROXY          \
BUILD_WLHSPOT              \
BUILD_IPPD                 \
BUILD_IPROUTE2             \
BUILD_IPSEC_TOOLS          \
BUILD_L2TPAC               \
BUILD_ACCEL_PPTP           \
BUILD_IPTABLES             \
BUILD_WPS_BTN              \
BUILD_LLTD                 \
BUILD_WSC                  \
BUILD_BCMCRYPTO \
BUILD_BCMSHARED \
BUILD_MKSQUASHFS           \
BUILD_NAS                  \
BUILD_NVRAM                \
BUILD_PORT_MIRRORING			 \
BUILD_PPPD                 \
PPP_AUTODISCONN			   \
BUILD_SES                  \
BUILD_SIPROXD              \
BUILD_SLACTEST             \
BUILD_SNMP                 \
BUILD_SNTP                 \
BUILD_SOAP                 \
BUILD_SOAP_VER             \
BUILD_SSHD                 \
BUILD_SSHD_MIPS_GENKEY     \
BUILD_TOD                  \
BUILD_BRCM_CMS             \
BUILD_TR64                 \
BUILD_TR64_DEVICECONFIG    \
BUILD_TR64_DEVICEINFO      \
BUILD_TR64_LANCONFIGSECURITY \
BUILD_TR64_LANETHINTERFACECONFIG \
BUILD_TR64_LANHOSTS        \
BUILD_TR64_LANHOSTCONFIGMGMT \
BUILD_TR64_LANUSBINTERFACECONFIG \
BUILD_TR64_LAYER3          \
BUILD_TR64_MANAGEMENTSERVER  \
BUILD_TR64_TIME            \
BUILD_TR64_USERINTERFACE   \
BUILD_TR64_QUEUEMANAGEMENT \
BUILD_TR64_LAYER2BRIDGE   \
BUILD_TR64_WANCABLELINKCONFIG \
BUILD_TR64_WANCOMMONINTERFACE \
BUILD_TR64_WANDSLINTERFACE \
BUILD_TR64_WANDSLLINKCONFIG \
BUILD_TR64_WANDSLCONNECTIONMGMT \
BUILD_TR64_WANDSLDIAGNOSTICS \
BUILD_TR64_WANETHERNETCONFIG \
BUILD_TR64_WANETHERNETLINKCONFIG \
BUILD_TR64_WANIPCONNECTION \
BUILD_TR64_WANPOTSLINKCONFIG \
BUILD_TR64_WANPPPCONNECTION \
BUILD_TR64_WLANCONFIG      \
BUILD_TR69C                \
BUILD_TR69_QUEUED_TRANSFERS \
BUILD_TR69C_SSL            \
BUILD_TR69_XBRCM           \
BUILD_TR69_UPLOAD          \
BUILD_TR69C_VENDOR_RPC     \
BUILD_OMCI                 \
BUILD_UDHCP                \
BUILD_UDHCP_RELAY          \
BUILD_UPNP                 \
BUILD_VCONFIG              \
BUILD_SUPERDMZ             \
BUILD_WLCTL                \
BUILD_DHDCTL               \
BUILD_ZEBRA                \
BUILD_LIBUSB               \
BUILD_WANVLANMUX           \
HOSTTOOLS_DIR              \
INC_KERNEL_BASE            \
INSTALL_DIR                \
PROFILE_DIR                \
WEB_POPUP                  \
BUILD_VIRT_SRVR            \
BUILD_PORT_TRIG            \
BUILD_TR69C_BCM_SSL        \
BUILD_IPV6                 \
BUILD_BOARD_LOG_SECTION    \
BRCM_LOG_SECTION_SIZE      \
BRCM_FLASHBLK_SIZE         \
BRCM_AUXFS_PERCENT         \
BRCM_BACKUP_PSI            \
LINUX_KERNEL_USBMASS       \
BUILD_IPSEC                \
BUILD_MoCACTL              \
BUILD_MoCACTL2             \
BUILD_6802_MOCA            \
BRCM_MOCA_AVS          \
BUILD_GPON                 \
BUILD_GPONCTL              \
BUILD_PMON                 \
BUILD_BUZZZ                \
BUILD_BOUNCE               \
BUILD_HELLO                \
BUILD_SPUCTL               \
BUILD_PWRCTL               \
BUILD_RNGD                 \
RELEASE_BUILD              \
NO_PRINTK_AND_BUG          \
FLASH_NAND_BLOCK_16KB      \
FLASH_NAND_BLOCK_128KB     \
FLASH_NAND_BLOCK_256KB     \
FLASH_NAND_BLOCK_512KB     \
FLASH_NAND_BLOCK_1024KB     \
FLASH_NAND_BLOCK_2056KB     \
BRCM_SCHED_RT_RUNTIME       \
BRCM_CONFIG_HIGH_RES_TIMERS \
BRCM_SWITCH_SCHED_SP        \
BRCM_SWITCH_SCHED_WRR       \
BUILD_SWMDK                 \
BUILD_IQCTL                 \
BUILD_BPMCTL                \
BUILD_EPONCTL               \
BUILD_ETHTOOL               \
BUILD_TMS                   \
IMAGE_VERSION               \
TOOLCHAIN_VER               \
TOOLCHAIN_PREFIX            \
PROFILE_KERNEL_VER          \
KERNEL_LINKS_DIR            \
LINUX_VER_STR               \
KERNEL_DIR                  \
FORCE                       \
BUILD_VLAN_AGGR             \
BUILD_DPI                   \
BUILD_MAP                   \
BRCM_KERNEL_DEBUG           \
BUILD_BRCM_FTTDP            \
BUILD_BRCM_XDSL_DISTPOINT   \
BRCM_1905_FM                \
BUILD_BRCM_CMS              \
BUILD_WEB_SOCKETS           \
BUILD_WEB_SOCKETS_TEST      \
BRCM_1905_TOPOLOGY_WEB_PAGE \
BUILD_NAND_KERNEL_LZMA      \
BUILD_NAND_KERNEL_LZ4       \
BUILD_DISABLE_EXEC_STACK    \
NO_MINIFY                   \
BCM_SPEEDYGET
