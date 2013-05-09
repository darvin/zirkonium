//
//  ZKMORConduit.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 23.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORConduit.h"
#import "ZKMORUtilities.h"
#import "ZKMORException.h"
#import "ZKMORGraph.h"
#import "ZKMORAudioUnit.h"
#include "ZKMORLoggerCPP.h"
#include "CAStreamBasicDescription.h"


Float64		ZKMORDefaultSampleRate() { return 44100.; }
unsigned	ZKMORDefaultNumberChannels() { return 2; }

  // default to the same as the AudioUnits
unsigned	ZKMORDefaultMaxFramesPerSlice() { return 1152; }

void ZKMORStreamFormatChangeNumberOfChannels(AudioStreamBasicDescription* streamFormat, unsigned numChannels)
{
	CAStreamBasicDescription format(*streamFormat);
	format.ChangeNumberChannels(numChannels, false);
	*streamFormat = format;
}

BOOL ZKMORIsDebuggingOnBus(ZKMORConduitBus* conduitBus, unsigned debugLevel)
{
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct*)conduitBus;
	ZKMORConduitStruct* conduitStruct = (ZKMORConduitStruct *)busStruct->_conduit;
	return (busStruct->_debugLevel & debugLevel) || (conduitStruct->_debugLevel & debugLevel) || (((ZKMORGraphStruct*) conduitStruct->_graph)->_debugLevel & debugLevel);
}

void ZKMORMakeBufferListSilent(AudioBufferList *ioData, AudioUnitRenderActionFlags *ioActionFlags)
{
	// memset the buffers to 0
	unsigned numBuffers = ioData->mNumberBuffers;
	unsigned i;
	for (i = 0; i < numBuffers; i++) {
		memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
	}
	
	*ioActionFlags = (*ioActionFlags) | kAudioUnitRenderAction_OutputIsSilence;
}

void ZKMORMakeBufferListTailSilent(	AudioBufferList				*ioData, 
									AudioUnitRenderActionFlags	*ioActionFlags, 
									UInt32						initialFrame)
{
	// memset the buffers to 0 and return
	unsigned numBuffers = ioData->mNumberBuffers;
	unsigned i;
	for (i = 0; i < numBuffers; i++) {
		UInt32 dataByteSize = ioData->mBuffers[i].mDataByteSize;
		UInt32 initalIndex = initialFrame * ioData->mBuffers[i].mNumberChannels * sizeof(float);
		UInt32 length = dataByteSize - initalIndex;
		memset(((char *)ioData->mBuffers[i].mData + initalIndex), 0, length);
	}
	
	if (initialFrame > 0)
		*ioActionFlags = (*ioActionFlags) | kAudioUnitRenderAction_OutputIsSilence;
}

static OSStatus EmptyRenderFunction(	id							SELF,
										AudioUnitRenderActionFlags 	* ioActionFlags,
										const AudioTimeStamp 		* inTimeStamp,
										UInt32						inOutputBusNumber,
										UInt32						inNumberFrames,
										AudioBufferList				* ioData)
{
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) return noErr;
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) return noErr;
	
	ZKMORLogDebug((CFStringRef) @"Called empty render function for %@", SELF);
	ZKMORMakeBufferListSilent(ioData, ioActionFlags);
	return noErr;
}


@implementation ZKMORConduit

- (void)dealloc {
	[_inputBuses release];
	[_outputBuses release];
	if (_purposeString) [_purposeString release];
	[_descriptionCached release];
	
	[super dealloc];
}

- (id)init {
	if (!(self = [super init]))
		return nil;
	_isInitialized = NO;
	_conduitType = kZKMORConduitType_Processor;
	_maxFramesPerSlice = ZKMORDefaultMaxFramesPerSlice();
	
	_areBusesInitialized = NO;
		// empty arrays just to have arrays there -- they'll get thrown away. 
	_inputBuses = [[NSMutableArray alloc] initWithCapacity: 1];
	_outputBuses = [[NSMutableArray alloc] initWithCapacity: 1];
	
	_debugLevel = kZKMORDebugLevel_None;
	
	_renderFunction = [self renderFunction];
	_isGraphConnectionOwner = [self isGraphConnectionOwner];
	_graph = nil;

	return self;
}

