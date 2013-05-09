//
//  ZKMORAudioUnitParameterScheduler.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 17.05.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMORCore.h"
#include <AudioUnit/AudioUnit.h>

ZKMDECLCPPT(ZKMORAUParameterScheduler)

///
///  ZKMORAudioUnitParameterScheduler
///  
///  Handles scheduling parameter changes. Parameter changes should be scheduled in a non-realtime thread
///  since scheduling may cause a memory allocation. The parameter changes are executed in the audio thread
///  and should thus be smooth.
///
///  The parameter scheduler is created for an audio unit (it adds a render notify callback to the AU) and
///  can be used to schedule changes to parameters.
///
@class ZKMORAudioUnit;
@interface ZKMORAudioUnitParameterScheduler : NSObject {
	ZKMCPPT(ZKMORAUParameterScheduler)	mParameterScheduler;
}

//  Initializing
- (id)initWithConduit:(ZKMORAudioUnit *)audioUnit;

//  Accessors
- (ZKMORAudioUnit *)audioUnit;

//  Actions
	/// call this before scheduling parameter changes
- (void)beginScheduling;
- (void)scheduleParameter:(AudioUnitParameterID)parameter scope:(AudioUnitScope)scope element:(AudioUnitElement)element value:(float)value duration:(Float64)seconds;
	/// call to signal finished scheduling
- (void)endScheduling;

@end

