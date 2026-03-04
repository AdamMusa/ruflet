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

#import "client.h"
#import "render.h"
#import "render_gl.h"
#import "stream_cb.h"

FOUNDATION_EXPORT double media_kit_videoVersionNumber;
FOUNDATION_EXPORT const unsigned char media_kit_videoVersionString[];

