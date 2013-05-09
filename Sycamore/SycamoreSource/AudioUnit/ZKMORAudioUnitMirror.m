//
//  ZKMORAudioUnitMirror.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 18.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioUnitMirror.h"
#import "ZKMORException.h"
#import "ZKMORAudioUnit.h"
#import "ZKMORLogger.h"

@interface ZKMORAudioUnitMirror (ZKMORAudioUnitMirrorPrivate)

- (void)initializeEventListener;
- (void)initializeParameterMirrors;
- (void)initializeParametersInScope:(AudioUnitScope)scope;
- (void)initializeParameterMirrorsForBus:(AudioUnitElement)bus inScope:(AudioUnitScope)scope;
- (NSMutableDictionary *)createParameterDictForScope:(AudioUnitScope)scope bus:(AudioUnitElement)bus capacity:(unsigned)capacity;
- (void)addListenerFor:(ZKMORAudioUnitParameterMirror *)paramMirror parameter:(AudioUnitParameter *)parameter;
- (void)streamFormatChanged;
- (void)mainThreadValueChangedForProperty:(NSString *)propertyName;

@end

@interface ZKMORAudioUnitParameterMirror (ZKMORAudioUnitParameterMirrorPrivate)

- (id)initWithParentMirror:(ZKMORAudioUnitMirror *)parentMirror parameter:(AudioUnitParameter *)parameter;
- (void)initializeCachedInfo;
- (void)mainThreadValueChangedForProperty:(NSString *)propertyName;

@end

static void ZKMORAudioUnitMirrorEventListener(		void*					refCon,
													void*					changer,
													const AudioUnitEvent*	event,
													UInt64					eventHostTime,
													Float32					parameterValue)
{
	if (kAudioUnitEvent_ParameterValueChange == event->mEventType) {
		// the event listener was set up to do its callbacks in
		// a thread we can treat as the main thread
		[(ZKMORAudioUnitParameterMirror*)changer 
			mainThreadValueChangedForProperty: @"value"];
		return;
	}
	
	if (kAudioUnitEvent_PropertyChange != event->mEventType)
		return;

	switch (event->mArgument.mProperty.mPropertyID) {
		case kAudioUnitProperty_StreamFormat:
			[(ZKMORAudioUnitMirror*) changer streamFormatChanged];
		break;

		default:
			ZKMORLogDebug(CFSTR("MirrorEventListenerFired %x %x %i %i"), refCon, changer, event->mEventType, event->mArgument);
		break;
		
	}
}

@implementation ZKMORAudioUnitMirror

- (void)dealloc {
	if (_audioUnit) [_audioUnit release];
	if (_eventListener) AUListenerDispose(_eventListener);
	[super dealloc];
}

- (id)initWithConduit:(ZKMORAudioUnit *)audioUnit
{
	if (!(self = [super init])) return nil;
	_audioUnit = [audioUnit retain];
	OSStatus err;
	err =
		AUEventListenerCreate(	ZKMORAudioUnitMirrorEventListener,						// listener func
								self,													// ref con
								[[NSRunLoop currentRunLoop] getCFRunLoop],				// run loop
								(CFStringRef) NSDefaultRunLoopMode,						// run loop mode
								(Float32) (1.f / [self maxNotificationFrequency]),		// in seconds
								(Float32) ([self notificationGanularity]),				// in seconds
								&_eventListener);
	if (err) {
		[self autorelease];
		ZKMORThrow(AudioUnitError, @"Could not create event listener");
	}

	[self initializeEventListener];
	[self initializeParameterMirrors];
	
	return self;
}

#pragma mark _____ Accessors
- (ZKMORAudioUnit *)audioUnit { return _audioUnit; }
- (unsigned)numberOfInputBuses { return [_audioUnit numberOfInputBuses]; }
- (unsigned)numberOfOutputBuses { return [_audioUnit numberOfOutputBuses]; }

#pragma mark _____ Parameter Mirror Accessors
- (NSDictionary *)parameterMirrorsForScope:(AudioUnitScope)scope bus:(unsigned)bus 
{
	NSNumber* scopeKey = [NSNumber numberWithUnsignedInt: scope];	
	NSMutableDictionary* scopeParamMirrors = [_parameterMirrors objectForKey: scopeKey];

	NSNumber* busKey = [NSNumber numberWithUnsignedInt: bus];
	return [scopeParamMirrors objectForKey: busKey];
}


