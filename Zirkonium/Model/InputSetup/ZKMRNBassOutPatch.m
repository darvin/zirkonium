//
//  ZKMRNBassOutPatch.m
//  Zirkonium
//
//  Created by R. Chandrasekhar on 7/10/13.
//
//

#import "ZKMRNBassOutPatch.h"
#import "ZKMRNZirkoniumSystem.h"

@implementation ZKMRNBassOutPatch

#pragma mark _____ ZKMRNAbstractInOutPatchInternal
- (NSString *)patchChannelEntityName { return @"BassOutPatchChannel"; }

- (NSArray *)channelDescriptionsArray { return [[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] audioOutputDevice] outputChannelNames]; }

- (NSString *)patchDefaultName { return @"Bass Out Patch"; }

- (unsigned)numberOfChannels { return [[self valueForKey: @"channels"] count]; }

@end
