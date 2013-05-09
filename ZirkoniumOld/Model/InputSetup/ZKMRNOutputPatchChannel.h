//
//  ZKMRNOutputPatchChannel.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* ZKMRNOutputPatchChangedNotification;


@interface ZKMRNOutputPatchChannel : NSManagedObject {

}

//  Accessors
- (void)setSourceChannel:(NSNumber *)sourceChannel;

@end