- (ZKMORAudioUnitParameterMirror *)parameterMirrorForID:(AudioUnitParameterID)paramID scope:(AudioUnitScope)scope bus:(unsigned)bus
{
	NSNumber* scopeKey = [NSNumber numberWithUnsignedInt: scope];	
	NSMutableDictionary* scopeParamMirrors = [_parameterMirrors objectForKey: scopeKey];

	NSNumber* busKey = [NSNumber numberWithUnsignedInt: bus];
	NSMutableDictionary* busParamMirrors =  [scopeParamMirrors objectForKey: busKey];
	
	NSNumber* paramKey = [NSNumber numberWithUnsignedInt: paramID];
	return [busParamMirrors objectForKey: paramKey];	
}

#pragma mark _____ Event Listener Accessors
- (AUEventListenerRef)eventListener { return _eventListener; }

  // 10 times per second
- (float)maxNotificationFrequency { return 10.f; }
- (float)notificationGanularity { return 1.f / [self maxNotificationFrequency]; }

#pragma mark _____ Logging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	
	unsigned myLevel = level | kZKMORLogLevel_Continue;
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	[_audioUnit logAtLevel: myLevel source: source indent: indent +1];

	AudioUnit au = [_audioUnit audioUnit];
	AUChannelInfo info;
	UInt32 dataSize = sizeof(info);
	
	OSStatus result = AudioUnitGetProperty(	au,
											kAudioUnitProperty_SupportedNumChannels,
											kAudioUnitScope_Global, 
											0,
											&info, 
											&dataSize);
	if (noErr == result)
		ZKMORLog(myLevel, source, CFSTR("%s\tSupported Num Channels: [%i, %i]"), indentStr, info.inChannels, info.outChannels);
		
	[self logParametersForScope: kAudioUnitScope_Global bus: 0 level: myLevel source: source indent: indent + 1 tag: @"Global Parameters: "];
	[self logParametersForScope: kAudioUnitScope_Input bus: 0 level: myLevel source: source indent: indent + 1	tag: @"Input Parameters: "];
	[self logParametersForScope: kAudioUnitScope_Output bus: 0 level: myLevel source: source indent: indent + 1 tag: @"Output Parameters: "];	
}

- (void)logParametersForScope:(AudioUnitScope)scope bus:(unsigned)bus level:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(level, source, CFSTR("%s%@"), indentStr, tag);
	
	unsigned myLevel = level | kZKMORLogLevel_Continue;
	
	NSDictionary* params = [self parameterMirrorsForScope: scope bus: bus];
	NSEnumerator* enumerator = [params objectEnumerator];
	ZKMORAudioUnitParameterMirror* parameterMirror;
	while (parameterMirror = [enumerator nextObject]) {
		ZKMORLog(myLevel, source, CFSTR("%s\t%.2u: %@ (%@)"), indentStr, [parameterMirror parameterID], [parameterMirror parameterName], [parameterMirror parameterTag]);
	}
}				

#pragma mark _____ ZKMORAudioUnitMirrorPrivate
- (void)initializeEventListener 
{
	OSStatus err;
	AudioUnitEvent event;
	event.mEventType = kAudioUnitEvent_PropertyChange;
	event.mArgument.mProperty.mAudioUnit = [_audioUnit audioUnit];
	event.mArgument.mProperty.mPropertyID = kAudioUnitProperty_BusCount;
	event.mArgument.mProperty.mScope = kAudioUnitScope_Global;
	event.mArgument.mProperty.mElement = 0; 

	err = AUEventListenerAddEventType(_eventListener, self, &event);
	if (err) ZKMORThrow(AudioUnitError, @"Could not add bus count listener");
	
	event.mArgument.mProperty.mPropertyID = kAudioUnitProperty_ParameterList;
	err = AUEventListenerAddEventType(_eventListener, self, &event);
	if (err) ZKMORThrow(AudioUnitError, @"Could not add parameter list listener");
	
	event.mArgument.mProperty.mPropertyID = kAudioUnitProperty_StreamFormat;
	err = AUEventListenerAddEventType(_eventListener, self, &event);
	if (err) ZKMORThrow(AudioUnitError, @"Could not add stream format listener");
}

