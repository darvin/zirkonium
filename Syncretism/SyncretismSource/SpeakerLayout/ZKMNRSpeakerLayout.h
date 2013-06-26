//
//  ZKMNRSpeakerLayout.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 24.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRCoordinates.h"

///
///  ZKMNRSpeakerPosition
/// 
///  The speaker layout is modeled as a series of rings
///  that have the same height. Each speaker has a physical coordinate
///  and a Platonic coordinate. The physical coordinate is where the
///  speaker actually is, the Platonic coordinate is where the speaker
///  is located for the panning model. Platonic coordinates always lie
///  on the surface of the sphere r = 1. (Thus mRadius is always 1)
///
///  Speaker Positions are ordered by their Platonic positions, in ascending ring number, followed by
///	 descending azimuth order, followed by ascending zenith order. 
///  The reason for this, is we want the speakers ordered ascending clockwise (as is typical with panners),
///  but the canonical Euclidian coordinate system has positive angles being counter-clockwise.
///
@interface ZKMNRSpeakerPosition : NSObject <NSCoding> {
	int							_ringNumber;		///< the ring this speaker is in
	int							_layoutIndex;		///< the index in the layout of the speaker
	ZKMNRSphericalCoordinate	_coordPlatonic;		///< the Platonic coordinate of the speaker (see above)	
	ZKMNRSphericalCoordinate	_coordPhysical;		///< the coordinate of the speaker
	ZKMNRRectangularCoordinate	_coordRectangular;	///< the coordinate of the speaker, rectangular
	id							_tag;				///< a way to identify the speaker position
}

//  Accessors
- (int)ringNumber;		///< a negative ring number means this object is not yet initialized
- (int)layoutIndex;		///< a negative layout index means this object is not yet initialized

- (ZKMNRSphericalCoordinate)coordPlatonic;
- (void)setCoordPlatonic:(ZKMNRSphericalCoordinate)coordPlatonic;

- (ZKMNRSphericalCoordinate)coordPhysical;
- (void)setCoordPhysical:(ZKMNRSphericalCoordinate)coordPhysical;			///< changes coord rectangular as well

- (ZKMNRRectangularCoordinate)coordRectangular;
- (void)setCoordRectangular:(ZKMNRRectangularCoordinate)coordRectangular;	///< changes coord rectangular as well

- (id)tag;
- (void)setTag:(id)tag;

//  Actions
- (void)computeCoordPlatonicFromPhysical;

//  Serialization
- (NSDictionary *)dictionaryRepresentation;
- (void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;

//  Comparison
- (NSComparisonResult)compare:(ZKMNRSpeakerPosition *)otherPosition;

@end

///
///  ZKMNRSpeakerPosition (ZKMNRSpeakerPositionInternal)
/// 
///  Internal methods on a ZKMNRSpeakerPosition. You shouldn't need to call
///  these directly, but subclassers may want to override.
///
@interface ZKMNRSpeakerPosition (ZKMNRSpeakerPositionInternal)

- (void)setRingNumber:(unsigned)ringNumber;
- (void)setLayoutIndex:(unsigned)layoutIndex;

@end

///
///  ZKMNRSpeakerLayout
/// 
///  This is similar to an AudioChannelLayout, but it
///  has no concept of channels -- it just captures the
///  positions of the loudspeakers.
///
///  The speakers are ordered based on ascending ring number
///  and ascending azimuth.
///
///  Thus, the first speaker is the lowest speaker either directly
///  behind (left of directly behind, if there is no speaker
///  directly behind) the origin.
///
@interface ZKMNRSpeakerLayout : NSObject <NSCoding> {
	NSString*			_speakerLayoutName;
	NSMutableArray*		_speakerPositionRings;
	NSMutableArray*		_speakerPositions;
	NSMutableArray*		_numberOfSpeakersPerRing;
	BOOL				_isMutable;
}

//  Accessors
- (NSString *)speakerLayoutName;
- (void)setSpeakerLayoutName:(NSString *)speakerLayoutName;

- (NSArray *)speakerPositionRings;		///< An array of arrays of speaker positions, each array being one "ring"
- (void)setSpeakerPositionRings:(NSArray *)speakerPositionRings;

- (NSArray *)speakerPositions;			///< An array of speaker positions absolutely ordered as described above

- (NSArray *)numberOfSpeakersPerRing;	///< An array of NSNumber, each number being the number of speakers in that ring

- (unsigned)numberOfRings;
- (unsigned)numberOfSpeakers;

//  Serialization
- (NSDictionary *)dictionaryRepresentation;
- (void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;

//  Queries
	// Are all the speakers in one plane?
- (BOOL)isPlanar;
	// Are some speakers below z=0?
- (BOOL)hasBottomHemisphere;

@end

///
///  ZKMNRSpeakerLayoutEditing
///
///  Methods for editing a speaker layout. This is in many cases easier to use than creating
///  all the position rings directly.
///
@interface ZKMNRSpeakerLayout (ZKMNRSpeakerLayoutEditing)

//  Editing Boundry
	/// call before starting to edit. Call this only once -- it clears existing state.
- (void)beginEditing;
	/// call when finished editing. Makes all the changes happen.
- (void)endEditing;

//  Editing
- (void)setNumberOfRings:(unsigned)numberOfRings;
- (NSMutableArray *)ringAtIndex:(unsigned)idx;

@end
