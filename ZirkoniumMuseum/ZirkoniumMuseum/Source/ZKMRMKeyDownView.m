//
//  ZKMRMKeyDownView.m
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 29.09.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMKeyDownView.h"


@implementation ZKMRMKeyDownView

- (BOOL)acceptsFirstResponder { return YES; }

- (void)keyDown:(NSEvent *)event
{
	if (53 == [event keyCode])
		NSLog(@"View ESC");
	else
		[super keyDown: event];
}

@end
