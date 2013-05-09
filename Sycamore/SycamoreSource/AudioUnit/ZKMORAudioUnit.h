//
//  ZKMORAudioUnit.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORAudioUnit_h__
#define __ZKMORAudioUnit_h__

#import "ZKMORConduit.h"

ZKMDECLCPPT(CAAudioUnitZKM)

///
///  ZKMORAudioUnit
///  
///  A way to inject data from/to an AudioUnit (/AU graph) into/from a ZKMOR graph.
/// 
@interface ZKMORAudioUnit : ZKMORConduit {
	ZKMCPPT(CAAudioUnitZKM)		mAudioUnit;
	
	BOOL			_disposeWhenDone;
}

//  Accessors
- (AudioUnit)audioUnit;

- (NSString *)audioUnitManufacturer;
- (NSString *)audioUnitName;
- (NSString *)componentName;
- (NSString *)componentInfo;

@end



///
///  ZKMORAudioUnit (ZKMORAudioUnitInternal)
/// 
///  Internal methods on an AudioUnit. You shouldn't *need* to call
///  these directly, but it might be useful.
///
@interface ZKMORAudioUnit (ZKMORAudioUnitInternal)

//  Initializing
	/// These are internal because you shouldn't need to create an AudioUnit this way.
	/// The typical way to do this is to either call alloc/init on a subclass, e.g., [[ZKMORMixerMatrix alloc] init]
	/// or to copy a prototype from the ZKMORAudioUnitSystem.
- (id)initWithAudioUnit:(AudioUnit)audioUnit;
	/// set to NO if you don't want the audio unit cleaned-up when this class
	/// is dealloc'd
- (id)initWithAudioUnit:(AudioUnit)audioUnit disposeWhenDone:(BOOL)disposeWhenDone;

//  Parameter Access
- (unsigned)numberOfParametersInScope:(AudioUnitScope)scope bus:(unsigned)bus;
- (void)getParameterIDs:(AudioUnitParameterID *)ids scope:(AudioUnitScope)scope	bus:(unsigned)bus dataSize:(unsigned *)size;

- (float)valueOfParameter:(AudioUnitParameterID)parameter scope:(AudioUnitScope)scope element:(AudioUnitElement)element;
- (void)setValueOfParameter:(AudioUnitParameterID)parameter scope:(AudioUnitScope)scope element:(AudioUnitElement)element value:(float)value;

//  Channel Layouts					
- (BOOL)hasChannelLayoutsInScope:(AudioUnitScope)scope bus:(AudioUnitElement)bus;

@end

///
///  ZKMORAudioUnitInputBus
///
///  The bus that accepts audio data.
///
@interface ZKMORAudioUnitInputBus : ZKMORInputBus {

}

- (float)valueOfParameter:(AudioUnitParameterID)parameter;
- (void)setValueOfParameter:(AudioUnitParameterID)parameter value:(float)value;

@end



///
///  ZKMORAudioUnitOutputBus
///
///  The bus that produces audio data.
///
@interface ZKMORAudioUnitOutputBus : ZKMOROutputBus {

}

- (float)valueOfParameter:(AudioUnitParameterID)parameter;
- (void)setValueOfParameter:(AudioUnitParameterID)parameter value:(float)value;

@end



ZKMOR_C_BEGIN

///
///  ZKMORAudioUnitStruct
/// 
///  The struct form of the conduit, for digging into the state of the object (used to
///  improve performance).
///
typedef struct { @defs(ZKMORAudioUnit) } ZKMORAudioUnitStruct;

ZKMOR_C_END

#ifdef __cplusplus
@interface ZKMORAudioUnit (ZKMORAudioUnitCPP)

- (CAAudioUnitZKM *)caAudioUnit;			

@end
#endif


#endif __ZKMORAudioUnit_h__
