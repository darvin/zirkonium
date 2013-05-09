#import "Zirkalloy_UIView.h"
#import "ZKMRNDeviceConstants.h"

extern NSString *kDomeViewDataChangedNotification;
extern NSString *kDomeViewBeginGestureNotification;
extern NSString *kDomeViewEndGestureNotification;

extern NSString *kShapeViewDataChangedNotification;
extern NSString *kShapeViewBeginGestureNotification;
extern NSString *kShapeViewEndGestureNotification;

@interface Zirkalloy_UIView (UIViewPrivate)
#pragma mark ____ PRIVATE FUNCTIONS
    - (void)registerAUListeners;
    - (void)unregisterAUListeners;
    
#pragma mark ____ LISTENER CALLBACK DISPATCHEE ____
    - (void)eventListener:(void *) inObject event:(const AudioUnitEvent *)inEvent value:(Float32)inValue;
@end

#pragma mark ____ LISTENER CALLBACK DISPATCHER ____

// This listener responds to parameter changes, gestures, and property notifications
void EventListenerDispatcher (void *inRefCon, void *inObject, const AudioUnitEvent *inEvent, UInt64 inHostTime, Float32 inValue)
{
	Zirkalloy_UIView *SELF = (Zirkalloy_UIView *)inRefCon;
	[SELF eventListener:inObject event: inEvent value: inValue];
}

@implementation Zirkalloy_UIView

-(void) awakeFromNib
{
	NSString *path = [[NSBundle bundleForClass: [Zirkalloy_UIView class]] pathForImageResource: @"SectionPatternLight"];
	NSImage *pattern = [[NSImage alloc] initByReferencingFile: path];
	mBackgroundColor = [[NSColor colorWithPatternImage: [pattern autorelease]] retain];
    
    for (int i = 0; i < DEVICE_NUM_CHANNELS; i += 2)
    {
        [channelMenu addItemWithTitle: [NSString stringWithFormat:@"Channels %d-%d", i, i+1]];
    }
}

#pragma mark ____ (INIT /) DEALLOC ____
- (void)dealloc
{
    [self unregisterAUListeners];
	[mBackgroundColor release];
		
	[[NSNotificationCenter defaultCenter] removeObserver: self];

    [super dealloc];
}

#pragma mark ____ PUBLIC FUNCTIONS ____
- (void)setAU:(AudioUnit)inAU
{
	// remove previous listeners
	if (mAU) 
		[self unregisterAUListeners];

    // Dome view observers
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onDataChanged:) name: kDomeViewDataChangedNotification object: domeView];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onBeginGesture:) name: kDomeViewBeginGestureNotification object: domeView];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onEndGesture:) name: kDomeViewEndGestureNotification object: domeView];

    // Shape view observers
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onSpanDataChanged:) name: kShapeViewDataChangedNotification object: shapeView];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onBeginSpanGesture:) name: kShapeViewBeginGestureNotification object: shapeView];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onEndSpanGesture:) name: kShapeViewEndGestureNotification object: shapeView];    
    
	mAU = inAU;
    
	// add new listeners
	[self registerAUListeners];
}

- (void)drawRect:(NSRect)rect
{
	[mBackgroundColor set];
	NSRectFill(rect);
	
	[super drawRect: rect];
}

#pragma mark ____ INTERFACE ACTIONS ____

#pragma mark ____ Audio Unit responses ____
- (IBAction) azimuthChanged:(id)sender
{
	float floatValue = [sender floatValue];
	AudioUnitParameter azimuthParameter = {mAU, kZirkalloyParam_Azimuth, kAudioUnitScope_Global, 0 };
	
	NSAssert(	AUParameterSet(mAUEventListener, sender, &azimuthParameter, (Float32)floatValue, 0) == noErr,
                @"[Zirkalloy_UIView azimuthChanged:] AUParameterSet()");
}

- (IBAction) zenithChanged:(id)sender
{
	float floatValue = [sender floatValue];
	AudioUnitParameter zenithParameter = {mAU, kZirkalloyParam_Zenith, kAudioUnitScope_Global, 0 };

	NSAssert(	AUParameterSet(mAUEventListener, sender, &zenithParameter, (Float32)floatValue, 0) == noErr,
                @"[Zirkalloy_UIView zenithChanged:] AUParameterSet()");
}

- (IBAction) azimuthSpanChanged:(id)sender
{
	float floatValue = [sender floatValue];
	AudioUnitParameter azimuthSpanParameter = {mAU, kZirkalloyParam_AzimuthSpan, kAudioUnitScope_Global, 0 };
	
	NSAssert(	AUParameterSet(mAUEventListener, sender, &azimuthSpanParameter, (Float32)floatValue, 0) == noErr,
             @"[Zirkalloy_UIView azimuthChanged:] AUParameterSet()");
}

