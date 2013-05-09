//
//  ZKMORMixerMatrix.mm
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 25.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORMixerMatrix.h"
#include "CAAudioUnitZKM.h"
#include "ZKMORLoggerCPP.h"
#include "ZKMORException.h"

// Convenience Functions
unsigned	ElementForMatrixCrosspoint(unsigned inputBus, unsigned outputBus)
{
	return (inputBus << 16) | (outputBus & 0x0000FFFF);
}

static void		BusesForMatrixCrosspoint(unsigned crosspoint, unsigned* inputBus, unsigned* outputBus)
{
	*inputBus = (crosspoint >> 16);
	*outputBus = (crosspoint & 0x0000FFFF);	
}

@implementation ZKMORMixerMatrix

- (id)init
{
	// create the matrix mixer
	Component comp;
	ComponentDescription desc;
	AudioUnit copyMixerMatrix;
	
	desc.componentType = kAudioUnitType_Mixer;
	desc.componentSubType = kAudioUnitSubType_MatrixMixer;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	comp = FindNextComponent(NULL, &desc);
	if (comp == NULL) return nil;
	if (OpenAComponent(comp, &copyMixerMatrix)) return nil;
	
	self = [super initWithAudioUnit: copyMixerMatrix disposeWhenDone: YES];
	if (self) {
			// this is, for some reason, necessary to ensure that the AU can initialize
			// so just do it here
		[self setNumberOfInputBuses: 1];
		[self setNumberOfOutputBuses: 1];
	}
	
	return self;
}

#pragma mark _____ Metering Properties
- (BOOL)isMeteringOn 
{
	UInt32 isMeteringOn = 0;
	UInt32 dataSize = sizeof(isMeteringOn);

	OSStatus err = mAudioUnit->GetProperty(	kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0,
											&isMeteringOn, &dataSize);
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("isMeteringOn>>error : %i"), err);
	return (BOOL)isMeteringOn;
}

- (void)setMeteringOn:(BOOL)isMeteringOn 
{ 
	UInt32 meteringValue = isMeteringOn;
	UInt32 dataSize = sizeof(meteringValue);

	OSStatus err = mAudioUnit->SetProperty(	kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0,
											&meteringValue, dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"setMeteringOn:>>error : %@", error);
	}
}

#pragma mark _____ Matrix Properties
- (void)getMatrixDimensionsInput:(unsigned *)inputDim output:(unsigned *)outputDim
{
	UInt32 dims[2];
	UInt32 size =  sizeof(UInt32) * 2;
	OSStatus err;
	err = mAudioUnit->GetProperty(	kAudioUnitProperty_MatrixDimensions, kAudioUnitScope_Global, 0,
								dims, &size);
	if (err) {
		if (kAudioUnitErr_Uninitialized == err) {
			*inputDim = 0; *outputDim = 0;
			return;
		}
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"getMatrixDimensionsInput:output:>>error : %@", error);
	} 
	*inputDim = dims[0];
	*outputDim = dims[1];
}

- (void)getMixerLevelsDimensionsInput:(unsigned *)inputDim output:(unsigned *)outputDim
{
	[self getMatrixDimensionsInput: inputDim output: outputDim];
	(*inputDim) += 1; (*outputDim) += 1;
}

#pragma mark _____ Parameters
- (unsigned)getMixerLevels:(Float32 *)levels size:(unsigned)levelsSize
{
	UInt32 size = levelsSize * sizeof(Float32);
	OSStatus err;
	err = mAudioUnit->GetProperty(	kAudioUnitProperty_MatrixLevels, kAudioUnitScope_Global, 0,
								levels, &size);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"getMixerLevels:size:>>error : %@", error);
	} 
	return (unsigned) (size / sizeof(Float32));
}

- (void)setMixerLevels:(Float32 *)levels size:(unsigned)levelsSize
{
	UInt32 size = levelsSize * sizeof(Float32);
	OSStatus err;
	err = mAudioUnit->SetProperty(	kAudioUnitProperty_MatrixLevels, kAudioUnitScope_Global, 0,
								levels, size);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"setMixerLevels:size:>>error : %@", error);
	} 
}

- (float)masterVolume 
{ 
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_Volume, kAudioUnitScope_Global, 0xFFFFFFFF, volume);
	return (float) volume;
}

