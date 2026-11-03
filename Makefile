TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Turrit

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TurritAntiEdit
TurritAntiEdit_FILES = Tweak.xm AntiEditView.swift
TurritAntiEdit_CFLAGS = -fobjc-arc
TurritAntiEdit_SWIFTFLAGS = -ISwiftRuntimeHeaders
TurritAntiEdit_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
