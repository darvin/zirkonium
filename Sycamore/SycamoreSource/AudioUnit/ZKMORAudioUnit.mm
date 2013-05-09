//
//  ZKMORAudioUnit.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioUnit.h"
#import "ZKMORException.h"
#import "ZKMORUtilities.h"
#include "ZKMORLogger.h"
#include "CAAudioUnitZKM.h"
#include "CAComponentDescription.h"
#include "CAXException.h"


@interface ZKMORAudioUnit (ZKMORAudioUnitPrivate)

- (void)initializePropertyListeners;
- (void)changedStreamFormatInScope:(AudioUnitScope)scope bus:(AudioUnitElement)bus;

@end

static OSStatus AudioUnitRenderFunction(	id							SELF,
											AudioUnitRenderActionFlags 	* ioActionFlags,
											const AudioTimeStamp 		* inTimeStamp,
											UInt32						inOutputBusNumber,
											UInt32						inNumberFrames,
											AudioBufferList				* ioData)
{
	ZKMORAudioUnitStruct* theAU = (ZKMORAudioUnitStruct*) SELF;
	CAAudioUnitZKM* caAU = theAU->mAudioUnit;
	return caAU->Render(ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
}

static OSStatus AudioUnitParameterScheduleFunction(		id								SELF, 
														const AudioUnitParameterEvent	* inParameterEvent,
														UInt32							inNumParamEvents)
{
	ZKMORAudioUnitStruct* theAU = (ZKMORAudioUnitStruct*) SELF;
	CAAudioUnitZKM* caAU = theAU->mAudioUnit;
	return caAU->ScheduleParameterViaListener(inParameterEvent, inNumParamEvents);
}

static OSStatus AudioUnitParameterGetFunction(	id						SELF, 
												AudioUnitParameterID	inID,
												AudioUnitScope			inScope,
												AudioUnitElement		inElement,
												Float32					* outValue)	
{
	ZKMORAudioUnitStruct* theAU = (ZKMORAudioUnitStruct*) SELF;
	CAAudioUnitZKM* caAU = theAU->mAudioUnit;
	return caAU->GetParameter(inID, inScope, inElement, *outValue);
}

static void AudioUnitPropertyListener(	void*						SELF,
										AudioUnit					ci, 
										AudioUnitPropertyID			inID, 
										AudioUnitScope				inScope, 
										AudioUnitElement			inElement)
{
	ZKMORAudioUnit* theAU = (ZKMORAudioUnit*) SELF;
	ZKMORAudioUnitStruct* theAUStruct = (ZKMORAudioUnitStruct*) SELF;
	
	// check if the bus initiated this change	
	NSMutableArray* array;
		// reach directly into the object and grab what we are looking for
	array = (kAudioUnitScope_Input == inScope) ? theAUStruct->_inputBuses : theAUStruct->_outputBuses;
	if (inElement < [array count]) {
		ZKMORConduitBusStruct* bus = (ZKMORConduitBusStruct*) [array objectAtIndex: inElement];
		if (bus->_isExecutingPropertyChange)
			return;		
	}

	if (kAudioUnitProperty_StreamFormat == inID) {
		[theAU changedStreamFormatInScope: inScope bus: inElement];
	}
	
	if (kAudioUnitProperty_BusCount == inID) {
		theAUStruct->_areBusesInitialized = NO;
	}
}

@implementation ZKMORAudioUnit
	
- (void)dealloc {
	if (mAudioUnit) {
		if (_disposeWhenDone)
			CloseComponent(mAudioUnit->AU());
		delete mAudioUnit;
	}
	[super dealloc];
}
	
- (id)initWithAudioUnit:(AudioUnit)audioUnit {
	if (self = [super init]) {
		mAudioUnit = new CAAudioUnitZKM(audioUnit);
		_disposeWhenDone = YES;
		[self initializePropertyListeners];
	}
	return self;
}

- (id)initWithAudioUnit:(AudioUnit)audioUnit disposeWhenDone:(BOOL)disposeWhenDone; {
	if (self = [self initWithAudioUnit:audioUnit]) {
		_disposeWhenDone = disposeWhenDone;
	}
	return self;
}

#pragma mark _____ Accessors
- (AudioUnit)audioUnit { return mAudioUnit->AU(); }

- (NSString *)audioUnitManufacturer { return (NSString*) mAudioUnit->Comp().GetAUManu(); }
- (NSString *)audioUnitName { return (NSString*) mAudioUnit->Comp().GetAUName(); }
- (NSString *)componentName { return (NSString*) mAudioUnit->Comp().GetCompName(); }
- (NSString *)componentInfo { return (NSString*) mAudioUnit->Comp().GetCompInfo(); }

#pragma mark _____ ZKMORConduit Overrides
- (Class)inputBusClass { return [ZKMORAudioUnitInputBus class]; }
- (Class)outputBusClass { return [ZKMORAudioUnitOutputBus class]; }

- (unsigned)numberOfInputBuses {
	UInt32 busCount;
	mAudioUnit->GetElementCount(kAudioUnitScope_Input, busCount);
	return (unsigned)busCount;
}

- (unsigned)numberOfOutputBuses {
	UInt32 busCount;
	mAudioUnit->GetElementCount(kAudioUnitScope_Output, busCount);
	return (unsigned)busCount;
}

- (BOOL)isMixer { 
	const CAComponent& component = mAudioUnit->Comp();
	return component.Desc().componentType == kAudioUnitType_Mixer;
}

- (BOOL)isFormatConverter { 
	const CAComponent& component = mAudioUnit->Comp();
	return component.Desc().IsFConv();
}


- (BOOL)isNumberOfInputBusesSettable 
{ 
	bool isSettable;
	OSStatus err = [self caAudioUnit]->IsElementCountWritable(kAudioUnitScope_Input, isSettable);
	if (err)
		ZKMORLogError(kZKMORLogSource_AudioUnit, 
			CFSTR("isNumberOfInputBusesSettable : IsElementCountWritable>>error %u"), err);
	return isSettable;
}

- (BOOL)isNumberOfOutputBusesSettable 
{ 
	bool isSettable;
	OSStatus err = [self caAudioUnit]->IsElementCountWritable(kAudioUnitScope_Output, isSettable);
	if (err)
		ZKMORLogError(kZKMORLogSource_AudioUnit, 
			CFSTR("isNumberOfOutputBusesSettable : IsElementCountWritable>>error %u"), err);
	return isSettable;
}

- (void)setNumberOfBuses:(unsigned)busCount scope:(AudioUnitScope)scope 
{
	OSStatus err = [self caAudioUnit]->SetElementCount(scope, busCount);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"setNumberOfBuses:scope:>>error : %@", error);
	}
}

