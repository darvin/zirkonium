//
//  ZKMRMLightController.h
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 10.09.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNLightController.h"

/// 
///  ZKMRMLightController
///
///  Replaces the Light Controller, because the Museum has an integrated 
///  connection to the LanBox and does not need to send light commnads over
///  the network 
///
@interface ZKMRMLightController : ZKMRNLightController {
		//  Panner State
	NSMutableArray*		lightIds;
}

@end
