//
//  ZKMRNBassOutPatchChannel.h
//  Zirkonium
//
//  Created by R. Chandrasekhar on 7/11/13.
//
//

#import "ZKMRNAbstractInOutPatchChannel.h"

@interface ZKMRNBassOutPatchChannel : ZKMRNAbstractInOutPatchChannel {

}

- (NSString *)entityName;

- (NSNumber *)gain;
- (void)setGain:(NSNumber *)gain;

@end
