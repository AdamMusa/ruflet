//
//  GADSignal.h
//  Google Mobile Ads SDK
//
//  Copyright 2024 Google LLC. All rights reserved.
//
#import <UIKit/UIKit.h>

/// A signal that can be used as input in a server-to-server ad request.
NS_SWIFT_NAME(Signal)
@interface GADSignal : NSObject

/// Signal string used in a server-to-server ad request.
@property(nonatomic, readonly, nonnull) NSString *signalString NS_SWIFT_NAME(signal);

#pragma mark Initialization

/// Unavailable. An instance of this class will be returned when generating a signal.
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
