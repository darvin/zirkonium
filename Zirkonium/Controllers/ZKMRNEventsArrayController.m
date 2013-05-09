//
//  ZKMRNEventsArrayController.m
//  Zirkonium
//
//  Created by C. Ramakrishnan on 14.02.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNEventsArrayController.h"


@implementation ZKMRNEventsArrayController

#pragma mark -
#pragma mark Accessors
- (int)isSpherical { return _addMode == kZKMRNEventAddMode_Spherical; }
- (void)setSpherical:(int)isSpherical {
	[self willChangeValueForKey: @"cartesian"];
	_addMode = (isSpherical) ? kZKMRNEventAddMode_Spherical : kZKMRNEventAddMode_Cartesian; 
	[self didChangeValueForKey: @"cartesian"];	
}

- (int)isCartesian { return _addMode == kZKMRNEventAddMode_Cartesian; }
- (void)setCartesian:(int)isCartesian
{
	[self willChangeValueForKey: @"spherical"];
	_addMode = (isCartesian) ? kZKMRNEventAddMode_Cartesian : kZKMRNEventAddMode_Spherical; 
	[self didChangeValueForKey: @"spherical"];	
}

#pragma mark -
#pragma mark Actions
// dummy method -- does nothing
- (IBAction)changeMode:(id)sender { }

#pragma mark -
#pragma mark NSArrayController Overrides
- (void)add:(id)sender
{
	NSManagedObjectContext*  moc = [self managedObjectContext];
	id newObject;
	if (kZKMRNEventAddMode_Spherical == _addMode) {
		newObject = [NSEntityDescription insertNewObjectForEntityForName: @"PositionEvent" inManagedObjectContext: moc];
	} else {
		newObject = [NSEntityDescription insertNewObjectForEntityForName: @"CartesianEvent" inManagedObjectContext: moc];	
	}
	
	[self addObject: newObject];
}

/* DEBUG
- (void)addObject:(id)object
{
	[super addObject: object];
}
*/

@end
