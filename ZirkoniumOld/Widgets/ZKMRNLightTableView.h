//
//  ZKMRNLightTableView.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 19.10.07.
//  Copyright 2007 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString* ZKMRNLightTableChangedNotification;

@class ZKMRNLightController;
@interface ZKMRNLightTableView : NSView {
	ZKMRNLightController*	_lightController;
		/// the starting point in the table (0 for red, 1 for green, 2 for blue)
	unsigned				_initialIndex;
}

//  Accessors
- (ZKMRNLightController *)lightController;
- (void)setLightController:(ZKMRNLightController *)lightController;

- (unsigned)initialIndex;
- (void)setInitialIndex:(unsigned)initialIndex;

@end