- (void)getStreamFormatForBus:(ZKMORConduitBus *)bus 
{
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct*) bus;
	if (kAudioUnitScope_Input == busStruct->_scope)
		[self caAudioUnit]->GetInputStreamFormat(	busStruct->_busNumber, 
													busStruct->_streamFormat);
	else
		[self caAudioUnit]->GetOutputStreamFormat(	busStruct->_busNumber, 
													busStruct->_streamFormat);
}

- (void)setStreamFormatForBus:(ZKMORConduitBus *)bus 
{
	CAAudioUnitZKM* au = [self caAudioUnit];
	// pass this call on through
	try {
		ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct*) bus;
		if (kAudioUnitScope_Input == busStruct->_scope) {
			au->SetInputStreamFormat(busStruct->_busNumber, busStruct->_streamFormat);
			au->GetInputStreamFormat(busStruct->_busNumber, busStruct->_streamFormat);
		} else {
			au->SetOutputStreamFormat(busStruct->_busNumber, busStruct->_streamFormat);
			au->GetOutputStreamFormat(busStruct->_busNumber, busStruct->_streamFormat);
		}
	} catch (CAXException& e) {
		char errorStr[255];
		e.FormatError(errorStr);
		ZKMORThrow(AudioUnitError, @"setStreamFormatForBus:>>error: %s", errorStr);
	}
}