- (void)initializeParameterMirrors 
{
	_parameterMirrors = [[NSMutableDictionary alloc] initWithCapacity: 3];
	[self initializeParametersInScope: kAudioUnitScope_Input];
	[self initializeParametersInScope: kAudioUnitScope_Output];
	[self initializeParametersInScope: kAudioUnitScope_Global];
}

- (void)initializeParametersInScope:(AudioUnitScope)scope 
{
	NSNumber* scopeKey = [NSNumber numberWithUnsignedInt: scope];	
	NSMutableDictionary* scopeParamMirrors;
	unsigned numBuses;
	switch (scope) {
		case kAudioUnitScope_Input: numBuses = [self numberOfInputBuses];
		break;
		case kAudioUnitScope_Output: numBuses = [self numberOfOutputBuses];
		break;
		default: numBuses = 1;
		break;
	}
	
	scopeParamMirrors = [[NSMutableDictionary alloc] initWithCapacity: numBuses];
	[_parameterMirrors setObject: scopeParamMirrors forKey: scopeKey];
		// hand ownership of the scopeParamMirrors to the dictionary
	[scopeParamMirrors release];
	
	unsigned i;
	for (i = 0; i < numBuses; i++) {
		[self initializeParameterMirrorsForBus: i inScope: scope];
	}
}

- (NSMutableDictionary *)createParameterDictForScope:(AudioUnitScope)scope bus:(AudioUnitElement)bus capacity:(unsigned)capacity 
{
	// get the dictionary of mirrors for this scope
	NSNumber* scopeKey = [NSNumber numberWithUnsignedInt: scope];
	NSMutableDictionary* scopeParamMirrors = [_parameterMirrors objectForKey: scopeKey];

	// remember the old array, so we can dispose of it later
	NSNumber* busKey = [NSNumber numberWithUnsignedInt: bus];
	NSMutableDictionary* oldParameterMirrors = [scopeParamMirrors objectForKey: busKey];
	
	NSMutableDictionary* newParameterMirrors = [[NSMutableDictionary alloc] initWithCapacity: capacity];
	[scopeParamMirrors setObject: newParameterMirrors forKey: busKey];
	// give ownership to the dictionary
	[newParameterMirrors release];
	if (oldParameterMirrors) [oldParameterMirrors release];
	
	return newParameterMirrors;
}

- (void)addListenerFor:(ZKMORAudioUnitParameterMirror *)paramMirror parameter:(AudioUnitParameter *)parameter 
{
	OSStatus err;
	AudioUnitEvent event;
	event.mEventType = kAudioUnitEvent_ParameterValueChange;
	event.mArgument.mParameter = *parameter;

	err = AUEventListenerAddEventType(_eventListener, paramMirror, &event);
	if (err) ZKMORThrow(AudioUnitError, @"Could not add listener for value changes to parameter %@", paramMirror);
}

- (void)initializeParameterMirrorsForBus:(AudioUnitElement)bus inScope:(AudioUnitScope)scope {
	// create the parameter ids
	unsigned numParams = [_audioUnit numberOfParametersInScope: scope bus: bus];
	
	if (numParams < 1) return;
		
	unsigned dataSize = numParams * sizeof(AudioUnitParameterID);
	AudioUnitParameterID ids[numParams];
	[_audioUnit getParameterIDs: ids scope: scope bus: bus dataSize: &dataSize];
	
	AudioUnit primitiveAudioUnit = [_audioUnit audioUnit];
	
	// initialize the new mirrors
	NSMutableDictionary* newParameterMirrors = 
		[self createParameterDictForScope: scope bus: bus capacity: numParams];
	unsigned i;
	for (i = 0; i < numParams; i++) {
		AudioUnitParameter parameter = { primitiveAudioUnit, ids[i], scope, bus };
		NSNumber* paramKey = [NSNumber numberWithUnsignedInt: parameter.mParameterID]; 
		ZKMORAudioUnitParameterMirror* paramMirror = 
			[[ZKMORAudioUnitParameterMirror alloc]
				initWithParentMirror: self
				parameter: &parameter];
		[newParameterMirrors setObject: paramMirror forKey: paramKey];
			// give ownership to the array
		[paramMirror release];
	}
}

- (void)streamFormatChanged
{
	[self initializeParameterMirrors];
	[self mainThreadValueChangedForProperty: @"streamFormat"];
}

