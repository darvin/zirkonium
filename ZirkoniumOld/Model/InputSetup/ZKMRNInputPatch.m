//
//  ZKMRNInputConfig.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 04.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNInputPatch.h"
#import "ZKMRNZirkoniumSystem.h"


@implementation ZKMRNInputPatch
#pragma mark _____ ZKMRNAbstractInOutPatchInternal
- (NSString *)patchChannelEntityName { return @"InputPatchChannel"; } 
- (NSArray *)channelDescriptionsArray { return [[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] audioOutputDevice] inputChannelNames]; }
- (NSString *)patchDefaultName { return @"Input Patch"; }
@end
