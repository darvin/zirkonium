//
//  ZKMORAudioFile.mm
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 13.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioFile.h"
#import "ZKMORUtilities.h"
#include "ZKMORLogger.h"
#include "CAAudioFile.h"
#include "ZKMORFileStreamer.h"
#include "CAXException.h"

// #define DEBUG_READER

static OSStatus AudioFileRenderFunction(	id							SELF,
											AudioUnitRenderActionFlags 	* ioActionFlags,
											const AudioTimeStamp 		* inTimeStamp,
											UInt32						inOutputBusNumber,
											UInt32						inNumberFrames,
											AudioBufferList				* ioData)
{
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) return noErr;
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) return noErr;

	ZKMORAudioFileStruct* theFile = (ZKMORAudioFileStruct*) SELF;
	try {
		CAAudioFile* fileCPP = theFile->mAudioFile;
		if (!fileCPP) {
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("No file selected on %@"), SELF);
			ZKMORMakeBufferListSilent(ioData, ioActionFlags);
			return noErr;
		}

		SInt64 currentFrame = theFile->_currentFrame;
		SInt64 totalFrames = fileCPP->GetNumberFrames();
			// don't read past the end of the file -- this causes problems in 
			// non-PCM file formats.
		SInt32 numFramesToRead = inNumberFrames;
		if ((currentFrame + inNumberFrames) > totalFrames)
			numFramesToRead = totalFrames - currentFrame;

		// read the correct number of frames and update the current frame counter
		if (numFramesToRead > 0) { 
			UInt32 numFrames = (UInt32) numFramesToRead;
			fileCPP->Read(numFrames, ioData);
			currentFrame += numFramesToRead;
		}
		
		// clear any untouched parts of the buffer -- not necessary, Read already does this
//		SInt32 numFramesToZero = inNumberFrames - numFramesToRead;
//		if (numFramesToZero > 0)
//			ZKMORMakeBufferListSectionSilent(ioData, ioActionFlags, inNumberFrames - numFramesToZero);

		// remember the current frame counter
		theFile->_currentFrame = currentFrame;
	} catch (CAXException& e) {
		char errorStr[255];
		e.FormatError(errorStr);
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("%@::AudioFileRenderFunction error %s"), SELF, errorStr);
		return e.mError;
	}
	return noErr;
}

static OSStatus AudioFilePlayerRenderFunction(	id							SELF,
												AudioUnitRenderActionFlags 	* ioActionFlags,
												const AudioTimeStamp 		* inTimeStamp,
												UInt32						inOutputBusNumber,
												UInt32						inNumberFrames,
												AudioBufferList				* ioData)
{
#ifdef DEBUG_READER
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) return noErr;
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) return noErr;
	
	ZKMORAudioFilePlayerStruct* theFile = (ZKMORAudioFilePlayerStruct*) SELF;
	UInt32 numberOfFramesDesired = inNumberFrames;

	if (theFile->_debugLevel & kZKMORDebugLevel_PreRender) {
		char debugStr[255];
		theFile->mAudioFileReader->SNPrint(debugStr, 255);
		ZKMORLogDebug(CFSTR("File Player 0x%x pre-render %s"), theFile, debugStr);
	}
	theFile->mAudioFileReader->PullBuffer(numberOfFramesDesired, ioData);
	if (numberOfFramesDesired < inNumberFrames) {
		ZKMORMakeBufferListTailSilent(ioData, ioActionFlags, numberOfFramesDesired);
	}
	if (theFile->_debugLevel & kZKMORDebugLevel_PostRender) {
		char debugStr[255];
		theFile->mAudioFileReader->SNPrint(debugStr, 255);
		ZKMORLogDebug(CFSTR("File Player 0x%x post-render %s"), theFile, debugStr);
	}
	
	return noErr;
#else
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) return noErr;
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) return noErr;
	
	ZKMORAudioFilePlayerStruct* theFile = (ZKMORAudioFilePlayerStruct*) SELF;
	UInt32 numberOfFramesDesired = inNumberFrames;
	theFile->mAudioFileReader->PullBuffer(numberOfFramesDesired, ioData);
	if (numberOfFramesDesired < inNumberFrames) {
		ZKMORMakeBufferListTailSilent(ioData, ioActionFlags, numberOfFramesDesired);
	}
	return noErr;
