//
//  ZKMORFileStreamer.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 05.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORFileStreamer_h__
#define __ZKMORFileStreamer_h__

#include "ZKMORZone.h"
#include "CAAudioFile.h"
#include "ZKMMPQueue.h"

///
///  ZKMORFileReader
///
///  Reads audio files.
/// 
class ZKMORFileReader : public ZKMORPullBufferQueue {
public:
//  CTOR
	ZKMORFileReader(int nBuffers, UInt32 bufferSizeFrames) :
		ZKMORPullBufferQueue(nBuffers, bufferSizeFrames), 
		mFile(NULL), mNumberOfFrames(-1),
		mSetPositionQueue(4) 
	{ 
		mSetPositionQueue.FinishInitializing();
	}
	
	~ZKMORFileReader() { RemoveFromWorkerThread(); if (mFile) delete mFile; }

//  Accessors
	CAAudioFile&	GetFile() { return *mFile; }
	
	void			SetFile(const FSRef &inFile);
	void			SetFilePath(const char* filePath);
	
		/// returns a value between 0. -> 1. for the position in the file
	double			GetCurrentPosition() const;
		/// accepts a value between 0. -> 1. for the position in the file
		///		Removes the object from the worker thread, changes the position, and re-adds to the worker thread.
	void			SetCurrentPosition(double loc);
		/// accepts a value between 0. -> 1. for the position in the file
		///		Can be called while the audio thread is running, but may not be processed for an indeterminate amount
		///		of time.
	void			AsyncSetCurrentPosition(double loc);
	

		
	SInt64			GetCurrentFrame() const;
	SInt64			GetNumberFrames() const    { return mNumberOfFrames; }
	
	//  Format Accessors
		/// The format that the file is in
	const CAStreamBasicDescription&		GetFileDataFormat() const { return mFile->GetFileDataFormat(); }
		/// The format that the reader outputs	
	const CAStreamBasicDescription&		GetClientDataFormat() const { return mFile->GetClientDataFormat(); }
		/// Set the format the reader outputs -- removes from the worker thread		
	void								SetClientDataFormat(const CAStreamBasicDescription& format);

protected:
//  Internal Functions
	void		RunIteration();
	void		SynchronousSetCurrentPosition(double loc);
	void		SynchronousSetClientDataFormat(const CAStreamBasicDescription& format);
	
//  Internal State
	CAAudioFile*	mFile;
	SInt64			mNumberOfFrames;

//  Buffer Reading -- Need a subclass of buffer and a ReadBuffer method that uses the subclass
	class FileReadBuffer : public ZKMORBufferQueue::Buffer {
	public:
		FileReadBuffer(ZKMORBufferQueue *queue, const CAStreamBasicDescription &fmt, UInt32 nBytes) :
			ZKMORBufferQueue::Buffer(queue, fmt, nBytes), mBufferStartFileFrame(0)
		{ }
		
		void			UpdateAfterRead(SInt64 curFrame, UInt32 nFramesRead);
		void			GetLocation(UInt32 &frm0, UInt32 &frame1) const { frm0 = mStartFrame; frame1 = mEndFrame; }
		SInt64			mBufferStartFileFrame;
	};
	
	ZKMORBufferQueue::Buffer *	CreateBuffer(const CAStreamBasicDescription &fmt, UInt32 nBytes) {
							return new FileReadBuffer(this, fmt, nBytes);
						}
	
	void				ReadBuffer(FileReadBuffer *b);

//  Asynchronous actions
	struct SetPositionAction {
		double position; 
		SetPositionAction*	get_next() { return mNext; }
		void				set_next(SetPositionAction* next) { mNext = next; }
		SetPositionAction*	mNext;
	};
	typedef	TManagedQueue<SetPositionAction> SetPositionQueue;
	SetPositionQueue		mSetPositionQueue;
};



///
///  ZKMORFileWriter
///
///  Writes audio files.
/// 
class ZKMORFileWriter : public ZKMORPushBufferQueue {
public:
	ZKMORFileWriter(int nBuffers, UInt32 bufferSizeFrames) :
		ZKMORPushBufferQueue(nBuffers, bufferSizeFrames),
		mFile(NULL) { }
		
//  Accessors
	CAAudioFile&	GetFile() { return *mFile; }
	
		/// throws a CAXException if the file exists
	void			CreateFile(const FSRef &parentDir, CFStringRef filename, AudioFileTypeID filetype, const CAStreamBasicDescription &dataFormat, const CAAudioChannelLayout *layout);
	
	
	//  Format Accessors
		/// The format that the file is in
	const CAStreamBasicDescription&		GetFileDataFormat() const { return mFile->GetFileDataFormat(); }
		/// The format that the reader outputs	
	const CAStreamBasicDescription&		GetClientDataFormat() const { return mFile->GetClientDataFormat(); }
		/// Set the format the reader outputs -- removes from the worker thread		
	void								SetClientDataFormat(const CAStreamBasicDescription& format);
	
//  Actions
		/// Flushes the buffer and writes out the file. This needs to be called to ensure the file is complete.
	void	FlushAndClose();
		/// Flushes the buffer and writes out the file, and disploses of the file data.
	void	FlushCloseAndDispose();

protected:
//  Internal Functions
	void		RunIteration();
	void		SynchronousSetClientDataFormat(const CAStreamBasicDescription& format);	
	
//  Internal State
	CAAudioFile*	mFile;
	
	ZKMORBufferQueue::Buffer *	CreateBuffer(const CAStreamBasicDescription &fmt, UInt32 nBytes) {
							return new ZKMORBufferQueue::Buffer(this, fmt, nBytes);
						}
	void				WriteBuffer(ZKMORBufferQueue::Buffer *b);
};


#endif __ZKMORFileStreamer_h__