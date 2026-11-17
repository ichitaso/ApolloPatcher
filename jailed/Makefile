MODULES = jailed
DISPLAY_NAME = Apollo
BUNDLE_ID = com.christianselig.Apollo
CODESIGN_IPA = 0

# make package APOLLO_VERSION=1.8.7
APOLLO_VERSION ?= 1.15.11
PATCHER_VERSION := $(shell grep '^Version:' ../control | cut -d' ' -f2)

ifeq ($(APOLLO_VERSION),1.8.7)
TARGET := iphone:clang:16.5:13.0
else
TARGET := iphone:clang:16.5:15.0
endif
ARCHS = arm64

DEBUG = 0
FINALPACKAGE = 1

TWEAK_NAME = ApolloPatcher
$(TWEAK_NAME)_FILES = ../Tweak.xm ../SettingsController.m ../fishhook.c ../Backup.m ../WebAuth.m
$(TWEAK_NAME)_FRAMEWORKS = UIKit SafariServices Security WebKit
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

$(TWEAK_NAME)_USE_FLEX = 0
$(TWEAK_NAME)_IPA = $(THEOS_PROJECT_DIR)/Apollo-$(APOLLO_VERSION).ipa
OUTPUT_NAME = Apollo-$(APOLLO_VERSION)_ApolloPatcher_$(PATCHER_VERSION).ipa

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