- (void)mainThreadValueChangedForProperty:(NSString *)propertyName 
{
	[self willChangeValueForKey: propertyName];
	[self didChangeValueForKey: propertyName];
}

@end

@implementation ZKMORAudioUnitParameterMirror

- (void)dealloc {
	if (_parameterName) CFRelease(_parameterName);
	if (_parameterTag) CFRelease(_parameterTag);
	if (_namedParameters) CFRelease(_namedParameters);
	
	[super dealloc];
}

- (id)initWithParentMirror:(ZKMORAudioUnitMirror *)parentMirror parameter:(AudioUnitParameter *)parameter
{
	if (!(self = [super init])) return nil;
	
	_parentMirror = parentMirror;
	_parameter = *parameter;
	[self initializeCachedInfo];
	[_parentMirror addListenerFor: self parameter: &_parameter];

	return self;
}

#pragma mark _____ Accessors
- (NSString *)parameterName { return (NSString *)_parameterName; }
- (AudioUnitParameterID)parameterID { return _parameter.mParameterID; }

- (float)value
{
	Float32 value = 0.f;
	AudioUnitGetParameter(	_parameter.mAudioUnit, 
							_parameter.mParameterID,
							_parameter.mScope,
							_parameter.mElement,
							&value);
	return value;
}


- (void)setValue:(float)value 
{
    // clip inValue as: maxValue >= inValue >= minValue before setting
    Float32 valueToSet = value;
    if (valueToSet > _parameterInfo.maxValue)
        valueToSet = _parameterInfo.maxValue;
    if (valueToSet < _parameterInfo.minValue)
        valueToSet = _parameterInfo.minValue;
    
	AUParameterSet([_parentMirror eventListener], _parentMirror, &_parameter, valueToSet, 0);
}

#pragma mark _____ Value Strings
- (BOOL)hasStringsAssociatedToValues { return (_parameterInfo.flags & kAudioUnitParameterFlag_ValuesHaveStrings); }

- (NSString *)stringForValue:(float *)value
{
	if ([self hasStringsAssociatedToValues]) {
		AudioUnitParameterStringFromValue stringValue;
		stringValue.inParamID = _parameter.mParameterID;
		stringValue.inValue = value;
		stringValue.outString = NULL;
		UInt32 size = sizeof(stringValue);
		
		OSStatus err = AudioUnitGetProperty (_parameter.mAudioUnit, 
											kAudioUnitProperty_ParameterStringFromValue,
											_parameter.mScope, 
											_parameter.mParameterID, 
											&stringValue, 
											&size);
		
		if (err == noErr && stringValue.outString != NULL)
			return [(NSString *) (stringValue.outString) autorelease];
	}
	
	float val = (value == NULL ? [self value] : *value);
	char valstr[32];
	AUParameterFormatValue (val, &_parameter, valstr, ([self hasDisplayTransformation] ? 4 : 3));
	return 
		[(NSString *) (CFStringCreateWithCString(NULL, valstr, kCFStringEncodingUTF8)) 
			autorelease];	
}

- (NSString *)parameterTag { return (NSString *)_parameterTag; }

#pragma mark _____ Indexed Parameter Accessors
- (BOOL)isIndexedParameter { return _numberOfIndexedValues != 0; }
- (int)numberOfIndexedValues { return _numberOfIndexedValues; }

- (NSString *)nameAtIndex:(int)valueIndex
{
	return 
		(_namedParameters && (valueIndex < _numberOfIndexedValues)) 
			? (NSString *) CFArrayGetValueAtIndex(_namedParameters, valueIndex)
			: nil;
}

#pragma mark _____ Queries
- (BOOL)hasDisplayTransformation { return GetAudioUnitParameterDisplayType(_parameterInfo.flags); }

