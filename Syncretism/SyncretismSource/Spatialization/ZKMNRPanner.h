//
//  ZKMNRPanner.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 06.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMNRPanner_h__
#define __ZKMNRPanner_h__

#import <Cocoa/Cocoa.h>
#import "ZKMNRCoordinates.h"
#import "ZKMNREventScheduler.h"



///
///  ZKMNRPannerSourceExpanding
///
///  The protocol for objects that want to see how a Panner Source gets expanded into points in space.
///
@class ZKMNRPannerSource;
@protocol ZKMNRPannerSourceExpanding
- (void)pannerSource:(ZKMNRPannerSource *)source spatialSampleAt:(ZKMNRRectangularCoordinate)center;
@end



///
///  ZKMNRVBAPPanner
///
///  A Vector-Based Amplitude Panner.
/// 
///  A panner takes a point on the surface of a 3-sphere and generates coefficients
///  for the Apple Matrix Mixer. The order of the output channels on the mixer need
///  to match the order of the speakers in the speaker layout.
///
///  This panner uses the the VBAP algorithm, see Pulkki, "Virtual Source Positioning Using VBAP" in the
///  Journal of the Audio Engineering Society, vol. 45 no. 6 1997.
///
///  The panner requires a mesh be generated from the speaker positions. We recommend using triangle to
///  for this task <http://www.cs.cmu.edu/~quake/triangle.html>.
///
///
@class ZKMNRPannerSource, ZKMNRSpeakerMeshElement, ZKMNRSpeakerLayout, ZKMNRSpeakerPosition, ZKMORMixerMatrix, ZKMORAudioUnitParameterScheduler;
@interface ZKMNRVBAPPanner : NSObject <ZKMNRTimeDependent, ZKMNRPannerSourceExpanding> {
	ZKMNRSpeakerLayout*		_speakerLayout;
	unsigned				_numberOfSpeakers;
	
		/// All the sources that are attached to a panner -- used only internally to
		/// notify sources of changes to the panner, because multiple documents may be
		/// attached one panner.
	NSMutableArray*			_registeredSources;
	
		/// The currently relevant sources. The graph must have the same number of input channels
		/// as there are active sources and they must be in the same order.
	NSMutableArray*			_activeSources;
	
		/// The Speaker Mesh is a decomposition of the speakers into subsets of speakers used
		/// for panning. In VBAP, the mesh is made up of sets of 2 or 3 speakers (2 speakers for
		/// a circle, 3 for a sphere).
	NSMutableArray*			_speakerMesh;
	
		/// The matrix mixer that implements the mixing for the spatialization.
	ZKMORMixerMatrix*					_mixer;
	ZKMORAudioUnitParameterScheduler*	_mixerParameterScheduler;
	
	unsigned				_debugLevel;
}

//  Accessors
- (ZKMNRSpeakerLayout *)speakerLayout;
- (void)setSpeakerLayout:(ZKMNRSpeakerLayout *)speakerLayout;

- (ZKMNRSpeakerPosition *)speakerClosestToPoint:(ZKMNRSphericalCoordinate)point;

	/// The mixer this panner controls. The user is responsible for keeping the number of inputs / outputs 
	/// in synch with the panner's number of sources / speaker layout.
- (ZKMORMixerMatrix *)mixer;
- (void)setMixer:(ZKMORMixerMatrix *)mixer;

- (NSArray *)speakerMesh;

//  Actions
	/// Transfers panning for all sources, whether or not they think they are synched
- (void)transferPanningToMixer;
	/// Transfers panning only for sources that are not synched
- (void)updatePanningToMixer;
	/// Smoothly transfers the panning over the time range
- (void)transferPanningToMixerOverTimeRange:(ZKMNREventTaskTimeRange *)timeRange;

@end

@interface ZKMNRVBAPPanner (ZKMNRVBAPPannerSpeakerMesh)
- (void)beginEditingSpeakerMesh;
- (void)addSpeakerMeshElement:(ZKMNRSpeakerMeshElement *)meshElement;
- (void)endEditingSpeakerMesh;
@end

@interface ZKMNRVBAPPanner (ZKMNRVBAPPannerSourceMagement)
- (void)registerPannerSource:(ZKMNRPannerSource *)source;
- (void)unregisterPannerSource:(ZKMNRPannerSource *)source;

- (NSArray *)activeSources;

- (void)beginEditingActiveSources;
- (void)setNumberOfActiveSources:(unsigned)numberOfSources;
- (void)setActiveSource:(ZKMNRPannerSource *)source atIndex:(unsigned)idx;
	// internally calls setNumberOfActiveSources: and setActiveSource
- (void)setActiveSources:(NSArray *)sources;
- (void)endEditingActiveSources;
@end

