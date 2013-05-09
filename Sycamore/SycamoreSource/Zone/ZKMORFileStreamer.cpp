//
//  ZKMORFileStreamer.cpp
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 05.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORFileStreamer.h"
#include "ZKMORLogger.h"

// #define DEBUG_ZONE_STREAMER

#pragma mark _____ ZKMORFileReader
void	ZKMORFileReader::SetFile(const FSRef &inFile)
{
	RemoveFromWorkerThread();
	DisposeBuffers();
	mIsPrimed = false;
	
	delete mFile, mFile = NULL;
	mFile = new CAAudioFile;
	mFile->Open(inFile);
	
	
	mNumberOfFrames = mFile->GetNumberFrames();
	
	const CAStreamBasicDescription &fileFmt = mFile->GetFileDataFormat();
	CAStreamBasicDescription iofmt;
	iofmt.SetCanonical(fileFmt.mChannelsPerFrame, false);	// deinterleaved
	iofmt.mSampleRate = fileFmt.mSampleRate;
	SynchronousSetClientDataFormat(iofmt);
	AddToWorkerThread();
}

void	ZKMORFileReader::SetFilePath(const char* filePath)
{
	FSRef fsref;
	XThrowIfError(FSPathMakeRef((UInt8 *)filePath, &fsref, NULL), "locate audio file");
	SetFile(fsref);
}

double	ZKMORFileReader::GetCurrentPosition() const
{
	return (GetCurrentFrame() < 0) ? 0. : double(GetCurrentFrame()) / double(GetNumberFrames());
}

void	ZKMORFileReader::SetCurrentPosition(double loc)
{
	RemoveFromWorkerThread();
		SynchronousSetCurrentPosition(loc);
	AddToWorkerThread();
}

void	ZKMORFileReader::AsyncSetCurrentPosition(double loc)
{
	SetPositionAction* action = mSetPositionQueue.GetWriteItem();
	if (action) {
		action->position = loc;
		mSetPositionQueue.ReturnWrittenItem(action);
		MarkNeedsToRun();
	} else {
		ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_Zone, CFSTR("File reader 0x%x -- could not set position on to %f (queue full)"), this, loc);
	}
}


SInt64	ZKMORFileReader::GetCurrentFrame() const
{
//	if (!mRunning) return mFile->Tell();
	if (mEndOfStream) return GetNumberFrames();
	const FileReadBuffer *b = static_cast<const FileReadBuffer *>(GetCurrentBuffer());
		// the buffer from which we're reading
	UInt32 startFrame, endFrame;
	b->GetLocation(startFrame, endFrame);
	return b->mBufferStartFileFrame + startFrame;
}

void	ZKMORFileReader::SetClientDataFormat(const CAStreamBasicDescription& format)
{
	RemoveFromWorkerThread();
		SynchronousSetClientDataFormat(format);
	AddToWorkerThread();
}

void	ZKMORFileReader::RunIteration()
{
	FileReadBuffer *b;
#ifdef DEBUG_ZONE_STREAMER
	ZKMORLogDebug(CFSTR("0x%x RunIteration -- Start %u"), this, GetNumberOfValidBuffers());
#endif
	mSetPositionQueue.BeginReading();
		if (mSetPositionQueue.Count() > 0) {
			unsigned i, count = mSetPositionQueue.Count() - 1;
				// skip the first n - 1 items
			SetPositionAction* action;
			for (i = 0; i < count; ++i) {
				action = mSetPositionQueue.GetReadItem();
				mSetPositionQueue.ReturnReadItem(action);
			}
				// process the last one
			action = mSetPositionQueue.GetReadItem();
			SynchronousSetCurrentPosition(action->position);
			mSetPositionQueue.ReturnReadItem(action);
				// clean-up and leave
			mSetPositionQueue.EndReading();
			return;
		}
	mSetPositionQueue.EndReading();
	
	while (b = static_cast<FileReadBuffer*>(mBufferQueue.WriteItem())) {
		ReadBuffer(b);
		mBufferQueue.AdvanceWritePtr();
	}
#ifdef DEBUG_ZONE_STREAMER
	ZKMORLogDebug(CFSTR("0x%x RunIteration -- End %u"), this, GetNumberOfValidBuffers());
#endif
}


void	ZKMORFileReader::SynchronousSetCurrentPosition(double loc)
{
	SInt64 frameNumber = SInt64(loc * GetFile().GetNumberFrames() + 0.5);
//	SInt64 frameNumber = SInt64(loc * GetFile().GetNumberFrames());
	try {
		GetFile().Seek(frameNumber);
		Prime();
		char debugStr[255];
		SNPrint(debugStr, 255);
	}
	catch (CAXException &e) {
		char errStr[255];
		e.FormatError(errStr);
		ZKMORLogError(kZKMORLogSource_Zone, CFSTR("Could not set position on file 0x%x to %lli : %s"), this, frameNumber, errStr);
	}
	catch (...) {
		ZKMORLogError(kZKMORLogSource_Zone, CFSTR("Could not set position on file 0x%x to %lli"), this, frameNumber);
	}
}

