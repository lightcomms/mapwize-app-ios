#import <Foundation/Foundation.h>

@interface MWZAccountManager : NSObject

@property (nonatomic, retain) NSString* apiKey;
@property (nonatomic, retain) NSString* customApiUrl;

+ (instancetype) sharedInstance;

@end
