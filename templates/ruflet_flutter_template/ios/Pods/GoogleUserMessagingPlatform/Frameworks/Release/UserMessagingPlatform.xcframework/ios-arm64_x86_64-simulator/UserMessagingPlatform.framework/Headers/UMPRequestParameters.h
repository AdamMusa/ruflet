#import <UserMessagingPlatform/UMPDebugSettings.h>

/// Parameters sent on updates to user consent info.
NS_SWIFT_NAME(RequestParameters)
@interface UMPRequestParameters : NSObject <NSCopying>

/// Indicates whether the user is tagged for under age of consent.
@property(nonatomic) BOOL tagForUnderAgeOfConsent NS_SWIFT_NAME(isTaggedForUnderAgeOfConsent);

/// Debug settings for the request.
@property(nonatomic, copy, nullable) UMPDebugSettings *debugSettings;

/// The consent sync ID to sync the user consent status collected with the same ID.
///
/// The consent sync ID must meet the following requirements:
/// - Constructed as a UUID string, or matches the regular expression (regex)
/// ^[0-9a-zA-Z+.=\/_\-$,{}]{22,150}$ .
/// - A minimum of 22 characters.
/// - A maximum of 150 characters.
///
/// Failure to meet the requirements results in the consent sync ID not being set and the UMP SDK
/// logging a warning to the console.
@property(nonatomic, copy, nullable) NSString *consentSyncID;

@end
