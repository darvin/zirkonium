//
//  ZKMNRRoom.m
//  Zirkonium
//
//  Created by Jens on 08.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNRoom.h"

@class ZKMRNZirkoniumSystem;
@implementation ZKMRNRoom

-(BOOL)isPreferenceSelected
{
	if([[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] room] isEqualTo:self]) {
		return YES;
	}
	return NO; 
}

@end