#endif
}

static OSStatus AudioFileWriterRenderFunction(	id							SELF,
												AudioUnitRenderActionFlags 	* ioActionFlags,
												const AudioTimeStamp 		* inTimeStamp,
												UInt32						inOutputBusNumber,
												UInt32						inNumberFrames,
												AudioBufferList				* ioData)
{
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) return noErr;
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) return noErr;
	
	ZKMORAudioFileRecorderStruct* theFile = (ZKMORAudioFileRecorderStruct*) SELF;
	theFile->mAudioFileWriter->PushBuffer(inNumberFrames, ioData);

	return noErr;
}

@interface ZKMORAbstractAudioFile (ZKMORAbstractAudioFilePrivate)
- (void)synchronizeFileSRCQuality;
@end

@implementation ZKMORAbstractAudioFile

- (void)dealloc
{
	if (_fileURL) [_fileURL release];
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;

	_fileURL = nil;
	_srcQuality = kAudioConverterQuality_Max;
	
	return self;
}

#pragma mark _____ Accessors
- (NSURL *)fileURL { return _fileURL; }
- (void)setFileURL:(NSURL *)fileURL error:(NSError **)error
{
	if (_fileURL) {
		[_fileURL release]; _fileURL = nil;
	}
	
	if(fileURL) {
		_fileURL = [fileURL copy];
		if (!_fileURL) return;
		
		if (!(_isFileFSRefValid = CFURLGetFSRef((CFURLRef) _fileURL, &_fileFSRef))) {
			if (error) {
				NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: @"Audio File could not get file for path", NSLocalizedDescriptionKey, nil];
				*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: fnfErr userInfo: userInfo];
			} else
				ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not get file for path %@"), _fileURL);
		}
	}
}

- (void)setFilePath:(NSString *)path error:(NSError **)error
{
	NSURL* fileURL = [NSURL fileURLWithPath: path];
	[self setFileURL: fileURL error: error];
}

#pragma mark _____ Queries
- (BOOL)isFileFSRefValid { return _isFileFSRefValid; }

#pragma mark _____ File Information
- (AudioStreamBasicDescription)fileDataFormat { AudioStreamBasicDescription absd; return absd; }
- (unsigned)numberOfChannels { return 0; }
- (UInt32)fileFormatMagic { return 0; }
- (SInt64)numberOfFrames { return 0; }
- (Float64)duration { return 0.; }
- (AudioStreamBasicDescription)streamFormat { return [self fileDataFormat]; }
- (UInt32)srcQuality { return _srcQuality; }
- (void)setSRCQuality:(UInt32)srcQuality
{
	_srcQuality = srcQuality;
	[self synchronizeFileSRCQuality];
}

#pragma mark _____ Running Information
- (Float64)currentPosition
{
	SInt64 currentFrame = [self currentFrame];
	SInt64 numberOfFrames = [self numberOfFrames];
	if (currentFrame >= numberOfFrames) return 1.;
	
	Float64 pos = ((Float64) currentFrame) / ((Float64) numberOfFrames);
	return MIN(pos, 1.);
}

- (void)setCurrentPosition:(Float64)pos { }
- (SInt64)currentFrame { return 0; }
- (Float64)currentSeconds { return [self currentPosition] * [self duration]; }
- (void)setCurrentSeconds:(Float64)secs { [self setCurrentPosition: secs / [self duration]]; }

#pragma mark _____ ZKMORConduit Overrides

- (void)setStreamFormatForBus:(ZKMORConduitBus *)bus
{
	[self synchronizeFileSRCQuality];
	[super setStreamFormatForBus: bus];
}

