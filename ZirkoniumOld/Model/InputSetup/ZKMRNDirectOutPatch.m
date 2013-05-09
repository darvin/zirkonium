//
//  ZKMRNDirectOutPatch.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 13.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNDirectOutPatch.h"
#import "ZKMRNZirkoniumSystem.h"

@implementation ZKMRNDirectOutPatch
#pragma mark _____ ZKMRNAbstractInOutPatchInternal
- (NSString *)patchChannelEntityName { return @"DirectOutPatchChannel"; } 
- (NSArray *)channelDescriptionsArray { return [[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] audioOutputDevice] outputChannelNames]; }
- (NSString *)patchDefaultName { return @"Direct Out Patch"; }

- (unsigned)numberOfChannels { return [[self valueForKey: @"channels"] count]; }

@end