- (IBAction) zenithSpanChanged:(id)sender
{
	float floatValue = [sender floatValue];
	AudioUnitParameter zenithSpanParameter = {mAU, kZirkalloyParam_ZenithSpan, kAudioUnitScope_Global, 0 };
    
	NSAssert(	AUParameterSet(mAUEventListener, sender, &zenithSpanParameter, (Float32)floatValue, 0) == noErr,
             @"[Zirkalloy_UIView zenithChanged:] AUParameterSet()");
}

- (IBAction) gainChanged:(id)sender
{
	float floatValue = [sender floatValue];
	AudioUnitParameter gainParameter = {mAU, kZirkalloyParam_Gain, kAudioUnitScope_Global, 0 };
    
	NSAssert(	AUParameterSet(mAUEventListener, sender, &gainParameter, (Float32)floatValue, 0) == noErr,
             @"[Zirkalloy_UIView zenithChanged:] AUParameterSet()");
}


- (IBAction) channelChanged:(id)sender
{
    int channelIndex = [sender indexOfSelectedItem];
    
    AudioUnitParameter channelParameter = {mAU, kZirkalloyParam_Channel, kAudioUnitScope_Global, 0 };
    
	NSAssert(	AUParameterSet(mAUEventListener, sender, &channelParameter, (Float32)channelIndex, 0) == noErr,
             @"[Zirkalloy_UIView channelChanged:] AUParameterSet()");
}

#pragma mark ____ Dome view actions ___
- (void) onDataChanged:(NSNotification *) aNotification
{    
    AudioUnitParameter azimuthParameter = { mAU, kZirkalloyParam_Azimuth, kAudioUnitScope_Global, 0 };
    AudioUnitParameter zenithParameter  = { mAU, kZirkalloyParam_Zenith,  kAudioUnitScope_Global, 0 };
    
	NSAssert(	AUParameterSet(mAUEventListener, azimuthField, &azimuthParameter, (Float32)domeView.azimuth, 0) == noErr,
                @"[Zirkalloy_UIView azimuthChanged:] AUParameterSet()");

	NSAssert(	AUParameterSet(mAUEventListener, zenithField, &zenithParameter, (Float32)domeView.zenith, 0) == noErr,
                @"[Zirkalloy_UIView zenithChanged:] AUParameterSet()");
}

- (void) onBeginGesture:(NSNotification *) aNotification 
{
	AudioUnitEvent event;
	AudioUnitParameter parameter = {mAU, kZirkalloyParam_Azimuth, kAudioUnitScope_Global, 0 };
	event.mArgument.mParameter = parameter;
	event.mEventType = kAudioUnitEvent_BeginParameterChangeGesture;
	
	AUEventListenerNotify (mAUEventListener, self, &event);
		
	event.mArgument.mParameter.mParameterID = kZirkalloyParam_Zenith;
	AUEventListenerNotify (mAUEventListener, self, &event);
}

- (void) onEndGesture:(NSNotification *) aNotification
{
	AudioUnitEvent event;
	AudioUnitParameter parameter = {mAU, kZirkalloyParam_Azimuth, kAudioUnitScope_Global, 0 };
	event.mArgument.mParameter = parameter;
	event.mEventType = kAudioUnitEvent_EndParameterChangeGesture;
	
	AUEventListenerNotify (mAUEventListener, self, &event);
	
	event.mArgument.mParameter.mParameterID = kZirkalloyParam_Zenith;
	AUEventListenerNotify (mAUEventListener, self, &event);	
}

#pragma mark ____ Shape view actions ____
- (void) onSpanDataChanged:(NSNotification *) aNotification
{    
    AudioUnitParameter azimuthSpanParameter = { mAU, kZirkalloyParam_AzimuthSpan, kAudioUnitScope_Global, 0 };
    AudioUnitParameter zenithSpanParameter  = { mAU, kZirkalloyParam_ZenithSpan,  kAudioUnitScope_Global, 0 };
    
	NSAssert(	AUParameterSet(mAUEventListener, azimuthField, &azimuthSpanParameter, (Float32)shapeView.azimuthSpan, 0) == noErr,
             @"[Zirkalloy_UIView azimuthChanged:] AUParameterSet()");
    
	NSAssert(	AUParameterSet(mAUEventListener, zenithField, &zenithSpanParameter, (Float32)shapeView.zenithSpan, 0) == noErr,
             @"[Zirkalloy_UIView zenithChanged:] AUParameterSet()");
}

- (void) onBeginSpanGesture:(NSNotification *) aNotification 
{
	AudioUnitEvent event;
	AudioUnitParameter parameter = {mAU, kZirkalloyParam_AzimuthSpan, kAudioUnitScope_Global, 0 };
	event.mArgument.mParameter = parameter;
	event.mEventType = kAudioUnitEvent_BeginParameterChangeGesture;
	
	AUEventListenerNotify (mAUEventListener, self, &event);
    
	event.mArgument.mParameter.mParameterID = kZirkalloyParam_ZenithSpan;
	AUEventListenerNotify (mAUEventListener, self, &event);
}

