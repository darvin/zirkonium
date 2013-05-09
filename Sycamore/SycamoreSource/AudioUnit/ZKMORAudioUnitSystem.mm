//
//  ZKMORAudioUnitSystem.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 18.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioUnitSystem.h"
#import "ZKMORAudioUnit.h"
#import "CAAudioUnitZKM.h"
#import "ZKMORLogger.h"


@interface ZKMORAudioUnitSystem (ZKMORAudioUnitSystemPrivate)

- (BOOL)isComponent:(Component)comp inArray:(NSArray *)array;
- (int)indexOfComponentDescription:(ComponentDescription)desc inArray:(NSArray *)array;
- (void)addAudioUnitsOfType:(OSType)type toArray:(NSMutableArray *)array;

@end

static ZKMORAudioUnitSystem* sharedAudioUnitSystem = NULL;

@implementation ZKMORAudioUnitSystem

- (void)dealloc
{
	[_outputAudioUnits release];
	[_musicDeviceAudioUnits release];
	[_musicEffectAudioUnits release];
	[_formatConverterAudioUnits release];
	[_effectAudioUnits release];
	[_mixerAudioUnits release];
	[_pannerAudioUnits release];
	[_offlineEffectAudioUnits release];
	[_generatorAudioUnits release];
	
	[super dealloc];
}

- (id)init {
	if (sharedAudioUnitSystem) {
		[self release];
		return sharedAudioUnitSystem;
	}
	
	if (self = [super init]) {
		sharedAudioUnitSystem = self;
		
		_outputAudioUnits = [[NSMutableArray alloc] init];
		_musicDeviceAudioUnits = [[NSMutableArray alloc] init];
		_musicEffectAudioUnits = [[NSMutableArray alloc] init];
		_formatConverterAudioUnits = [[NSMutableArray alloc] init];
		_effectAudioUnits = [[NSMutableArray alloc] init];
		_mixerAudioUnits = [[NSMutableArray alloc] init];
		_pannerAudioUnits = [[NSMutableArray alloc] init];
		_offlineEffectAudioUnits = [[NSMutableArray alloc] init];
		_generatorAudioUnits = [[NSMutableArray alloc] init];
	
		[self rescanForAudioUnits];
	}
	
	return self;
}

#pragma mark _____ Singleton
+ (ZKMORAudioUnitSystem *)sharedAudioUnitSystem
{
	if (!sharedAudioUnitSystem) {
			// this will assign the instance to sharedAudioUnitSystem
		[[ZKMORAudioUnitSystem alloc] init];
	}
		
	return sharedAudioUnitSystem;
}

#pragma mark _____ Actions
- (void)rescanForAudioUnits
{
	[self addAudioUnitsOfType: kAudioUnitType_Output toArray: _outputAudioUnits];
	[self addAudioUnitsOfType: kAudioUnitType_MusicDevice toArray: _musicDeviceAudioUnits];
	[self addAudioUnitsOfType: kAudioUnitType_MusicEffect toArray: _musicEffectAudioUnits];
	[self addAudioUnitsOfType: kAudioUnitType_FormatConverter toArray: _formatConverterAudioUnits];
	[self addAudioUnitsOfType: kAudioUnitType_Effect toArray: _effectAudioUnits];
	[self addAudioUnitsOfType: kAudioUnitType_Mixer toArray: _mixerAudioUnits];
	[self addAudioUnitsOfType: kAudioUnitType_Panner toArray: _pannerAudioUnits];
	[self addAudioUnitsOfType: kAudioUnitType_OfflineEffect toArray: _offlineEffectAudioUnits];
	[self addAudioUnitsOfType: kAudioUnitType_Generator toArray: _generatorAudioUnits];			
}

