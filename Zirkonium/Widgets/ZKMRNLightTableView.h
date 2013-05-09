//
//  ZKMRNLightTableView.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 19.10.07.
//  Copyright 2007 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString* ZKMRNLightTableChangedNotification;

@class LightController;

@interface ZKMRNLightTableView : NSView {
	LightController*	lightController;
	
	// the starting point in the table (0 for red, 1 for green, 2 for blue) ...
	unsigned				initialIndex;
}

@property (nonatomic, retain) LightController* lightController; 
@property unsigned initialIndex; 


@end
