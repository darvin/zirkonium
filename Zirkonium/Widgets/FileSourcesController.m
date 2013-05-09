//
//  FileSourcesController.m
//  Zirkonium
//
//  Created by Jens on 21.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FileSourcesController.h"


@implementation FileSourcesController
@synthesize delegate; 

#pragma mark -
#pragma mark Custom Overrides
#pragma mark -

- (void)add:(id)sender
{
	if([self.delegate canAddFileSource]) 
		[super add:sender];
}

- (void)addObject:(id)object
{
	if([self.delegate canAddFileSource]) 
		[super addObject:object];
}

- (void)addObjects:(NSArray *)objects
{
	if([self.delegate canAddFileSource]) 
		[super addObjects:objects]; 
}

- (BOOL)addSelectedObjects:(NSArray *)objects
{
	if([self.delegate canAddFileSource]) 
		return [super addSelectedObjects:objects]; 

	return NO; 
}

- (BOOL)addSelectionIndexes:(NSIndexSet *)indexes
{
	if([self.delegate canAddFileSource]) 
		return [super addSelectionIndexes:indexes]; 

	return NO; 
}

@end