#pragma mark _____ State Management
- (void)initialize 
{ 
	if (!_areBusesInitialized) [self initializeBuses];
	_isInitialized = YES;
}
- (void)globalReset { }
- (void)uninitialize { _isInitialized = NO;}
- (BOOL)isInitialized { return _isInitialized; }

#pragma mark _____ Type Queries
- (BOOL)isProcessor { return _conduitType & kZKMORConduitType_Processor; }
- (BOOL)isSource { return _conduitType & kZKMORConduitType_Source; }
- (BOOL)isSink { return _conduitType & kZKMORConduitType_Sink; }
- (BOOL)isAudioUnit { return [self isKindOfClass: [ZKMORAudioUnit class]]; }
- (BOOL)isMixer { return NO; }
- (BOOL)isFormatConverter { return NO; }
- (BOOL)isStartable { return [self conformsToProtocol: @protocol(ZKMORStarting)]; }




#pragma mark _____ Format Management
- (unsigned)maxFramesPerSlice { return _maxFramesPerSlice; }
- (void)setMaxFramesPerSlice:(unsigned)maxFramesPerSlice { _maxFramesPerSlice = maxFramesPerSlice; }
								

#pragma mark _____ Bus Management 
- (unsigned)numberOfInputBuses { return 1; }
- (BOOL)isNumberOfInputBusesSettable { return NO; }
- (void)setNumberOfInputBuses:(unsigned)busCount
{
	if (![self isNumberOfInputBusesSettable]) {
		ZKMORThrow(ConduitError, @"setNumberOfInputBuses: -- Number of input buses is not settable");
	}
		
	[self setNumberOfBuses:busCount scope: kAudioUnitScope_Input];
	_areBusesInitialized = NO;
}


- (unsigned)numberOfOutputBuses { return 1; }
- (BOOL)isNumberOfOutputBusesSettable { return NO; }

- (void)setNumberOfOutputBuses:(unsigned)busCount
{
	if (![self isNumberOfOutputBusesSettable]) {
		ZKMORThrow(ConduitError, @"setNumberOfOutputBuses: -- Number of output buses is not settable");
	}

	[self setNumberOfBuses: busCount scope: kAudioUnitScope_Output];	
	_areBusesInitialized = NO;
}

- (ZKMORInputBus*)inputBusAtIndex:(unsigned)index {
	if (!(index < [self numberOfInputBuses])) {
		ZKMORThrow(ConduitError, 
			@"Input bus %u does not exist (%u number of buses)", index, [self numberOfInputBuses]);
	}
	if (!_areBusesInitialized) {
		[self initializeBuses];
	}
	return [_inputBuses objectAtIndex: index];	
}

- (ZKMOROutputBus*)outputBusAtIndex:(unsigned)index {
	if (!(index < [self numberOfOutputBuses])) {
		ZKMORThrow(ConduitError, 
			@"Output bus %u does not exist (%u number of buses)", index, [self numberOfOutputBuses]);
	}
	if (!_areBusesInitialized) {
		[self initializeBuses];
	}
	return [_outputBuses objectAtIndex: index];
}

#pragma mark _____ Debugging
- (unsigned)debugLevel { return _debugLevel; }
- (void)setDebugLevel:(unsigned)debugLevel { _debugLevel = debugLevel; }

#pragma mark _____ Rendering
- (ZKMORRenderFunction)renderFunction { return EmptyRenderFunction; }

#pragma mark _____ NSCopying
- (id)copyWithZone:(NSZone *)zone
{
	id newMe = [[[self class] allocWithZone: zone] init];
	return newMe;
}

#pragma mark _____ NSCoding
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	if ([aCoder allowsKeyedCoding]) {
		
	} else {

	}
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [self init])) {
		[self release];
		return nil;
	}
	
	if ([aDecoder allowsKeyedCoding]) {

	} else {

	}

	return self;
}

#pragma mark _____ ZKMORConduitLogging
- (NSString *)purposeString { return _purposeString; }
- (void)setPurposeString:(NSString *)purposeString
{
	if (_purposeString) [purposeString release];
		// copy does an implicit retain
	_purposeString = [purposeString copy];
}

