//
//  ZKMRNOutputPatchChannel.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOutputPatchChannel.h"

NSString* ZKMRNOutputPatchChangedNotification = @"ZKMRNOutputPatchChangedNotification";

@implementation ZKMRNOutputPatchChannel

#pragma mark _____ Accessors
- (void)setSourceChannel:(NSNumber *)sourceChannel
{
	[self willChangeValueForKey: @"sourceChannel"];
	[self setPrimitiveValue: sourceChannel forKey: @"sourceChannel"];
	[self didChangeValueForKey: @"sourceChannel"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNOutputPatchChangedNotification object: self];
}

@end
