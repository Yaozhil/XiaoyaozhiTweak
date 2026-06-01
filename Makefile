ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = XiaoyaozhiTweak
XiaoyaozhiTweak_FILES = XiaoyaozhiTweak.xm \
	Core/YZPluginLifecycle.m \
	Core/YZEnvironmentDetector.m \
	Core/YZConfigManager.m \
	UI/YZGlassOverlayView.m \
	UI/YZFluidButton.m \
	UI/YZGlassSheetController.m \
	UI/YZDonationImageProvider.m \
	UI/YZFollowIconProvider.m \
	UI/YZAnimator.m \
	UI/YZParticleEffectView.m \
	UI/YZRewardView.m \
	WeChat/YZWCRuntime.m \
	WeChat/YZWCServiceCenter.m \
	Optimizer/YZAsyncExecutor.m \
	Optimizer/YZMemoryCache.m \
	Guard/YZCrashGuard.m \
	Guard/YZPrivacyGuard.m
XiaoyaozhiTweak_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics CoreImage
XiaoyaozhiTweak_CFLAGS = -fobjc-arc -fobjc-exceptions -Wno-unused-parameter -I. -ICore -IUI -IWeChat -IOptimizer -IGuard
XiaoyaozhiTweak_LDFLAGS = -lz -lobjc

include $(THEOS_MAKE_PATH)/tweak.mk
