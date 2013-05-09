//
//  ZKMRNInputSource.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 08.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNInputSource.h"
#import "ZKMRNZirkoniumSystem.h"


@implementation ZKMRNInputSource
#pragma mark _____ Accessors
- (ZKMORConduit *)conduit
{
	ZKMRNZirkoniumSystem* system = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
	return [system deviceInput];
}

#pragma mark _____ Queries
- (BOOL)isConduitValid 
{
	ZKMRNZirkoniumSystem* system = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
	return [[system deviceInput] isValid]; 
}

@end
