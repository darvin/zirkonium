//
//  ZKMORAudioFileOutput.mm
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 02.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioFileOutput.h"
#include "ZKMORLogger.h"
#import "ZKMORGraph.h"
#import "ZKMORClock.h"
#import "ZKMORUtilities.h"
#include "CAAudioFile.h"
#include "AUOutputBL.h"
#include "CAAudioTimeStamp.h"

static BOOL GetCStringForURL(CFURLRef url, char** cString, NSError** error)
{
	// cache the UTF8 representation of the path
	CFStringRef fsPath = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
		// add 1 for the null terminator
	CFIndex pathLength = CFStringGetLength(fsPath) + 1;
		// OS X paths are UTF8 encoded
	*cString = (char*) malloc(pathLength * sizeof(UTF8Char));
	if (!CFStringGetCString(fsPath, *cString, pathLength, kCFStringEncodingUTF8)) {
		free(*cString); *cString = NULL;
		CFRelease(fsPath);
		if (error) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: @"ZKMORAudioFile could not get CString for path", NSLocalizedDescriptionKey, nil];
			*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: memFullErr userInfo: userInfo];
		} else
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not get CString for path %@"), url);
		return NO;
	}
	CFRelease(fsPath);
	return YES;
}

@implementation ZKMORAudioFileOutput

- (void)dealloc
{
	if (_fileURL) [_fileURL release];
	if (_filePathUTF8) free(_filePathUTF8);
	if (mAudioFile) delete mAudioFile;
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;

	_fileURL = nil;
	_filePathUTF8 = NULL;
	mAudioFile = new CAAudioFile;
	mBufferList = NULL;
	mTimeStamp = NULL;
	
	return self;
}

#pragma mark _____ Accessors
- (NSURL *)fileURL { return _fileURL; }

- (void)setFileURL:(NSURL *)fileURL fileType:(AudioFileTypeID)fileType dataFormat:(AudioStreamBasicDescription)dataFormat error:(NSError **)error
{
	if (_fileURL) {
		[_fileURL release]; _fileURL = nil;
		free(_filePathUTF8); _filePathUTF8 = NULL;
	}
	
	_fileURL = [fileURL copy];
	if (!GetCStringForURL((CFURLRef) _fileURL, &_filePathUTF8, error)) {
		[_fileURL release]; 
		_fileURL = nil;
	}
	
	if (!_filePathUTF8) return;
	
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
		mAudioFile->CreateNew(parentDirFSRef, filename, fileType, caDataFormat, NULL);
		CFRelease(filename);
	} catch (CAXException& e) {
		if (error) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: [NSString stringWithFormat: @"Could not create file %@", _fileURL], NSLocalizedDescriptionKey, nil];		
			*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: e.mError userInfo: userInfo];
		} else
			ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not create file %@"), _fileURL);
		[_fileURL release]; _fileURL = nil;
		free(_filePathUTF8); _filePathUTF8 = NULL;
		return;
	}
}
- (void)setFilePath:(NSString *)path fileType:(AudioFileTypeID)fileType dataFormat:(AudioStreamBasicDescription)dataFormat error:(NSError **)error
{
	NSURL* fileURL = [NSURL fileURLWithPath: path];
	[self setFileURL: fileURL fileType: fileType dataFormat: dataFormat error: error];
}

- (unsigned)maxFramesPerSlice { return (_graph) ? [_graph maxFramesPerSlice] : 0; }
- (void)setMaxFramesPerSlice:(unsigned)maxFramesPerSlice { if (_graph) [_graph setMaxFramesPerSlice: maxFramesPerSlice]; }

- (OSStatus)lastError { return _lastError; }

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

#pragma mark _____ Actions
- (void)runIteration:(unsigned)numberOfFrames
{
	AudioUnitRenderActionFlags ioActionFlags = 0;
	
	mBufferList->Prepare();
	_lastError = GraphRenderFunction(_graph, &ioActionFlags, mTimeStamp, 0, numberOfFrames, mBufferList->ABL());
	if (noErr != _lastError) return;
	
	mTimeStamp->mSampleTime = mTimeStamp->mSampleTime + numberOfFrames;
	[_clock setCurrentTimeSeconds: mTimeStamp->mSampleTime / [_graph graphSampleRate]];	
	mAudioFile->Write(numberOfFrames, mBufferList->ABL());
}

#pragma mark _____ ZKMORAudioFileOutputCPP

- (CAAudioFile *)caAudioFile { return mAudioFile; }


#pragma mark _____ ZKMOROutput Overrides
- (void)setGraph:(ZKMORGraph *)graph
{
	[super setGraph: graph];
		// needs to come after the sample rate change, since that may change the stream format
	[self graphOutputStreamFormatChanged];
}

- (void)start 
{
	[super start];
	_lastError = noErr;
	mBufferList = new AUOutputBL(mAudioFile->GetClientDataFormat(), [self maxFramesPerSlice]);
	mBufferList->Allocate([self maxFramesPerSlice]);
	mTimeStamp = new CAAudioTimeStamp(0.0);
}

- (void)stop 
{
	mAudioFile->Close();
	mBufferList->Allocate(0);
	delete mBufferList; mBufferList = NULL;
	delete mTimeStamp; mTimeStamp = NULL;
	
	[super stop];
}

- (void)graphOutputStreamFormatChanged
{
	if (_graph) {
		CAStreamBasicDescription format([[_graph outputBusAtIndex: 0] streamFormat]);
		mAudioFile->SetClientFormat(format, NULL);		
	}
}

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
	ZKMORPrintABSD([[_graph outputBusAtIndex: 0] streamFormat], dataFormatStr, 256, false);
	
	ZKMORLog(myLevel, source, CFSTR("%s\tFile       : %s %lu max fames per slice \n%s\tIn Format  : %s"),
		indentStr, _filePathUTF8, [self maxFramesPerSlice],
		indentStr, dataFormatStr);
		
	ZKMORPrintABSD([self fileDataFormat], dataFormatStr, 256, false);
	ZKMORLog(myLevel, source, CFSTR("%s\tData Format: %s"),
		indentStr, dataFormatStr);
		
	CAAudioFile* file = [self caAudioFile];
	if (!file) return;
	
	UInt32 dataSize, quality = 0;
	dataSize = sizeof(UInt32);
	AudioConverterGetProperty(file->GetConverter(), kAudioConverterSampleRateConverterQuality, &dataSize, &quality);
	ZKMORLog(myLevel, source, CFSTR("%s\tSRC Quality: 0x%x"),
			indentStr, quality);
}


@end