- (void)logInputFormatWithIndent:(unsigned)indent bus:(unsigned)bus
{
	ZKMORConduitBus* inputBus = [self inputBusAtIndex: bus];
	char indentStr[16];
	char str[255];
	
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORPrintABSD([inputBus streamFormat], str, 255, false);
	ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Conduit, CFSTR("%sInput Format  %u : %s"), indentStr, bus, str);
}

- (void)logOutputFormatWithIndent:(unsigned)indent bus:(unsigned)bus
{
	ZKMORConduitBus* outputBus = [self outputBusAtIndex: bus];
	CAStreamBasicDescription streamFormat();
	
	char indentStr[16];
	char str[255];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORPrintABSD([outputBus streamFormat], str, 255, false);
	ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Conduit, CFSTR("%sOutput Format  %u : %s"), indentStr, bus, str);
}

- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	unsigned numInputs = [self numberOfInputBuses];
	unsigned numOutputs = [self numberOfOutputBuses];
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);	
	const char* isInitString = ([self isInitialized]) ? "Initialized" : "Uninitialized";
	ZKMORLog(level, source, CFSTR("%@%s%@ %s num buses: [%u in, %u out]"), tag, indentStr, self, isInitString, numInputs, numOutputs);
	[self logBusFormatSummary];
}

- (void)logBusFormatSummary
{
	unsigned i;
	unsigned numInputs = [self numberOfInputBuses];
	unsigned numOutputs = [self numberOfOutputBuses];	
	unsigned numToPrint = MIN(numInputs, (unsigned) 5);
	for (i = 0; i < numToPrint; i++) {
		[self logInputFormatWithIndent: 1 bus: i];
	}
	if (numToPrint < numInputs)
			// extra space before %u to line up with "Output Format"	
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Irrelevant, CFSTR("\tInput Format  %u - %u..."), numToPrint, numInputs - 1);
	numToPrint = MIN(numOutputs, (unsigned) 5);
	for (i = 0; i < numToPrint; i++) {
		[self logOutputFormatWithIndent: 1 bus: i];
	}
	if (numToPrint < numOutputs)
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Irrelevant, CFSTR("\tOutput Format %u - %u..."), numToPrint, numOutputs - 1);	
}

#pragma mark _____ ZKMORConduitInternal
- (ZKMORGraph *)graph { return _graph; }
- (void)setGraph:(ZKMORGraph *)graph { _graph = graph; }
- (Class)inputBusClass { return [ZKMORInputBus class]; }
- (Class)outputBusClass { return [ZKMOROutputBus class]; }

	// do nothing by default
- (void)setNumberOfBuses:(unsigned)numBuses scope:(AudioUnitScope)scope { }

- (void)initializeBusesForScope:(AudioUnitScope)scope {
	unsigned i, numberOfBuses;
	Class busClass;
	NSMutableArray* arrayOld;
	if (kAudioUnitScope_Input == scope) {
		numberOfBuses = [self numberOfInputBuses];
		busClass = [self inputBusClass];
		arrayOld = _inputBuses;
	} else {
		numberOfBuses = [self numberOfOutputBuses];
		busClass = [self outputBusClass];
		arrayOld = _outputBuses;
	}
	
	// create a new array as a way of weeding out buses I now longer need
	NSMutableArray* arrayNew = [[NSMutableArray alloc] initWithCapacity: numberOfBuses];
	for (i = 0; i < numberOfBuses; i++) {
		id bus;
		// check if the bus already exists
		if (i < [arrayOld count]) {
			// if so, copy the old bus over
			bus = [arrayOld objectAtIndex: i];
			[bus updateStreamFormat];
			[arrayNew addObject: bus];
		} else {
			// o.w., create a new bus
			bus = 
				[[busClass alloc] 
					initWithConduit: self
					busNumber: i
					scope: scope];
			[arrayNew addObject: bus];
				// it's in the array now (which is retaining it)
			[bus release];					
		}
	}
	
	if (kAudioUnitScope_Input == scope)
		_inputBuses = arrayNew;
	else
		_outputBuses = arrayNew;
	[arrayOld release];
}

