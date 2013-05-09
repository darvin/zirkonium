//
//  ZKMORAudioFile.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 13.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORAudioFile_h__
#define __ZKMORAudioFile_h__

#import "ZKMORConduit.h"
#import <AudioToolbox/AudioToolbox.h>

ZKMDECLCPPT(CAAudioFile)
ZKMDECLCPPT(ZKMORFileReader)
ZKMDECLCPPT(ZKMORFileWriter)

///
///  ZKMORAbstractAudioFile
///
///  Things common to all audio file-based conduits.
///
@interface ZKMORAbstractAudioFile : ZKMORConduit {
	NSURL*					_fileURL;
	FSRef					_fileFSRef;
	BOOL					_isFileFSRefValid;
	UInt32					_srcQuality;
}


//  Accessors
- (NSURL *)fileURL;
- (void)setFileURL:(NSURL *)fileURL error:(NSError **)error;
- (void)setFilePath:(NSString *)path error:(NSError **)error;

// Queries
- (BOOL)isFileFSRefValid;

//  File Information
- (AudioStreamBasicDescription)fileDataFormat;
- (unsigned)numberOfChannels;
- (UInt32)fileFormatMagic;
- (SInt64)numberOfFrames;
	/// in seconds
- (Float64)duration;

	/// The format I deliver samples in (defaults to the file data format, but non-interleaved).
	/// You can get this information from the audio file's output bus as well.
- (AudioStreamBasicDescription)streamFormat;

	/// See the enum kAudioConverterQuality
- (UInt32)srcQuality;
	/// srcQualtiy should be one of the kAudioConverterQuality enum values
- (void)setSRCQuality:(UInt32)srcQuality;


//  Running Information
- (Float64)currentPosition;					///< 0 -> 1
- (void)setCurrentPosition:(Float64)pos;	///< 0 -> 1

- (Float64)currentSeconds;					///< current position in seconds
- (void)setCurrentSeconds:(Float64)secs;	///< set current position in seconds

- (SInt64)currentFrame;

@end

///
///  ZKMORAudioFile
///
///  A wrapper on CAAudioFile. This can be used for <i>reading</i> files synchronously, for example, for
///  out of realtime processing. These should not be used for playing out an audio interface. In
///  that case, use ZKMORAudioFilePlayer. For writing synchronously, use a ZKMORFileOutput, and for
///  writing in realtime ZKMORAudioFileRecorder.
///
@interface ZKMORAudioFile : ZKMORAbstractAudioFile {
	ZKMCPPT(CAAudioFile)	mAudioFile;
	SInt64					_currentFrame;
}

@end



///
///  ZKMORAudioFilePlayer
///
///  Reads audio files in a worker thread and makes the data available to the render thread. Use this
///  for playing back files in realtime.
///
@interface ZKMORAudioFilePlayer : ZKMORAbstractAudioFile {
	ZKMCPPT(ZKMORFileReader)	mAudioFileReader;
}

//  Initialization
	/// defaults to 3 buffers of 4096 frames
- (id)initWithNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers size:(unsigned)numberOfFrames;

//  File Reader Properties
	/// number of internal buffers used for buffering data from the disk
- (unsigned)numberOfInternalBuffers;
	/// change the number of internal buffers used. Destroys any data in the existing sample buffer
- (void)setNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers;
	/// size in frames of each of the internal buffers used for buffering data from the disk
- (unsigned)internalBufferSize;
	/// change the size in frames of each of the internal buffers. Destroys any data in the existing sample buffer.
- (void)setInternalBufferSize:(unsigned)numberOfFrames;

//  Running Information
	///< Returns true if the reader thread is running faster than samples can be delivered
- (BOOL)hasDetectedUnderflow;
- (void)resetUnderflowDetector;

@end

///
///  ZKMORAudioFileRecorder
///
///  Writes audio files in a worker thread. Use this for recording to file in realtime.
///
@interface ZKMORAudioFileRecorder : ZKMORAbstractAudioFile {
	ZKMCPPT(ZKMORFileWriter)	mAudioFileWriter;
}

//  Initialization
	/// defaults to 3 buffers of 4096 frames
- (id)initWithNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers size:(unsigned)numberOfFrames;

//  Format Helpers -- for a more complete list, use CAAudioFileFormats
	/// Fills the ASBD to match the 16 Bit Int AIFF format
+ (void)getAIFFInt16Format:(AudioStreamBasicDescription *)dataFormat channels:(unsigned)channels;
	/// Fills the ASBD to match the 24 Bit Int AIFC format
+ (void)getAIFCInt24Format:(AudioStreamBasicDescription *)dataFormat channels:(unsigned)channels;
	/// Fills the ASBD to match the 16 Bit Int AIFC format
+ (void)getAIFCFloat32Format:(AudioStreamBasicDescription *)dataFormat channels:(unsigned)channels;
	/// Fills the ASBD to match the 16 Bit Int WAVE format
+ (void)getWAVEInt16Format:(AudioStreamBasicDescription *)dataFormat channels:(unsigned)channels;

//  File Writer Properties
	/// number of internal buffers used for buffering data from the disk
- (unsigned)numberOfInternalBuffers;
	/// change the number of internal buffers used. Destroys any data in the existing sample buffer
- (void)setNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers;
	/// size in frames of each of the internal buffers used for buffering data from the disk
- (unsigned)internalBufferSize;
	/// change the size in frames of each of the internal buffers. Destroys any data in the existing sample buffer.
- (void)setInternalBufferSize:(unsigned)numberOfFrames;

//  Accessors
- (void)setFileURL:(NSURL *)fileURL fileType:(AudioFileTypeID)fileType dataFormat:(AudioStreamBasicDescription)dataFormat error:(NSError **)error;
- (void)setFilePath:(NSString *)path fileType:(AudioFileTypeID)fileType dataFormat:(AudioStreamBasicDescription)dataFormat error:(NSError **)error;

//  Actions
	/// Must be called to ensure the file is written out properly
- (void)flushAndClose;

@end

ZKMOR_C_BEGIN

///
///  ZKMORAudioFileStruct
/// 
///  The struct form of the conduit, for digging into the state of the object (used to
///  improve performance).
///
typedef struct { @defs(ZKMORAudioFile) } ZKMORAudioFileStruct;
typedef struct { @defs(ZKMORAudioFilePlayer) } ZKMORAudioFilePlayerStruct;
typedef struct { @defs(ZKMORAudioFileRecorder) } ZKMORAudioFileRecorderStruct;

ZKMOR_C_END

#ifdef __cplusplus
@interface ZKMORAbstractAudioFile (ZKMORAbstractAudioFileCPP)

- (CAAudioFile *)caAudioFile;

@end
#endif

#endif __ZKMORAudioFile_h__
