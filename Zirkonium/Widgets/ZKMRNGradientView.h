//
//  ZKMRNGradientView.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 30.04.08.
//  Copyright 2008 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class LightController;

@interface ZKMRNGradientView : NSView {
	
	LightController*	lightController;
	unsigned int		_numberOfSteps;
}
@property (nonatomic, retain) LightController* lightController; 

@end