- (void) onEndSpanGesture:(NSNotification *) aNotification
{
	AudioUnitEvent event;
	AudioUnitParameter parameter = {mAU, kZirkalloyParam_AzimuthSpan, kAudioUnitScope_Global, 0 };
	event.mArgument.mParameter = parameter;
	event.mEventType = kAudioUnitEvent_EndParameterChangeGesture;
	
	AUEventListenerNotify (mAUEventListener, self, &event);
	
	event.mArgument.mParameter.mParameterID = kZirkalloyParam_ZenithSpan;
	AUEventListenerNotify (mAUEventListener, self, &event);	
}

void addParamListener (AUEventListenerRef listener, void* refCon, AudioUnitEvent *inEvent)
{
	inEvent->mEventType = kAudioUnitEvent_BeginParameterChangeGesture;
	verify_noerr ( AUEventListenerAddEventType(	listener, refCon, inEvent));
	
	inEvent->mEventType = kAudioUnitEvent_EndParameterChangeGesture;
	verify_noerr ( AUEventListenerAddEventType(	listener, refCon, inEvent));
	
	inEvent->mEventType = kAudioUnitEvent_ParameterValueChange;
	verify_noerr ( AUEventListenerAddEventType(	listener, refCon, inEvent));	
}

#pragma mark ____ PRIVATE FUNCTIONS ____
- (void)registerAUListeners 
{
	if (mAU)
    {
		verify_noerr( AUEventListenerCreate(EventListenerDispatcher, self,
											CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0.01, 0.1, 
											&mAUEventListener));
		
		AudioUnitEvent auEvent;
		AudioUnitParameter parameter = {mAU, kZirkalloyParam_Azimuth, kAudioUnitScope_Global, 0 };
		auEvent.mArgument.mParameter = parameter;		
			
		addParamListener (mAUEventListener, self, &auEvent);
		
		auEvent.mArgument.mParameter.mParameterID = kZirkalloyParam_Zenith;
		addParamListener (mAUEventListener, self, &auEvent);
        
        auEvent.mArgument.mParameter.mParameterID = kZirkalloyParam_AzimuthSpan;
		addParamListener (mAUEventListener, self, &auEvent);
        
        auEvent.mArgument.mParameter.mParameterID = kZirkalloyParam_ZenithSpan;
		addParamListener (mAUEventListener, self, &auEvent);

        auEvent.mArgument.mParameter.mParameterID = kZirkalloyParam_Gain;
		addParamListener (mAUEventListener, self, &auEvent);
        
        auEvent.mArgument.mParameter.mParameterID = kZirkalloyParam_Channel;
		addParamListener (mAUEventListener, self, &auEvent);
	}
}

- (void)unregisterAUListeners 
{
	if (mAUEventListener) verify_noerr (AUListenerDispose(mAUEventListener));
	mAUEventListener = NULL;
	mAU = NULL;
}

#pragma mark ____ LISTENER CALLBACK DISPATCHEE ____
- (void)eventListener:(void *) inObject event:(const AudioUnitEvent *)inEvent value:(Float32)inValue
{
	switch (inEvent->mEventType)
    {
		case kAudioUnitEvent_ParameterValueChange:
			switch (inEvent->mArgument.mParameter.mParameterID)
            {
				case kZirkalloyParam_Azimuth:
					[azimuthField setFloatValue: inValue * 180];
                    [domeView setAzimuth: inValue];
                    [domeView setNeedsDisplay:YES];
                    break;
				case kZirkalloyParam_Zenith:
					[zenithField setFloatValue: inValue * 180];
                    [domeView setZenith: inValue];
                    [domeView setNeedsDisplay:YES];
					break;
                case kZirkalloyParam_AzimuthSpan:
                    [shapeView setAzimuthSpan: inValue];
                    [shapeView setNeedsDisplay:YES];
                    break;
                case kZirkalloyParam_ZenithSpan:
                    [shapeView setZenithSpan: inValue];
                    [shapeView setNeedsDisplay:YES];
                    break;
                case kZirkalloyParam_Channel:
                    [channelMenu selectItemAtIndex: (unsigned int)inValue];
                    [domeView setNeedsDisplay:YES];
                    [shapeView setNeedsDisplay:YES];
                    break;
			}
			break;
		case kAudioUnitEvent_BeginParameterChangeGesture:
			[domeView handleBeginGesture];
			break;
		case kAudioUnitEvent_EndParameterChangeGesture:
			[domeView handleEndGesture];
			break;
	}
}

/* If we get a mouseDown, that means it was not in the graph view, or one of the text fields. 
   In this case, we should make the window the first responder. This will deselect our text fields if they are active. */
- (void) mouseDown: (NSEvent *) theEvent
{
	[super mouseDown: theEvent];
	[[self window] makeFirstResponder: self];
}

- (BOOL) acceptsFirstResponder 
{
	return YES;
}

- (BOOL) becomeFirstResponder
{	
	return YES;
}

- (BOOL) isOpaque
{
	return YES;
}

@end
