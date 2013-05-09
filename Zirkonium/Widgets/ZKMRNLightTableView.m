//
//  ZKMRNLightTableView.m
//  Zirkonium
//
//  Created by C. Ramakrishnan on 19.10.07.
//  Copyright 2007 Illposed Software. All rights reserved.
//

#import "ZKMRNLightTableView.h"
#import "LightController.h"
#import <Syncretism/ZKMORUtilities.h>

NSString* ZKMRNLightTableChangedNotification = @"ZKMRNLightTableChangedNotification";

@interface ZKMRNLightTableView (ZKMRNLightTableViewPrivate)
- (NSColor *)backgroundColor;
- (NSColor *)tableColor;
@end

@implementation ZKMRNLightTableView
@synthesize lightController; 
@synthesize initialIndex;

#pragma mark -
#pragma mark NSView
- (id)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;;

	self.initialIndex = 0;

    return self;
}

- (void)drawRect:(NSRect)rect {
	[[self backgroundColor] set];
	NSRect boundsRect = [self bounds];
	NSRectFill(boundsRect);
	
	[[self tableColor] set];

	CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];	
	unsigned lightTableSize = dbLightTableSize;
	float* lightTable = [self.lightController uiSelectedLightTable];
	
	lightTable += self.initialIndex;
	
	NSSize penSize = [self convertSize: NSMakeSize(1, 1) fromView: nil];
	CGContextSetLineWidth(ctx, MAX(penSize.width, penSize.height));
	
	unsigned i;
	float x = boundsRect.origin.x;
	float y = boundsRect.origin.y + boundsRect.size.height * ZKMORClamp(*lightTable, 0.f, 1.f);
	
	float xStride = boundsRect.size.width / lightTableSize;
	
	CGContextBeginPath(ctx);	
	CGContextMoveToPoint(ctx, x, y);
	for (i = 0; i < lightTableSize - 1; ++i) {
		lightTable += 3;	
		x += xStride;	
		y = boundsRect.origin.y + boundsRect.size.height * ZKMORClamp(*lightTable, 0.f, 1.f);
		CGContextAddLineToPoint(ctx, x, y);
	}
	CGContextStrokePath(ctx);
}
#pragma mark -
#pragma mark ZKMRNLightTableViewPrivate
- (NSColor *)backgroundColor { return [NSColor whiteColor]; }
- (NSColor *)tableColor { return [NSColor blackColor]; }

-(void)update
{
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNLightTableChangedNotification object: self];		
	[self setNeedsDisplay: YES];
}

-(void)processMouse:(NSEvent*)theEvent
{
	NSRect bounds = [self bounds];
	NSPoint localPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	unsigned lightTableSize = dbLightTableSize;
	float* lightTable = [self.lightController uiSelectedLightTable];
	
	unsigned tableIndex = ((localPoint.x - bounds.origin.x) / bounds.size.width) * lightTableSize; 
	tableIndex = MAX(0, MIN(tableIndex, lightTableSize - 1));
	
	float tableValue = (localPoint.y - bounds.origin.y) / bounds.size.height;
	
	unsigned index = 3 * tableIndex + self.initialIndex; 
	lightTable[3 * tableIndex + self.initialIndex] = tableValue;
	
	[self update];
}

#pragma mark -
#pragma mark NSResponder
- (void)mouseDown:(NSEvent *)theEvent
{
	[self processMouse:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	[self processMouse:theEvent];
}


@end
