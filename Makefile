TARGET := iphone:clang:latest:13.0
INSTALL_TARGET_PROCESSES = SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UINative

UINative_FILES = $(shell find Sources/UINative -name '*.swift') $(shell find Sources/UINativeC -name '*.m' -o -name '*.c' -o -name '*.mm' -o -name '*.cpp')
UINative_SWIFTFLAGS = -ISources/UINativeC/include
UINative_PRIVATE_FRAMEWORKS = Celestial
UINative_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = UINativeResources
UINativeResources_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
