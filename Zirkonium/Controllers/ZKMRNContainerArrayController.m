//
//  ZKMRNContainerArrayController.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 04.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNContainerArrayController.h"


@implementation ZKMRNContainerArrayController

#pragma mark _____ NSObjectController Overrides

#pragma mark _____ NSArrayController Overrides
- (NSArray *)arrangeObjects:(NSArray *)objects
{
	NSSortDescriptor* sortDesc = [[NSSortDescriptor alloc] initWithKey: @"displayString" ascending: YES];
	NSArray* descriptors = [NSArray arrayWithObject: sortDesc];
	NSArray* sortedObjects =  [objects sortedArrayUsingDescriptors: descriptors];
	return sortedObjects;
}

@end