#pragma mark _____ ZKMORAudioUnitParameterMirrorPrivate
- (void)initializeCachedInfo 
{
	UInt32 size = sizeof(_parameterInfo);
	OSStatus err = 
		AudioUnitGetProperty(	_parameter.mAudioUnit,
								kAudioUnitProperty_ParameterInfo,
								_parameter.mScope,
								_parameter.mParameterID,
								&_parameterInfo,
								&size);
	if (err) ZKMORThrow(AudioUnitError, @"Could not get info for parameter %@", self);

	if (_parameterInfo.flags & kAudioUnitParameterFlag_HasCFNameString) {
		_parameterName = _parameterInfo.cfNameString;
		if (!(_parameterInfo.flags & kAudioUnitParameterFlag_CFNameRelease))
			CFRetain(_parameterName);
	} else
		_parameterName = CFStringCreateWithCString(NULL, _parameterInfo.name, kCFStringEncodingUTF8);

	char* str = 0;
	switch (_parameterInfo.unit)
	{
		case kAudioUnitParameterUnit_Boolean:
			str = "T/F";
			break;
		case kAudioUnitParameterUnit_Percent:
		case kAudioUnitParameterUnit_EqualPowerCrossfade:
			str = "%";
			break;
		case kAudioUnitParameterUnit_Seconds:
			str = "Secs";
			break;
		case kAudioUnitParameterUnit_SampleFrames:
			str = "Samps";
			break;
		case kAudioUnitParameterUnit_Phase:
		case kAudioUnitParameterUnit_Degrees:
			str = "Degr.";
			break;
		case kAudioUnitParameterUnit_Hertz:
			str = "Hz";
			break;
		case kAudioUnitParameterUnit_Cents:
		case kAudioUnitParameterUnit_AbsoluteCents:
			str = "Cents";
			break;
		case kAudioUnitParameterUnit_RelativeSemiTones:
			str = "S-T";
			break;
		case kAudioUnitParameterUnit_MIDINoteNumber:
		case kAudioUnitParameterUnit_MIDIController:
			str = "MIDI";
				//these are inclusive, so add one value here
			_numberOfIndexedValues = (int) (_parameterInfo.maxValue+1 - _parameterInfo.minValue);
			break;
		case kAudioUnitParameterUnit_Decibels:
			str = "dB";
			break;
		case kAudioUnitParameterUnit_MixerFaderCurve1:
		case kAudioUnitParameterUnit_LinearGain:
			str = "Gain";
			break;
		case kAudioUnitParameterUnit_Pan:
			str = "L/R";
			break;
		case kAudioUnitParameterUnit_Meters:
			str = "Mtrs";
			break;
		case kAudioUnitParameterUnit_Octaves:
			str = "8ve";
			break;
		case kAudioUnitParameterUnit_BPM:
			str = "BPM";
			break;
		case kAudioUnitParameterUnit_Beats:
			str = "Beats";
			break;
		case kAudioUnitParameterUnit_Milliseconds:
			str = "msecs";
			break;
		case kAudioUnitParameterUnit_Indexed:
			{
				size = sizeof(_namedParameters);
				err = AudioUnitGetProperty (	_parameter.mAudioUnit, 
												kAudioUnitProperty_ParameterValueStrings,
												_parameter.mScope,
												_parameter.mParameterID, 
												&_namedParameters, 
												&size);
				if (!err && _namedParameters) {
					_numberOfIndexedValues = CFArrayGetCount(_namedParameters);
				} else {
						//these are inclusive, so add one value here
					_numberOfIndexedValues = (int) (_parameterInfo.maxValue+1 - _parameterInfo.minValue);
				}
				str = NULL;
			}
			break;
		case kAudioUnitParameterUnit_CustomUnit:
		{
			CFStringRef unitName = _parameterInfo.unitName;
			static char paramStr[256];
			CFStringGetCString (unitName, paramStr, 256, kCFStringEncodingUTF8);
			if (_parameterInfo.flags & kAudioUnitParameterFlag_CFNameRelease)
				CFRelease (unitName);
			str = paramStr;
			break;
		}
		case kAudioUnitParameterUnit_Generic:
		case kAudioUnitParameterUnit_Rate:
		default:
			str = NULL;
			break;
	}
	
	if (str)
		_parameterTag = CFStringCreateWithCString(NULL, str, kCFStringEncodingUTF8);
	else
		_parameterTag = NULL;
}

- (void)mainThreadValueChangedForProperty:(NSString *)propertyName 
{
	[self willChangeValueForKey: propertyName];
	[self didChangeValueForKey: propertyName];
}

#pragma mark _____ Logging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	
	unsigned myLevel = level | kZKMORLogLevel_Continue;
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(myLevel, source, CFSTR("%s\t%@ (%@)"), indentStr, [self parameterName], [self parameterTag]);
}

@end
