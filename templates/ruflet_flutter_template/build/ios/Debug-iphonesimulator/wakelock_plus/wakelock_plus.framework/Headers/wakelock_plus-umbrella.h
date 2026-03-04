#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "messages.g.h"
#import "UIApplication+idleTimerLock.h"
#import "WakelockPlusPlugin.h"

FOUNDATION_EXPORT double wakelock_plusVersionNumber;
FOUNDATION_EXPORT const unsigned char wakelock_plusVersionString[];

