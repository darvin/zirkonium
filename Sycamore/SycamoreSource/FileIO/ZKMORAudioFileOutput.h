//
//  ZKMORAudioFileOutput.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 02.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//


#ifndef __ZKMORAudioFileOutput_h__
#define __ZKMORAudioFileOutput_h__

#import "ZKMORConduit.h"
#import "ZKMOROutput.h"
#import <AudioToolbox/AudioToolbox.h>

ZKMDECLCPPT(CAAudioFile)
ZKMDECLCPPT(AUOutputBL)
ZKMDECLCPPT(CAAudioTimeStamp)


///
///  ZKMORFileOutput
///
///  Calls a graph for data and sends the output to a file.
///
@interface ZKMORAudioFileOutput : ZKMOROutput {
	NSURL*					_fileURL;
	char*					_filePathUTF8;	
	ZKMCPPT(CAAudioFile)	mAudioFile;
	
	//  Render State
	ZKMCPPT(AUOutputBL)			mBufferList;
	ZKMCPPT(CAAudioTimeStamp)	mTimeStamp;
	OSStatus					_lastError;
}

//  Accessors
- (NSURL *)fileURL;
	/// Use the convenience functions on ZKMORAudioFileRecorder to create a data format
- (void)setFileURL:(NSURL *)fileURL fileType:(AudioFileTypeID)fileType dataFormat:(AudioStreamBasicDescription)dataFormat error:(NSError **)error;
	/// Use the convenience functions on ZKMORAudioFileRecorder to create a data format
- (void)setFilePath:(NSString *)path fileType:(AudioFileTypeID)fileType dataFormat:(AudioStreamBasicDescription)dataFormat error:(NSError **)error;

	/// This is the same as the graph's maxFramesPerSlice
- (unsigned)maxFramesPerSlice;	
	/// A convenience method -- sets the graph's maxFramesPerSlice
- (void)setMaxFramesPerSlice:(unsigned)maxFramesPerSlice;

	/// The more robust way to watch for errors is to make yourself a delegate of the graph or add a
	/// render notification to the graph, but, as a convenience, I store more recent error.
- (OSStatus)lastError;

//  File Information
- (AudioStreamBasicDescription)fileDataFormat;
- (unsigned)numberOfChannels;
- (UInt32)fileFormatMagic;
- (SInt64)numberOfFrames;
	/// in seconds
- (Float64)duration;

//  Actions
	/// Call start before running the iterations. A call to stop will flush and close the file.
- (void)runIteration:(unsigned)numberOfFrames;

@end

#ifdef __cplusplus
@interface ZKMORAudioFileOutput (ZKMORAudioFileOutputCPP)

- (CAAudioFile *)caAudioFile;

@end
#endif

#endif
