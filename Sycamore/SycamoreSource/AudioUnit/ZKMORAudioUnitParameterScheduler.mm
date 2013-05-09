//
//  ZKMORAudioUnitParameterScheduler.mm
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 17.05.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioUnitParameterScheduler.h"
#import "ZKMORException.h"
#import "ZKMORAudioUnit.h"
#include "CAAudioUnitZKM.h"
#include "CAAudioTimeStamp.h"
#import "ZKMORLogger.h"
#import "ZKMORUtilities.h"
#include "ZKMORGuardRT.h"
#include <map>

/// 
///  ZKMORAUParameterScheduler
///
///  Does the heavy lifting in the implementation of the AudioUnitParameterScheduler.
/// 
class ZKMORAUParameterScheduler {
//  CTOR / DTOR
public:
	ZKMORAUParameterScheduler(ZKMORAudioUnit* audioUnit);
	~ZKMORAUParameterScheduler();
	
//  Public Interface
	void	BeginScheduling();
	void	ScheduleParameterValue(AudioUnitParameterID parameter, AudioUnitScope scope, AudioUnitElement element,  float value, Float64 seconds);
	void	EndScheduling();
	
//  Internal Functions
	static void ParameterSchedPropertyListener(	void*						THIS,
												AudioUnit					ci, 
												AudioUnitPropertyID			inID, 
												AudioUnitScope				inScope, 
												AudioUnitElement			inElement);
	
	static OSStatus ParameterSchedRenderFunction(	void						* THIS,
													AudioUnitRenderActionFlags 	* ioActionFlags,
													const AudioTimeStamp 		* inTimeStamp,
													UInt32						inOutputBusNumber,
													UInt32						inNumberFrames,
													AudioBufferList				* ioData);
													
	OSStatus	ParameterSchedTick(		AudioUnitRenderActionFlags 	* ioActionFlags,
										const AudioTimeStamp 		* inTimeStamp,
										UInt32						inOutputBusNumber,
										UInt32						inNumberFrames,
										AudioBufferList				* ioData);


//  Internal Types
	typedef enum { kParameterEventState_Starting, kParameterEventState_Running, kParameterEventState_Finished } ParameterEventState;
	
	struct ParameterEvent {
		AudioUnitParameterID	mParameter;
		AudioUnitScope			mScope;
		AudioUnitElement		mElement;
		float					mValue;
		UInt32					mDurationInFrames;
		CAAudioUnitZKM*			mAudioUnit;
		
		bool					mCanRamp;
		ParameterEventState		mState;
		float					mStartValue;
		UInt32					mCurrentFrame;
		
		ParameterEvent() { }
		
		ParameterEvent(AudioUnitParameterID parameter, AudioUnitScope scope, AudioUnitElement element,  float value, UInt32 durInSamples, CAAudioUnitZKM* au) : mParameter(parameter), mScope(scope), mElement(element), mValue(value), mDurationInFrames(durInSamples), mAudioUnit(au), mState(kParameterEventState_Starting), mCurrentFrame(0)
		{
			AudioUnitParameterInfo parameterInfo;
			UInt32 size = sizeof(parameterInfo);
			OSStatus err = mAudioUnit->GetProperty(kAudioUnitProperty_ParameterInfo, mScope, mParameter, &parameterInfo, &size);
			if (err) {
				ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("Could not get can ramp %i"), err);
				mCanRamp = false;
			} else {
				mCanRamp = parameterInfo.flags & kAudioUnitParameterFlag_CanRamp;
			}
		}
		
		void RenderTick(UInt32 numberOfFrames);
		void RenderTickRamp(UInt32 numberOfFrames);
		void RenderTickNoRamp(UInt32 numberOfFrames);
	};

	typedef std::map<AudioUnitElement, ParameterEvent> EventMap;
	typedef std::map<AudioUnitParameterID, EventMap> ParameterMap;
	
//  Internal Functions
	void	ParameterSchedTickIterator(ParameterMap::iterator begin, ParameterMap::iterator end, UInt32 numberOfFrames);

//  Internal State
	ZKMORAudioUnit*			mAudioUnit;
	Float64					mSampleRate;
	ZKMORGuardRT			mGuardRT;
	
	ParameterMap			mGlobalEvents;
	ParameterMap			mInputEvents;
	ParameterMap			mOutputEvents;	
};

@implementation ZKMORAudioUnitParameterScheduler
- (void)dealloc 
{
	if (mParameterScheduler) delete mParameterScheduler;
	[super dealloc];
}

#pragma mark _____ Initializing
- (id)initWithConduit:(ZKMORAudioUnit *)audioUnit
{
	if (!(self = [super init])) return nil;
	
	mParameterScheduler = new ZKMORAUParameterScheduler(audioUnit);
	
	return self;
}