- (void)setMasterVolume:(float)volume 
{ 
	mAudioUnit->SetParameterViaListener(kMatrixMixerParam_Volume, kAudioUnitScope_Global, 0xFFFFFFFF, volume, 0);
}


- (float)volumeForInput:(unsigned)inputNum 
{
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_Volume, kAudioUnitScope_Input, inputNum, volume);
	return (float) volume;
}

- (void)setVolume:(float)volume forInput:(unsigned)inputNum;
{
	mAudioUnit->SetParameterViaListener(kMatrixMixerParam_Volume, kAudioUnitScope_Input, inputNum, volume, 0);
}

- (float)volumeForOutput:(unsigned)outputNum
{
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_Volume, kAudioUnitScope_Output, outputNum, volume);
	return (float) volume;
}

- (void)setVolume:(float)volume forOutput:(unsigned)outputNum
{
	mAudioUnit->SetParameterViaListener(kMatrixMixerParam_Volume, kAudioUnitScope_Output, outputNum, volume, 0);
}

- (float)volumeForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum 
{ 
	return 
		[self 
			crosspointParameterValue: kMatrixMixerParam_Volume
			inputBus: inputNum
			outputBus: outputNum];
}

- (void)setVolume:(float)volume forCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum
{
	[self 
		setCrosspointParameter:	kMatrixMixerParam_Volume
		value: volume
		inputBus: inputNum
		outputBus: outputNum];
}

#pragma mark _____ Metering
- (float)preAveragePowerForInput:(unsigned)inputNum
{
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_PreAveragePower, kAudioUnitScope_Input, inputNum, volume);
	return (float) volume;
}

- (float)prePeakHoldLevelPowerForInput:(unsigned)inputNum
{
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_PrePeakHoldLevel, kAudioUnitScope_Input, inputNum, volume);
	return (float) volume;
}

- (float)postAveragePowerForInput:(unsigned)inputNum
{
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_PostAveragePower, kAudioUnitScope_Input, inputNum, volume);
	return (float) volume;
}

- (float)postAveragePowerForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum
{
	return 
		[self 
			crosspointParameterValue: kMatrixMixerParam_PostAveragePower
			inputBus: inputNum
			outputBus: outputNum];
}

- (float)postAveragePowerForOutput:(unsigned)outputNum
{
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_PostAveragePower, kAudioUnitScope_Output, outputNum, volume);
	return (float) volume;
}

- (float)postPeakHoldLevelPowerForInput:(unsigned)inputNum
{
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_PostPeakHoldLevel, kAudioUnitScope_Input, inputNum, volume);
	return (float) volume;
}

- (float)postPeakHoldLevelPowerForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum
{
	return 
		[self 
			crosspointParameterValue: kMatrixMixerParam_PostPeakHoldLevel
			inputBus: inputNum
			outputBus: outputNum];
}

- (float)postPeakHoldLevelPowerForOutput:(unsigned)outputNum
{
	Float32 volume;
	mAudioUnit->GetParameter(kMatrixMixerParam_PostPeakHoldLevel, kAudioUnitScope_Output, outputNum, volume);
	return (float) volume;
}

#pragma mark _____ Shortcuts
- (void)setToCanonicalLevels
{
	[self setMasterVolume: 1.0f];
	
	unsigned inputDim, outputDim;
	unsigned i;
	[self getMatrixDimensionsInput: &inputDim output: &outputDim];
	
	// open up all inputs
	for (i = 0; i < inputDim; i++) {
		[self setVolume: 1.0f forInput: i];
	}
	
	// open up all the outputs
	for (i = 0; i < outputDim; i++) {
		[self setVolume: 1.0f forOutput: i];
	}

	// open up the diagonals on each bus
	unsigned numInputBuses = [self numberOfInputBuses];
	unsigned numOutputChannels = [[self outputBusAtIndex: 0] numberOfChannels];	
	unsigned inputNumber = 0;
	for (i = 0; i < numInputBuses; i++) {
		unsigned j;
		unsigned numChannels = [[self inputBusAtIndex: i] numberOfChannels];
		for (j = 0; j < numChannels; j++) {
			unsigned outputNumber = (numOutputChannels > 0) ? j % numOutputChannels : j; // (JB 10.6)Throws Arithmetic exception when numOutputChannels = zero
			[self setVolume: 1.0f forCrosspointInput: inputNumber++ output: outputNumber];
		}
	}
}

