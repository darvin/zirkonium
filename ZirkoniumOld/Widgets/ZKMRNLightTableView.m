//
//  ZKMRNLightTableView.m
//  Zirkonium
//
//  Created by C. Ramakrishnan on 19.10.07.
//  Copyright 2007 Illposed Software. All rights reserved.
//

#import "ZKMRNLightTableView.h"
#import "ZKMRNLightController.h"
#import <Syncretism/ZKMORUtilities.h>

NSString* ZKMRNLightTableChangedNotification = @"ZKMRNLightTableChangedNotification";

@interface ZKMRNLightTableView (ZKMRNLightTableViewPrivate)
- (NSColor *)backgroundColor;
- (NSColor *)tableColor;
@end

@implementation ZKMRNLightTableView
#pragma mark -
#pragma mark NSView
- (id)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;;

	_initialIndex = 0;

    return self;
}

- (void)drawRect:(NSRect)rect {
	[[self backgroundColor] set];
	NSRect boundsRect = [self bounds];
	NSRectFill(boundsRect);
	
	[[self tableColor] set];

	CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];	
	unsigned lightTableSize = [_lightController dbLightTableSize];
	float* lightTable = [_lightController dbLightTable];
	lightTable += _initialIndex;
	
	NSSize penSize = [self convertSize: NSMakeSize(1, 1) fromView: nil];
	CGContextSetLineWidth(ctx, MAX(penSize.width, penSize.height));
	
	unsigned i;
	float x = boundsRect.origin.x, y = boundsRect.origin.y + boundsRect.size.height * ZKMORClamp(*lightTable, 0.f, 1.f);
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
#pragma mark Accessors
- (ZKMRNLightController *)lightController { return _lightController; }
- (void)setLightController:(ZKMRNLightController *)lightController { _lightController = lightController; }

- (unsigned)initialIndex { return _initialIndex; }
- (void)setInitialIndex:(unsigned)initialIndex { _initialIndex = initialIndex; }

#pragma mark -
#pragma mark ZKMRNLightTableViewPrivate
- (NSColor *)backgroundColor { return [NSColor whiteColor]; }
- (NSColor *)tableColor { return [NSColor blackColor]; }

#pragma mark -
#pragma mark NSResponder
- (void)mouseDown:(NSEvent *)theEvent
{
	NSRect bounds = [self bounds];
	NSPoint localPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	unsigned lightTableSize = [_lightController dbLightTableSize];
	float* lightTable = [_lightController dbLightTable];
	
	unsigned tableIndex = ((localPoint.x - bounds.origin.x) / bounds.size.width) * lightTableSize; 
	float tableValue = (localPoint.y - bounds.origin.y) / bounds.size.height;
	lightTable[3 * tableIndex + _initialIndex] = tableValue;
	
	BOOL keepProcessing = YES;
	while (keepProcessing) {
		theEvent = [[self window] nextEventMatchingMask: (NSLeftMouseUpMask | NSLeftMouseDraggedMask)];
		localPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
				tableIndex = MIN(((localPoint.x - bounds.origin.x) / bounds.size.width) * lightTableSize, lightTableSize - 1); 
				tableValue = (localPoint.y - bounds.origin.y) / bounds.size.height;
				lightTable[3 * tableIndex + _initialIndex] = tableValue;
				[self setNeedsDisplay: YES];
				break;
			case NSLeftMouseUp:
				keepProcessing = NO;
				break;
			default:
				keepProcessing = NO;
				break;
		}
		[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNLightTableChangedNotification object: self];		
	}
	
	[self setNeedsDisplay: YES];
}


@end
