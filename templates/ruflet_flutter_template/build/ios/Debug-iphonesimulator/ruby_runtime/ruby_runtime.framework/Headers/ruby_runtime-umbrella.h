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

#import "MrubyRuntimePlugin.h"

FOUNDATION_EXPORT double ruby_runtimeVersionNumber;
FOUNDATION_EXPORT const unsigned char ruby_runtimeVersionString[];

