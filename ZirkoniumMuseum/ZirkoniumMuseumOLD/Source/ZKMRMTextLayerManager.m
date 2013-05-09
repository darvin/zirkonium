//
//  ZKMRMTextLayerManager.m
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 06.08.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMTextLayerManager.h"
#import "ZKMMDPiece.h"

/*
#define LOREM_IPSUM @"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse facilisis, ipsum ut vulputate pellentesque, enim neque venenatis nibh, sed porttitor metus dolor et lacus. Aliquam mollis dapibus nibh, sed posuere magna tincidunt eget. Nam congue, tellus vel facilisis gravida, nunc nibh rutrum felis, non euismod enim ipsum nec nisi. Aliquam in dolor vel massa bibendum porttitor. Ut vel tortor tortor, sit amet tincidunt nunc. Nulla commodo rutrum mollis. Sed malesuada vulputate dolor, interdum pharetra elit viverra nec. Suspendisse pellentesque sapien in ante mattis nec varius urna rutrum. Sed dignissim pulvinar ligula nec elementum. Donec ultrices, nibh id venenatis luctus, ligula eros mollis ipsum, tempus tempor ante mauris id arcu. Donec mollis dictum nunc ut fermentum. Aenean ac orci vel tellus egestas faucibus. Vivamus at nunc nec metus consequat pulvinar eget non dui. Ut orci ante, sodales non consequat eget, ullamcorper non enim. Aliquam tempus faucibus ligula, sit amet sodales lorem."
*/

#define LOREM_IPSUM @""

@interface ZKMRMTextLayerManager (ZKMRMTextLayerManagerPrivate)

- (void)initializeEffects;
- (void)setScrollPosition:(float)position;
- (void)setText:(NSString *)textString;
- (void)tick:(id)sender;

@end

@implementation ZKMRMTextLayerManager

- (void)dealloc
{
	[textLayer release];
	[scrollLayer release];
	[textAttributes release];
	[scrollTimer invalidate], [scrollTimer release];
	[effects release];
	[blurAnimation release];
	
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	NSFont* textLayerFont = [NSFont fontWithName: @"Helvetica Neue" size: 18.f];
	NSLayoutManager* layoutManager = [[NSLayoutManager alloc] init];
	lineHeight = [layoutManager defaultLineHeightForFont: textLayerFont];
	[layoutManager release];
	
	textLayer = [[CATextLayer layer] retain];	
	textLayer.wrapped = YES;
	textLayer.font = textLayerFont;
	textLayer.fontSize = [textLayerFont pointSize];
	
	textAttributes = [[NSDictionary dictionaryWithObject: textLayerFont forKey: NSFontAttributeName] retain];
	
	CGColorRef fgColor = CGColorCreateGenericRGB(0.8, 0.8, 0.8, 1.0);
	textLayer.foregroundColor = fgColor;
	CGColorRelease(fgColor);
	
	[self setText: @""];
	
	scrollLayer = [[CAScrollLayer layer] retain];
	[scrollLayer addSublayer: textLayer];
	scrollLayer.anchorPoint = CGPointMake(0.f, 0.f);
	scrollLayer.delegate = self;
	scrollLayer.backgroundColor = CGColorCreateGenericGray(0.f, 1.f);
	
	[self initializeEffects];
	
	scrollTimer = [[NSTimer timerWithTimeInterval: 1.f target: self selector: @selector(tick:) userInfo: nil repeats: YES] retain];
	[[NSRunLoop currentRunLoop] addTimer: scrollTimer forMode: NSRunLoopCommonModes];
	
	return self;
}

- (void)initializeEffects
{
	CIFilter* blur = [CIFilter filterWithName: @"CIGaussianBlur"];
	blur.name = @"blur";
	[blur setDefaults];
	effects = [[NSArray arrayWithObject: blur] retain];
	
	blurAnimation = [[CABasicAnimation animationWithKeyPath: @"filters.blur.inputRadius"] retain];
	blurAnimation.duration = 2.f;
	blurAnimation.fromValue = [NSNumber numberWithFloat: 0.f];
	blurAnimation.toValue = [NSNumber numberWithFloat: 15.f];
	blurAnimation.repeatCount = 1;
	blurAnimation.autoreverses = YES;
	blurAnimation.delegate = self;	
}

- (CALayer *)layer { return scrollLayer; }

- (void)setPieceMetadata:(ZKMMDPiece *)piece
{
	NSString* textDE = (piece.textDE) ? piece.textDE : LOREM_IPSUM;
	NSString* textEN = (piece.textEN) ? piece.textEN : LOREM_IPSUM;	
	NSString* pieceTextString = [NSString stringWithFormat: @"%@\n\n%@", textDE, textEN];
	[self setText: pieceTextString];
}

#pragma mark ZKMRMTextLayerManagerPrivate
- (void)setScrollPosition:(float)position
{
	scrollPosition = position;
	[scrollLayer scrollToPoint: CGPointMake(0.f, textLayer.frame.size.height - scrollPosition)];
}

- (void)resetScrollPosition
{
	scrollPosition = 0.f;
	
	[CATransaction begin];

	[CATransaction setValue: [NSNumber numberWithBool: YES] forKey: kCATransactionDisableActions];
	[scrollLayer scrollToPoint: CGPointMake(0.f, textLayer.frame.size.height - scrollPosition)];
	
	[CATransaction commit];
}

- (void)setText:(NSString *)textString
{
	// Setting the layer's text will invalidate the layer, so we don't need
	// to call -setNeedsDisplay directly.
	textLayer.string = textString;
	
	// get text metrics
	NSAttributedString* attrString = [[NSAttributedString alloc] initWithString: textString attributes: textAttributes];
	CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((CFAttributedStringRef) attrString);
	[attrString release];
	CGFloat lineWidth = MAX(scrollLayer.frame.size.width, 300.f);
	
	CFIndex breakIndex, lineCount;
	for (breakIndex = 0, lineCount = 1; breakIndex < [textString length]; lineCount++)
		breakIndex += CTTypesetterSuggestLineBreak(typesetter, breakIndex, lineWidth);
	CFRelease(typesetter);
	
	textLayer.frame = CGRectMake(0.0, 0.0, lineWidth, ceilf(lineCount * lineHeight));
	[self resetScrollPosition];
	
	// Add a blur used for animations	
//	scrollLayer.filters = effects;
//	[scrollLayer addAnimation: blurAnimation forKey: @"blurAnimation"];

}


- (void)tick:(id)sender
{
	if (scrollPosition > textLayer.frame.size.height + scrollLayer.frame.size.height) {
		[self resetScrollPosition];
		return;
	}
	
	float position = scrollPosition + 12.f;
	[self setScrollPosition: position];
}

#pragma mark CALayerDelegate
- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
	if ([@"bounds" isEqualToString: event]) {
		CABasicAnimation* action = [CABasicAnimation animationWithKeyPath: event];
		action.duration = 1.f;
		return action;
	}
	
	return nil;
}

#pragma mark CAAnimationDelegate
- (void)animationDidStart:(CAAnimation *)anim
{
	++runningCount;
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
	if (--runningCount < 1)
		scrollLayer.filters = nil;
}


@end