#pragma mark _____ ZKMORConduitLogging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	
	unsigned myLevel = level | kZKMORLogLevel_Continue;
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	if (!_fileURL) {
		ZKMORLog(myLevel, source, CFSTR("%s\t*NO FILE ATTACHED*"), indentStr);
		return;
	}
	
	char dataFormatStr[256];
	ZKMORPrintABSD([self fileDataFormat], dataFormatStr, 256, false);
	
	ZKMORLog(myLevel, source, CFSTR("%s\tFile       : %@ %lli frames (%.2f secs) \n%s\tData Format: %s"),
		indentStr, _fileURL, [self numberOfFrames], [self duration],
		indentStr, dataFormatStr);
		
	ZKMORPrintABSD([[self outputBusAtIndex: 0] streamFormat], dataFormatStr, 256, false);
	ZKMORLog(myLevel, source, CFSTR("%s\tOut Format : %s"),
		indentStr, dataFormatStr);
		
	CAAudioFile* file = [self caAudioFile];
	if (!file) return;
	
	UInt32 dataSize, quality = 0;
	dataSize = sizeof(UInt32);
	AudioConverterGetProperty(file->GetConverter(), kAudioConverterSampleRateConverterQuality, &dataSize, &quality);
	ZKMORLog(myLevel, source, CFSTR("%s\tSRC Quality: 0x%x"),
			indentStr, quality);
}

#pragma mark _____ ZKMORAbstractAudioFileCPP
	// subclass responsibility
- (CAAudioFile *)caAudioFile { return NULL; }

#pragma mark _____ ZKMORAbstractAudioFilePrivate
- (void)synchronizeFileSRCQuality
{
	CAAudioFile* file = [self caAudioFile];
	if (!file) return;
	AudioConverterRef converter = file->GetConverter();
	if (!converter) return;
	
	UInt32 dataSize, quality = _srcQuality;
	dataSize = sizeof(UInt32);
	OSStatus err = AudioConverterSetProperty(converter, kAudioConverterSampleRateConverterQuality, dataSize, &quality);
	if (err) {
		if (!(kAudioConverterErr_PropertyNotSupported == err))
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not set kAudioConverterSampleRateConverterQuality %4.4s"), &err);
	}
}

@end


@implementation ZKMORAudioFile

- (void)dealloc
{
	if (mAudioFile) delete mAudioFile;
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;

	_conduitType = kZKMORConduitType_Source;
	mAudioFile = new CAAudioFile;
	_currentFrame = 0;
	
	return self;
}

#pragma mark _____ Accessors
- (void)setFileURL:(NSURL *)fileURL error:(NSError **)error
{
	if (_fileURL) mAudioFile->Close();
	[super setFileURL: fileURL error: error];
	
	if (!_isFileFSRefValid) return;
	
	try {
		mAudioFile->Open(_fileFSRef);
	} catch (CAXException& e) {
		if (error) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: @"Could not open file", NSLocalizedDescriptionKey, _fileURL, NSURLErrorKey, nil];
			*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: e.mError userInfo: userInfo];
		} else
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not open file %@"), _fileURL);
		[_fileURL release]; _fileURL = nil;
		return;
	}

	CAStreamBasicDescription clientFormat = mAudioFile->GetFileDataFormat();
		// same format, non-interleaved
	clientFormat.SetCanonical(clientFormat.NumberChannels(), false);
	mAudioFile->SetClientDataFormat(clientFormat);
	[self synchronizeFileSRCQuality];
	_currentFrame = 0;
	_areBusesInitialized = NO;
}

#pragma mark _____ File Information
- (AudioStreamBasicDescription)fileDataFormat { return mAudioFile->GetFileDataFormat(); }
- (unsigned)numberOfChannels { return mAudioFile->GetFileDataFormat().mChannelsPerFrame; }
- (UInt32)fileFormatMagic 
{ 
	UInt32 fileFormat;
	UInt32 propertySize = sizeof(fileFormat);
	OSStatus err = AudioFileGetProperty(mAudioFile->GetAudioFileID(), kAudioFilePropertyFileFormat, &propertySize, &fileFormat);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not get file %@'s file format magic number : %i"), self, err);
		return 0;
	}
	return fileFormat;
}
- (SInt64)numberOfFrames { return mAudioFile->GetNumberFrames(); }

