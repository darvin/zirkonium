//
//  ZKMRMScrollView.m
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 29.09.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMScrollView.h"

NSString* const ZKMRMEscKeyPressedEvent = @"ZKMRMEscKeyPressedEvent";

@implementation ZKMRMScrollView

- (void)keyDown:(NSEvent *)event
{
	if (53 == [event keyCode]) {
		[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRMEscKeyPressedEvent object: self];
	} else
		[super keyDown: event];
}

@end
