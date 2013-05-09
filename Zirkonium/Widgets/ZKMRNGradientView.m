//
//  ZKMRNGradientView.m
//  Zirkonium
//
//  Created by C. Ramakrishnan on 30.04.08.
//  Copyright 2008 Illposed Software. All rights reserved.
//

#import "ZKMRNGradientView.h"
#import "LightController.h"
#import "ZKMRNLightTableView.h"
#import <Syncretism/ZKMORUtilities.h>


@interface ZKMRNGradientView (ZKMRNGradientViewPrivate)
- (NSColor *)backgroundColor;
- (NSColor *)tableColor;
@end


@implementation ZKMRNGradientView
@synthesize lightController; 

#pragma mark -
#pragma mark NSView
- (void)dealloc
{
	self.lightController = nil; 
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
	
	[[NSNotificationCenter defaultCenter] 
		addObserver: self 
		selector: @selector(lightTableChanged:)
		name: ZKMRNLightTableChangedNotification 
		object: nil];

    return self;
}

- (void)drawRect:(NSRect)rect {
	[[self backgroundColor] set];
	NSRect boundsRect = [self bounds];
	NSRectFill(boundsRect);

	CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];	
	unsigned lightTableSize = dbLightTableSize;
	float* lightTable = [self.lightController uiSelectedLightTable];
	
	NSSize penSize = [self convertSize: NSMakeSize(1, 1) fromView: nil];
	CGContextSetLineWidth(ctx, MAX(penSize.width, penSize.height));
	
	unsigned i;
	float xStride = boundsRect.size.width / (lightTableSize - 1);
	CGRect colorBlock = CGRectMake(boundsRect.origin.x, boundsRect.origin.y, xStride, boundsRect.size.height);

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	for (i = 0; i < lightTableSize - 1; ++i) {
		[[NSColor colorWithDeviceRed: lightTable[0] green: lightTable[1] blue: lightTable[2] alpha: 1.f] set];
		CGContextFillRect(ctx, colorBlock);
		lightTable += 3;
		colorBlock.origin.x += xStride;
	}
	[pool release];
}

#pragma mark -
#pragma mark ZKMRNLightTableViewPrivate
- (NSColor *)backgroundColor { return [NSColor blackColor]; }
- (NSColor *)tableColor { return [NSColor whiteColor]; }

- (void)lightTableChanged:(NSNotification *)notification
{
	[self setNeedsDisplay: YES];
}

@end
