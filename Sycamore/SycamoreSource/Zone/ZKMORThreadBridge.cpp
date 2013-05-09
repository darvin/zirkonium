//
//  ZKMORThreadBridge.cpp
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 15.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#include "ZKMORThreadBridge.h"

#pragma mark _____ ZKMORBufferBridge
ZKMORBufferBridge::ZKMORBufferBridge(int nBuffers, UInt32 bufferSizeFrames) :
	mNumberBuffers(nBuffers),
	mBufferQueue(nBuffers),
	mBuffersAreValid(false),
	mBufferSizeFrames(bufferSizeFrames),
	mBufferList(NULL), mUnderflowCount(0), mOverflowCount(0)
{

}

ZKMORBufferBridge::~ZKMORBufferBridge()
{
	DisposeBuffers();
}

void	ZKMORBufferBridge::PullBuffer(UInt32 &ioFrames, AudioBufferList *outBufferList)
{
	UInt32 framesRequired = ioFrames;
	UInt32 framesProduced = 0;
	
	do {
		Buffer *b = mBufferQueue.ReadItem();
		if (NULL == b) {
			mUnderflowCount++;
			break;
		}
		
		if (b->CopyInto(outBufferList, mBytesPerFrame, framesProduced, framesRequired))
			mBufferQueue.AdvanceReadPtr();
	} while (framesRequired > 0);
	ioFrames = framesProduced;
}

void	ZKMORBufferBridge::PushBuffer(UInt32 inNumberFrames, const AudioBufferList *inBufferList)
{
	UInt32 framesRequired = inNumberFrames;
	UInt32 framesProduced = 0;
	
	do {
		Buffer *b = mBufferQueue.WriteItem();
		if (NULL == b) {
			mOverflowCount++;
			break;
		}
		
		if (b->CopyFrom(inBufferList, mBytesPerFrame, framesProduced, framesRequired)) {
			mBufferQueue.AdvanceWritePtr();
		}
	} while (framesRequired > 0);
}

void	ZKMORBufferBridge::SetFormat(const CAStreamBasicDescription &fmt)
{
	DisposeBuffers();
	
	mBytesPerFrame = fmt.mBytesPerFrame;
	Buffer** allBuffers = mBufferQueue.AllItemsNA();
	for (int i = 0; i < mNumberBuffers; ++i) { 
		allBuffers[i] = CreateBuffer(fmt, mBufferSizeFrames * mBytesPerFrame);
	}
	mBufferList = CABufferList::New("", fmt);
	mBuffersAreValid = true;
}

#pragma mark _____ ZKMORBufferBridge::Buffer
ZKMORBufferBridge::Buffer::Buffer(ZKMORBufferBridge *queue, const CAStreamBasicDescription &fmt, UInt32 nBytes) :
	mQueue(queue)
{
	mMemory = CABufferList::New("", fmt);
	mMemory->AllocateBuffers(nBytes);
	mByteSize = nBytes;
	mStartFrame = mEndFrame = 0;
}

// return true if buffer emptied AND we're not at end-of-stream
bool	ZKMORBufferBridge::Buffer::CopyInto(AudioBufferList *destBufferList, int bytesPerFrame, UInt32 &framesProduced, UInt32 &framesRequired)
{
	UInt32 framesInBuffer = mEndFrame - mStartFrame;
	UInt32 framesToCopy = std::min(framesInBuffer, framesRequired);
	if (framesToCopy > 0) {
		const CABufferList *bufMemory = mMemory;
		const AudioBufferList &srcBufferList = bufMemory->GetBufferList();
		const AudioBuffer *srcbuf = srcBufferList.mBuffers;
		AudioBuffer *dstbuf = destBufferList->mBuffers;
		for (int i = destBufferList->mNumberBuffers; --i >= 0; ++srcbuf, ++dstbuf) {
			Byte* destPos = (Byte *)dstbuf->mData + framesProduced * bytesPerFrame;
			Byte* startPos = (Byte *)srcbuf->mData + mStartFrame * bytesPerFrame;
			memcpy(destPos, startPos, framesToCopy * bytesPerFrame);
		}
		framesProduced += framesToCopy;
		framesRequired -= framesToCopy;
		mStartFrame += framesToCopy;
	}
	return (framesToCopy == framesInBuffer);
}

// return true if buffer filled
bool	ZKMORBufferBridge::Buffer::CopyFrom(const AudioBufferList *srcBufferList, int bytesPerFrame, UInt32 &framesProduced, UInt32 &framesRequired)
{
	UInt32 framesInBuffer = mEndFrame - mStartFrame;
	UInt32 freeFramesInBuffer = (mByteSize / bytesPerFrame) - framesInBuffer;
	UInt32 framesToCopy = std::min(freeFramesInBuffer, framesRequired);
	if (framesToCopy > 0) {
		const AudioBuffer *srcbuf = srcBufferList->mBuffers;
		const CABufferList *bufMemory = mMemory;
		const AudioBufferList &destBufferList = bufMemory->GetBufferList();
		const AudioBuffer *dstbuf = destBufferList.mBuffers;
		for (int i = srcBufferList->mNumberBuffers; --i >= 0; ++srcbuf, ++dstbuf) {
			memcpy(
				(Byte *)dstbuf->mData + framesInBuffer * bytesPerFrame,
				(Byte *)srcbuf->mData + framesProduced * bytesPerFrame,
				framesToCopy * bytesPerFrame);
		}
		framesProduced += framesToCopy;
		framesRequired -= framesToCopy;
		mEndFrame += framesToCopy;
	}
	return (framesToCopy == freeFramesInBuffer);
}

void	ZKMORBufferBridge::DisposeBuffer(Buffer *b)
{
	delete b;
}

void	ZKMORBufferBridge::DisposeBuffers()
{
	if (mBuffersAreValid) {
		Buffer** allBuffers = mBufferQueue.AllItemsNA();
		for (int i = 0; i < mNumberBuffers; ++i)
			DisposeBuffer(allBuffers[i]);
		mBuffersAreValid = false;
	}
	delete mBufferList; mBufferList = NULL;
}