- (Float64)duration
{
	Float64 numberOfFrames = (Float64) mAudioFile->GetNumberFrames();
	return numberOfFrames / mAudioFile->GetFileDataFormat().mSampleRate;
}

- (AudioStreamBasicDescription)streamFormat { return mAudioFile->GetClientDataFormat(); }

#pragma mark _____ Running Information
- (void)setCurrentPosition:(Float64)pos
{
	_currentFrame = (SInt64) (pos * [self numberOfFrames]);
	mAudioFile->Seek(_currentFrame);
}

- (SInt64)currentFrame { return _currentFrame; }

#pragma mark _____ ZKMORConduit Overrides
- (unsigned)numberOfInputBuses { return 0; }
- (unsigned)numberOfOutputBuses { return 1; }

- (ZKMORRenderFunction)renderFunction { return AudioFileRenderFunction; }

- (void)getStreamFormatForBus:(ZKMORConduitBus *)bus
{
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct *) bus;
	busStruct->_streamFormat = mAudioFile->GetClientDataFormat();
}

- (void)setStreamFormatForBus:(ZKMORConduitBus *)bus
{
	CAStreamBasicDescription streamFormat([bus streamFormat]);
	mAudioFile->SetClientDataFormat(streamFormat);
	[super setStreamFormatForBus: bus];
}

#pragma mark _____ ZKMORAbstractAudioFileCPP
- (CAAudioFile *)caAudioFile { return mAudioFile; }

@end

@implementation ZKMORAudioFilePlayer

- (void)dealloc
{
	if (mAudioFileReader) delete mAudioFileReader;
	[super dealloc];
}

- (id)init { return [self initWithNumberOfInternalBuffers: 3 size: 4096]; }

#pragma mark _____ Initialization
- (id)initWithNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers size:(unsigned)numberOfFrames
{
	if (!(self = [super init])) return nil;

	_conduitType = kZKMORConduitType_Source;
	mAudioFileReader = new ZKMORFileReader(numberOfInternalBuffers, numberOfFrames);

	return self;
}

#pragma mark _____ File Reader Properties
- (unsigned)numberOfInternalBuffers { return mAudioFileReader->GetNumberOfBuffers(); }
- (void)setNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers 
{ 
	mAudioFileReader = new ZKMORFileReader(numberOfInternalBuffers, [self internalBufferSize]); 
}
- (unsigned)internalBufferSize { return mAudioFileReader->GetBufferSizeFrames(); }
- (void)setInternalBufferSize:(unsigned)numberOfFrames
{
	mAudioFileReader = new ZKMORFileReader([self numberOfInternalBuffers], numberOfFrames); 
}

#pragma mark _____ Accessors
- (void)setFileURL:(NSURL *)fileURL error:(NSError **)error
{
	[super setFileURL: fileURL error: error];
	if (!_isFileFSRefValid) return;
	
	try {
		mAudioFileReader->SetFile(_fileFSRef);
	} catch (CAXException& e) {
		if (error) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: @"Could not open file", NSLocalizedDescriptionKey, _fileURL, NSURLErrorKey, nil];			
			*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: e.mError userInfo: userInfo];
		} else
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not open file %@"), _fileURL);
		[_fileURL release]; _fileURL = nil;
		_areBusesInitialized = NO;
		return;
	}

	_areBusesInitialized = NO;
	[self synchronizeFileSRCQuality];
}

#pragma mark _____ File Information
- (AudioStreamBasicDescription)fileDataFormat { return mAudioFileReader->GetFileDataFormat(); }
- (unsigned)numberOfChannels { return mAudioFileReader->GetFileDataFormat().mChannelsPerFrame; }
- (UInt32)fileFormatMagic 
{ 
	UInt32 fileFormat;
	UInt32 propertySize = sizeof(fileFormat);
	OSStatus err = AudioFileGetProperty(mAudioFileReader->GetFile().GetAudioFileID(), kAudioFilePropertyFileFormat, &propertySize, &fileFormat);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not get file %@'s file format magic number : %i"), self, err);
		return 0;
	}
	return fileFormat;
}
- (SInt64)numberOfFrames { return mAudioFileReader->GetNumberFrames(); }

