//
//  ZKMRNAudioSource.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNAudioSource.h"


@implementation ZKMRNAudioSource
#pragma mark _____ Accessors
- (ZKMORConduit *)conduit { return nil; }

#pragma mark _____Actions
	// do nothing by default
- (void)setCurrentTime:(Float64)seconds { }

#pragma mark _____ Queries
- (BOOL)isConduitValid { return NO; }

#pragma mark _____ ZKMRNManagedObjectExtensions
+ (NSArray *)copyKeys 
{ 
	static NSArray* copyKeys = nil;
	if (!copyKeys) {
		copyKeys = [[NSArray alloc] initWithObjects: @"name", @"numberOfChannels", nil];
	}
	
	return copyKeys;
}
@end
