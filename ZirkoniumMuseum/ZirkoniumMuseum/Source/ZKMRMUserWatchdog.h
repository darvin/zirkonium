//
//  ZKMRMUserWatchdog.h
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 03.09.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZKMRMUserWatchdog : NSObject {
	CFMachPortRef	eventTap;
	NSDate*			lastEventDate;
}

@end
