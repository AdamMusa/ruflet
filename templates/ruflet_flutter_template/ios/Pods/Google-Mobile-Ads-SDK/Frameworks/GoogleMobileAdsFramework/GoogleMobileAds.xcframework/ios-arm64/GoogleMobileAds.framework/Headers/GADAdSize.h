//
//  GADAdSize.h
//  Google Mobile Ads SDK
//
//  Copyright 2012 Google LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAdsDefines.h>
#import <UIKit/UIKit.h>

/// A valid GADAdSize is considered to be one of the predefined GADAdSize constants or a GADAdSize
/// constructed by GADAdSizeFromCGSize, GADAdSizeFullWidthPortraitWithHeight,
/// GADAdSizeFullWidthLandscapeWithHeight.
///
/// Do not create a GADAdSize manually. Use one of the GADAdSize constants. Treat GADAdSize as an
/// opaque type. Do not access any fields directly. To obtain a concrete CGSize, use the function
/// CGSizeFromGADAdSize().
typedef struct GAD_BOXABLE GADAdSize GADAdSize;

/// Ad size.
///
/// @see typedef GADAdSize
struct GAD_BOXABLE GADAdSize {
  /// The ad size. Don't modify this value directly.
  CGSize size;
  /// Reserved.
  NSUInteger flags;
} NS_SWIFT_NAME(AdSize);

#pragma mark Standard Sizes

/// iPhone and iPod Touch ad size. Typically 320x50.
FOUNDATION_EXPORT GADAdSize const GADAdSizeBanner NS_SWIFT_NAME(AdSizeBanner);

/// Taller version of GADAdSizeBanner. Typically 320x100.
FOUNDATION_EXPORT GADAdSize const GADAdSizeLargeBanner NS_SWIFT_NAME(AdSizeLargeBanner);

/// Medium Rectangle size for the iPad (especially in a UISplitView's left pane). Typically 300x250.
FOUNDATION_EXPORT GADAdSize const GADAdSizeMediumRectangle NS_SWIFT_NAME(AdSizeMediumRectangle);

/// Full Banner size for the iPad (especially in a UIPopoverController or in
/// UIModalPresentationFormSheet). Typically 468x60.
FOUNDATION_EXPORT GADAdSize const GADAdSizeFullBanner NS_SWIFT_NAME(AdSizeFullBanner);

/// Leaderboard size for the iPad. Typically 728x90.
FOUNDATION_EXPORT GADAdSize const GADAdSizeLeaderboard NS_SWIFT_NAME(AdSizeLeaderboard);

/// Skyscraper size for the iPad. Mediation only. AdMob/Google does not offer this size. Typically
/// 120x600.
FOUNDATION_EXPORT GADAdSize const GADAdSizeSkyscraper NS_SWIFT_NAME(AdSizeSkyscraper);

/// An ad size that spans the full width of its container, with a height dynamically determined by
/// the ad.
FOUNDATION_EXPORT GADAdSize const GADAdSizeFluid NS_SWIFT_NAME(AdSizeFluid);

/// Invalid ad size marker.
FOUNDATION_EXPORT GADAdSize const GADAdSizeInvalid NS_SWIFT_NAME(AdSizeInvalid);

#pragma mark Inline Adaptive Sizes

/// Returns a GADAdSize with the given width and the device's portrait height. This ad size
/// allows Google servers to choose an optimal ad size less than or equal to the returned size. The
/// exact size of the ad returned is passed through the banner's ad size delegate and is indicated
/// by the banner's intrinsicContentSize. This ad size is most suitable for ads intended for scroll
/// views.
FOUNDATION_EXPORT GADAdSize GADPortraitInlineAdaptiveBannerAdSizeWithWidth(CGFloat width)
    NS_SWIFT_NAME(portraitInlineAdaptiveBanner(width:));

/// Returns a GADAdSize with the given width and the device's landscape height. This ad size
/// allows Google servers to choose an optimal ad size less than or equal to the returned size. The
/// exact size of the ad returned is passed through the banner's ad size delegate and is indicated
/// by the banner's intrinsicContentSize. This ad size is most suitable for ads intended for scroll
/// views.
FOUNDATION_EXPORT GADAdSize GADLandscapeInlineAdaptiveBannerAdSizeWithWidth(CGFloat width)
    NS_SWIFT_NAME(landscapeInlineAdaptiveBanner(width:));

/// Returns a GADAdSize with the given width and the device's height. This is a convenience
/// function to return GADPortraitInlineAdaptiveBannerAdSizeWithWidth or
/// GADLandscapeInlineAdaptiveBannerAdSizeWithWidth based on the current interface orientation.
/// This function must be called on the main queue.
FOUNDATION_EXPORT GADAdSize GADCurrentOrientationInlineAdaptiveBannerAdSizeWithWidth(CGFloat width)
    NS_SWIFT_NAME(currentOrientationInlineAdaptiveBanner(width:));

/// Returns a GADAdSize with the given width and max height. This ad size allows Google servers to
/// choose an optimal ad size less than or equal to the returned size. The exact size of the ad
/// returned is passed through the banner's ad size delegate and is indicated by the banner's
/// intrinsicContentSize. This ad size is most suitable for ads intended for scroll views.
///
/// @param width The ad width.
/// @param maxHeight The maximum height a loaded ad will have. Must be at least 32 px, but a max
/// height of 50 px or higher is recommended.
FOUNDATION_EXPORT GADAdSize GADInlineAdaptiveBannerAdSizeWithWidthAndMaxHeight(CGFloat width,
                                                                               CGFloat maxHeight)
    NS_SWIFT_NAME(inlineAdaptiveBanner(width:maxHeight:));

