//
//  ZKMRNOutputPatchChannel.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNAbstractInOutPatchChannel.h"

extern NSString* ZKMRNOutputPatchChangedNotification;

@class ZKMRNAbstractInOutPatchChannel;
@interface ZKMRNOutputPatchChannel : ZKMRNAbstractInOutPatchChannel {

}
- (NSString *)entityName;

//  Accessors
- (void)setSourceChannel:(NSNumber *)sourceChannel;
@end
