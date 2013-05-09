//
//  ZKMORMixerMatrix.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 25.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioUnit.h"

///
///  ZKMORMixerMatrix
///  
///  The matrix mixer.
///
///  Features some shortcut methods for working with the matrix. Most of these are pretty straighforward, but
///  the difference between setToCanonicalLevels and setToDiagonalLevels is worth explaining.
///  <pre>
///  On a matrix with 2 input buses, each with 2 channels, and one 4 channel output you get:
///     setToCanonicalLevels                                setToDiagonalLevels
///    out 0  1  2  3                                      out 0  1  2  3
///  in 0  X                                             in 0  X
///     1     X                                             1     X
///     2  X                                                2        X
///     3     X                                             3           X
///  </pre>
///
@interface ZKMORMixerMatrix : ZKMORAudioUnit {

}

//  Metering Properties
- (BOOL)isMeteringOn;
- (void)setMeteringOn:(BOOL)isMeteringOn;

//  Matrix Properties
- (void)getMatrixDimensionsInput:(unsigned *)inputDim output:(unsigned *)outputDim;
	/// the size of the levels matrix (matrix dims + 1 in each dimension)
- (void)getMixerLevelsDimensionsInput:(unsigned *)inputDim output:(unsigned *)outputDim;

//  Parameters
	/// retreive the matrix as a big array; levelsSize should be (matrix input dim + 1) * (matrix output dim + 1)
- (unsigned)getMixerLevels:(Float32 *)levels size:(unsigned)levelsSize;
	/// edit the matrix as a big array; levelsSize should be (matrix input dim + 1) * (matrix output dim + 1)
- (void)setMixerLevels:(Float32 *)levels size:(unsigned)levelsSize;

	// accessors for particular elements in the matrix
- (float)masterVolume;
- (void)setMasterVolume:(float)volume;

	// the input and output numbers here are individual mono channel numbers, not buses
- (float)volumeForInput:(unsigned)inputNum;
- (void)setVolume:(float)volume forInput:(unsigned)inputNum;
- (float)volumeForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum;
- (void)setVolume:(float)volume forCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum;
- (float)volumeForOutput:(unsigned)outputNum;
- (void)setVolume:(float)volume forOutput:(unsigned)outputNum;

//  Metering
	// these methods return values in DB
- (float)preAveragePowerForInput:(unsigned)inputNum;
- (float)prePeakHoldLevelPowerForInput:(unsigned)inputNum;
- (float)postAveragePowerForInput:(unsigned)inputNum;
- (float)postAveragePowerForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum;
- (float)postAveragePowerForOutput:(unsigned)outputNum;
- (float)postPeakHoldLevelPowerForInput:(unsigned)inputNum;
- (float)postPeakHoldLevelPowerForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum;
- (float)postPeakHoldLevelPowerForOutput:(unsigned)outputNum;

//  Shortcuts
- (void)setToCanonicalLevels;	///< sets in ch 1 to go to out ch 1, in ch 2 to out ch 2, etc. for each bus
- (void)setToDiagonalLevels;	///< sets in ch 1 to go to out ch 1, in ch 2 to out ch 2, etc. over the mixer
- (void)setInputsAndOutputsOn;	///< enables all buses and sets all inputs and outputs to 1, but does not alter crosspoints.
- (void)setCrosspointsToZero;	///< sets crosspoints to 0
- (void)setCrosspointsToZeroForInput:(unsigned)input;	///< sets crosspoints to 0 just for the specified input

//  Printing
- (void)logVolumesAtLevel:(unsigned)level;
- (void)logVolumesDebug;

@end


///
///  ZKMORMixerMatrix (ZKMORMixerMatrixInternal)
///  
///  Convenience functions used internally
///
@interface ZKMORMixerMatrix (ZKMORMixerMatrixInternal)

- (float)
	crosspointParameterValue:(AudioUnitElement)parameter
	inputBus:(unsigned)inputBus
	outputBus:(unsigned)outputBus;
					
- (void)
	setCrosspointParameter:(AudioUnitElement)parameter
	value:(float)value
	inputBus:(unsigned)inputBus
	outputBus:(unsigned)outputBus;
	
@end



///
///  ZKMORMixerMatrixInputBus
///  
///  Methods manipulating parameters on the input bus scope.
///
@interface ZKMORMixerMatrixInputBus : ZKMORAudioUnitInputBus {

}

//  Accessing
	/// what index in the matrix channel 0 on this bus maps to
- (unsigned)mixerBusZeroOffset;

//  Parameters
- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)isEnabled;

//  Metering
- (float)preAveragePower;
- (float)postAveragePower;
- (float)prePeakHoldLevelPower;
- (float)postPeakHoldLevelPower;

//  Shortcus
- (void)setToCanonicalLevels;	// sets in ch 1 to go to out ch 1, in ch 2 to out ch 2, etc.

@end



///
///  ZKMORMixerMatrixOutputBus
///  
///  Methods manipulating parameters on the output bus scope.
///
@interface ZKMORMixerMatrixOutputBus : ZKMORAudioUnitOutputBus {

}

//  Accessing
	/// what index in the matrix channel 0 on this bus maps to
- (unsigned)mixerBusZeroOffset;

//  Parameters
- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)isEnabled;

//  Metering
- (float)postAveragePower;
- (float)postPeakHoldLevelPower;

@end

ZKMOR_C_BEGIN

//  Utility Functions
	/// Return the Element used to address the crosspoint inputBus, outputBus
unsigned	ElementForMatrixCrosspoint(unsigned inputBus, unsigned outputBus);


	/// For the DB return a value between 0 and 1
float		ZKMORDBToNormalizedDB(float db);
float		ZKMORLinearToDB(float linear);
float		ZKMORDBToLinear(float db);

BOOL		ZKMORIsClipping(float db);

ZKMOR_C_END



