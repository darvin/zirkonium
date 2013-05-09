//
//  ZKMRNEventsArrayController.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 14.02.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum ZKMRNEventAddModes {
	kZKMRNEventAddMode_Spherical = 0,
	kZKMRNEventAddMode_Cartesian = 1
};

@interface ZKMRNEventsArrayController : NSArrayController {
	unsigned	_addMode;
}

//  Accessors
- (int)isSpherical;
- (void)setSpherical:(int)isSpherical;

- (int)isCartesian;
- (void)setCartesian:(int)isCartesian;

//  Actions
- (IBAction)changeMode:(id)sender;

@end
