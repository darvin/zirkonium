//
//  ZKMORAudioUnitSystem.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 18.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifndef __ZKMORAudioUnitSystem_H__
#define __ZKMORAudioUnitSystem_H__
///
///  ZKMORAudioUnitSystem
///
///  Abstraction for all audio units available to the user.
///
///  If you find an AudioUnit you like, you can get your own by sending copy to it.
///
@class ZKMORAudioUnit;
@interface ZKMORAudioUnitSystem : NSObject {
	NSMutableArray*		_outputAudioUnits;
	NSMutableArray*		_musicDeviceAudioUnits;
	NSMutableArray*		_musicEffectAudioUnits;	
	NSMutableArray*		_formatConverterAudioUnits;
	NSMutableArray*		_effectAudioUnits;
	NSMutableArray*		_mixerAudioUnits;
	NSMutableArray*		_pannerAudioUnits;
	NSMutableArray*		_offlineEffectAudioUnits;
	NSMutableArray*		_generatorAudioUnits;
}

//  Singleton
+ (ZKMORAudioUnitSystem *)sharedAudioUnitSystem;

//  Actions
- (void)rescanForAudioUnits;	///<  Looks for new audio units -- previously existing ones remain in the list

//  Accessing -- these return arrays of ZKMORAudioUnit objects.
- (NSArray *)outputAudioUnits;
- (NSArray *)musicDeviceAudioUnits;
- (NSArray *)musicEffectAudioUnits;
- (NSArray *)formatConverterAudioUnits;
- (NSArray *)effectAudioUnits;
- (NSArray *)mixerAudioUnits;
- (NSArray *)pannerAudioUnits;
- (NSArray *)offlineEffectAudioUnits;
- (NSArray *)generatorAudioUnits;

	/// this only returns for exact matches -- for inexact matches, use the normal
	/// Component Manager functions
- (ZKMORAudioUnit *)audioUnitWithComponentDescription:(ComponentDescription)desc;

@end
#endif