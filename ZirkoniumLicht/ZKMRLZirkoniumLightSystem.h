//
//  ZKMRLZirkoniumLightSystem.h
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

@class ZKMRLPannerLight, ZKMRLMixerLight, ZKMRLOutputDMX, ZKMRLLightSetupDocument, ZKMRLLightView;
@class ZKMRLOSCController;
@interface ZKMRLZirkoniumLightSystem : NSObject {

	//  Misc State
	ZKMRLLightSetupDocument*	_lightSetup;
	id							_appDelegate;
	
	//  Light State
	ZKMNRSpeakerLayout*	_lampLayout;
	ZKMRLPannerLight*	_panner;
	ZKMRLMixerLight*	_mixer;
	ZKMRLOutputDMX*		_outputDMX;
	NSTimer*			_outputTimer;
	
	//  Panner State
	NSMutableArray*		_lightIds;
	
	// External Interfaces
	ZKMRLOSCController*	_oscController;
}

//  Singleton
+ (ZKMRLZirkoniumLightSystem *)sharedZirkoniumLightSystem;

//  Accessors
- (ZKMRLPannerLight *)panner;
- (ZKMRLMixerLight *)mixer;
- (ZKMNRSpeakerLayout *)lampLayout;

- (ZKMRLLightSetupDocument *)lightSetup;

- (NSString *)lanBoxAddress;
- (void)setLanBoxAddress:(NSString *)lanBoxAddress;
- (NSString *)defaultLanBoxAddress;

- (id)appDelegate;
- (void)setAppDelegate:(id)appDelegate;

//  Actions
- (unsigned)numberOfLightIds;
- (void)setNumberOfLightIds:(unsigned)numberOfIds;

	/// If color is nil, it remains unchanged
- (void)panId:(unsigned)idNumber az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span color:(NSColor *)color;
	/// If color is nil, it remains unchanged
- (void)panId:(unsigned)idNumber xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span color:(NSColor *)color ;
	/// If color is nil, it remains unchanged
- (void)panId:(unsigned)idNumber lampAz:(ZKMNRSphericalCoordinate)center color:(NSColor *)color;
	/// If color is nil, it remains unchanged
- (void)panId:(unsigned)idNumber lampXy:(ZKMNRRectangularCoordinate)center color:(NSColor *)color;

- (void)setColor:(NSColor *)color forId:(unsigned)idNumber;

@end
