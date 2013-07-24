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

	NSUInteger	_chordNumberOfPoints;
	float		_chordSpacing;
	float		_chordTransitionTime;
	
	// State that is updated for each chord
	NSMutableArray *_chordSources;
	NSMutableArray *_nonChordSources;
}

- (id)initWithPieceDocument:(ZKMRNPieceDocument *)pieceDocument;

- (NSUInteger)chordNumberOfPoints;
- (void)setChordNumberOfPoints:(NSUInteger)chordNumberOfPoints;
- (float)chordSpacing;
- (void)setChordSpacing:(float)chordSpacing;
- (float)chordTransitionTime;
- (void)setChordTransitionTime:(float)chordTransitionTime;

- (void)startChord;

@end