- (void)setToDiagonalLevels
{
	[self setMasterVolume: 1.0f];
	
	unsigned inputDim, outputDim;
	unsigned i;
	[self getMatrixDimensionsInput: &inputDim output: &outputDim];
	
	// open up all inputs
	for (i = 0; i < inputDim; i++)
		[self setVolume: 1.0f forInput: i];
	
	// open up all the outputs
	for (i = 0; i < outputDim; i++)
		[self setVolume: 1.0f forOutput: i];

	// open up the diagonals
//	unsigned count = MIN(inputDim, outputDim);
//	for (i = 0; i < count; i++)
//		[self setVolume: 1.0f forCrosspointInput: i output: i];
	unsigned count = MAX(inputDim, outputDim);
	for (i = 0; i < count; i++)
		[self setVolume: 1.0f forCrosspointInput: i % inputDim output: i % outputDim];
}

- (void)setInputsAndOutputsOn
{
	[self setMasterVolume: 1.0f];
	
	unsigned inputDim, outputDim;
	unsigned i;
	[self getMatrixDimensionsInput: &inputDim output: &outputDim];
	
	// open up all inputs
	for (i = 0; i < inputDim; i++)
		[self setVolume: 1.0f forInput: i];
	
	// open up all the outputs
	for (i = 0; i < outputDim; i++)
		[self setVolume: 1.0f forOutput: i];

	// enable all inputs and outputs
	unsigned numInputBuses = [self numberOfInputBuses];
	for (i = 0; i < numInputBuses; i++)
		[(ZKMORMixerMatrixInputBus*) [self inputBusAtIndex: i] setEnabled: YES];

	[(ZKMORMixerMatrixOutputBus*) [self outputBusAtIndex: 0] setEnabled: YES];
}

- (void)setCrosspointsToZero
{
	// close all crosspoints
	unsigned inputDim, outputDim;
	[self getMatrixDimensionsInput: &inputDim output: &outputDim];
	
	//...Bug Track Down here
	unsigned i;
	for (i = 0; i < inputDim; i++) {
		unsigned j;
		for (j = 0; j < outputDim; j++)
			[self setVolume: 0.0f forCrosspointInput: i output: j];
	}
}

- (void)setCrosspointsToZeroForInput:(unsigned)input
{
	// close all crosspoints for this input
	unsigned inputDim, outputDim;
	[self getMatrixDimensionsInput: &inputDim output: &outputDim];

	unsigned j;
	for (j = 0; j < outputDim; j++)
		[self setVolume: 0.0f forCrosspointInput: input output: j];
}

- (Class)inputBusClass { return [ZKMORMixerMatrixInputBus class]; }
- (Class)outputBusClass { return [ZKMORMixerMatrixOutputBus class]; }

- (void)graphSampleRateChanged:(Float64)graphSampleRate
{
	if ([self isInitialized]) {
		// remember the matrix levels
		unsigned inputDim, outputDim;
		[self getMixerLevelsDimensionsInput: &inputDim output: &outputDim];
		unsigned numLevels = inputDim * outputDim;
		Float32 levels[numLevels];
		[self getMixerLevels: levels size: numLevels];
		
/*
		// remember the matrix state -- not actually needed at the moment
		unsigned numInputBuses, numOutputBuses;
		numInputBuses = [self numberOfInputBuses];
		numOutputBuses = [self numberOfOutputBuses];
		BOOL inputsEnabled[numInputBuses], outputsEnabled[numOutputBuses];
		unsigned i;
		for (i = 0; i < numInputBuses; i++)
			inputsEnabled[i] = [(ZKMORMixerMatrixBus*) [self inputBusAtIndex: i] isEnabled];
		for (i = 0; i < numOutputBuses; i++)
			outputsEnabled[i] = [(ZKMORMixerMatrixBus*) [self outputBusAtIndex: i] isEnabled];
*/
		
		// change the sample rate
		[super graphSampleRateChanged: graphSampleRate];
		
		// reinstate the levels
		[self setMixerLevels: levels size: numLevels];

/*
		// reinstate enableing
		for (i = 0; i < numInputBuses; i++)
			[(ZKMORMixerMatrixBus*) [self inputBusAtIndex: i] setEnabled: inputsEnabled[i]];
		for (i = 0; i < numOutputBuses; i++)
			[(ZKMORMixerMatrixBus*) [self outputBusAtIndex: i] setEnabled: outputsEnabled[i]];
*/
	} else {
		// change the sample rate
		[super graphSampleRateChanged: graphSampleRate];	
	}
}



