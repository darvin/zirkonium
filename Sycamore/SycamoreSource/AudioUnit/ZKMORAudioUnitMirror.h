//
//  ZKMORAudioUnitMirror.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 18.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORAudioUnitMirror_h__
#define __ZKMORAudioUnitMirror_h__

#import "ZKMORCore.h"
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>

///
///  ZKMORAudioUnitMirror
///  
///  An object for reflecting on audio units. The implementation is inspires by the concept of mirrors 
///  in the Self programming language. See this paper by Gilad Bracha and David Ungar:
///
///		http://bracha.org/mirrors.pdf
///
@class ZKMORAudioUnitParameterMirror, ZKMORAudioUnit;
@interface ZKMORAudioUnitMirror : NSObject {
	ZKMORAudioUnit*			_audioUnit;
	AUEventListenerRef		_eventListener;
	
	// parameters
	NSMutableDictionary*	_parameterMirrors;
}

//  Initializing
- (id)initWithConduit:(ZKMORAudioUnit *)audioUnit;

//  Accessors
- (ZKMORAudioUnit *)audioUnit;
- (unsigned)numberOfInputBuses;
- (unsigned)numberOfOutputBuses;

//  Parameter Mirror Accessors
- (NSDictionary *)parameterMirrorsForScope:(AudioUnitScope)scope bus:(unsigned)bus;
- (ZKMORAudioUnitParameterMirror *)parameterMirrorForID:(AudioUnitParameterID)paramID  scope:(AudioUnitScope)scope bus:(unsigned)bus;


//  Event Listener Accessors
- (AUEventListenerRef)eventListener;
- (float)maxNotificationFrequency;		///< number of times/sec a notification can fire
- (float)notificationGanularity;		///< the time range (seconds) during which I only care about the last change

//  Logging
- (void)logParametersForScope:(AudioUnitScope)scope bus:(unsigned)bus level:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag;

@end



///
///  ZKMORAudioUnitParameterMirror
///
///  A conduit mirror on an audio unit parameter -- this is similar
///  to the CAAUParameter utility class in the CA Developer Tools package.
///  (and, in fact, borrows code from CAAUParamaeter)
///
@interface ZKMORAudioUnitParameterMirror : NSObject {
	ZKMORAudioUnitMirror*	_parentMirror;
	AudioUnitParameter		_parameter;

	// cached parameter info
	AudioUnitParameterInfo		_parameterInfo;
	CFStringRef					_parameterName;
	CFStringRef					_parameterTag;
	int							_numberOfIndexedValues;
	CFArrayRef					_namedParameters;	
	
}

//  Accessors
- (NSString *)parameterName;
- (AudioUnitParameterID)parameterID;

- (float)value;
- (void)setValue:(float)value;

//  Value Strings
- (BOOL)hasStringsAssociatedToValues;
- (NSString *)stringForValue:(float *)value;

- (NSString *)parameterTag;

//  Indexed Parameter Accessors
- (BOOL)isIndexedParameter;
- (int)numberOfIndexedValues;
- (NSString *)nameAtIndex:(int)valueIndex;

//  Queries
- (BOOL)hasDisplayTransformation;

@end

#endif