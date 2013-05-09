//
//  ItemView.m
//  ZirkoniumMuseum
//
//  Created by Jens on 19.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ItemView.h"

@implementation ItemView

-(void)setSelected:(BOOL)flag
{
	NSBox* box = (NSBox*)[[self subviews] objectAtIndex:0] ;	
	NSTextField* text1 = (NSTextField*)[[[[box subviews] objectAtIndex:0] subviews] objectAtIndex:1];
	NSTextField* text2 = (NSTextField*)[[[[box subviews] objectAtIndex:0] subviews] objectAtIndex:2];
	
	if(!flag) {
		
		// Unselected ...
		[box setFillColor:[NSColor blackColor]];
		[text1 setTextColor:[NSColor whiteColor]];
		[text2 setTextColor:[NSColor whiteColor]];
		
	} else {
		// Selected ...
		
		[box setFillColor:[NSColor whiteColor]];
		[text1 setTextColor:[NSColor blackColor]];
		[text2 setTextColor:[NSColor blackColor]];


	}
	
	[self setNeedsDisplay:YES];
}

@end
