//
//  GADMediationAppOpenAd.h
//  Google Mobile Ads SDK
//
//  Copyright 2022 Google LLC. All rights reserved.
//

#import <GoogleMobileAds/Mediation/GADMediationAd.h>
#import <GoogleMobileAds/Mediation/GADMediationAdConfiguration.h>
#import <GoogleMobileAds/Mediation/GADMediationAdEventDelegate.h>
#import <UIKit/UIKit.h>

/// Rendered app open ad.
NS_SWIFT_NAME(MediationAppOpenAd)
@protocol GADMediationAppOpenAd <GADMediationAd>

/// Presents the receiver from the view controller.
- (void)presentFromViewController:(nonnull UIViewController *)viewController
    NS_SWIFT_NAME(present(from:));
@end

/// App open ad configuration.
@interface GADMediationAppOpenAdConfiguration : GADMediationAdConfiguration
@end