void	ZKMORFileReader::SynchronousSetClientDataFormat(const CAStreamBasicDescription& format)
{
	mFile->SetClientFormat(format, NULL);
	
	SetFormat(format);
	
	mUnderflowCount = 0;
	mEndOfStream = false;
	if (!mIsPrimed) 
		Prime();
	else
		SynchronousSetCurrentPosition(GetCurrentPosition());
}

void	ZKMORFileReader::FileReadBuffer::UpdateAfterRead(SInt64 curFrame, UInt32 nFrames)
{
	//printf("read %ld PCM packets, file packets %qd-%qd\n", nPackets, b->mStartPacket, b->mEndPacket);
	mEndFrame = nFrames;
	mEndOfStream = (nFrames == 0);
	mBufferStartFileFrame = curFrame;
}

void	ZKMORFileReader::ReadBuffer(FileReadBuffer *b)
{
	b->SetEmpty();
	CABufferList *ioMemory = b->GetBufferList();
	CABufferList *fileBuffers = GetBufferList();
	fileBuffers->SetFrom(ioMemory);
	UInt32 nFrames = GetBufferSizeFrames();
	SInt64 curFrame = mFile->Tell();
	mFile->Read(nFrames, &fileBuffers->GetModifiableBufferList());
	b->UpdateAfterRead(curFrame, nFrames);
}

#pragma mark _____ ZKMORFileWriter
void	ZKMORFileWriter::CreateFile(const FSRef &parentDir, CFStringRef filename, AudioFileTypeID filetype, const CAStreamBasicDescription &dataFormat, const CAAudioChannelLayout *layout)
{
	RemoveFromWorkerThread();
	
	FlushAndClose();
	DisposeBuffers();
	
	delete mFile;   mFile = NULL;
	mFile = new CAAudioFile;
	mFile->CreateNew(parentDir, filename, filetype, dataFormat, layout ? &layout->Layout() : NULL);
	
	const CAStreamBasicDescription &fileFmt = mFile->GetFileDataFormat();
	CAStreamBasicDescription iofmt;
	iofmt.SetCanonical(fileFmt.mChannelsPerFrame, false);	// deinterleaved
	iofmt.mSampleRate = fileFmt.mSampleRate;
	SetClientDataFormat(iofmt);
	AddToWorkerThread();
}

void	ZKMORFileWriter::SetClientDataFormat(const CAStreamBasicDescription& format)
{
	RemoveFromWorkerThread();
		SynchronousSetClientDataFormat(format);
	AddToWorkerThread();
}

void	ZKMORFileWriter::RunIteration()
{
	ZKMORBufferQueue::Buffer *b;
#ifdef DEBUG_ZONE_STREAMER
	ZKMORLogDebug(CFSTR("0x%x Write::RunIteration -- Start %u"), this, GetNumberOfValidBuffers());
#endif
	while (b = mBufferQueue.ReadItem()) {
		WriteBuffer(b);
		mBufferQueue.AdvanceReadPtr();
	}
#ifdef DEBUG_ZONE_STREAMER
	ZKMORLogDebug(CFSTR("0x%x Write::RunIteration -- End %u"), this, GetNumberOfValidBuffers());	
#endif
}

void	ZKMORFileWriter::SynchronousSetClientDataFormat(const CAStreamBasicDescription& format)
{
	mFile->SetClientFormat(format, NULL);
	SetFormat(format);
	mUnderflowCount = 0;
}
	
void	ZKMORFileWriter::WriteBuffer(ZKMORBufferQueue::Buffer *b)
{
	CABufferList *ioMemory = b->GetBufferList();
	CABufferList *fileBuffers = GetBufferList();
	UInt32 nFrames = b->FrameCount();
	fileBuffers->SetFrom(ioMemory, GetBytesPerFrame() * nFrames);
	mFile->Write(nFrames, &fileBuffers->GetModifiableBufferList());
	b->SetEmpty();
}

void	ZKMORFileWriter::FlushAndClose()
{
	RemoveFromWorkerThread();
	Flush();
	// Write out the file
	if (mFile) mFile->Close();
}

void	ZKMORFileWriter::FlushCloseAndDispose()
{
	FlushAndClose();
		// Don't hold a reference to the file anymore -- I can't do anything with it.
	delete mFile; mFile = NULL;
}