- (Float64)duration
{
	Float64 numberOfFrames = (Float64) mAudioFileReader->GetNumberFrames();
	return numberOfFrames / mAudioFileReader->GetFileDataFormat().mSampleRate;
}

- (AudioStreamBasicDescription)streamFormat { return mAudioFileReader->GetClientDataFormat(); }

#pragma mark _____ Running Information
- (Float64)currentPosition { return mAudioFileReader->GetCurrentPosition(); }
- (void)setCurrentPosition:(Float64)pos { mAudioFileReader->SetCurrentPosition(pos); }
- (SInt64)currentFrame { return mAudioFileReader->GetCurrentFrame(); }

- (BOOL)hasDetectedUnderflow { return mAudioFileReader->UnderflowCount() > 0; }
- (void)resetUnderflowDetector { mAudioFileReader->ResetUnderflowCount(); }

#pragma mark _____ ZKMORAbstractAudioFileCPP
- (CAAudioFile *)caAudioFile { return &mAudioFileReader->GetFile(); }

#pragma mark _____ ZKMORConduit Overrides
- (unsigned)numberOfInputBuses { return 0; }
- (unsigned)numberOfOutputBuses { return 1; }
- (ZKMORRenderFunction)renderFunction { return AudioFilePlayerRenderFunction; }

- (void)getStreamFormatForBus:(ZKMORConduitBus *)bus
{
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct *) bus;
	busStruct->_streamFormat = mAudioFileReader->GetClientDataFormat();
}

- (void)setStreamFormatForBus:(ZKMORConduitBus *)bus
{
	CAStreamBasicDescription streamFormat([bus streamFormat]);
	if (_debugLevel & kZKMORDebugLevel_SRate) {
		char str1[255];
		char str2[255];
		ZKMORPrintABSD(mAudioFileReader->GetClientDataFormat(), str1, 255, false);
		ZKMORPrintABSD(streamFormat, str2, 255, false);
		ZKMORLogDebug(CFSTR("%@ : change stream format from %s to %s"), self, str1, str2);
	}
	mAudioFileReader->SetClientDataFormat(streamFormat);
	[super setStreamFormatForBus: bus];
}

@end

@implementation ZKMORAudioFileRecorder

- (void)dealloc
{
	if (mAudioFileWriter) delete mAudioFileWriter;
	[super dealloc];
}

- (id)init { return [self initWithNumberOfInternalBuffers: 3 size: 4096]; }

#pragma mark _____ Initialization
- (id)initWithNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers size:(unsigned)numberOfFrames
{
	if (!(self = [super init])) return nil;

	_conduitType = kZKMORConduitType_Processor;
	mAudioFileWriter = new ZKMORFileWriter(numberOfInternalBuffers, numberOfFrames);

	return self;
}

#pragma mark _____ File Writer Properties
- (unsigned)numberOfInternalBuffers { return mAudioFileWriter->GetNumberOfBuffers(); }
- (void)setNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers 
{ 
	mAudioFileWriter = new ZKMORFileWriter(numberOfInternalBuffers, [self internalBufferSize]); 
}
- (unsigned)internalBufferSize { return mAudioFileWriter->GetBufferSizeFrames(); }
- (void)setInternalBufferSize:(unsigned)numberOfFrames
{
	mAudioFileWriter = new ZKMORFileWriter([self numberOfInternalBuffers], numberOfFrames); 
}

#pragma mark _____ Format Helpers
+ (void)getAIFFInt16Format:(AudioStreamBasicDescription *)dataFormat channels:(unsigned)channels
{
	unsigned bytesPerChannel = 2;
	if (fiszero(dataFormat->mSampleRate)) dataFormat->mSampleRate = 44100.;
	dataFormat->mFormatID = kAudioFormatLinearPCM;
	dataFormat->mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	dataFormat->mFramesPerPacket = 1;
	dataFormat->mChannelsPerFrame = channels;
	dataFormat->mBitsPerChannel = bytesPerChannel * 8;
	dataFormat->mBytesPerPacket = dataFormat->mBytesPerFrame = bytesPerChannel * channels;
}

