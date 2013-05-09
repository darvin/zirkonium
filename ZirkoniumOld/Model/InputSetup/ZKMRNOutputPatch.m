//
//  ZKMRNOutputPatch.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOutputPatch.h"
#import "ZKMRNZirkoniumSystem.h"

@implementation ZKMRNOutputPatch
#pragma mark _____ ZKMRNAbstractInOutPatchInternal
- (NSString *)patchChannelEntityName { return @"OutputPatchChannel"; } 
- (NSArray *)channelDescriptionsArray { return [[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] audioOutputDevice] outputChannelNames]; }
- (NSString *)patchDefaultName { return @"Output Patch"; }
@end
