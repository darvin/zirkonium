#import <Cocoa/Cocoa.h>
#import "Zirkalloy.h"

/**
 * @brief Provides a combined view of source spanning
 */
@interface Zirkalloy_ShapeView : NSView
{	
	NSRect	mShapeFrame;
	float	mActiveWidth;
	BOOL	mMouseDown;
    
    NSPoint mShapeSize;
    
	NSImage *mBackgroundCache;
    
    NSPoint mCentre;
}

-(void)setAzimuthSpan:(float)azimuthSpan;
-(float)azimuthSpan;

-(void)setZenithSpan:(float)zenithSpan;
-(float)zenithSpan;

-(void) handleBeginGesture;
-(void) handleEndGesture;

@end
