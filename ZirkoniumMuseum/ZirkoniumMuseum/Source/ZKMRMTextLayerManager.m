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

#pragma mark -
#pragma mark Initialize
#pragma mark -

- (id)initWithLineWidth:(float)width
{
	if (!(self = [super init])) return nil;
	
	lineWidth = width; 
	
	//[self initializeTextLayer];
		
	[self setText: @""];
	
	[self initializeEffects];
	
	return self;
}

#pragma mark -
#pragma mark Scroll (Scroll Layer)
#pragma mark -

-(void)initializeScrollLayer
{
	if(scrollLayer)
		[scrollLayer release]; 
	scrollLayer = nil;
	
	scrollLayer = [[CAScrollLayer layer] retain];
	scrollLayer.anchorPoint = CGPointMake(0.f, 0.f);
	scrollLayer.delegate = self;
	scrollLayer.backgroundColor = CGColorCreateGenericGray(0.f, 1.f);
}

- (CALayer *)layer 
{ 
	return scrollLayer; 
}

#pragma mark -

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

#pragma mark -
#pragma mark Text (Text Layer)
#pragma mark -

-(void)initializeTextLayerWithString:(NSString*)textString
{
	if(!scrollLayer) {
		[self initializeScrollLayer];
	} else {
		[scrollLayer removeAllAnimations]; 
		
		NSArray* sublayers = [[scrollLayer sublayers] retain];
		for(CALayer* sublayer in sublayers)
			[sublayer removeFromSuperlayer];
		[sublayers release]; 
	}

	// Font ...
	NSFont* textLayerFont = [NSFont fontWithName: @"Helvetica Neue Light" size: 18.f];
	NSLayoutManager* layoutManager = [[NSLayoutManager alloc] init];
	lineHeight = [layoutManager defaultLineHeightForFont: textLayerFont];
	[layoutManager release];
	
	// Text Layer ...
	if(textLayer)
		[textLayer release]; 
	textLayer = nil; 	
	
	textLayer = [[CATextLayer layer] retain];	
	textLayer.wrapped = YES;
	textLayer.font = textLayerFont;
	textLayer.fontSize = [textLayerFont pointSize];
	
	textAttributes = [[NSDictionary dictionaryWithObject: textLayerFont forKey: NSFontAttributeName] retain];
	
	CGColorRef fgColor = CGColorCreateGenericRGB(1.0, 1.0, 1.0, 1.0);
	textLayer.foregroundColor = fgColor;
	CGColorRelease(fgColor);
	
	textLayer.string = textString;
	
	// Calculate Text Frame ...
	NSAttributedString* attrString = [[NSAttributedString alloc] initWithString: textString attributes: textAttributes];
	CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((CFAttributedStringRef) attrString);
	
	[attrString release];
	CGFloat width = MAX(scrollLayer.frame.size.width, lineWidth);
	CGFloat height = 24.0; 
	
	CFIndex breakIndex, lineCount;
	for (breakIndex = 0, lineCount = 1; breakIndex < [textString length]; lineCount++)
		breakIndex += CTTypesetterSuggestLineBreak(typesetter, breakIndex, width);
	CFRelease(typesetter);
	
	textLayer.frame = CGRectMake(0.0, 0.0, lineWidth, ceilf(lineCount * height));
					
	[scrollLayer addSublayer: textLayer];
}

#pragma mark -

- (void)setPieceMetadata:(ZKMMDPiece *)piece
{
	NSString* textDE = (piece.textDE) ? piece.textDE : LOREM_IPSUM;
	NSString* textEN = (piece.textEN) ? piece.textEN : LOREM_IPSUM;	
	NSString* pieceTextString = [NSString stringWithFormat: @"%@\n\n%@", textDE, textEN];
	[self setText: pieceTextString];
}

- (void)setText:(NSString *)textString
{
	[self stopScrollTimer];
	
	[self initializeTextLayerWithString:textString];

	[self resetScrollPosition];
	
	[self startScrollTimer];
}



#pragma mark -
#pragma mark Scroll Timer
#pragma mark -

-(void)startScrollTimer
{
	[self stopScrollTimer];
	
	scrollTimer = [[NSTimer timerWithTimeInterval: 0.5f target: self selector: @selector(tick:) userInfo: nil repeats: YES] retain];
	[[NSRunLoop currentRunLoop] addTimer: scrollTimer forMode: NSRunLoopCommonModes];
}

-(void)stopScrollTimer
{
	if(scrollTimer) {
		[scrollTimer invalidate];
		[scrollTimer release];
	}
	scrollTimer = nil; 
}

- (void)tick:(id)sender
{
	//NSLog(@"%f > %f", scrollPosition, textLayer.frame.size.height);
	
	if (scrollPosition > textLayer.frame.size.height + scrollLayer.frame.size.height) {
		[self resetScrollPosition];
		return;
	}
	
	float position = scrollPosition + 12.f;
	[self setScrollPosition: position];
}

#pragma mark -
#pragma mark Effects
#pragma mark -

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

#pragma mark -
#pragma mark CALayerDelegate
#pragma mark -

- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
	if ([@"bounds" isEqualToString: event]) {
		CABasicAnimation* action = [CABasicAnimation animationWithKeyPath: event];
		action.duration = 0.5f;
		return action;
	}
	
	return nil;
}

#pragma mark -
#pragma mark CAAnimationDelegate
#pragma mark -

- (void)animationDidStart:(CAAnimation *)anim
{
	++runningCount;
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
	if (--runningCount < 1)
		scrollLayer.filters = nil;
}

#pragma mark -
#pragma mark Clean Up
#pragma mark -

-(void)close
{
	//NSLog(@"ZKMRMTextLayerManager Close");
	
	[self stopScrollTimer];
	[effects release];
	[blurAnimation release];
	
	}

- (void)dealloc
{
	//NSLog(@"ZKMRMTextLayerManager Dealloc");
	
	[textAttributes release];
	[textLayer release];
	[scrollLayer release];


	[super dealloc];
}


@end
