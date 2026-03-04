//
//  GADMediationAd.h
//  Google Mobile Ads SDK
//
//  Copyright 2018 Google LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

/// Rendered ad. Objects conforming to this protocol are created by the adapter and returned to
/// the Google Mobile Ads SDK through the adapter's render method completion handler.
NS_SWIFT_NAME(MediationAd)
@protocol GADMediationAd <NSObject>
@end