#pragma mark _____ Accessors
- (ZKMORAudioUnit *)audioUnit { return mParameterScheduler->mAudioUnit; }

#pragma mark _____ Actions
- (void)beginScheduling 
{ 
	// wait until we can take control of the scheduler
	mParameterScheduler->BeginScheduling();
}

- (void)scheduleParameter:(AudioUnitParameterID)parameter scope:(AudioUnitScope)scope element:(AudioUnitElement)element value:(float)value duration:(Float64)seconds
{
	mParameterScheduler->ScheduleParameterValue(parameter, scope, element, value, seconds);
}

- (void)endScheduling 
{ 
	// give up control of the scheduler
	mParameterScheduler->EndScheduling();	
}

@end


#pragma mark _____ CTOR / DTOR
ZKMORAUParameterScheduler::ZKMORAUParameterScheduler(ZKMORAudioUnit* audioUnit) : mAudioUnit(audioUnit)
{
	[mAudioUnit retain];
	ZKMORConduitBus* bus = nil;
	if ([mAudioUnit numberOfOutputBuses] > 0) bus = [mAudioUnit outputBusAtIndex: 0];
	if (!bus && ([mAudioUnit numberOfInputBuses] > 0)) bus = [mAudioUnit inputBusAtIndex: 0];

	mSampleRate = bus ? [bus sampleRate] : ZKMORDefaultSampleRate();
	[mAudioUnit caAudioUnit]->AddPropertyListener(kAudioUnitProperty_StreamFormat, ParameterSchedPropertyListener, this);
	[mAudioUnit caAudioUnit]->AddRenderNotify(ParameterSchedRenderFunction, this);
}
	
ZKMORAUParameterScheduler::~ZKMORAUParameterScheduler()
{
	[mAudioUnit caAudioUnit]->RemovePropertyListener(kAudioUnitProperty_StreamFormat, ParameterSchedPropertyListener);
	[mAudioUnit caAudioUnit]->RemoveRenderNotify(ParameterSchedRenderFunction, this);
	[mAudioUnit release];
}
	
#pragma mark _____ Public Interface
void	ZKMORAUParameterScheduler::BeginScheduling() 
{
	mGuardRT.LockNRT();
}

void  ZKMORAUParameterScheduler::ScheduleParameterValue(AudioUnitParameterID parameter, AudioUnitScope scope, AudioUnitElement element,  float value, Float64 duration)
{
	ParameterEvent event(parameter, scope, element, value, (UInt32) (duration * mSampleRate), [mAudioUnit caAudioUnit]);
	switch(scope) {
		case kAudioUnitScope_Global:
			mGlobalEvents[parameter][element] = event;
			break;
		case kAudioUnitScope_Input:
			mInputEvents[parameter][element] = event;
			break;
		case kAudioUnitScope_Output:
			mOutputEvents[parameter][element] = event;
			break;
	}
}

void	ZKMORAUParameterScheduler::EndScheduling() 
{ 
	mGuardRT.UnlockNRT();
}
	
#pragma mark _____ Internal Functions
void	ZKMORAUParameterScheduler::ParameterSchedPropertyListener(	void*						refCon,
																	AudioUnit					ci, 
																	AudioUnitPropertyID			inID, 
																	AudioUnitScope				inScope, 
																	AudioUnitElement			inElement)
{
	ZKMORAUParameterScheduler* THIS = (ZKMORAUParameterScheduler*) refCon;

	if (kAudioUnitProperty_StreamFormat == inID) {
		switch (inScope) {
			case kAudioUnitScope_Input: 
				THIS->mSampleRate = [[THIS->mAudioUnit inputBusAtIndex: inElement] sampleRate];
				break;
			case kAudioUnitScope_Output:
				THIS->mSampleRate  = [[THIS->mAudioUnit outputBusAtIndex: inElement] sampleRate];
				break;
		}
	}
}

OSStatus ZKMORAUParameterScheduler::ParameterSchedRenderFunction(	void						* refCon,
																	AudioUnitRenderActionFlags 	* ioActionFlags,
																	const AudioTimeStamp 		* inTimeStamp,
																	UInt32						inOutputBusNumber,
																	UInt32						inNumberFrames,
																	AudioBufferList				* ioData)
{
	ZKMORAUParameterScheduler* THIS = (ZKMORAUParameterScheduler*) refCon;

	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) 
		return THIS->ParameterSchedTick(ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
	
	return noErr;
}

