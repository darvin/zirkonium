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

- (float)gain
{
	// TODO BASS OUT should store this value
	return 0.05f;
}

- (void)setGain:(float)gain
{
	[self willChangeValueForKey: @"gain"];
	[self setPrimitiveValue: [NSNumber numberWithFloat: gain] forKey: @"gain"];
	[self didChangeValueForKey: @"gain"];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object: self];
}

@end
