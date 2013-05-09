//
//  ZKMRMBorderlessWindow.m
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 06.08.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMBorderlessWindow.h"


@implementation ZKMRMBorderlessWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag 
{
	if (!(self = [super initWithContentRect: contentRect styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]))
		return nil;

	[self setBackgroundColor: [NSColor colorWithCalibratedWhite: 0.3f alpha: 0.7f]];
//	[self setBackgroundColor: [NSColor clearColor]];
	[self setLevel: NSStatusWindowLevel];
	[self setAlphaValue: 0.6];
	[self setOpaque: NO];
	[self setHasShadow: NO];

    return self;
}

@end