@interface ZKMNRVBAPPanner (ZKMNREventSchedulerDebugging)
- (unsigned)debugLevel;
	/// ZKMNREventDebugLevels may be or'd together for debugLevel
- (void)setDebugLevel:(unsigned)debugLevel;
@end



///
///  ZKMNRPannerSource
///
///  State for a virtual source in the panner.
///
@class ZKMNRPannerEvent;
@interface ZKMNRPannerSource : NSObject <ZKMNRTimeDependent> {
	ZKMNRVBAPPanner*	_panner;
	BOOL				_isPlanar;
		/// The number of mixer coefficients is the same as the panner's 
		///	number of speakers.
	unsigned			_numberOfMixerCoefficients;
	float*				_mixerCoefficients;
	NSMutableSet*		_activeTriangles;
	
		// Initial Position State
	ZKMNRSphericalCoordinate		_initialCenter;
	ZKMNRSphericalCoordinateSpan	_initialSpan;
	float							_initialGain;
	BOOL							_isMute;
		
		// Position State
	ZKMNRSphericalCoordinate		_center;
	ZKMNRSphericalCoordinateSpan	_span;
	ZKMNRRectangularCoordinateSpan	_spanRect;
	float							_gain;
	BOOL							_isRectangular;

		// Scheduler State
	ZKMNRPannerEvent*				_activePannerEvent;
	
	id								_tag;				///< a way to identify the panner source
	
		// Mixer <-> Source synch state
	BOOL							_isSynchedWithMixer;
}

//  Accessors
- (ZKMNRSphericalCoordinate)initialCenter;
- (void)setInitialCenter:(ZKMNRSphericalCoordinate)initialCenter;

- (ZKMNRSphericalCoordinateSpan)initialSpan;
- (void)setInitialSpan:(ZKMNRSphericalCoordinateSpan)initialSpan;

- (float)initialGain;
- (void)setInitialGain:(float)initialGain; 

- (void)setInitialCenter:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain;

- (ZKMNRSphericalCoordinate)center;
- (void)setCenter:(ZKMNRSphericalCoordinate)center;

- (ZKMNRSphericalCoordinateSpan)span;
- (void)setSpan:(ZKMNRSphericalCoordinateSpan)span;

- (ZKMNRRectangularCoordinateSpan)spanRectangular;

- (float)gain;
- (void)setGain:(float)gain;

- (BOOL)isMute;
- (void)setMute:(BOOL)isMute;

- (void)setCenter:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain;

- (void)setCenterRectangular:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain;

- (unsigned)numberOfMixerCoefficients;
- (float *)mixerCoefficients;

- (NSMutableSet *)activeTriangles;

- (id)tag;
- (void)setTag:(id)tag;

//  Actions
- (void)moveToInitialPosition;
	/// Runs the same algorithm the panner sources uses to generate virtual sources from the center/span information and
	/// calls the evaluator.
- (void)expandFor:(id <ZKMNRPannerSourceExpanding>)evaluator useInitial:(BOOL)useInitial;

//  Queries
	/// return false if the source position has been modified since the last synch
- (BOOL)isSynchedWithMixer;
	/// used internally, other can also use to force an update
- (void)setSynchedWithMixer:(BOOL)isSynchedWithMixer;

@end

@interface ZKMNRPannerSource (ZKMNRPannerPositionInternal)
- (void)privateSetPanner:(ZKMNRVBAPPanner *)panner;
- (void)speakerLayoutChanged;
- (float)pannerGain; ///< this should always be 1.f
@end


///
///  ZKMNRSpeakerMeshElement
/// 
///  An element in the tessellation of the speaker positions array.
///
@interface ZKMNRSpeakerMeshElement : NSObject {
		// an array of ZKMNRSpeakerPosition
	NSMutableArray*		_speakers;
	unsigned			_numberOfSpeakers;
	
		// true if the speaker matrix is invertable
	BOOL				_isInvertable;
	
		// storage for the matrix of speaker positions
	float*				_A;
	unsigned			_byteSizeOfA;

		// LU Decomposition of the speaker position matrix
	float*				_LU;
	long int			_pivots[3];
}

//  Accessors
	/// count may be two or three speakers, depending on the speaker layout
- (NSArray *)speakers;
- (unsigned)numberOfSpeakers;


	/// coeffs should have the same size as the number of speakers (2 or 3)
	/// The position should be on the unit sphere.
- (void)getCoeffs:(float *)coeffs atPosition:(ZKMNRRectangularCoordinate)pos;

//  Queries
	/// If the mesh element is non-invertable, it won't be very useful.
	/// After generating a mesh, check that all elements are invertable and
	/// throw an error otherwise.
- (BOOL)isInvertable;

//  Computations
- (float)perimeter;
- (float)area;

@end

#endif
