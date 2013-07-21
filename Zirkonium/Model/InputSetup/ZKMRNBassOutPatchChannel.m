//
//  ZKMRNBassOutPatchChannel.m
//  Zirkonium
//
//  Created by R. Chandrasekhar on 7/11/13.
//
//

#import "ZKMRNBassOutPatchChannel.h"

@implementation ZKMRNBassOutPatchChannel

- (NSString *)entityName { return @"BassOutPatchChannel"; }

- (NSNumber *)gain
{
	// TODO BASS OUT should store this value
	return [NSNumber numberWithFloat: 0.05f];
}

- (void)setGain:(NSNumber *)gain
{
	[self willChangeValueForKey: @"gain"];
	[self setPrimitiveValue: gain forKey: @"gain"];
	[self didChangeValueForKey: @"gain"];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object: self];
}

@end
