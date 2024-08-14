ifeq ($(TARGET_OS), macos)

TARGET := macosx:clang:11.3:11.0

else ifeq ($(TARGET_OS), ios)

TARGET := iphone:clang:latest:15.0
ARCHS = arm64

THEOS_PACKAGE_SCHEME=rootless

endif

include $(THEOS)/makefiles/common.mk

TOOL_NAME = rootless-patcher

rootless-patcher_FILES = $(shell find . -type f -name '*.m') $(shell find . -type f -name '*.c')
rootless-patcher_CFLAGS = -fobjc-arc

ifeq ($(TARGET_OS), ios)
rootless-patcher_CODESIGN_FLAGS = -Sentitlements.plist
endif

rootless-patcher_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk