TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Turrit

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TurritAntiEdit
TurritAntiEdit_FILES = Tweak.xm SwiftNodeProbe.swift
TurritAntiEdit_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
TurritAntiEdit_SWIFTFLAGS = -ISwiftRuntimeHeaders
TurritAntiEdit_FRAMEWORKS = UIKit Foundation
TurritAntiEdit_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
