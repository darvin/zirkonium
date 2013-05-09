//
//  ZKMRLMixerLight.h
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 08.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/// Name of Mixer Changed Size Notification
extern NSString* ZKMRLMixerLightChangedSizeNotification;

///  
///  ZKMRLMixerLight
///  
///  The Mixer Light takes colors as input, has float crosspoint coefficients which determine how much
///  of each color gets mixed in, and output coefficients to scale the brightness of the output color
///
///    Input
///  NSColor 1   crosspoint 11   crosspoint 12   ...   crosspoint 1M
///  NSColor 2   crosspoint 21   crosspoint 22   ...   crosspoint 2M
///  ...
///  NSColor N   crosspoint N1   crosspoint N2   ...   crosspoint NM
///
///  Output      output 1        output 2              output M
///
///  Colors are stored and manipulated in the NSCalibratedRGBColorSpace color space.
///
@interface ZKMRLMixerLight : NSObject {
	NSMutableArray*		_inputColors;
	NSMutableArray*		_outputColors;
	unsigned			_numberOfInputChannels;
	unsigned			_numberOfOutputChannels;
		/// _coefficientsSize = (_numberOfInputChannels + 1) + _numberOfOutputChannels (see above)
	unsigned			_coefficientsSize;
	float*				_coefficients;
	
		/// used to detect if DMX actually needs to be sent
	BOOL				_isSynchedWithOutput;
}

//  Accessors
- (unsigned)numberOfInputChannels;
- (void)setNumberOfInputChannels:(unsigned)numberOfInputChannels;

- (unsigned)numberOfOutputChannels;
- (void)setNumberOfOutputChannels:(unsigned)numberOfOutputChannels;

//  Matrix Accessors
- (NSColor *)colorForInput:(unsigned)inputNum;
- (void)setColor:(NSColor *)color forInput:(unsigned)inputNum;

- (float)valueForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum;
- (void)setValue:(float)value forCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum;

- (NSColor *)colorForOutput:(unsigned)outputNum;

//  Queries
- (BOOL)isSynchedWithOutput;
- (void)setSynchedWithOutput:(BOOL)isSynchedWithOutput;

//  Actions

- (void)updateOutputColors;		///< Call this to have the matrix compute the new output
- (void)setToDiagonalLevels;	///< sets in ch 1 to go to out ch 1, in ch 2 to out ch 2, etc. over the mixer
- (void)setOutputsOn;			///< sets all output coefficients to 1.f;

@end
