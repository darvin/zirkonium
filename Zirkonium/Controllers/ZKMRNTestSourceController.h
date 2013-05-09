/*
 *  ZKMRNTestSourceController.h
 *  Zirkonium
 *
 *  Created by Jens on 24.06.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

@interface ZKMRNTestSourceController : NSObject {	
	
	IBOutlet	NSArrayController*	_outputPatches; 
	
	NSArrayController*			_outputsArrayController;
	
	ZKMORGraph*					_testGraph;
	ZKMORMixerMatrix*			_testMixer;
		/// test sources: 0 == pink noise, 1 == white noise
	unsigned					_testSourceIndex;
	float						_testSourceVolume;
	NSIndexSet*					_testSourceOutputs;
	ZKMNRPannerSource*			_testPannerSource;
	
	BOOL _isTestingPanner;
	
	BOOL _isTestingInPreferences;
	BOOL _isTestingInPresets; 
	
	BOOL _isGraphTesting; 
	
	ZKMORDeviceOutput*		_deviceOutput;
	ZKMORGraph*				_audioGraph;
	ZKMORMixerMatrix*		_mixer;
	ZKMNRVBAPPanner*		_panner;
	ZKMOROutput*			_output; 

}

//Singleton
+(ZKMRNTestSourceController*)sharedTestSourceController;

//Init
-(void)initialize;

//  Testing Accessors
- (ZKMORGraph *)testGraph;

- (unsigned)testSourceIndex;
- (void)setTestSourceIndex:(unsigned)testSourceIndex;
- (IBAction)actionSetTestSourceIndex:(id)inSender;

- (float)testSourceVolume;
- (void)setTestSourceVolume:(float)testSourceVolume;
- (IBAction)actionSetTestSourceVolume:(id)inSender;

- (NSIndexSet *)testSourceOutputs;
- (void)setTestSourceOutputs:(NSIndexSet *)testSourceOutputs;

- (BOOL)isGraphTesting;
- (void)setGraphTesting:(BOOL)isGraphTesting;
//- (IBAction)actionSetGraphTesting:(id)inSender;

- (ZKMNRPannerSource *)testPannerSource;

-(BOOL)isTestingPanner;
-(void)setIsTestingPanner:(BOOL)flag; 

-(BOOL)isTestingInPreferences;
-(void)setIsTestingInPreferences:(BOOL)flag;  

-(BOOL)isTestingInPresets;
-(void)setIsTestingInPresets:(BOOL)flag; 

// synchronization
- (void)synchronizeSpatializationMixerCrosspoints;

// output binding
- (void)bindToOutputController:(NSArrayController*)inController isTestingPanner:(BOOL)isTestingPanner;

@end


@interface ZKMRNTestSourceController (Private) 

@end

