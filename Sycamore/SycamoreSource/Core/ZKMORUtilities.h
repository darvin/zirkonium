//
//  ZKMORUtilities.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 23.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  Useful utility functions
//  

#ifndef __ZKMORUtilities_h__
#define __ZKMORUtilities_h__


#import <AudioUnit/AudioUnit.h>
#import "ZKMORCore.h"

ZKMOR_C_BEGIN

//  Formatting of Debugging Strings
void	ZKMORGenerateIndentString(char* indentString, unsigned size, unsigned numIndent);
void	ZKMORPrintABSD(AudioStreamBasicDescription absd, char* destStr, unsigned length, BOOL withFlags);

//	Printing of Buffers
float	ZKMORBufferListChannelRMS(AudioBufferList* buffers, unsigned channel);
void	ZKMORLogBufferList(unsigned level, unsigned indent, AudioBufferList* buffers);
void	ZKMORLogTimeStamp(unsigned level, unsigned indent, const AudioTimeStamp* timeStamp);

//  Printing of 4 char strings
///  outString should be at least 6 chars long
void	ZKMORFormatError(OSStatus error, char* outString);

//  Math Functions
//  (n.b. make sure this header file is included -- I managed to compile source that was calling
//  these functions w/o including the header file and the generated code was incorrect
	/// returns a random number in the range 0.f -> 1.f
float	ZKMORFRand();
	/// wrap a value to the range [0, max]
float	ZKMORWrap0ToMax(float value, float max);
	/// fold a value to the range [0, max]
float	ZKMORFold0ToMax(float value, float max);
	// fold a value to the range [-min, max]
float	ZKMORFold(float value, float min, float max);
	/// clamp a value to the range [min, max]
float	ZKMORClamp(float value, float min, float max);
	/// return the value between startValue and endValue at percent
float	ZKMORInterpolateValue(float startValue, float endValue, float percent);

ZKMOR_C_END

#endif __ZKMORUtilities_h__