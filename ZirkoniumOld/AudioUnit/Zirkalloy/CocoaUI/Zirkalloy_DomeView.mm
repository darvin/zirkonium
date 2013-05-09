#import "Zirkalloy_DomeView.h"

@interface Zirkalloy_DomeView (DomeViewPrivate)
-(void)updateCoords:(NSPoint)pos;

-(NSPoint)domeToScreen:(NSPoint)d;
-(NSPoint)screenToDome:(NSPoint)s;

-(PolarAngles)pointToPolar:(NSPoint)pos;
-(NSPoint)polarToPoint:(PolarAngles)heading;
@end

static const float kPolarRadius = 1.0f;
static const float kDotRadius = 5.0f;

@implementation Zirkalloy_DomeView


NSString *kDomeViewDataChangedNotification = @"Zirkalloy_DomeViewDataChangedNotification";
NSString *kDomeViewBeginGestureNotification= @"Zirkalloy_DomeViewBeginGestureNotification";
NSString *kDomeViewEndGestureNotification= @"Zirkalloy_DomeViewEndGestureNotification";

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
        
        mDomeFrame = NSMakeRect(0.0f, 0.0f, w, h);
        
        mRadius = w / 2;
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
    NSPoint centre = { mDomeFrame.size.width / 2, mDomeFrame.size.height / 2 };
    
    if (!mBackgroundCache)
    {
		mBackgroundCache = [[NSImage alloc] initWithSize: [self frame].size];

		[mBackgroundCache lockFocus];
        
        [[NSColor whiteColor] setFill];
        [[NSColor blackColor] setStroke];
        
        path = [NSBezierPath bezierPathWithOvalInRect:rect];
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
    
    // Convert from normalized dome offset to screen position
    NSPoint screen = [self domeToScreen:mSourcePoint];
    float screenX = screen.x - kDotRadius;
    float screenY = screen.y - kDotRadius;
    
    NSRect sourceDot = { { screenX, screenY },
                         { kDotRadius * 2, kDotRadius * 2 } };
    
    path = [NSBezierPath bezierPathWithOvalInRect:sourceDot];
    [[NSColor blueColor] setStroke];
    [path setLineWidth: 2.0f];
    [path stroke];
}


#pragma mark ___ Events ___
-(void) mouseDown:(NSEvent *)e
{
	NSPoint mouseLoc = [self convertPoint:[e locationInWindow] fromView:nil];
	mMouseDown = YES;
	
	[[NSNotificationCenter defaultCenter] postNotificationName: kDomeViewBeginGestureNotification object:self];
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
	[[NSNotificationCenter defaultCenter] postNotificationName: kDomeViewEndGestureNotification object:self];

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
-(void)setSourcePoint:(NSPoint)pos
{
    mSourcePoint = pos;
    mSourceHeading = [self pointToPolar:pos];
}

-(NSPoint)sourcePoint
{
    return mSourcePoint;
}

-(void)setHeading:(PolarAngles)heading
{
    mSourcePoint = [self polarToPoint:heading];
    mSourceHeading = heading;
}

-(PolarAngles)heading
{
    return mSourceHeading;
}

-(void)setAzimuth:(float)azimuth
{
    mSourceHeading.azimuth = azimuth;
    mSourcePoint = [self polarToPoint:mSourceHeading];
}

-(float)azimuth
{
    return mSourceHeading.azimuth;
}

-(void)setZenith:(float)zenith
{
    mSourceHeading.zenith = zenith;
    mSourcePoint = [self polarToPoint:mSourceHeading];
}

-(float)zenith
{
    return mSourceHeading.zenith;
}

#pragma mark ___ Private ___
// Converts a point in screen coordinates to a normalized offset in flattened
// dome view.
-(void)updateCoords:(NSPoint)pos
{
    NSPoint rPos = [self screenToDome:pos];
    
    [self setSourcePoint: rPos];
    
    [[NSNotificationCenter defaultCenter] postNotificationName: kDomeViewDataChangedNotification object:self];
}

-(NSPoint)domeToScreen:(NSPoint)d
{
    NSPoint s;
    // Manual transformation
    s.x = -d.y * mRadius + mCentre.x;
    s.y = d.x * mRadius + mCentre.y;
    // Matrix transformations
//    s.x = d.y * mRadius - mCentre.y * mRadius;
//    s.y = -d.x * mRadius + mCentre.x * mRadius;
    // Reverse matrices
//    s.x = d.y * mRadius - mCentre.x;
//    s.y = -d.x * mRadius - mCentre.y;
    return s;
}

-(NSPoint)screenToDome:(NSPoint)s
{
    NSPoint d;
    // Manual transformation
    d.x = (s.y - mCentre.y) / mRadius;
    d.y = -(s.x - mCentre.x) / mRadius;
    
    // Matrix transformations
//    d.x = -s.y / mRadius + mCentre.x;
//    d.y = s.x / mRadius + mCentre.y;
    // Reverse matrices
//    d.x = -s.y / mRadius - mCentre.y / mRadius;
//    d.y = s.x / mRadius + mCentre.x / mRadius;
    return d;
}

// Converts a point in a flattened dome view to radians / pi coordinates. 
-(PolarAngles)pointToPolar:(NSPoint)pos
{
    PolarAngles ret;
    ret.azimuth = (atan2f(pos.y, pos.x)) / M_PI;
    float root = kPolarRadius * kPolarRadius - pos.x * pos.x - pos.y * pos.y;
    // Rounding mistakes & distance clamping
    if (root < 0.0001f)
        root = 0.0f;
    ret.zenith = asinf(sqrtf(root) / kPolarRadius) / M_PI;
    return ret;
}

// Converts a heading in radians / pi coordinates to an offset in flattened
// dome view.
-(NSPoint)polarToPoint:(PolarAngles)heading
{
    NSPoint ret;
    ret.x = kPolarRadius * cosf(heading.zenith * M_PI) * cosf(heading.azimuth * M_PI);
    ret.y = kPolarRadius * cosf(heading.zenith * M_PI) * sinf(heading.azimuth * M_PI);
    return ret;
}

@end