- (void)initializeBuses {
	[self initializeBusesForScope: kAudioUnitScope_Input];
	[self initializeBusesForScope: kAudioUnitScope_Output];
	_areBusesInitialized = YES;
}

- (void)getStreamFormatForBus:(ZKMORConduitBus *)bus { 
	CAStreamBasicDescription streamFormat;
		// set non-interleaved for the default number of channels
	streamFormat.SetCanonical(ZKMORDefaultNumberChannels(), false);
	streamFormat.mSampleRate = ZKMORDefaultSampleRate();

	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct *) bus;
	busStruct->_streamFormat = streamFormat;
}

- (void)setStreamFormatForBus:(ZKMORConduitBus *)bus { 
	// by default, only accept non-interleaved PCM float formats
	CAStreamBasicDescription streamFormat([bus streamFormat]);
	if (!streamFormat.IsPCM()) {
		ZKMORThrow(ConduitError, @"setStreamFormatForBus: -- stream format must be PCM");
	}
	
	if (streamFormat.IsInterleaved()) {
		ZKMORThrow(ConduitError, @"setStreamFormatForBus: -- stream format must be non-interleaved");
	}	

	if (!(streamFormat.mFormatFlags & kAudioFormatFlagIsFloat)) {
		ZKMORThrow(ConduitError, @"setStreamFormatForBus: -- stream format must be a float format");
	}
	if (_graph) [_graph changedStreamFormatOnConduitBus: bus];
}

- (BOOL)isGraphConnectionOwner { return [self isAudioUnit]; }

- (void)setCallback:(AURenderCallbackStruct*)callback busNumber:(unsigned)bus { }

	// go through the buses and update their sample rates -- subclasses may override
- (void)graphSampleRateChanged:(Float64)graphSampleRate
{
	BOOL wasInitialized = [self isInitialized];
	[self uninitialize];
	unsigned i, numberOfBuses = [self numberOfOutputBuses];
	for (i = 0; i < numberOfBuses; i++) {
		ZKMORConduitBus* bus = [self outputBusAtIndex: i];
		[bus setSampleRate: graphSampleRate];
	}
	numberOfBuses = [self numberOfInputBuses];
	for (i = 0; i < numberOfBuses; i++) {
		ZKMORConduitBus* bus = [self inputBusAtIndex: i];
		[bus setSampleRate: graphSampleRate];
	}
	if (wasInitialized)
		[self initialize];
}

@end

@implementation ZKMORConduitBus

- (NSString *)description
{
	NSString* myDesc = [super description];
	NSString* parentDesc = [_conduit description];
	NSString* string = [NSString stringWithFormat:@"%@:%u <%@>", parentDesc, _busNumber, myDesc];	
	return string;
}

- (id)initWithConduit:(id)conduit busNumber:(unsigned)busNumber scope:(AudioUnitScope)scope
{
	if (self = [super init]) {
		_conduit = conduit;
		_busNumber = busNumber;
		_scope = scope;
		_isExecutingPropertyChange = NO;
		
		// default the stream desc
		CAStreamBasicDescription desc;
		desc.mSampleRate = ZKMORDefaultSampleRate();
		// make it non-interleaved, canonical
		desc.SetCanonical(ZKMORDefaultNumberChannels(), false);
		_streamFormat = desc;
		
			// read in the appropriate stream format
		[self updateStreamFormat];		
	}
	return self;
}

#pragma mark _____ Accessors
- (ZKMORConduit *)conduit { return _conduit; }
- (unsigned)busNumber { return _busNumber; }

- (AudioStreamBasicDescription)streamFormat { return _streamFormat; }
- (void)setStreamFormat:(AudioStreamBasicDescription)streamFormat {
	// Used to throw an error in this case -- now try to make the programmer's life easier
//	if ([_conduit isInitialized]) {
//		ZKMORThrow(ConduitError, @"setStreamFormat: -- processor core already initialized");
//	}
	BOOL wasInitialized = [_conduit isInitialized];
	if (wasInitialized) [_conduit uninitialize];
	
	@synchronized(self) {
		_isExecutingPropertyChange = YES;
		_streamFormat = streamFormat;
		[_conduit setStreamFormatForBus: self];
		_isExecutingPropertyChange = NO;
	}
	if (wasInitialized) [_conduit initialize];
}