- (void)graphSampleRateChanged:(Float64)graphSampleRate
{
	// change the output sample rate, but don't change the input,
	// if I'm a format converter -- 
	BOOL isInitialized = [self isInitialized];
	[self uninitialize];
	unsigned i, numberOfBuses;
	numberOfBuses = [self numberOfOutputBuses];
	for (i = 0; i < numberOfBuses; i++) {
		ZKMORConduitBus* outputBus = [self outputBusAtIndex: i];
		[outputBus setSampleRate: graphSampleRate];
	}
	
	if ([self isFormatConverter])
		return;
	
	numberOfBuses = [self numberOfInputBuses];
	for (i = 0; i < numberOfBuses; i++) {
		ZKMORConduitBus* inputBus = [self inputBusAtIndex: i];
		[inputBus setSampleRate: graphSampleRate];
	}
	
	if (isInitialized) [self initialize];
}

- (void)setCallback:(AURenderCallbackStruct *)callback busNumber:(unsigned)bus { mAudioUnit->SetRenderCallback(bus, callback); }

- (void)initialize 
{
	OSStatus err = mAudioUnit->Initialize();
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		//ZKMORThrow(AudioUnitError, @"initialize>>error: %@", error);
		NSLog(@"ZKMORAudioUnit Error: %@", [error description]);
	}
	[super initialize];	
}

- (void)globalReset 
{
	OSStatus err = mAudioUnit->GlobalReset();
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"globalReset>>error: %@", error);
	}
	[super globalReset];
}

- (void)uninitialize 
{
	[super uninitialize];
	OSStatus err = mAudioUnit->Uninitialize();
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"uninitialize>>error: %@", error);
	}
}

- (unsigned)maxFramesPerSlice 
{
	try {
		return mAudioUnit->GetMaximumFramesPerSlice();
	} catch (CAXException& e) {
//		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: e.mError userInfo: nil];
//		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("maxFramesPerSlice>>error %@"), error);
		char errorStr[255];
		e.FormatError(errorStr);
		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("maxFramesPerSlice>>error %s"), errorStr);
	}
	return 0;
}

- (void)setMaxFramesPerSlice:(unsigned)maxFramesPerSlice
{
	try {
		mAudioUnit->SetMaximumFramesPerSlice(maxFramesPerSlice);
		[super setMaxFramesPerSlice: maxFramesPerSlice];
	} catch (CAXException& e) {
//		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: e.mError userInfo: nil];
//		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("setMaxFramesPerSlice>>error %@"), error);
		char errorStr[255];
		e.FormatError(errorStr);
//		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("setMaxFramesPerSlice>>error %s"), errorStr);
		ZKMORThrow(AudioUnitError, @"setMaxFramesPerSlice>>error %s", errorStr);
	}
}

- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	
	unsigned myLevel = level | kZKMORLogLevel_Continue;
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	if (!mAudioUnit->IsValid()) {
		ZKMORLog(myLevel, source, CFSTR("%s\t*INVALID*"), indentStr);
		return;
	}
	
	CAComponentDescription desc = mAudioUnit->Comp().Desc();
	ZKMORLog(myLevel, source, CFSTR("%s\t%4.4s:%4.4s:%4.4s : %@"),
		indentStr,
		(char *)&(desc.componentType), 
		(char *)&(desc.componentSubType), 
		(char *)&(desc.componentManufacturer),
		[self componentName]);
}

- (ZKMORRenderFunction)renderFunction { return AudioUnitRenderFunction; }

#pragma mark _____ NSCopying
- (id)copyWithZone:(NSZone *)zone
{
	CAComponent comp = mAudioUnit->Comp();
	AudioUnit newAU;
	OSStatus err = noErr;
	if (err = comp.Open(newAU)) {
		CAComponentDescription desc = comp.Desc();
		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("Could not copy Audio Unit {%4.4s, %4.4s, %4.4s} : %i"), 
			desc.componentType, desc.componentSubType, desc.componentManufacturer, err);
		return nil;
	}
	
	id newMe = [[[self class] allocWithZone: zone] initWithAudioUnit: newAU];
	return newMe;
}