+ (void)getAIFCInt24Format:(AudioStreamBasicDescription *)dataFormat channels:(unsigned)channels
{
	unsigned bytesPerChannel = 3;
	if (fiszero(dataFormat->mSampleRate)) dataFormat->mSampleRate = 44100.;
	dataFormat->mFormatID = kAudioFormatLinearPCM;
	dataFormat->mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	dataFormat->mFramesPerPacket = 1;
	dataFormat->mChannelsPerFrame = channels;
	dataFormat->mBitsPerChannel = bytesPerChannel * 8;
	dataFormat->mBytesPerPacket = dataFormat->mBytesPerFrame = bytesPerChannel * channels;
}

+ (void)getAIFCFloat32Format:(AudioStreamBasicDescription *)dataFormat channels:(unsigned)channels
{
	unsigned bytesPerChannel = 4;
	if (fiszero(dataFormat->mSampleRate)) dataFormat->mSampleRate = 44100.;
	dataFormat->mFormatID = kAudioFormatLinearPCM;
	dataFormat->mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
	dataFormat->mFramesPerPacket = 1;
	dataFormat->mChannelsPerFrame = channels;
	dataFormat->mBitsPerChannel = bytesPerChannel * 8;
	dataFormat->mBytesPerPacket = dataFormat->mBytesPerFrame = bytesPerChannel * channels;
}

	/// Fills the ASBD to match the 16 Bit Int WAVE format
+ (void)getWAVEInt16Format:(AudioStreamBasicDescription *)dataFormat channels:(unsigned)channels
{
	unsigned bytesPerChannel = 2;
	if (fiszero(dataFormat->mSampleRate)) dataFormat->mSampleRate = 44100.;
	dataFormat->mFormatID = kAudioFormatLinearPCM;
	dataFormat->mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	dataFormat->mFramesPerPacket = 1;
	dataFormat->mChannelsPerFrame = channels;
	dataFormat->mBitsPerChannel = bytesPerChannel * 8;
	dataFormat->mBytesPerPacket = dataFormat->mBytesPerFrame = bytesPerChannel * channels;
}

#pragma mark _____ Accessors
- (void)setFileURL:(NSURL *)fileURL error:(NSError **)error
{
	NSException* e = [NSException exceptionWithName: NSInvalidArgumentException reason: @"setFileURL:error: not implemented by ZKMORAudioFileRecorder. Call setFileURL:fileType:dataFormat:error:." userInfo: nil];
	@throw e;
}

- (void)setFileURL:(NSURL *)fileURL fileType:(AudioFileTypeID)fileType dataFormat:(AudioStreamBasicDescription)dataFormat error:(NSError **)error
{
	// don't call the super, since the FSRef will not exist
//	[super setFileURL: fileURL error: error];
	if (_fileURL) {
		[_fileURL release]; _fileURL = nil;
	}
	
	_fileURL = [fileURL copy];
	
		// make sure the file does not exist
	if ([[NSFileManager defaultManager] fileExistsAtPath: [fileURL relativePath]]) {
		if (error) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: @"File already exists", NSLocalizedDescriptionKey, _fileURL, NSURLErrorKey, nil];		
			*error = [NSError errorWithDomain: NSCocoaErrorDomain code: -1 userInfo: userInfo];
		} else
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("File already exists at path %@"), _fileURL);
		return;
	}
	
		// get the parent directory
	CFURLRef parentURL = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorDefault, (CFURLRef) _fileURL);
	if (NULL == parentURL) {
		NSException* e = [NSException exceptionWithName: NSMallocException reason: @"Out of memory" userInfo: nil];
		@throw e;
	}

	FSRef parentDirFSRef;
	if (!CFURLGetFSRef(parentURL, &parentDirFSRef)) {
		if (error) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: @"Parent directory does not exist", NSLocalizedDescriptionKey, parentURL, NSURLErrorKey, nil];		
			*error = [NSError errorWithDomain: NSCocoaErrorDomain code: -1 userInfo: userInfo];
		} else
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Parent directory does not exist for path %@"), _fileURL);	
		CFRelease(parentURL);
		return;
	}
	CFRelease(parentURL);

	try {
		CFStringRef filename = CFURLCopyLastPathComponent((CFURLRef) _fileURL);
		CAStreamBasicDescription caDataFormat(dataFormat);
		mAudioFileWriter->CreateFile(parentDirFSRef, filename, fileType, caDataFormat, NULL);
		CFRelease(filename);
	} catch (CAXException& e) {
		if (error) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: [NSString stringWithFormat: @"Could not create file %@", _fileURL], NSLocalizedDescriptionKey, nil];		
			*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: e.mError userInfo: userInfo];
		} else
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not create file %@"), _fileURL);
		[_fileURL release]; _fileURL = nil;
		return;
	}

	_areBusesInitialized = NO;
	[self synchronizeFileSRCQuality];
}
- (void)setFilePath:(NSString *)path fileType:(AudioFileTypeID)fileType dataFormat:(AudioStreamBasicDescription)dataFormat error:(NSError **)error
{
	NSURL* fileURL = [NSURL fileURLWithPath: path];
	[self setFileURL: fileURL fileType: fileType dataFormat: dataFormat error: error];
}