#pragma mark Anchored Adaptive Sizes

/// Returns a GADAdSize with the given width and a Google-optimized height to create a banner ad.
/// The size returned has an aspect ratio similar to that of GADAdSizeBanner, suitable for
/// anchoring near the top or bottom of your app. The height is never larger than 15% of the
/// device's portrait height and is always between 50-90 points. This function always returns the
/// same height for any width / device combination.
FOUNDATION_EXPORT GADAdSize GADPortraitAnchoredAdaptiveBannerAdSizeWithWidth(CGFloat width)
    NS_SWIFT_NAME(portraitAnchoredAdaptiveBanner(width:));

/// Returns a GADAdSize with the given width and a Google-optimized height to create a banner ad.
/// The size returned is suitable for use in a banner ad anchored near the top or bottom of your
/// app, similar to use of GADAdSizeBanner. The height is never larger than 15% of the devices's
/// landscape height and is always between 50-90 points. This function always returns the same
/// height for any width / device combination.
FOUNDATION_EXPORT GADAdSize GADLandscapeAnchoredAdaptiveBannerAdSizeWithWidth(CGFloat width)
    NS_SWIFT_NAME(landscapeAnchoredAdaptiveBanner(width:));

/// Returns a GADAdSize with the given width and a Google-optimized height. This is a convenience
/// function to return GADPortraitAnchoredAdaptiveBannerAdSizeWithWidth or
/// GADLandscapeAnchoredAdaptiveBannerAdSizeWithWidth based on the current interface orientation.
/// This function must be called on the main queue.
FOUNDATION_EXPORT GADAdSize GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(
    CGFloat width) NS_SWIFT_NAME(currentOrientationAnchoredAdaptiveBanner(width:));

#pragma mark Custom Sizes

/// Returns a custom GADAdSize for the provided CGSize. Use this only if you require a non-standard
/// size. Otherwise, use one of the standard size constants above.
FOUNDATION_EXPORT GADAdSize GADAdSizeFromCGSize(CGSize size) NS_SWIFT_NAME(adSizeFor(cgSize:));

/// Returns a custom GADAdSize that spans the full width of the application in portrait orientation
/// with the height provided.
FOUNDATION_EXPORT GADAdSize GADAdSizeFullWidthPortraitWithHeight(CGFloat height)
    NS_SWIFT_NAME(fullWidthPortrait(height:));

/// Returns a custom GADAdSize that spans the full width of the application in landscape orientation
/// with the height provided.
FOUNDATION_EXPORT GADAdSize GADAdSizeFullWidthLandscapeWithHeight(CGFloat height)
    NS_SWIFT_NAME(fullWidthLandscape(height:));

#pragma mark Convenience Functions

/// Returns YES if the two GADAdSizes are equal, otherwise returns NO.
FOUNDATION_EXPORT BOOL GADAdSizeEqualToSize(GADAdSize size1, GADAdSize size2)
    NS_SWIFT_NAME(isAdSizeEqualToSize(size1:size2:));

/// Returns YES if |size| is one of the predefined constants or is a custom GADAdSize generated by
/// GADAdSizeFromCGSize.
FOUNDATION_EXPORT BOOL IsGADAdSizeValid(GADAdSize size) NS_SWIFT_NAME(isAdSizeValid(size:));

/// Returns YES if |size| is a fluid ad size.
FOUNDATION_EXPORT BOOL GADAdSizeIsFluid(GADAdSize size) NS_SWIFT_NAME(isAdSizeFluid(size:));

/// Returns a CGSize for the provided a GADAdSize constant. If the GADAdSize is unknown, returns
/// CGSizeZero.
FOUNDATION_EXPORT CGSize CGSizeFromGADAdSize(GADAdSize size) NS_SWIFT_NAME(cgSize(for:));

/// Returns a NSString describing the provided GADAdSize.
FOUNDATION_EXPORT NSString *_Nonnull NSStringFromGADAdSize(GADAdSize size)
    NS_SWIFT_NAME(string(for:));

/// Returns an NSValue representing the GADAdSize.
FOUNDATION_EXPORT NSValue *_Nonnull NSValueFromGADAdSize(GADAdSize size)
    NS_SWIFT_NAME(nsValue(for:));

/// Returns a GADAdSize from an NSValue. Returns GADAdSizeInvalid if the value is not a GADAdSize.
FOUNDATION_EXPORT GADAdSize GADAdSizeFromNSValue(NSValue *_Nonnull value)
    NS_SWIFT_NAME(adSizeFor(nsValue:));

#pragma mark Deprecated

/// An ad size that spans the full width of the application in portrait orientation. The height is
/// typically 50 points on an iPhone/iPod UI, and 90 points tall on an iPad UI.
FOUNDATION_EXPORT GADAdSize const kGADAdSizeSmartBannerPortrait
    GAD_DEPRECATED_MSG_ATTRIBUTE("Use GADPortraitAnchoredAdaptiveBannerAdSizeWithWidth.");

/// An ad size that spans the full width of the application in landscape orientation. The height is
/// typically 32 points on an iPhone/iPod UI, and 90 points tall on an iPad UI.
FOUNDATION_EXPORT GADAdSize const kGADAdSizeSmartBannerLandscape
    GAD_DEPRECATED_MSG_ATTRIBUTE("Use GADLandscapeAnchoredAdaptiveBannerAdSizeWithWidth");