#pragma mark _____ Scope
- (AudioUnitScope)scope { return _scope; }
- (BOOL)isInput { return NO; }
- (BOOL)isOutput { return NO; }

					
#pragma mark _____ Convenience Functions
- (unsigned)numberOfChannels { return _streamFormat.mChannelsPerFrame; }
- (void)setNumberOfChannels:(unsigned)numberOfChannels
{
	CAStreamBasicDescription streamFormat(_streamFormat);
	streamFormat.ChangeNumberChannels(numberOfChannels, false);
	[self setStreamFormat: streamFormat];
}

- (Float64)sampleRate { return _streamFormat.mSampleRate; }
- (void)setSampleRate:(Float64)sampleRate 
{ 
	AudioStreamBasicDescription absdNew = _streamFormat;
	absdNew.mSampleRate = sampleRate;
	[self setStreamFormat: absdNew];
}

#pragma mark _____ Debugging
- (unsigned)debugLevel { return _debugLevel; }
- (void)setDebugLevel:(unsigned)debugLevel { _debugLevel = debugLevel; }

#pragma mark _____ ZKMORConduitLogging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	char indentStr[16];
	char str[255];
	
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORPrintABSD([self streamFormat], str, 255, false);
	if ([self isInput])
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Conduit, CFSTR("%sInput Bus %u on %@ : %s"), indentStr, _busNumber, _conduit, str);
	else 
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Conduit, CFSTR("%sOutput Bus %u on %@ : %s"), indentStr, _busNumber, _conduit, str);		
}

- (void)logDebug
{
	[self logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Irrelevant indent: 0 tag: @""];
}

#pragma mark _____ ZKMORConduitBusInternal
- (void)updateStreamFormat { [_conduit getStreamFormatForBus: self]; }

@end

@implementation ZKMORInputBus

- (id)init
{
	if (!(self = [super init]))
		return nil;
	
	_feederBus = nil;
	return self;
}

- (BOOL)isInput { return YES; }

#pragma mark _____ ZKMORInputBusInternal

- (BOOL)preparePatch:(ZKMOROutputBus *)source error:(NSError **)error
{
	[_conduit uninitialize];
	[self setStreamFormat: [source streamFormat]];
	
	return YES;
}

@end


@implementation ZKMOROutputBus

- (id)init
{
	if (!(self = [super init]))
		return nil;
	
	_receiverBus = nil;
	return self;
}

- (BOOL)isOutput { return YES; }

@end


static OSStatus ZKMORAbstractMethodCallCallback(	id							SELF,
													AudioUnitRenderActionFlags 	* ioActionFlags,
													const AudioTimeStamp 		* inTimeStamp,
													UInt32						inOutputBusNumber,
													UInt32						inNumberFrames,
													AudioBufferList				* ioData)
{
	ZKMORAbstractMethodCallConduit* selfObj = (ZKMORAbstractMethodCallConduit*) SELF;
	return 
		[selfObj
			invokeFlags: ioActionFlags
			timeStamp: inTimeStamp
			outputBusNumber: inOutputBusNumber
			numberOfFrames: inNumberFrames
			bufferList: ioData];
}


@implementation ZKMORAbstractMethodCallConduit

- (id)init
{
	if (!(self = [super init]))
		return nil;

	_invokeFunctionPointer = 
		[self 
			methodForSelector: 
				@selector(invokeFlags:timeStamp:outputBusNumber:numberOfFrames:bufferList:)];
	return self;
}

- (ZKMORRenderFunction)renderFunction { return ZKMORAbstractMethodCallCallback; }

- (OSStatus)
	invokeFlags:(AudioUnitRenderActionFlags *)ioActionFlags
	timeStamp:(const AudioTimeStamp *)inTimeStamp
	outputBusNumber:(UInt32)inOutputBusNumber
	numberOfFrames:(UInt32)inNumberFrames
	bufferList:(AudioBufferList *)ioData
{
	// subclass responsibility
	return noErr;
}	

@end
