//
//  ZKMRMTextLayerManager.h
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 06.08.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>


@class ZKMMDPiece;
@interface ZKMRMTextLayerManager : NSObject {
	CATextLayer*	textLayer;
	CAScrollLayer*	scrollLayer;
		// for getting text metrics
	CGFloat			lineHeight;
	NSDictionary*	textAttributes;
	
		// for automated scrolling
	NSTimer*		scrollTimer;
	float			scrollPosition;
	
	float lineWidth; 
	
		// effects
	NSArray*			effects;
	CABasicAnimation*	blurAnimation;
	int					runningCount;
	
}

@property(readonly) CALayer* layer;

- (id)initWithLineWidth:(float)width;
- (void)setPieceMetadata:(ZKMMDPiece *)piece;

-(void)close;

-(void)startScrollTimer;
-(void)stopScrollTimer; 


@end