#pragma mark _____ Accessing
- (NSArray *)outputAudioUnits { return _outputAudioUnits; }
- (NSArray *)musicDeviceAudioUnits { return _musicDeviceAudioUnits; }
- (NSArray *)musicEffectAudioUnits { return _musicEffectAudioUnits; }
- (NSArray *)formatConverterAudioUnits { return _formatConverterAudioUnits; }
- (NSArray *)effectAudioUnits { return _effectAudioUnits; }
- (NSArray *)mixerAudioUnits { return _mixerAudioUnits; }
- (NSArray *)pannerAudioUnits { return _pannerAudioUnits; }
- (NSArray *)offlineEffectAudioUnits { return _offlineEffectAudioUnits; }
- (NSArray *)generatorAudioUnits { return _generatorAudioUnits; }

- (ZKMORAudioUnit *)audioUnitWithComponentDescription:(ComponentDescription)desc
{
	NSArray* theArray = nil;
	switch (desc.componentType) {
		case kAudioUnitType_Output:
			theArray = _outputAudioUnits;
			break;
		case kAudioUnitType_MusicDevice:
			theArray = _musicDeviceAudioUnits;
			break;
		case kAudioUnitType_MusicEffect:
			theArray = _musicEffectAudioUnits;
			break;
		case kAudioUnitType_FormatConverter:
			theArray = _formatConverterAudioUnits;
			break;
		case kAudioUnitType_Effect:
			theArray = _effectAudioUnits;
			break;
		case kAudioUnitType_Mixer:
			theArray = _mixerAudioUnits;
			break;
		case kAudioUnitType_Panner:
			theArray = _pannerAudioUnits;
			break;
		case kAudioUnitType_OfflineEffect:
			theArray = _offlineEffectAudioUnits;
			break;
		case kAudioUnitType_Generator:
			theArray = _generatorAudioUnits;
			break;
		default:
			theArray = nil;
	}
	
	if (nil == theArray) return nil;
	
	int index = [self indexOfComponentDescription: desc inArray: theArray];

	if (index < 0) return nil;
	return [theArray objectAtIndex: index];
}

#pragma mark _____ ZKMORAudioUnitSystemPrivate
- (BOOL)isComponent:(Component)comp inArray:(NSArray *)array
{
	CAComponentDescription desc = CAComponent(comp).Desc();
	return 
		([self indexOfComponentDescription: (ComponentDescription)desc inArray: array] < 0) ?
			NO :
			YES;
}

	// returns -1 if the component is not in the array
- (int)indexOfComponentDescription:(ComponentDescription)desc inArray:(NSArray *)array
{
	unsigned i, count = [array count];
	for (i = 0; i < count; i++) {
		ZKMORAudioUnit* audioUnit = [array objectAtIndex: i];
		CAAudioUnitZKM* caAudioUnit = [audioUnit caAudioUnit];
		if (caAudioUnit->Comp().Desc().Matches(desc))
			return i;
	}
	
	return -1;
}

- (void)addAudioUnitsOfType:(OSType)type toArray:(NSMutableArray *)array
{
	Component comp = NULL;
	ComponentDescription desc;
	AudioUnit basicAU;
	OSStatus err = noErr;
	
	desc.componentType = type;
	desc.componentSubType = 0;
	desc.componentManufacturer = 0;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	while (comp = FindNextComponent(comp, &desc)) {
		if ([self isComponent: comp inArray: array])
			continue;
				
		if (err = OpenAComponent(comp, &basicAU)) {
			ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_AudioUnit, 
				CFSTR("System could not create Audio Unit {%4.4s, %4.4s, %4.4s} : %i"), 
				&desc.componentType, &desc.componentSubType, &desc.componentManufacturer, err);
			continue;
		}
		
		CAComponentDescription desc = CAComponent(comp).Desc();
		
		ZKMORAudioUnit* audioUnit = [[ZKMORAudioUnit alloc] initWithAudioUnit: basicAU disposeWhenDone: YES];
		[array addObject: audioUnit];
		[audioUnit release];
		desc.componentSubType = 0;
		desc.componentManufacturer = 0;
		desc.componentFlags = 0;
		desc.componentFlagsMask = 0;
	}

}


@end
