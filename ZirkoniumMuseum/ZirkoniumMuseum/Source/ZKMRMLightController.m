//
//  ZKMRMLightController.m
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 10.09.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMLightController.h"
#import "ZKMRMMuseumSystem.h"
#import "ZKMRLPannerLight.h"
#import "ZKMRLMixerLight.h"
#import "ZKMRLOutputDMX.h"

@interface ZKMRMLightController (ZKMRMLightControllerPrivate)

- (void)setPreferencesToDefaultValues;

@end


@implementation ZKMRMLightController


- (void)dealloc
{
	if (lightIds) [lightIds release];
	[super dealloc];
}

- (id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)zirkoniumSystem
{
	if (!(self = [super initWithZirkoniumSystem: zirkoniumSystem])) return nil;
	
	lightIds = [[NSMutableArray alloc] init];
	
	[self setPreferencesToDefaultValues];
	
	return self;
}

- (ZKMRMMuseumSystem *)museumSystem { return (ZKMRMMuseumSystem *) _zirkoniumSystem; }

- (ZKMRLMixerLight *)mixerLight { return [[self museumSystem] mixerLight]; }
- (ZKMRLPannerLight *)pannerLight { return [[self museumSystem] pannerLight]; }
- (ZKMRLOutputDMX *)outputDMX { return [[self museumSystem] outputDMX]; }

- (void)setColor:(NSColor *)color forId:(unsigned)idNumber
{
	if (color) [[self mixerLight] setColor: color forInput: idNumber];	
}

- (void)sendNumberOfLights
{
	// In this case, since we have an in-process pannerLight, we don't actually need to "send" 
	// it -- we just setup the pannerLight
		// remove the old ids
	int i = [lightIds count] - 1;
	for ( ; i > -1; --i) 
	{
		[[self pannerLight] unregisterPannerSource: [lightIds objectAtIndex: i]];
		[lightIds removeObjectAtIndex: i];
	}

	// set the number of ids on the mixer	
	[[self mixerLight] setNumberOfInputChannels: self.numberOfLights];
	
	NSColor* blackColor = [[NSColor blackColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
	// register the ids with the panner
	for (i = 0; i < self.numberOfLights; ++i)
	{
		ZKMNRPannerSource* newId = [[ZKMNRPannerSource alloc] init];
		[[self pannerLight] registerPannerSource: newId];
		ZKMNRSphericalCoordinate center;
		center.azimuth = 0.f; center.zenith = 0.f; center.radius = 1.f;
		ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
		[newId setInitialCenter: center span: span gain: 1.f];
		[newId setCenter: center span: span gain: 1.f];
		[[self mixerLight] setColor: blackColor forInput: i];

		[lightIds addObject: newId];
	}
	
	// activate the new Ids
	[[self pannerLight] beginEditingActiveSources];		
		[[self pannerLight] setActiveSources: lightIds];
	[[self pannerLight] endEditingActiveSources];
}

- (void)sendLightPositions
{
	// In this case, since we have an in-process mixerLight, we don't actually need to "send" 
	// the info -- we just inform the mixerLight
	ZKMRNSpeakerSetup* speakerSetup = [_zirkoniumSystem speakerSetup];
	NSArray* speakerPositions = [[speakerSetup speakerLayout] speakerPositions];
	int i;
	ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
	NSColor* defaultColor = [NSColor blackColor];
	for (i = 0; i < self.numberOfLights; ++i) {
		ZKMNRSphericalCoordinate coordPlatonic = [[speakerPositions objectAtIndex: i] coordPlatonic];
		ZKMNRPannerSource* source = [lightIds objectAtIndex: i];
		[source setCenter: coordPlatonic span: span gain: 1.f];
		[self setColor: defaultColor forId: i];
	}
}

- (void)sendRunningLightState
{
	ZKMORMixerMatrix* spatMixer = [_zirkoniumSystem spatializationMixer];
	
	float lightGain = [[[NSUserDefaults standardUserDefaults] valueForKey:@"lightGain"] floatValue]; 
	
	unsigned maxIndex = dbLightTableSize - 1;
	
	int i;
	for (i = 0; i < self.numberOfLights; ++i) {
		
		float scale = ZKMORDBToNormalizedDB([spatMixer postAveragePowerForOutput: i]);
		
		unsigned tableIndex = MIN((unsigned) (scale * dbLightTableSize), maxIndex);
	
		float r, g, b;

		r = _activeDbLightTable[3*tableIndex]; 
		g = _activeDbLightTable[3*tableIndex + 1]; 
		b = _activeDbLightTable[3*tableIndex + 2];

		r *= lightGain; 
		g *= lightGain; 
		b *= lightGain;
		
		r = MAX(0.0, MIN(1.0, r)); 
		g = MAX(0.0, MIN(1.0, g)); 
		b = MAX(0.0, MIN(1.0, b)); 
		
		NSColor* color = [NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.];
		[self setColor: color forId: i];
	}
}

- (void)setPreferencesToDefaultValues
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	NSString* lanBoxAddress = [userDefaults stringForKey: @"LanBoxAddress"];
	if (nil == lanBoxAddress) lanBoxAddress = [[self outputDMX]  defaultLanBoxAddress];
	NSError* error;
	if (![[self outputDMX] setAddress: lanBoxAddress error: &error]) {
		NSLog(@"Could not set LanBox address to %@ : %@", lanBoxAddress, error);
	}
}

@end