#pragma mark _____ ZKMORAudioUnitPrivate
- (void)initializePropertyListeners 
{
	mAudioUnit->AddPropertyListener(kAudioUnitProperty_StreamFormat, AudioUnitPropertyListener, self);
	mAudioUnit->AddPropertyListener(kAudioUnitProperty_BusCount, AudioUnitPropertyListener, self);
}

- (void)changedStreamFormatInScope:(AudioUnitScope)scope bus:(AudioUnitElement)bus 
{ 
	_areBusesInitialized = NO;
}

#pragma mark _____ ZKMORAudioUnitCPP
- (CAAudioUnitZKM *)caAudioUnit { return mAudioUnit; }


#pragma mark _____ ZKMORAudioUnitInternal
- (BOOL)hasChannelLayoutsInScope:(AudioUnitScope)scope bus:(AudioUnitElement)bus {
	try {
		return mAudioUnit->HasChannelLayouts(scope, bus);
	} catch (CAXException& e) {
		char errorStr[255];
		e.FormatError(errorStr);
		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("hasChannelLayoutsInScope:bus:>>error %s"), errorStr);
		return 0;
	}
	return NO;
}

- (unsigned)numberOfParametersInScope:(AudioUnitScope)scope bus:(unsigned)bus 
{ 
	try {
		return mAudioUnit->GetNumParameters(scope, bus);
	} catch (CAXException& e) {
		char errorStr[255];
		e.FormatError(errorStr);
		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("numberOfParametersInScope:bus:>>error %s"), errorStr);
		return 0;
	}
}

- (void)getParameterIDs:(AudioUnitParameterID *)ids scope:(AudioUnitScope)scope	bus:(unsigned)bus dataSize:(unsigned *)size
{
	UInt32 dataSize = *size;
	mAudioUnit->GetParameterIDs(scope, bus, ids, &dataSize);
	*size = dataSize;
}

- (float)valueOfParameter:(AudioUnitParameterID)parameter scope:(AudioUnitScope)scope element:(AudioUnitElement)element 
{
	Float32 value;
	OSStatus err = mAudioUnit->GetParameter(parameter, scope, element, value);
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("valueOfParameter:scope:element:>>error %i"), err);
	return (float) value;
}

- (void)setValueOfParameter:	(AudioUnitParameterID)parameter 
					scope:		(AudioUnitScope)scope 
					element:	(AudioUnitElement)element
					value:		(float)value 
{
	Float32 myValue = (Float32) value;
	OSStatus err = mAudioUnit->SetParameterViaListener(parameter, scope, element, myValue, 0);
	if (err) 
		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("setValueOfParameter:scope:element:value:>>error %i"), err);
}


//- (ZKMORParameterGetFunction)parameterGetFunction { return AudioUnitParameterGetFunction; }

//- (ZKMORParameterScheduleFunction)parameterScheduleFunction { return AudioUnitParameterScheduleFunction; }

@end

@implementation ZKMORAudioUnitInputBus

- (float)valueOfParameter:(AudioUnitParameterID)parameter {
	return [(ZKMORAudioUnit*) _conduit valueOfParameter: parameter scope: _scope element: _busNumber];
}

- (void)setValueOfParameter:(AudioUnitParameterID)parameter value:(float)value {
	[(ZKMORAudioUnit*)_conduit setValueOfParameter: parameter scope: _scope element: _busNumber value: value];
}

@end


@implementation ZKMORAudioUnitOutputBus

- (float)valueOfParameter:(AudioUnitParameterID)parameter {
	return [(ZKMORAudioUnit*) _conduit valueOfParameter: parameter scope: _scope element: _busNumber];
}

- (void)setValueOfParameter:(AudioUnitParameterID)parameter value:(float)value {
	[(ZKMORAudioUnit*) _conduit setValueOfParameter: parameter scope: _scope element: _busNumber value: value];
}

@end
