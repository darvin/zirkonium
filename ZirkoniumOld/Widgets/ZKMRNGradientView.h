//
//  ZKMRNGradientView.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 30.04.08.
//  Copyright 2008 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class ZKMRNLightController;
@interface ZKMRNGradientView : NSView {
	ZKMRNLightController*	_lightController;
	unsigned int			_numberOfSteps;
}

//  Accessors
- (ZKMRNLightController *)lightController;
- (void)setLightController:(ZKMRNLightController *)lightController;

@end
