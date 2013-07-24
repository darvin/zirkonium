//
//  ZKMRNSpatialChordController.m
//  Zirkonium
//
//  Created by R. Chandrasekhar on 7/23/13.
//
//

#import "ZKMRNSpatialChordController.h"
#import "ZKMRNPieceDocument.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNGraphChannel.h"
#import <Syncretism/Syncretism.h>

@implementation ZKMRNSpatialChordController

- (void)dealloc
{
	[_chordSources release], _chordSources = nil;
	[_nonChordSources release], _nonChordSources = nil;
	[super dealloc];
}

- (id)initWithPieceDocument:(ZKMRNPieceDocument *)pieceDocument
{
    if (!(self = [super init])) return nil;
    
	_pieceDocument = pieceDocument;
	_chordSources = [[NSMutableArray alloc] init];
	_nonChordSources = [[NSMutableArray alloc] init];

    return self;
}

- (NSUInteger)chordNumberOfPoints { return _chordNumberOfPoints; }
- (void)setChordNumberOfPoints:(NSUInteger)chordNumberOfPoints { _chordNumberOfPoints = chordNumberOfPoints; }
- (float)chordSpacing { return _chordSpacing; }
- (void)setChordSpacing:(float)chordSpacing { _chordSpacing = chordSpacing; }
- (float)chordTransitionTime { return _chordTransitionTime; }
- (void)setChordTransitionTime:(float)chordTransitionTime { _chordTransitionTime = chordTransitionTime; }

- (void)updateChordSources
{
	[_chordSources removeAllObjects];
	[_nonChordSources removeAllObjects];
	[_nonChordSources addObjectsFromArray: [_pieceDocument orderedGraphChannels]];
	// Return an array with _chordNumberOfPoints sources
	NSUInteger i, count = MIN(_chordNumberOfPoints, [_nonChordSources count]);
	for (i = 0; i < count; ++i) {
		NSUInteger index = floorf([_nonChordSources count] * ZKMORFRand());
		index = MIN(index, count - 1);
		id source = [_nonChordSources objectAtIndex: index];
		[_chordSources addObject: source];
		[_nonChordSources removeObjectAtIndex: index];
	}
}

- (void)startChord
{
	ZKMNREventScheduler* scheduler = [[ZKMRNZirkoniumSystem sharedZirkoniumSystem] scheduler];
	[scheduler unscheduleAllEvents];
	
	float azimuth = ZKMORFRand() * 2.f;
	float zenith = ZKMORFRand();
	
	[self updateChordSources];
	unsigned i, count = [_chordSources count];
	for (i = 0; i < count; ++i) {
		ZKMNRPannerSource *pannerSource = [[_chordSources objectAtIndex: i] pannerSource];
		if ([pannerSource isMute]) {
			[pannerSource setGain: 0.0f];
			[pannerSource setMute: NO];
		}
		ZKMNRSphericalCoordinate center = [pannerSource center];
		ZKMNRPannerEvent *pannerEvent = [[ZKMNRPannerEvent alloc] init];
		[pannerEvent setStartTime: [[_pieceDocument timeWatch] currentTime]];
		[pannerEvent setDuration: _chordTransitionTime];
		[pannerEvent setDeltaAzimuth: (azimuth - center.azimuth) + (ZKMORFRand() * 2.f * _chordSpacing)];
		[pannerEvent setDeltaZenith: (zenith - center.zenith) + (ZKMORFRand() * _chordSpacing)];
		[pannerEvent setAzimuthSpan: 0.0f];
		[pannerEvent setZenithSpan: 0.0f];
		[pannerEvent setGain: 1.0f];
		[pannerEvent setTarget: pannerSource];
		[scheduler scheduleEvent: pannerEvent];
		[pannerEvent release];
	}
	
	// Fade out the sources that are not part of the chord
	count = [_nonChordSources count];
	for (i = 0; i < count; ++i) {
		ZKMNRPannerSource *pannerSource = [[_nonChordSources objectAtIndex: i] pannerSource];
		ZKMNRPannerEvent *pannerEvent = [[ZKMNRPannerEvent alloc] init];
		[pannerEvent setStartTime: [[_pieceDocument timeWatch] currentTime]];
		[pannerEvent setDuration: _chordTransitionTime];
		[pannerEvent setGain: 0.0f];
		[pannerEvent setTarget: pannerSource];
		[scheduler scheduleEvent: pannerEvent];
		[pannerEvent release];
	}	
}

@end
