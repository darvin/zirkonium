//
//  ZKMRNAbstractInOutPatch.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 13.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZKMRNAbstractInOutPatch : NSManagedObject {

}

//  Accessors
- (void)setNumberOfChannels:(NSNumber *)numberOfChannels;
- (NSArray *)channelDescriptions;

@end

@interface ZKMRNAbstractInOutPatch (ZKMRNAbstractInOutPatchInternal)
//  Subclass Overrides
- (NSString *)patchChannelEntityName;
- (NSArray *)channelDescriptionsArray;
- (NSString *)patchDefaultName;

@end

