#import <Cocoa/Cocoa.h>
#import "Zirkalloy.h"

/**
 * @brief Provides a top-down view of dome spacialization
 *
 * This class provides a simplified view of the detailed OpenGL view of
 * Zirkonium's speaker dome. It serves primarily to represent the area from
 * which sounds originate. Unlike Zirkonium's detailed view, the Zirkalloy view
 * does not indicate the location of the speakers but only of the source
 * direction.
 */
@interface Zirkalloy_DomeView : NSView
{	
	NSRect	mDomeFrame;
	float	mActiveWidth;
	BOOL	mMouseDown;
    
    // Attribute copies
    NSPoint     mSourcePoint;
    PolarAngles mSourceHeading;
	
	NSImage *mBackgroundCache;
    
    // Math
    float   mRadius;
    NSPoint mCentre;
}

-(void)setSourcePoint:(NSPoint)pos;
-(NSPoint)sourcePoint;

-(void)setHeading:(PolarAngles)heading;
-(PolarAngles)heading;

-(void)setAzimuth:(float)azimuth;
-(float)azimuth;

-(void)setZenith:(float)zenith;
-(float)zenith;

-(void) handleBeginGesture;
-(void) handleEndGesture;

@end
