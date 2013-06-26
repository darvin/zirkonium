//
//  ZKMORUtilities.mm
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 23.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORUtilities.h"
#include "CAStreamBasicDescription.h"
#include "ZKMORLoggerCPP.h"
#include "CAXException.h"

void ZKMORGenerateIndentString(char* indentString, unsigned size, unsigned numIndent)
{
	unsigned i, count = MIN(size - 1, numIndent);
	for (i = 0; i < count; i++) {
		indentString[i] = '\t';
	}
	indentString[i] = '\0';
}

void		ZKMORPrintABSD(AudioStreamBasicDescription absd, char* destStr, unsigned size, BOOL withFlags)
{
	CAStreamBasicDescription casbd(absd);
	int numWritten = 0;	
	char formatID[5];
	*(UInt32 *)formatID = EndianU32_NtoB(absd.mFormatID);
	formatID[4] = '\0';
	if (withFlags)
		numWritten += 
			snprintf(&destStr[numWritten], (size - numWritten), 
				"%2ld ch, %6.0f Hz, '%-4.4s' (0x%08lX) ",		
				casbd.NumberChannels(), casbd.mSampleRate, formatID,
				casbd.mFormatFlags);
	else
		numWritten += 
			snprintf(&destStr[numWritten], (size - numWritten), 
				"%2ld ch, %6.0f Hz, '%-4.4s' ", casbd.NumberChannels(), casbd.mSampleRate, formatID);
	if (casbd.mFormatID == kAudioFormatLinearPCM) {
		bool isInt = !(casbd.mFormatFlags & kLinearPCMFormatFlagIsFloat);
		int wordSize = casbd.SampleWordSize();
		const char *endian = (wordSize > 1) ? 
			((casbd.mFormatFlags & kLinearPCMFormatFlagIsBigEndian) ? " big-endian" : " little-endian" ) : "";
		const char *sign = isInt ? 
			((casbd.mFormatFlags & kLinearPCMFormatFlagIsSignedInteger) ? " signed" : " unsigned") : "";
		const char *floatInt = isInt ? "integer" : "float";
		char packed[32];
		if (casbd.PackednessIsSignificant()) {
			if (casbd.mFormatFlags & kLinearPCMFormatFlagIsPacked)
				sprintf(packed, "packed in %d bytes", wordSize);
			else
				sprintf(packed, "unpacked in %d bytes", wordSize);
		} else
			packed[0] = '\0';
		const char *align = casbd.AlignmentIsSignificant() ?
			((casbd.mFormatFlags & kLinearPCMFormatFlagIsAlignedHigh) ? " high-aligned" : " low-aligned") : "";
		const char *deinter = (casbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? ", deinterleaved" : "";
		const char *commaSpace = (packed[0]!='\0') || (align[0]!='\0') ? ", " : "";
		
		numWritten += 
			snprintf(&destStr[numWritten], (size - numWritten), 
				"%ld-bit%s%s %s%s%s%s%s",
				casbd.mBitsPerChannel, endian, sign, floatInt, 
				commaSpace, packed, align, deinter);
	} else
		numWritten += 
			snprintf(&destStr[numWritten], (size - numWritten), 
				"%ld bits/channel, %ld bytes/packet, %ld frames/packet, %ld bytes/frame", 
				casbd.mBitsPerChannel, casbd.mBytesPerPacket, casbd.mFramesPerPacket, casbd.mBytesPerFrame);
	return;
}

float ZKMORBufferListChannelRMS(AudioBufferList* buffers, unsigned channel)
{
	// this assumes non-interleaved buffers
	unsigned numberBuffers = buffers->mNumberBuffers;
	if (channel > numberBuffers) {
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("ZKMORBufferListChannelRMS with invalid channel %u (of %u)"), channel, numberBuffers);
		return 0.f;
	}
	
	float* channelSamps = ((float*)buffers->mBuffers[channel].mData);
	unsigned numSamples = (buffers->mBuffers[channel].mDataByteSize) / sizeof(Float32);
	float rms = 0.f;
	for (unsigned i = 0; i < numSamples; i++) {
		float samp = channelSamps[i];
		rms += samp * samp;
	}
	rms /= numSamples;
	rms = sqrtf(rms);
	return rms;
}

