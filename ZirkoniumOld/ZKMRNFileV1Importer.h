//
//  ZKMRNFileV1Importer.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 06.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

///  
///  ZKMRNFileV1Importer
///  
///  A class that read the old Zirkonium (v1) file format
///  
@class ZKMRNPieceDocument;
@interface ZKMRNFileV1Importer : NSObject {

}

///  Singleton
+ (ZKMRNFileV1Importer *)sharedFileImporter;


//  Actions

///  Open a file dialog and import the selected file
- (void)run;

///  Do an import
- (void)importPath:(NSString *)path intoDocument:(ZKMRNPieceDocument *)document;

@end



///  
///  ZKMRNFileV1Event
///  
///  The old v1 ZKMNREvent
///  
@interface ZKMRNFileV1Event : NSObject <NSCoding> {
	Float64		startTime, duration;
}

- (void)dumpToConsole:(int)indent;
- (void)setUpImportIntoDocument:(ZKMRNPieceDocument *)document;
- (void)importIntoDocument:(ZKMRNPieceDocument *)document;
- (NSComparisonResult)compare:(ZKMRNFileV1Event *)otherEvent;

@end

///  
///  ZKMRNFileV1Timeline
///  
///  The old v1 ZKMNRTimeline
///  
@interface ZKMRNFileV1Timeline : ZKMRNFileV1Event {
	NSArray*	tracks;
}

@end

///  
///  ZKMRNFileV1TimelineTrack
///  
///  The old v1 ZKMNRTimelineTrack
///  
@interface ZKMRNFileV1TimelineTrack : ZKMRNFileV1Event {
	NSArray*	events;
		// created during set-up import
	NSMutableArray*		ids;
}

- (NSArray *)ids;

@end

///  
///  ZKMRNFileV1SpatializedTimeline
///  
///  The old v1 ZKMNRSpatializedTimeline
///  
@interface ZKMRNFileV1SpatializedTimeline : ZKMRNFileV1Timeline {

}

@end

///  
///  ZKMRNFileV1InputEvent
///  
///  The old v1 ZKMNRAudioInputEvent and ZKMNRJackInputEvent
///  
@interface ZKMRNFileV1InputEvent : ZKMRNFileV1Event {
	int		numberOfOutputChannels;
}

@end

///  
///  ZKMRNFileV1FileReaderEvent
///  
///  The old v1 ZKMNRFileReaderEvent and ZKMNRSchedulableFileReader
///  
@interface ZKMRNFileV1FileReaderEvent : ZKMRNFileV1Event {
	NSURL*	pathURL;
}

@end

///  
///  ZKMRNFileV1PannerEvent
///  
///  The old v1 ZKMNRPannerEvent
///  
@interface ZKMRNFileV1PannerEvent : ZKMRNFileV1Event {
	ZKMRNFileV1TimelineTrack*		_track;
	unsigned						_channel;

	ZKMNRSphericalCoordinate		_startPoint;
	ZKMNRSphericalCoordinateSpan	_startSpan;
	float							_startGain;
	ZKMNRSphericalCoordinate		_endPoint;
	ZKMNRSphericalCoordinateSpan	_endSpan;
	float							_endGain;
	
	ZKMNRSphericalCoordinate		_prevEndPoint;
	BOOL							_hasPrevEndPoint;
}

- (void)takePrevEndPointFrom:(NSArray *)events index:(unsigned)index;

@end
