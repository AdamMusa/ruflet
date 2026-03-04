//
//  GADMediationRewardedAd.h
//  Google Mobile Ads SDK
//
//  Copyright 2018 Google LLC. All rights reserved.
//

#import <GoogleMobileAds/Mediation/GADMediationAd.h>
#import <GoogleMobileAds/Mediation/GADMediationAdConfiguration.h>
#import <GoogleMobileAds/Mediation/GADMediationAdEventDelegate.h>
#import <UIKit/UIKit.h>

/// Rendered rewarded ad.
NS_SWIFT_NAME(MediationRewardedAd)
@protocol GADMediationRewardedAd <GADMediationAd>

- (void)presentFromViewController:(nonnull UIViewController *)viewController
    NS_SWIFT_NAME(present(from:));
@end

/// Rewarded ad configuration.
NS_SWIFT_NAME(MediationRewardedAdConfiguration)
@interface GADMediationRewardedAdConfiguration : GADMediationAdConfiguration
@end