void ZKMORLogBufferList(unsigned level, unsigned indent, AudioBufferList* buffers)
{
	// this assumes non-interleaved buffers
	unsigned numberBuffers = buffers->mNumberBuffers;
	unsigned numSamplesToPrint = 5;
	unsigned source = kZKMORLogSource_Conduit;
	
	ZKMORLogger* logger = GlobalLogger();
	ZKMORWriteLogToken* token = logger->GetWriteLogToken(level);
	if (!token) return;
	
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	
	token->Log(	level, source, CFSTR("%sBuffer List { %u bufs : %u ch each}"), 
				indentStr, buffers->mNumberBuffers, buffers->mBuffers[0].mNumberChannels);
	
	for (unsigned j = 0; j < numberBuffers; j++) {

		float rms = ZKMORBufferListChannelRMS(buffers, j);
		token->ContinueLog(CFSTR("\n%sCH %u (%.2f) %u samps"), indentStr, j, rms, buffers->mBuffers[j].mDataByteSize / sizeof(Float32));
		if (rms < 0.000001f) continue;
		
		float* channelj = ((float*)buffers->mBuffers[j].mData);
		unsigned skip = (buffers->mBuffers[j].mDataByteSize) / (sizeof(Float32) * (numSamplesToPrint - 1));
		unsigned currentSample = 0;
		for (unsigned i = 0; i < numSamplesToPrint; i++) {
			token->ContinueLog(CFSTR("[%u, %5.2f] "), currentSample, channelj[currentSample]);	
			currentSample = (i+1)*skip - 1;
		}
	}
	logger->ReturnWriteLogToken(token);		
}

void ZKMORLogTimeStamp(unsigned level, unsigned indent, const AudioTimeStamp* timeStamp)
{
	unsigned source = kZKMORLogSource_Conduit;
	ZKMORLogger* logger = GlobalLogger();
	ZKMORWriteLogToken* token = logger->GetWriteLogToken(level);
	if (!token) return;
	
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	
	token->Log(level, source, CFSTR("%sTime Stamp\n"), indentStr);
	UInt32 flags = timeStamp->mFlags;
	if (flags & kAudioTimeStampSampleTimeValid)
		token->ContinueLog(CFSTR("%s\tSample Time: %f\n"), indentStr, timeStamp->mSampleTime);
	if (flags & kAudioTimeStampHostTimeValid)
		token->ContinueLog(CFSTR("%s\tHost Time:   %llu\n"), indentStr, timeStamp->mHostTime);
	if (flags & kAudioTimeStampRateScalarValid)
		token->ContinueLog(CFSTR("%s\tRate Scalar: %f\n"), indentStr, timeStamp->mRateScalar);
	if (flags & kAudioTimeStampWordClockTimeValid)
		token->ContinueLog(CFSTR("%s\tWord Clock:  %llu\n"), indentStr, timeStamp->mWordClockTime);
	if (flags & kAudioTimeStampSMPTETimeValid)
		token->ContinueLog(CFSTR("%s\tSMPTE Time:  %llu\n"), indentStr, timeStamp->mSMPTETime);
	logger->ReturnWriteLogToken(token);		
}

#pragma mark _____ Printing of 4 char strings
void	ZKMORFormatError(OSStatus error, char* outString)
{
	CAXException::FormatError(outString, error);
}

float	ZKMORFRand() 
{
	static float maxRandom = powf(2., 31.) - 1.f;
	return ((float) random()) / maxRandom;
//	return ((float) random()) / ((float) LONG_MAX);
}

float	ZKMORWrap0ToMax(float value, float max)
{
	while (value < 0.f) value += max;
	while (value > max) value -= max;
	return value;
}

float	ZKMORFold0ToMax(float value, float max)
{
	if (value < 0.f) value = fabsf(value);
	float pivot = 2.f * max;
	value = ZKMORWrap0ToMax(value, pivot);
	value = (value > max) ? pivot - value : value;
	return value;
}

float	ZKMORFold(float value, float min, float max)
{
	float valueMinusMin = value - min;
	float folded = ZKMORFold0ToMax(valueMinusMin, max - min);
	return folded + min;
}

	/// clamp a value to the range [min, max]
float	ZKMORClamp(float value, float min, float max)
{
	if (value < min) value = min;
	if (value > max) value = max;
	return value;
}

float	ZKMORInterpolateValue(float startValue, float endValue, float percent)
{
	return (1.f - percent) * startValue + (percent * endValue);
}
