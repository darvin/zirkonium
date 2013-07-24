//
//  ZKMRNSpatialChordController.h
//  Zirkonium
//
//  Created by R. Chandrasekhar on 7/23/13.
//
//

#import <Foundation/Foundation.h>

@class ZKMRNPieceDocument;
///
///  ZKMRNSpatialChordController
///
///  An object that manages spatial chords in Zirkonium
///
@interface ZKMRNSpatialChordController : NSObject {
	
	ZKMRNPieceDocument *_pieceDocument;

	// Chord
	NSUInteger	_chordNumberOfPoints;
	float		_chordSpacing;
	float		_chordTransitionTime;
	
	// Rotation
	float		_chordRotationSpeed;
	float		_chordRotationTilt;
	
	// Tilt
	float		_chordTiltAzimuth;
	float		_chordTiltZenith;
	
	// State that is updated for each chord
	NSMutableArray *_chordSources;
	NSMutableArray *_nonChordSources;
}

- (id)initWithPieceDocument:(ZKMRNPieceDocument *)pieceDocument;

// Chord
- (NSUInteger)chordNumberOfPoints;
- (void)setChordNumberOfPoints:(NSUInteger)chordNumberOfPoints;
- (float)chordSpacing;
- (void)setChordSpacing:(float)chordSpacing;
- (float)chordTransitionTime;
- (void)setChordTransitionTime:(float)chordTransitionTime;

// Rotation
@property(nonatomic) float chordRotationSpeed;
@property(nonatomic) float chordRotationTilt;

// Tilt
@property(nonatomic) float chordTiltAzimuth;
@property(nonatomic) float chordTiltZenith;

// Actions
- (void)startChord;
- (void)startRotation;

@end
