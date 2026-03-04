//
//  GADMediationInterstitialAd.h
//  Google Mobile Ads SDK
//
//  Copyright 2018 Google LLC. All rights reserved.
//

#import <GoogleMobileAds/Mediation/GADMediationAd.h>
#import <GoogleMobileAds/Mediation/GADMediationAdConfiguration.h>
#import <GoogleMobileAds/Mediation/GADMediationAdEventDelegate.h>
#import <UIKit/UIKit.h>

/// Rendered interstitial ad.
NS_SWIFT_NAME(MediationInterstitialAd)
@protocol GADMediationInterstitialAd <GADMediationAd>

/// Presents the receiver from the view controller.
- (void)presentFromViewController:(nonnull UIViewController *)viewController
    NS_SWIFT_NAME(present(from:));

@end

/// Interstitial ad configuration.
NS_SWIFT_NAME(MediationInterstitialAdConfiguration)
@interface GADMediationInterstitialAdConfiguration : GADMediationAdConfiguration
@end
