//
//  ZKMORQuickTime.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 15.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORQuickTime_h__
#define __ZKMORQuickTime_h__

#import "ZKMORConduit.h"
#import "ZKMOROutput.h"
#import <QTKit/QTKit.h>

ZKMDECLCPPT(ZKMQTReader)
ZKMDECLCPPT(CAAudioUnitZKM)

@interface ZKMORQTPlayer : ZKMORConduit <ZKMORStarting> {
	// mQTReader, mFormatConverter, and _sentEndNotification declared public so they can be
	// directly accessed in the render thread
@public
	ZKMCPPT(ZKMQTReader)	mQTReader;
	ZKMCPPT(CAAudioUnitZKM) mFormatConverter;
	BOOL					_sentEndNotification;

@protected	
	NSURL*				_fileURL;
	id					_delegate;
}

//  Initialization
	/// defaults to 8 buffers of 1920 frames
- (id)initWithNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers size:(unsigned)numberOfFrames;

//  Accessors
- (QTMovie *)qtMovie;
- (QTTime)movieDuration;

- (NSURL *)fileURL;
- (void)setFileURL:(NSURL *)fileURL error:(NSError **)error;
- (void)setFilePath:(NSString *)path error:(NSError **)error;

- (QTTime)currentTime;
- (void)setCurrentTime:(QTTime)time;

- (double)currentPosition;
- (void)setCurrentPosition:(double)position;

- (id)delegate;
	/// Delegate will receive the methods defined in ZKMORQTReaderDelegate
- (void)setDelegate:(id)delegate;

//  QT Reader Properties
	/// number of internal buffers used for buffering data from the disk
- (unsigned)numberOfInternalBuffers;
	/// change the number of internal buffers used. Destroys any data in the existing sample buffer
- (void)setNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers;
	/// size in frames of each of the internal buffers used for buffering data from the disk
- (unsigned)internalBufferSize;
	/// change the size in frames of each of the internal buffers. Destroys any data in the existing sample buffer.
- (void)setInternalBufferSize:(unsigned)numberOfFrames;

//  Accessing Video
	/// If you want to video, you need to call this method.
	/// To get at the video frames use the usual QT functions:
	///   QTVisualContextIsNewImageAvailable, CVOpenGLTextureRelease, QTVisualContextCopyImageForTime
- (void)setVisualContext:(QTVisualContextRef)visualContext;

@end

@interface NSObject (ZKMORQTPlayerDelegate)

- (void)qtReaderDidEnd:(ZKMORQTPlayer *)player;

@end

#endif __ZKMORQuickTime_h__