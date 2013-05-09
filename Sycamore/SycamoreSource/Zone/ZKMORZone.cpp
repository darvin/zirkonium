/*
 *  ZKMORZone.cpp
 *  Sycamore
 *
 *  Created by Chandrasekhar Ramakrishnan on 01.09.06.
 *  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include "ZKMORZone.h"
#include "ZKMORLogger.h"
#include "CAXException.h"

//#define DEBUG_ZONE

#pragma mark _____ ZKMORFileZoneObject
ZKMORFileZoneObject::WorkThread *ZKMORFileZoneObject::sWorkThread = NULL;


ZKMORFileZoneObject::ZKMORFileZoneObject() : mNeedsToRun(false)
{
	if (sWorkThread == NULL)
		sWorkThread = new WorkThread();
	mWorkThread = sWorkThread;  // for now
	AddToWorkerThread();
}

ZKMORFileZoneObject::~ZKMORFileZoneObject()
{
	RemoveFromWorkerThread();
}

ZKMORFileZoneObject::WorkThread::WorkThread() :
	CAPThread(ThreadEntry, this, CAPThread::kMaxThreadPriority, true),
	mStopped(false),
	mRunGuard("File Zone mRunGuard")
{
	mZoneObjects = CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
	Start();
}

ZKMORFileZoneObject::WorkThread::~WorkThread()
{
	CFRelease(mZoneObjects);
}

void	ZKMORFileZoneObject::WorkThread::RunThread()
{
	while (!mStopped) {
		CAGuard::Locker lock(mRunGuard);
		lock.Wait();
		
		if (!mStopped) {
						// run all the objects that need to be run
			CFIndex count = CFSetGetCount(mZoneObjects);
			ZKMORFileZoneObject* items[count];
			CFSetGetValues(mZoneObjects, (const void **)items);
			unsigned i;
			for (i = 0; i < count; i++) {
				if (items[i]->mNeedsToRun) {
#ifdef DEBUG_ZONE
					ZKMORLogDebug(CFSTR("Run Iteration on item %0x"), items[i]);
#endif
					items[i]->RunIteration();
					items[i]->mNeedsToRun = false;
				}
			}
		}
	}
}

void	ZKMORFileZoneObject::WorkThread::StopThread()
{
	mStopped = true;
	mRunGuard.Notify();
}

void	ZKMORFileZoneObject::WorkThread::NotifyThread() { mRunGuard.Notify(); }

void	ZKMORFileZoneObject::WorkThread::AddObject(ZKMORFileZoneObject *object)
{
	CAGuard::Locker lock(mRunGuard);
	CFSetAddValue(mZoneObjects, reinterpret_cast<const void *>(object));
}

void	ZKMORFileZoneObject::WorkThread::RemoveObject(ZKMORFileZoneObject *object)
{
	CAGuard::Locker lock(mRunGuard);
	CFSetRemoveValue(mZoneObjects, reinterpret_cast<const void *>(object));
}

void	ZKMORFileZoneObject::MarkNeedsToRun()
{
#ifdef DEBUG_ZONE
	ZKMORLogDebug(CFSTR("0x%x MarkNeedsToRun"), this);
#endif
	mNeedsToRun = true;
	mWorkThread->NotifyThread();
}

void	ZKMORFileZoneObject::RemoveFromWorkerThread()
{
#ifdef DEBUG_ZONE
	ZKMORLogDebug(CFSTR("0x%x RemoveFromWorkerThread"), this);
#endif
	mWorkThread->RemoveObject(this);
}

void	ZKMORFileZoneObject::AddToWorkerThread()
{
#ifdef DEBUG_ZONE
	ZKMORLogDebug(CFSTR("0x%x AddToWorkerThread"), this);
#endif
	mWorkThread->AddObject(this);
}


#pragma mark _____ ZKMORBufferQueue
ZKMORBufferQueue::ZKMORBufferQueue(int nBuffers, UInt32 bufferSizeFrames) :
	ZKMORFileZoneObject(), 
	mNumberBuffers(nBuffers),
	mBufferQueue(nBuffers),
	mBuffersAreValid(false),
	mBufferSizeFrames(bufferSizeFrames),
	mBufferList(NULL),
	mBufferQueueState(kZKMORBufferQueueState_Free)
{
	mUnderflowCount = 0;
	mValidBufferThreshold = (nBuffers > 1) ? nBuffers - 1 : 1;
}

ZKMORBufferQueue::~ZKMORBufferQueue()
{
	RemoveFromWorkerThread();
	DisposeBuffers();
}

void	ZKMORBufferQueue::SetFormat(const CAStreamBasicDescription &fmt)
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

#pragma mark _____ Debugging
int ZKMORBufferQueue::SNPrint(char* destStr, size_t strLen) const
{
	int numWritten = mBufferQueue.SNPrint(destStr, strLen);
	numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), " Number Valid %u ", GetNumberOfValidBuffers());
	return numWritten;
}

#pragma mark _____ ZKMORBufferQueue::Buffer
ZKMORBufferQueue::Buffer::Buffer(ZKMORBufferQueue *queue, const CAStreamBasicDescription &fmt, UInt32 nBytes) :
	mQueue(queue)
{
	mMemory = CABufferList::New("", fmt);
	mMemory->AllocateBuffers(nBytes);
	mByteSize = nBytes;
	mStartFrame = mEndFrame = 0;
	mEndOfStream = false;
}

// return true if buffer emptied AND we're not at end-of-stream
bool	ZKMORBufferQueue::Buffer::CopyInto(AudioBufferList *destBufferList, int bytesPerFrame, UInt32 &framesProduced, UInt32 &framesRequired)
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
	return (framesToCopy == framesInBuffer) && !mEndOfStream;
}

// return true if buffer filled
bool	ZKMORBufferQueue::Buffer::CopyFrom(const AudioBufferList *srcBufferList, int bytesPerFrame, UInt32 &framesProduced, UInt32 &framesRequired)
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

void	ZKMORBufferQueue::DisposeBuffer(Buffer *b)
{
	delete b;
}

void	ZKMORBufferQueue::DisposeBuffers()
{
	if (mBuffersAreValid) {
		Buffer** allBuffers = mBufferQueue.AllItemsNA();
		for (int i = 0; i < mNumberBuffers; ++i)
			DisposeBuffer(allBuffers[i]);
		mBuffersAreValid = false;
	}
	delete mBufferList; mBufferList = NULL;
}

void	ZKMORBufferQueue::Pause()
{
	do {
		if (kZKMORBufferQueueState_Paused == mBufferQueueState) break;
	} while (!CompareAndSwap(kZKMORBufferQueueState_Free, kZKMORBufferQueueState_Paused, (UInt32*)&mBufferQueueState));
}

void	ZKMORBufferQueue::Unpause()
{
	if (!CompareAndSwap(kZKMORBufferQueueState_Paused , kZKMORBufferQueueState_Free, (UInt32*)&mBufferQueueState))
		XThrow(paramErr, "ZKMORBufferQueue::Unpause called without a pause");
}

#pragma mark _____ ZKMORPullBufferQueue
void	ZKMORPullBufferQueue::Prime()
{
	mEndOfStream = false;
	if (!mBuffersAreValid) {
		ZKMORLogError(kZKMORLogSource_Zone, CFSTR("ZKMORPullBufferQueue::Prime() -- buffers are not valid"));
		XThrow(paramErr, "ZKMORPullBufferQueue::Prime() -- buffers are not valid");
	}

	Pause();
		mBufferQueue.ResetIndicesNA();
		RunIteration();
	Unpause();
	mIsPrimed = true;
}

void	ZKMORPullBufferQueue::PullBuffer(UInt32 &ioFrames, AudioBufferList *outBufferList)
{
	if (mEndOfStream) {
		ioFrames = 0;
		return;
	}
	UInt32 framesRequired = ioFrames;
	UInt32 framesProduced = 0;
	
		// another thread is messing with the buffer reader -- this only happens if the user has explicitly requested this
		// sort of thing
	if (!CompareAndSwap(kZKMORBufferQueueState_Free, kZKMORBufferQueueState_Rendering, (UInt32*)&mBufferQueueState))
	{
		// clear buffer
		unsigned numBuffers = outBufferList->mNumberBuffers;
		unsigned i;
		for (i = 0; i < numBuffers; i++) {
			// memset the buffers to 0
			memset(outBufferList->mBuffers[i].mData, 0, outBufferList->mBuffers[i].mDataByteSize);
		}
		return;
	}
	
#ifdef DEBUG_ZONE
	ZKMORLogDebug(CFSTR("PullBuffer -- Start {%u frames required, %u valid buffers}"), framesRequired, GetNumberOfValidBuffers());
#endif
	
	do {
		Buffer *b = mBufferQueue.ReadItem();
		if (NULL == b) {
			mUnderflowCount++;
			ZKMORLogError(kZKMORLogSource_Zone, CFSTR("DAC running faster than file reader thread (0x%x over:%i) -- %u required %u produced / %u valid %u threshold"), this, mUnderflowCount, framesRequired, framesProduced, GetNumberOfValidBuffers(), mValidBufferThreshold);
			MarkNeedsToRun();
			break;
		}
		
		mUnderflowCount = 0;
		if (b->CopyInto(outBufferList, mBytesPerFrame, framesProduced, framesRequired)) {
			mBufferQueue.AdvanceReadPtr();

				// if I don't have enough valid buffers, mark for running
			if (GetNumberOfValidBuffers() <= mValidBufferThreshold)
				MarkNeedsToRun();
		}
		else if (b->ReachedEndOfStream()) {
			mEndOfStream = true;
			break;
		}
	} while (framesRequired > 0);
	ioFrames = framesProduced;
	
		// this will succeed -- otherwise we wouldn't be here
	CompareAndSwap(kZKMORBufferQueueState_Rendering, kZKMORBufferQueueState_Free, (UInt32*)&mBufferQueueState);
	
#ifdef DEBUG_ZONE
	ZKMORLogDebug(CFSTR("PullBuffer -- End   {%u frames produced, %u valid buffers}"), framesProduced, GetNumberOfValidBuffers());
#endif
}

#pragma mark _____ ZKMORPushBufferQueue
void	ZKMORPushBufferQueue::PushBuffer(UInt32 inNumberFrames, const AudioBufferList *inBufferList)
{
	UInt32 framesRequired = inNumberFrames;
	UInt32 framesProduced = 0;
	
	do {
		Buffer *b = mBufferQueue.WriteItem();
		if (NULL == b) {
			mUnderflowCount++;
			ZKMORLogError(kZKMORLogSource_Zone, CFSTR("DAC running faster than file writer thread"));
			MarkNeedsToRun();
			break;
		}
		
		if (b->CopyFrom(inBufferList, mBytesPerFrame, framesProduced, framesRequired)) {
			mBufferQueue.AdvanceWritePtr();
			// buffer was filled, see if it's time to run the worker thread
			if (GetNumberOfValidBuffers() >= mValidBufferThreshold)
				MarkNeedsToRun();

		}
	} while (framesRequired > 0);
}

void	ZKMORPushBufferQueue::Flush()
{
	if (mBuffersAreValid) {
		if (mBufferQueue.ReadItem())
			RunIteration();
	}
}
