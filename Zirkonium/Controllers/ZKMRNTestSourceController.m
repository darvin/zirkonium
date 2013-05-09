/*
 *  ZKMRNTestSourceController.cpp
 *  Zirkonium
 *
 *  Created by Jens on 24.06.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#include "ZKMRNTestSourceController.h"
#include "ZKMRNZirkoniumSystem.h"
#include "ZKMRNOutputPatchChannel.h"

static ZKMRNTestSourceController* gSharedTestSourceController = nil;

@implementation ZKMRNTestSourceController 

#pragma mark __________SINGLETON
// For NIB safe implementation of Singleton see: http://www.cocoadev.com/index.pl?SingletonDesignPattern

+ (ZKMRNTestSourceController*)sharedTestSourceController
{
    @synchronized(self) {
        if (gSharedTestSourceController == nil) {
            [[self alloc] init];
        }
    }
    return gSharedTestSourceController;
}

#pragma mark -

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (gSharedTestSourceController == nil) {
            return [super allocWithZone:zone];
        }
    }
    return gSharedTestSourceController;
}

- (id)init
{
    Class myClass = [self class];
    @synchronized(myClass) {
        if (gSharedTestSourceController == nil) {
            if (self = [super init]) {
                gSharedTestSourceController = self;
                // custom initialization here
				[self initialize];
			}
        }
    }
    return gSharedTestSourceController;
}

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (unsigned)retainCount { return UINT_MAX; }

- (void)release {}

- (id)autorelease { return self; }

#pragma mark -

-(void)initialize
{
	// custom initialization ...

	//Init Testing
		// default to pink noise
	_testSourceIndex = 0;
	_testSourceVolume = 0.25;
	_isTestingPanner = NO;
	
	_testGraph = [[ZKMORGraph alloc] init];
	_testPannerSource = [[ZKMNRPannerSource alloc] init];
	[[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] panner] registerPannerSource: _testPannerSource];
	
	// set up test graph
	AudioStreamBasicDescription streamFormat;
	ZKMORPinkNoise*		pinkNoise = [[ZKMORPinkNoise alloc] init];
	ZKMORWhiteNoise* 	whiteNoise = [[ZKMORWhiteNoise alloc] init];
	_testMixer = [[ZKMORMixerMatrix alloc] init];
		// set up the conduits
	[_testMixer setNumberOfInputBuses: 2];
	[_testMixer setNumberOfOutputBuses: 1];
	[_testGraph setPurposeString: @"Graph for test tones"];
	[_testMixer setPurposeString: @"Mixer for test tones"];

	streamFormat = [[pinkNoise outputBusAtIndex: 0] streamFormat];
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[pinkNoise outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[whiteNoise outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[_testMixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[_testMixer inputBusAtIndex: 1] setStreamFormat: streamFormat];
		// just send out a mono output, either pink or white noise
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[_testMixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[_testGraph beginPatching];
		[_testGraph setHead: _testMixer];
		[_testGraph patchBus: [pinkNoise outputBusAtIndex: 0] into: [_testMixer inputBusAtIndex: 0]];
		[_testGraph patchBus: [whiteNoise outputBusAtIndex: 0] into: [_testMixer inputBusAtIndex: 1]];
		[_testGraph initialize];
	[_testGraph endPatching];
	[pinkNoise release]; [whiteNoise release]; [_testMixer release];
	
	
	// Init an audio graph and mixer for direct testing ...
	// ****************************************************
	
	_deviceOutput	= [[ZKMORDeviceOutput alloc] init];
	_audioGraph		= [[ZKMORGraph alloc] init];
	[_deviceOutput setGraph: _audioGraph];
	[_audioGraph release]; // give ownership to the device output ...
	
	_mixer = [[ZKMORMixerMatrix alloc] init];
	[_mixer setMeteringOn: YES];

	[self setTestSourceIndex: 0];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputPatchChanged:) name:ZKMRNOutputPatchChangedNotification object:nil];
}

#pragma mark -

#pragma mark - Notifications

-(void)outputPatchChanged:(NSNotification*)inNotification
{
	[self synchronizeSpatializationMixerCrosspoints];	
}

#pragma mark -

#pragma mark _____ Testing Accessors

#pragma mark - Test Graph
- (ZKMORGraph *)testGraph { return _testGraph; }

#pragma mark - Source Index
- (unsigned)testSourceIndex { return _testSourceIndex; }

- (void)setTestSourceIndex:(unsigned)testSourceIndex 
{ 
	_testSourceIndex = testSourceIndex;
	[_testMixer setInputsAndOutputsOn];
	[_testMixer setMasterVolume: _testSourceVolume];
	[_testMixer setVolume: 1.f forCrosspointInput: _testSourceIndex output: 0];	
	[_testMixer setVolume: 0.f forCrosspointInput: (_testSourceIndex + 1) % 2 output: 0];
}

-(IBAction)actionSetTestSourceIndex:(id)inSender
{
	[self setTestSourceIndex:(unsigned)[[inSender selectedCell] tag]];
}
#pragma mark - Source Volume
- (float)testSourceVolume { return _testSourceVolume; }

- (void)setTestSourceVolume:(float)testSourceVolume
{
	_testSourceVolume = testSourceVolume;
	[_testMixer setMasterVolume: _testSourceVolume];
}

- (IBAction)actionSetTestSourceVolume:(id)inSender
{
	[self setTestSourceVolume:[inSender floatValue]];
}

#pragma mark - Source Outputs
- (NSIndexSet *)testSourceOutputs { return _testSourceOutputs; }
- (void)setTestSourceOutputs:(NSIndexSet *)testSourceOutputs
{
	if (testSourceOutputs == _testSourceOutputs) return;
	if (_testSourceOutputs) [_testSourceOutputs release];
	_testSourceOutputs = (testSourceOutputs) ? [testSourceOutputs retain] : nil;
	if ([self isGraphTesting]) [self synchronizeSpatializationMixerCrosspoints];
}

#pragma mark - Graph Testing
- (BOOL)isGraphTesting { return _isGraphTesting; }
- (void)setGraphTesting:(BOOL)isGraphTesting
{
	_isGraphTesting = isGraphTesting; 
	
	[_testGraph stop];
	[_audioGraph stop];		
	[_deviceOutput stop];
	[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] setGraphTesting:NO];
	
	if(_isTestingInPreferences) {
		[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] setGraphTesting:isGraphTesting];
	}
	
	if(_isTestingInPresets)
	{			
		if(isGraphTesting) {
			// Set Output Device ...
			NSError* error = nil;
			ZKMORAudioDevice* audioDevice = [[ZKMRNZirkoniumSystem sharedZirkoniumSystem] audioOutputDevice];
		
			if (!audioDevice || ![_deviceOutput setOutputDevice:audioDevice error:&error]) {
				NSLog(@"Error setting Output Device for Test Source Controller"); 
				return; 
			}
				
			[_audioGraph beginPatching];
				[_mixer uninitialize];			
				unsigned nChannels = [[_deviceOutput outputDevice] numberOfOutputChannels];
				[[_mixer outputBusAtIndex: 0] setNumberOfChannels: nChannels]; 
			
				[_audioGraph 
					patchBus: [_testGraph outputBusAtIndex: 0]  
					into: [_mixer inputBusAtIndex: 0]];
			
				[_audioGraph setHead: _mixer];
			[_audioGraph endPatching];
			[_audioGraph initialize];
			[_mixer setInputsAndOutputsOn];
		
			[_testGraph start];
			[_audioGraph start];		
			[_deviceOutput start];
		} 
	}
	
	[self synchronizeSpatializationMixerCrosspoints];
}


#pragma mark -
- (ZKMNRPannerSource *)testPannerSource { return _testPannerSource; }

-(BOOL)isTestingPanner { return _isTestingPanner; }
-(void)setIsTestingPanner:(BOOL)flag { _isTestingPanner = flag; }

-(BOOL)isTestingInPreferences { return _isTestingInPreferences; }
-(void)setIsTestingInPreferences:(BOOL)flag { _isTestingInPreferences = flag; }  

-(BOOL)isTestingInPresets { return _isTestingInPresets; }
-(void)setIsTestingInPresets:(BOOL)flag { _isTestingInPresets = flag; }

#pragma mark -
- (void)synchronizeSpatializationMixerCrosspoints
{
	if (![self isGraphTesting])    return;
	if (![self testSourceOutputs]) return;
	if (!_outputsArrayController)  return;
	
	if (_isTestingPanner) {
		[_testPannerSource setSynchedWithMixer: NO];
		[[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] panner] transferPanningToMixer];
		return;
	}
		
	// turn off all crosspoints
	[_mixer setCrosspointsToZero];
    unsigned currentIndex = [_testSourceOutputs firstIndex];
	int channel, i = 0;
	
    while (currentIndex != NSNotFound) {
		NSNumber* sourceChannel = [[[_outputsArrayController selectedObjects] objectAtIndex:i] valueForKey:@"sourceChannel"];
		
		if(sourceChannel) {
			channel = [sourceChannel intValue];
			[_mixer setVolume: [[ZKMRNZirkoniumSystem sharedZirkoniumSystem] masterGain] forCrosspointInput: 0 output: channel];
		}
		currentIndex = [_testSourceOutputs indexGreaterThanIndex: currentIndex];
		i++;
    }
}

#pragma mark -
- (void)bindToOutputController:(NSArrayController*)inController isTestingPanner:(BOOL)isTestingPanner
{
	if([self testSourceOutputs])
		[self unbind:@"testSourceOutputs"];
	
	_outputsArrayController = inController;
	_isTestingPanner = isTestingPanner; 
	
	[self bind: @"testSourceOutputs" toObject:inController withKeyPath: @"selectionIndexes" options: nil];
}

@end