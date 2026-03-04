//
//  GADVideoOptions.h
//  Google Mobile Ads SDK
//
//  Copyright 2016 Google LLC. All rights reserved.
//

#import <GoogleMobileAds/GADAdLoader.h>

/// Video ad options.
NS_SWIFT_NAME(VideoOptions)
@interface GADVideoOptions : GADAdLoaderOptions

/// Indicates whether videos should start muted. By default this property value is YES.
@property(nonatomic, assign) BOOL startMuted NS_SWIFT_NAME(shouldStartMuted);

/// Indicates whether the requested video should have custom controls enabled for
/// play/pause/mute/unmute.
@property(nonatomic, assign) BOOL customControlsRequested NS_SWIFT_NAME(areCustomControlsRequested);

/// Indicates whether the requested video should have the click to expand behavior.
@property(nonatomic, assign) BOOL clickToExpandRequested NS_SWIFT_NAME(isClickToExpandRequested);

@end
