//
//  MuseumView.m
//  ZirkoniumMuseum
//
//  Created by Jens on 02.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MuseumView.h"


@implementation MuseumView

- (void)awakeFromNib 
{
	[super awakeFromNib];
	
	self.isShowingInitial = NO;
	self.pieceIsPlaying = YES; 
	self.useCamera = YES; 
	
}

/*
- (void)mouseUp:(NSEvent *)theEvent {}
- (void)mouseDragged:(NSEvent *)theEvent {}
- (void)mouseDown:(NSEvent *)theEvent {}
*/

@end