#pragma mark _____ Printing
- (void)logVolumesAtLevel:(unsigned)level 
{
	ZKMORLogger* logger = GlobalLogger();
	ZKMORWriteLogToken* token = logger->GetWriteLogToken(level);
	
	if (!token) return;
	
	unsigned inputs;
	unsigned outputs;
	unsigned i, j;
	[self getMatrixDimensionsInput:&inputs output:&outputs];
	unsigned source = kZKMORLogSource_AudioUnit;
	token->Log(level, source, CFSTR("%@ Mixer Volumes:\n"), self);
	token->ContinueLog(CFSTR("\tInput Channels = %ld, Output Channels = %ld\n"), inputs, outputs);
	
	// print the input and output bus info
	unsigned busCount = [self numberOfInputBuses];
	token->ContinueLog(CFSTR("\tInput Buses:\n\t\t"));
	for (i = 0; i < busCount; i++) {
		ZKMORMixerMatrixInputBus* bus = (ZKMORMixerMatrixInputBus*)[self inputBusAtIndex: i];
		unsigned numChannels = [bus numberOfChannels];
		BOOL isEnabled = [bus isEnabled];
		char frameCharStart = (isEnabled ? '[' : '{');
		char frameCharEnd = (isEnabled ? ']' : '}');
		token->ContinueLog(CFSTR("%ld:%c%ld, %c%c  "), 
			i, frameCharStart, numChannels, (isEnabled ? 'T' : 'F'), frameCharEnd);
	}
	token->ContinueLog(CFSTR("\n"));
	
	busCount = [self numberOfOutputBuses];
	token->ContinueLog(CFSTR("\tOutput Buses:\n\t\t"));
	for (i = 0; i < busCount; i++) {
		ZKMORMixerMatrixOutputBus* bus = (ZKMORMixerMatrixOutputBus*) [self outputBusAtIndex: i];
		unsigned numChannels = [bus numberOfChannels];
		BOOL isEnabled = [bus isEnabled];
		char frameCharStart = (isEnabled ? '[' : '{');
		char frameCharEnd = (isEnabled ? ']' : '}');
		token->ContinueLog(CFSTR("%ld:%c%ld, %c%c  "), 
			i, frameCharStart, numChannels, (isEnabled ? 'T' : 'F'), frameCharEnd);
	}
	logger->ReturnWriteLogToken(token);	
	
	// go into continue mode
	level = level | kZKMORLogLevel_Continue;
	UInt32 volsByteSize = ((inputs + 1) * (outputs + 1)) * sizeof(Float32);
	Float32* mixerLevels	= static_cast<Float32*> (malloc (volsByteSize));
	[self getMixerLevels: mixerLevels size: (volsByteSize / sizeof(Float32))];
		
	for (i = 0; i < (inputs + 1); ++i) {
		token = logger->GetWriteLogToken(level);
		if (!token) break;	
	
		if (i < inputs) {
			token->Log(level, source, CFSTR("\t%.3f   "), mixerLevels[(i + 1) * (outputs + 1) - 1]);
			for (j = 0; j < outputs; ++j)
				token->ContinueLog(CFSTR("(%.3f) "), mixerLevels[(i * (outputs  + 1)) + j]);
			logger->ReturnWriteLogToken(token);
		} else {
			token->Log(level, source, CFSTR("\t%.3f   "), mixerLevels[(inputs + 1) * (outputs + 1) - 1]);
			for (j = 0; j < outputs; ++j)
				token->ContinueLog(CFSTR(" %.3f  "), mixerLevels[(i * (outputs + 1)) + j]);
			logger->ReturnWriteLogToken(token);
		}
	}	

	free(mixerLevels);
}

- (void)logVolumesDebug
{
	[self logVolumesAtLevel: kZKMORLogLevel_Debug];
}

#pragma mark _____ ZKMORMixerMatrix (ZKMORMixerMatrixInternal)
- (float)
	crosspointParameterValue:(AudioUnitElement)parameter
	inputBus:(unsigned)inputBus
	outputBus:(unsigned)outputBus
{
	Float32 value;
	UInt32 element = ElementForMatrixCrosspoint(inputBus, outputBus);
	mAudioUnit->GetParameter(parameter, kAudioUnitScope_Global, element, value);
	return (float) value;
}
					