#pragma mark _____ Actions
//- (void)flushAndClose { mAudioFileWriter->FlushAndClose(); }
- (void)flushAndClose 
{ 
	mAudioFileWriter->FlushCloseAndDispose();
	[super setFileURL: nil error: nil];
}

#pragma mark _____ File Information
- (AudioStreamBasicDescription)fileDataFormat { return mAudioFileWriter->GetFileDataFormat(); }
- (unsigned)numberOfChannels { return mAudioFileWriter->GetFileDataFormat().mChannelsPerFrame; }
- (UInt32)fileFormatMagic 
{ 
	UInt32 fileFormat;
	UInt32 propertySize = sizeof(fileFormat);
	OSStatus err = AudioFileGetProperty(mAudioFileWriter->GetFile().GetAudioFileID(), kAudioFilePropertyFileFormat, &propertySize, &fileFormat);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not get file %@'s file format magic number : %i"), self, err);
		return 0;
	}
	return fileFormat;
}
- (SInt64)numberOfFrames { return mAudioFileWriter->GetFile().GetNumberFrames(); }

- (Float64)duration
{
	if(_fileURL) {
		Float64 numberOfFrames = (Float64) mAudioFileWriter->GetFile().GetNumberFrames();
		return numberOfFrames / mAudioFileWriter->GetFileDataFormat().mSampleRate;
	} 
	
	return 0.0; 
}

- (AudioStreamBasicDescription)streamFormat { return mAudioFileWriter->GetClientDataFormat(); }

#pragma mark _____ Running Information
- (Float64)currentPosition { return 1.f; }
- (void)setCurrentPosition:(Float64)pos { /* TODO: ZKMORAudioFileRecorder>>setCurrentPosition */ }
- (SInt64)currentFrame { return [self numberOfFrames]; }

#pragma mark _____ ZKMORAbstractAudioFileCPP
- (CAAudioFile *)caAudioFile { return &mAudioFileWriter->GetFile(); }

#pragma mark _____ ZKMORConduit Overrides
- (unsigned)numberOfInputBuses { return 1; }
- (unsigned)numberOfOutputBuses { return 1; }
- (ZKMORRenderFunction)renderFunction { return AudioFileWriterRenderFunction; }

- (void)getStreamFormatForBus:(ZKMORConduitBus *)bus
{
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct *) bus;
	if (!_fileURL) 
		[super getStreamFormatForBus: bus];
	else
		busStruct->_streamFormat = mAudioFileWriter->GetClientDataFormat();
}

- (void)setStreamFormatForBus:(ZKMORConduitBus *)bus
{
	CAStreamBasicDescription streamFormat([bus streamFormat]);
		// only set the stream format if the writer is connected to a file
	if (_fileURL) mAudioFileWriter->SetClientDataFormat(streamFormat);
	[super setStreamFormatForBus: bus];
}

@end