OSStatus	ZKMORAUParameterScheduler::ParameterSchedTick(		AudioUnitRenderActionFlags 	* ioActionFlags,
																const AudioTimeStamp 		* inTimeStamp,
																UInt32						inOutputBusNumber,
																UInt32						inNumberFrames,
																AudioBufferList				* ioData)
{
	// the scheduler is being updated -- just skip
	if (!mGuardRT.LockRT()) return noErr;
	
	ParameterSchedTickIterator(mGlobalEvents.begin(), mGlobalEvents.end(), inNumberFrames);
	ParameterSchedTickIterator(mInputEvents.begin(), mInputEvents.end(), inNumberFrames);
	ParameterSchedTickIterator(mOutputEvents.begin(), mOutputEvents.end(), inNumberFrames);
	
	mGuardRT.UnlockRT();
	
	return noErr;
}

void		ZKMORAUParameterScheduler::ParameterSchedTickIterator(ParameterMap::iterator begin, ParameterMap::iterator end, UInt32 numberOfFrames)
{
/*
	ParameterMap::iterator scopeEvents;
	for (scopeEvents = begin; scopeEvents != end; ++scopeEvents) {
		EventMap* events = &((*scopeEvents).second);
		EventMap::iterator event;
		for(event = events->begin(); event != events->end(); ++event) {
			ParameterEvent* paramEvent = &((*event).second);
			paramEvent->RenderTick(numberOfFrames);
//			if (kParameterEventState_Finished == paramEvent->mState) events->erase(event);
		}
	}
*/

	ParameterMap::iterator scopeEvents;
	for (scopeEvents = begin; scopeEvents != end; ++scopeEvents) {
		EventMap* events = &((*scopeEvents).second);
		EventMap::iterator event;
		for(event = events->begin(); event != events->end(); ) {
			ParameterEvent* paramEvent = &((*event).second);
			paramEvent->RenderTick(numberOfFrames);
			if (kParameterEventState_Finished == paramEvent->mState) {
				// erasing invalidates the pointer, so we need to this as follows
				events->erase(event++);
			} else 
				++event;
		}
	}
}

void ZKMORAUParameterScheduler::ParameterEvent::RenderTick(UInt32 numberOfFrames) 
{ 
	if (kParameterEventState_Finished == mState) return;
	
	if (kParameterEventState_Starting == mState) {
		OSStatus err = mAudioUnit->GetParameter(mParameter, mScope, mElement, mStartValue);
		if (err) {
			char errStr[8];
			ZKMORFormatError(err, errStr);
			ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("GetParameter failed %u %u %u : %s"), mParameter, mScope, mElement, errStr);
		}
	}
	
	(mCanRamp) ? RenderTickRamp(numberOfFrames) : RenderTickNoRamp(numberOfFrames);
	
	mCurrentFrame += numberOfFrames;	

	mState = (mCurrentFrame >= mDurationInFrames) ? kParameterEventState_Finished : kParameterEventState_Running;
}

void ZKMORAUParameterScheduler::ParameterEvent::RenderTickRamp(UInt32 numberOfFrames)
{	
	AudioUnitParameterEvent event;
	event.scope = mScope;
	event.element = mElement;
	event.parameter = mParameter;
	event.eventType = kParameterEvent_Ramped;
	event.eventValues.ramp.startBufferOffset = mCurrentFrame * -1;
	event.eventValues.ramp.durationInFrames = mDurationInFrames;
		
	event.eventValues.ramp.startValue = mStartValue;
	event.eventValues.ramp.endValue = mValue;		
				
	OSStatus err = mAudioUnit->ScheduleParameterViaListener(&event, 1);
	if (err) {
		char errStr[8];
		ZKMORFormatError(err, errStr);
		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("GetParameter failed %u %u %u : %s"), mParameter, mScope, mElement, errStr);
	}
}

void ZKMORAUParameterScheduler::ParameterEvent::RenderTickNoRamp(UInt32 numberOfFrames)
{
	AudioUnitParameterEvent event;
	event.scope = mScope;
	event.element = mElement;
	event.parameter = mParameter;
	event.eventType = kParameterEvent_Immediate;
	event.eventValues.immediate.bufferOffset = 0;
	float percentDone = MIN(1.f, ((float) (mCurrentFrame + numberOfFrames)) / ((float) mDurationInFrames));
	event.eventValues.immediate.value = ZKMORInterpolateValue(mStartValue, mValue, percentDone);
	
	OSStatus err = mAudioUnit->ScheduleParameterViaListener(&event, 1);
	if (err) {
		char errStr[8];
		ZKMORFormatError(err, errStr);
		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("GetParameter failed %u %u %u : %s"), mParameter, mScope, mElement, errStr);
	}
}