- (void)
	setCrosspointParameter:(AudioUnitElement)parameter
	value:(float)value
	inputBus:(unsigned)inputBus
	outputBus:(unsigned)outputBus
{
	UInt32 element = ElementForMatrixCrosspoint(inputBus, outputBus);
	mAudioUnit->SetParameterViaListener(	parameter, 
							kAudioUnitScope_Global,
							element,
							value, 
							0);	
}

@end

@implementation ZKMORMixerMatrixInputBus

#pragma mark _____ Accessing
- (unsigned)mixerBusZeroOffset
{
	unsigned inputNumberForBusChannelZero = 0;
	unsigned i;
	ZKMORMixerMatrix* conduit = (ZKMORMixerMatrix*) _conduit;
	for (i = 0; i < _busNumber; i++) 
		inputNumberForBusChannelZero += [[conduit inputBusAtIndex: i] numberOfChannels];
	return inputNumberForBusChannelZero;
}

#pragma mark _____ Parameters
- (BOOL)isEnabled { return (BOOL) [self valueOfParameter: kMatrixMixerParam_Enable]; }
- (void)setEnabled:(BOOL)isEnabled { [self setValueOfParameter: kMatrixMixerParam_Enable value: (float)isEnabled]; }

#pragma mark _____ Metering
- (float)preAveragePower { return [self valueOfParameter: kMatrixMixerParam_PreAveragePower]; }
- (float)postAveragePower { return [self valueOfParameter: kMatrixMixerParam_PostAveragePower]; }
- (float)prePeakHoldLevelPower { return [self valueOfParameter: kMatrixMixerParam_PrePeakHoldLevel]; }
- (float)postPeakHoldLevelPower { return [self valueOfParameter: kMatrixMixerParam_PostPeakHoldLevel]; }

#pragma mark _____ Shortcus
- (void)setToCanonicalLevels
{
	unsigned inputDim, outputDim;
	unsigned i;
	ZKMORMixerMatrix* conduit = (ZKMORMixerMatrix*) _conduit;
	[conduit getMatrixDimensionsInput: &inputDim output: &outputDim];
	
	unsigned inputNumberForBusChannelZero = [self mixerBusZeroOffset];
	unsigned numberOfChannels = [self numberOfChannels];
	unsigned numOutputChannels = [[conduit outputBusAtIndex: 0] numberOfChannels];	
	
		// open up all inputs and crosspoints
	for (i = 0; i < numberOfChannels; i++) {
		[conduit setVolume: 1.0f forInput: i + inputNumberForBusChannelZero];
		[conduit 
			setVolume: 1.0f 
			forCrosspointInput: i + inputNumberForBusChannelZero 
			output: i % numOutputChannels];
	}
}

@end

@implementation ZKMORMixerMatrixOutputBus

#pragma mark _____ Accessing
- (unsigned)mixerBusZeroOffset
{
	unsigned outputNumberForBusChannelZero = 0;
	unsigned i;
	ZKMORMixerMatrix* conduit = (ZKMORMixerMatrix*) _conduit;
	for (i = 0; i < _busNumber; i++) 
		outputNumberForBusChannelZero += [[conduit outputBusAtIndex: i] numberOfChannels];
	return outputNumberForBusChannelZero;
}

#pragma mark _____ Parameters
- (BOOL)isEnabled { return (BOOL) [self valueOfParameter: kMatrixMixerParam_Enable]; }
- (void)setEnabled:(BOOL)isEnabled { [self setValueOfParameter: kMatrixMixerParam_Enable value: (float)isEnabled]; }

#pragma mark _____ Metering
- (float)postAveragePower { return [self valueOfParameter: kMatrixMixerParam_PostAveragePower]; }
- (float)postPeakHoldLevelPower { return [self valueOfParameter: kMatrixMixerParam_PostPeakHoldLevel]; }

@end

#pragma mark _____ Utility Functions
float ZKMORDBToNormalizedDB(float db) { return MAX(1.f + (db / 120.f), 0.f); }
float ZKMORLinearToDB(float linear) { return 20.f * log10f(linear); }
float ZKMORDBToLinear(float db) { return powf(10.f, 0.05f * db); }

BOOL ZKMORIsClipping(float db)
{
	return db > 0.f;
}


