//
//  ZKMRMTableView.m
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 11.09.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMTableView.h"


@implementation ZKMRMTableView

- (void)highlightSelectionInClipRect:(NSRect)clipRect
{
//	NSLog(@"highlightSelectionInClipRect:");
//NSTextFieldCell
}

/*
- (void)keyDown:(NSEvent *)event
{
	if (53 == [event keyCode])
		NSLog(@"Table View ESC");
	else
		[super keyDown: event];
}
*/

@end

@implementation ZKMRMTableViewTextFieldCell

- (void)awakeFromNib
{
	NSDictionary* fontDescriptorDict =
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Helvetica Neue", NSFontFamilyAttribute,
			@"Light", NSFontFaceAttribute,
			nil];
	NSFontDescriptor* descriptor = [NSFontDescriptor fontDescriptorWithFontAttributes: fontDescriptorDict];
	NSFont* font = [NSFont fontWithDescriptor: descriptor size: 14.f];
	[self setFont: font];
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	return nil;
}

@end
