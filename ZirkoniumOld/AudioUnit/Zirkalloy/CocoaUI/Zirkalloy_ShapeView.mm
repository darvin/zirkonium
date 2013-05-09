#import "Zirkalloy_ShapeView.h"

@interface Zirkalloy_ShapeView (ShapeViewPrivate)
-(void)updateCoords:(NSPoint)pos;

-(NSPoint)shapeToScreen:(NSPoint)sh;
-(NSPoint)screenToShape:(NSPoint)sc;
@end

static const float kPolarRadius = 1.0f;
static const float kDotRadius = 5.0f;

@implementation Zirkalloy_ShapeView

NSString *kShapeViewDataChangedNotification = @"Zirkalloy_ShapeViewDataChangedNotification";
NSString *kShapeViewBeginGestureNotification = @"Zirkalloy_ShapeViewBeginGestureNotification";
NSString *kShapeViewEndGestureNotification = @"Zirkalloy_ShapeViewEndGestureNotification";

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
    {
        float w;
        float h;
        // Aspect ratio
        if (frameRect.size.width > frameRect.size.height)
        {
            w = h = frameRect.size.height;
        }
        else
        {
            w = h = frameRect.size.width;
        }
        
        mShapeFrame = NSMakeRect(0.0f, 0.0f, w, h);
        
        mCentre.x = frameRect.size.width / 2;
        mCentre.y = frameRect.size.height / 2;
        
		[self setPostsFrameChangedNotifications: YES];
	}
	return self;
}

-(void) dealloc
{	
    if (mBackgroundCache)
    {
        [mBackgroundCache release];
        mBackgroundCache = NULL;
	}
    
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{    
    NSBezierPath * path;
    NSPoint centre = { mShapeFrame.size.width / 2, mShapeFrame.size.height / 2 };
    
    if (!mBackgroundCache)
    {
		mBackgroundCache = [[NSImage alloc] initWithSize: [self frame].size];
        
		[mBackgroundCache lockFocus];
        
        [[NSColor whiteColor] setFill];
        [[NSColor blackColor] setStroke];
        
        path = [NSBezierPath bezierPathWithRect:rect];
        [path fill];
        [path stroke];
        
        NSRect centreDot = { { centre.x - kDotRadius / 2, centre.y - kDotRadius / 2 },
            { kDotRadius, kDotRadius } };
        path = [NSBezierPath bezierPathWithOvalInRect:centreDot];
        [[NSColor blackColor] setFill];
        [path fill];
        [path stroke];
        
        [mBackgroundCache unlockFocus];
    }
    
    [mBackgroundCache drawInRect: rect fromRect: rect operation: NSCompositeSourceOver fraction: 1.0];
    
    NSPoint screenOffset = [self shapeToScreen:mShapeSize];
    NSRect span = { { mCentre.x - screenOffset.x, mCentre.y - screenOffset.y },
                    { screenOffset.x * 2, screenOffset.y * 2 } };
    
    path = [NSBezierPath bezierPathWithRect:span];
    [[NSColor grayColor] setFill];
    [path fill];
    [path stroke];
}


#pragma mark ___ Events ___
-(void) mouseDown:(NSEvent *)e
{
	NSPoint mouseLoc = [self convertPoint:[e locationInWindow] fromView:nil];
	mMouseDown = YES;
	
	[[NSNotificationCenter defaultCenter] postNotificationName: kShapeViewBeginGestureNotification object:self];
	[self updateCoords: mouseLoc];
	
	[self setNeedsDisplay:YES];	// update the display of the crosshairs
}

- (void)mouseDragged:(NSEvent *)e
{
	NSPoint mouseLoc = [self convertPoint:[e locationInWindow] fromView:nil];
	mMouseDown = YES;
	[self updateCoords: mouseLoc];
}

- (void)mouseUp:(NSEvent *)e
{
	mMouseDown = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName: kShapeViewEndGestureNotification object:self];
    
	[self setNeedsDisplay:YES];
}

-(void) handleBeginGesture
{
	mMouseDown = YES;
	[self setNeedsDisplay: YES];
}

-(void) handleEndGesture
{
	mMouseDown = NO;
	[self setNeedsDisplay: YES];
}

#pragma mark ___ Properties ___
-(void)setAzimuthSpan:(float)azimuthSpan
{
    mShapeSize.x = azimuthSpan / 2.0f; /// @todo max angle constant
}

-(float)azimuthSpan
{
    return mShapeSize.x * 2.0f; /// @todo max angle constant
}

-(void)setZenithSpan:(float)zenithSpan
{
    mShapeSize.y = zenithSpan / 0.5f; /// @todo max angle constant
}

-(float)zenithSpan
{
    return mShapeSize.y * 0.5f;
}

#pragma mark ___ Private ___
// Converts a point in screen coordinates to a normalized offset in flattened
// dome view.
-(void)updateCoords:(NSPoint)pos
{
    mShapeSize = [self screenToShape:pos];
    
    // Clamp min/max
    // x
    if (mShapeSize.x > 1.0f)
        mShapeSize.x = 1.0f;
    if (mShapeSize.y > 1.0f)
        mShapeSize.y = 1.0f;
    
//    NSPoint rPos = [self screenToDome:pos];
//    
//    [self setSourcePoint: rPos];
    
    [[NSNotificationCenter defaultCenter] postNotificationName: kShapeViewDataChangedNotification object:self];
}

-(NSPoint)shapeToScreen:(NSPoint)sh
{
    NSPoint sc;

    sc.x = sh.x * mCentre.x;
    sc.y = sh.y * mCentre.y;
    
    return sc;
}

-(NSPoint)screenToShape:(NSPoint)sc
{
    NSPoint sh;
    
    sh.x = fabsf(sc.x - mCentre.x) / mCentre.x;
    sh.y = fabsf(sc.y - mCentre.y) / mCentre.y;
    
    return sh;
}

@end
