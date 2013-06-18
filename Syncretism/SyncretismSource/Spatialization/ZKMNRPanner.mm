//
//  ZKMNRPanner.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 06.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

// TetGen 
// A Quality Tetrahedral Mesh Generator and a 3D Delaunay Triangulator
//
// Hang Si
// Research Group: Numerical Mathematics and Scientific Computing
// Weierstrass Institute for Applied Analysis and Stochastics (WIAS)
// Mohrenstr. 39, 10117 Berlin, Germany
// si(at)wias-berlin.de


#import "ZKMNRPanner.h"
#import "ZKMNRSpeakerLayout.h"
#import "ZKMORLogger.h"
#import "ZKMORMixerMatrix.h"
//#import "triangle.h"
#import "ZKMNRLinearAlgebra.h"
#define TETLIBRARY
#import "tetgen.h"
#import "ZKMNRPannerEvent.h"
#import "ZKMORUtilities.h"
#import "ZKMORAudioUnitParameterScheduler.h"

@interface ZKMNRVBAPPanner (ZKMNRVBAPPannerPrivate)

- (void)speakerLayoutChanged;
- (void)computeSpeakerMesh;
- (void)compute2DSpeakerMesh;
- (void)compute3DSpeakerMesh;

	// fills out the panner position (speakerPolytopes and mixerCoeffs)
	// this methods accumulates information and doesn't reset what may already be there
	// N.B. this takes a *rectangular coord* because that's what gets internally used by the
	// Linear Algebra routines.
- (void)accumulateMixerLevelsForSource:(ZKMNRPannerSource *)source atPoint:(ZKMNRRectangularCoordinate)rectCoord;
- (void)transferPanningForSource:(ZKMNRPannerSource *)source index:(unsigned)idx;
- (void)transferPanningForSource:(ZKMNRPannerSource *)source index:(unsigned)idx timeRange:(ZKMNREventTaskTimeRange *)timeRange;

@end

@interface ZKMNRPannerSource (ZKMNRPannerPositionPrivate)
- (void)privateNormalizeCoefficients;
- (void)privateExpandSphericalFor:(id <ZKMNRPannerSourceExpanding>)evaluator center:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span;
- (void)privateExpandRectangularFor:(id <ZKMNRPannerSourceExpanding>)evaluator center:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span;
@end

@interface ZKMNRSpeakerMeshElement (ZKMNRSpeakerMeshElementPrivate)

- (void)addSpeaker:(ZKMNRSpeakerPosition *)speaker;
	// makes internal calculations after a speaker position update
	// returns true if the speaker matrix is invertable, false otherwise
	// This method should only be called once during the life of a MeshElement
- (void)initializeAfterSpeakerPositionsUpdate;

@end

@implementation ZKMNRVBAPPanner

#pragma mark _____ NSObject overrides
- (void)dealloc
{
	if (_mixerParameterScheduler) [_mixerParameterScheduler release];
	[self setSpeakerLayout: nil];
	if (_activeSources) [_activeSources release];	
	unsigned i, count = [_registeredSources count];
	for (i = 0; i < count; i++) [self unregisterPannerSource: [_registeredSources objectAtIndex: i]];
	if (_speakerMesh) [_speakerMesh release];
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	_registeredSources = [[NSMutableArray alloc] init];
	_activeSources = [[NSMutableArray alloc] init];
	_speakerMesh = [[NSMutableArray alloc] init];
	_speakerLayout = nil;
	_mixerParameterScheduler = nil;
	
	return self;
}

#pragma mark _____ Accessors
- (ZKMNRSpeakerLayout *)speakerLayout { return _speakerLayout; }
- (void)setSpeakerLayout:(ZKMNRSpeakerLayout *)speakerLayout
{
	if (speakerLayout == _speakerLayout) return;
	if (_speakerLayout) [_speakerLayout release], _speakerLayout = nil;
	if (!speakerLayout) return;
	_speakerLayout = [speakerLayout retain];
	[self speakerLayoutChanged];
}

- (ZKMNRSpeakerPosition *)speakerClosestToPoint:(ZKMNRSphericalCoordinate)point
{
	CFArrayRef speakerMesh = (CFArrayRef) _speakerMesh;
	ZKMNRRectangularCoordinate rectCoord = ZKMNRSphericalCoordinateToRectangular(point);
	
	float coeffs[3];
	unsigned i, count = CFArrayGetCount(speakerMesh);
	for (i = 0; i < count; ++i) {
		ZKMNRSpeakerMeshElement* meshElement = (ZKMNRSpeakerMeshElement*) CFArrayGetValueAtIndex(speakerMesh, i);
		[meshElement getCoeffs: coeffs atPosition: rectCoord];
		if (IsNonNegative(coeffs[0]) && IsNonNegative(coeffs[1]) && IsNonNegative(coeffs[2]))
		{
			unsigned j, speakerIndex = 0;
			float maxCoeff = 0.f;
			for (j = 0; j < 3; ++j) {
				if (coeffs[j] > maxCoeff) speakerIndex = j, maxCoeff = coeffs[j];
			}
			return [[meshElement speakers] objectAtIndex: speakerIndex];
		}
	}
	return nil;
}

- (ZKMORMixerMatrix *)mixer { return _mixer; }
- (void)setMixer:(ZKMORMixerMatrix *)mixer 
{ 
	_mixer = mixer;
	if (_mixerParameterScheduler) [_mixerParameterScheduler release];
	_mixerParameterScheduler = [[ZKMORAudioUnitParameterScheduler alloc] initWithConduit: _mixer];
}

- (NSArray *)speakerMesh { return _speakerMesh; }

#pragma mark _____ Actions
- (void)transferPanningToMixer
{
	// The fast way to implement this would be store the entire matrix in an array
	// and set the mixer's matrix using the array...
	unsigned i, numberOfSources = [_activeSources count];
	NSNull* globalNull = [NSNull null];
	for (i = 0; i < numberOfSources; i++) {
		if (globalNull == [_activeSources objectAtIndex: i]) continue;
		ZKMNRPannerSource* source = [_activeSources objectAtIndex: i];
		[self transferPanningForSource: source index: i];
	}
}

- (void)updatePanningToMixer
{
	// The fast way to implement this would be store the entire matrix in an array
	// and set the mixer's matrix using the array...
	unsigned i, numberOfSources = [_activeSources count];
	NSNull* globalNull = [NSNull null];
	for (i = 0; i < numberOfSources; i++) {
		if (globalNull == [_activeSources objectAtIndex: i]) continue;
		ZKMNRPannerSource* source = [_activeSources objectAtIndex: i];
		if ([source isSynchedWithMixer]) continue;
		[self transferPanningForSource: source index: i];
	}
}

- (void)transferPanningToMixerOverTimeRange:(ZKMNREventTaskTimeRange *)timeRange
{
	[_mixerParameterScheduler beginScheduling];
	// The fast way to implement this would be store the entire matrix in an array
	// and set the mixer's matrix using the array...
	unsigned i, numberOfSources = [_activeSources count];
	NSNull* globalNull = [NSNull null];
	for (i = 0; i < numberOfSources; i++) {
		if (globalNull == [_activeSources objectAtIndex: i]) continue;
		ZKMNRPannerSource* source = [_activeSources objectAtIndex: i];
		[self transferPanningForSource: source index: i timeRange: timeRange];
	}
	[_mixerParameterScheduler endScheduling];
}

#pragma mark _____ ZKMNRVBAPPannerSpeakerMesh
- (void)beginEditingSpeakerMesh { [_speakerMesh removeAllObjects]; }
- (void)addSpeakerMeshElement:(ZKMNRSpeakerMeshElement *)meshElement { [_speakerMesh addObject: meshElement]; }
- (void)endEditingSpeakerMesh { }

#pragma mark _____ ZKMNRVBAPPannerSourceMagement 
- (void)registerPannerSource:(ZKMNRPannerSource *)source 
{
	[source privateSetPanner: self];
	[_registeredSources addObject: source];
}

- (void)unregisterPannerSource:(ZKMNRPannerSource *)source 
{
	[source privateSetPanner: nil];
	[_registeredSources removeObject: source];
}

- (NSArray *)activeSources { return _activeSources; }
- (void)beginEditingActiveSources { [_activeSources removeAllObjects]; }
- (void)setNumberOfActiveSources:(unsigned)numberOfSources 
{ 
	unsigned i;
		// initialize the array
	for (i = 0; i < numberOfSources; i++) [_activeSources addObject: [NSNull null]];
}
- (void)setActiveSource:(ZKMNRPannerSource *)source atIndex:(unsigned)idx { [_activeSources replaceObjectAtIndex: idx withObject: source]; }

- (void)setActiveSources:(NSArray *)sources
{
	unsigned i, count = [sources count];
	[self beginEditingActiveSources];
		[self setNumberOfActiveSources: count];
		for (i = 0; i < count; i++) {
			ZKMNRPannerSource* source = [sources objectAtIndex: i];
			[self setActiveSource: source atIndex: i];
		}
	[self endEditingActiveSources];
}

- (void)endEditingActiveSources { [self transferPanningToMixer]; }

#pragma mark _____ ZKMNRTimeDependent
- (void)acceptEvent:(ZKMNREvent *)event time:(Float64)now { }

- (void)task:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler
{	
// used to use NSEnumerator, but re-written to avoid allocating objects to make more realtime friendly.
//	NSEnumerator* sources = [_activeSources objectEnumerator];
//	ZKMNRPannerSource* source;
//	while (source = [sources nextObject]) [source task: timeRange scheduler: scheduler];
	unsigned i, count = [_activeSources count];
	for (i = 0; i < count; i++) 
		[[_activeSources objectAtIndex: i] task: timeRange scheduler: scheduler];
	
	[self transferPanningToMixerOverTimeRange: timeRange];
}

- (void)scrub:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler
{
	[self task: timeRange scheduler: scheduler];
}

#pragma mark _____ ZKMNREventSchedulerDebugging
- (unsigned)debugLevel { return _debugLevel; }
- (void)setDebugLevel:(unsigned)debugLevel { _debugLevel = debugLevel; }

#pragma mark _____ ZKMNRVBAPPannerPrivate
- (void)speakerLayoutChanged
{
	_numberOfSpeakers = [_speakerLayout numberOfSpeakers];
	if(_numberOfSpeakers < 1) {
		[self beginEditingSpeakerMesh];
		[self endEditingSpeakerMesh];
		return;
	}
	
	// TODO -- check if one the speakers in a higher ring is outside the convex hull of the lower rings and move the speaker to be inside.
	[self computeSpeakerMesh];
	NSEnumerator* sources = [_registeredSources objectEnumerator];
	ZKMNRPannerSource* source;
	while (source = [sources nextObject])
		[source speakerLayoutChanged];
}

- (void)computeSpeakerMesh
{
	[self beginEditingSpeakerMesh];
		if (nil == _speakerLayout) {
			[self endEditingSpeakerMesh]; return;
		}
		([_speakerLayout isPlanar]) ? [self compute2DSpeakerMesh] : [self compute3DSpeakerMesh];
	[self endEditingSpeakerMesh];
}

- (void)compute2DSpeakerMesh
{	
	// 2D Groups are just made up of adjacent speakers
	// The speakers are already organized in clockwise, adjacent order
	NSArray* speakerPositions = [_speakerLayout speakerPositions];
	unsigned i, count = [speakerPositions count];
	
	// the first group is the first and last speaker together
	ZKMNRSpeakerMeshElement* meshElement = [[ZKMNRSpeakerMeshElement alloc] init];
	[meshElement addSpeaker: [speakerPositions objectAtIndex: 0]];
	[meshElement addSpeaker: [speakerPositions objectAtIndex: count - 1]];
	[meshElement initializeAfterSpeakerPositionsUpdate];

	[self addSpeakerMeshElement: meshElement];
	[meshElement release];	
		
	for (i = 1; i < count; i++) {		
		meshElement = [[ZKMNRSpeakerMeshElement alloc] init];
		[meshElement addSpeaker: [speakerPositions objectAtIndex: i - 1]];
		[meshElement addSpeaker: [speakerPositions objectAtIndex: i]];
		[meshElement initializeAfterSpeakerPositionsUpdate];
		
		[self addSpeakerMeshElement: meshElement];
		[meshElement release];
	}
}

- (void)compute3DSpeakerMesh
{
	// call Triangle to generate a 3D speaker mesh
	// use the triangle to generate
	// a Delaunay triangulation of the speaker positions
	// (JB) changed to 3D Delaunay Triangulation ...
	
	NSArray* speakerPositions = [_speakerLayout speakerPositions];	
	unsigned i, speakerCount = [speakerPositions count];
	if(speakerCount <= 0) return; 

	tetgenio input, output;
	
	input.firstnumber = 1;
	input.numberofpoints = speakerCount; 
	input.pointlist = new REAL[input.numberofpoints * 3];
	
	// put the positions into the input array
	for (i = 0; i < speakerCount; i++) {
		ZKMNRRectangularCoordinate speakerPosition; 
		speakerPosition = ZKMNRSphericalCoordinateToRectangular([[speakerPositions objectAtIndex: i] coordPlatonic]);
	
		input.pointlist[3*i]	 = (REAL)(speakerPosition.x) + 0.5; 
		input.pointlist[3*i + 1] = (REAL)(speakerPosition.y) + 0.5; 
		input.pointlist[3*i + 2] = (REAL)(speakerPosition.z) + 0.5;
	}
	
	tetgenbehavior behavior;
	behavior.parse_commandline((char *)"Q");
	tetrahedralize(&behavior, &input, &output, NULL, NULL);
	
	unsigned numberOfTriangles = output.numberoftrifaces;
	
	int idx1, idx2, idx3;
	for (i = 0; i < numberOfTriangles; i++) {
		idx1 = output.trifacelist[3*i + 0]-1; 
		idx2 = output.trifacelist[3*i + 1]-1; 
		idx3 = output.trifacelist[3*i + 2]-1;
		
		
		ZKMNRSpeakerPosition* sp1 = [speakerPositions objectAtIndex: idx1];
		ZKMNRSpeakerPosition* sp2 = [speakerPositions objectAtIndex: idx2];
		ZKMNRSpeakerPosition* sp3 = [speakerPositions objectAtIndex: idx3];
		// see if triangle lies in one plane ...
		if([sp1 ringNumber]==[sp2 ringNumber] && [sp1 ringNumber]== [sp3 ringNumber]) {
			// ...and is at the base of the dome
			ZKMNRRectangularCoordinate coord1 = [sp1 coordRectangular];
			ZKMNRRectangularCoordinate coord2 = [sp2 coordRectangular];
			ZKMNRRectangularCoordinate coord3 = [sp3 coordRectangular];
			if (coord1.z == 0 && coord2.z == 0 && coord3.z == 0)
				continue;
		}
		
		ZKMNRSpeakerMeshElement* meshElement = [[ZKMNRSpeakerMeshElement alloc] init];
		[meshElement addSpeaker: [speakerPositions objectAtIndex: idx1]];
		[meshElement addSpeaker: [speakerPositions objectAtIndex: idx2]];
		[meshElement addSpeaker: [speakerPositions objectAtIndex: idx3]];
		[meshElement initializeAfterSpeakerPositionsUpdate];
		
		[_speakerMesh addObject: meshElement];
		[meshElement release];		
	}	
	
	// free memory ... all alocations will be freed by deletion of local tetgenio vars "input" and "output"
}

- (void)accumulateMixerLevelsForSource:(ZKMNRPannerSource *)source atPoint:(ZKMNRRectangularCoordinate)rectCoord
{
	unsigned	numberOfMixerCoefficients = [source numberOfMixerCoefficients];
	if (numberOfMixerCoefficients < _numberOfSpeakers) {
		ZKMORLogError(kZKMORLogSource_Panner, CFSTR("Panner Position stores only %u cofficients, but needs %u"), numberOfMixerCoefficients, _numberOfSpeakers);
		return;
	}
	
	float*		mixerCoefficients = [source mixerCoefficients];
	CFArrayRef speakerMesh = (CFArrayRef) _speakerMesh;
	CFMutableSetRef speakerPolytopes = (CFMutableSetRef) [source activeTriangles];
	unsigned i, count = CFArrayGetCount(speakerMesh);
	
	float coeffs[3];
	for (i = 0; i < count; i++) {
		ZKMNRSpeakerMeshElement* meshElement = (ZKMNRSpeakerMeshElement*) CFArrayGetValueAtIndex(speakerMesh,  i);
		[meshElement getCoeffs: coeffs atPosition: rectCoord];
		if (IsNonNegative(coeffs[0]) && IsNonNegative(coeffs[1]) && IsNonNegative(coeffs[2]))
		{
			CFSetAddValue(speakerPolytopes, meshElement);
			
			CFArrayRef speakers = (CFArrayRef) [meshElement speakers];
			unsigned j, meshElementCount = CFArrayGetCount(speakers);
			for (j = 0; j < meshElementCount; j++) {
				ZKMNRSpeakerPosition* speakerPos = [[meshElement speakers] objectAtIndex: j];
				unsigned speakerIndex = [speakerPos layoutIndex];
					// do the fabsf in case a -0.f gets through
				mixerCoefficients[speakerIndex] += fabsf(coeffs[j]);
			}
			return;
		}
	}
	
	ZKMORLogError(kZKMORLogSource_Panner, CFSTR("No Positive Coeffs for { %.2f, %.2f, %.2f }"), rectCoord.x, rectCoord.y, rectCoord.z);
	[_speakerLayout logAtLevel: kZKMORLogLevel_Error | kZKMORLogLevel_Continue source: kZKMORLogSource_Panner indent: 1];
		// try again and log the results
	for (i = 0; i < count; i++) {
		ZKMNRSpeakerMeshElement* meshElement = (ZKMNRSpeakerMeshElement*) CFArrayGetValueAtIndex(speakerMesh,  i);
		[meshElement getCoeffs: coeffs atPosition: rectCoord];
		ZKMORLogDebug(CFSTR("\t%.2i : %f, %f, %f"), i, coeffs[0], coeffs[1], coeffs[2]);
		[meshElement logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Panner indent: 2];		
	}
}

- (void)transferPanningForSource:(ZKMNRPannerSource *)source index:(unsigned)idx
{
	unsigned j, outputCount = _numberOfSpeakers;
	float* coeffs = [source mixerCoefficients];
	for (j = 0; j < outputCount; j++) {
		[_mixer setVolume: coeffs[j] forCrosspointInput: idx output: j];
	}
	[source setSynchedWithMixer: YES];
}

- (void)transferPanningForSource:(ZKMNRPannerSource *)source index:(unsigned)idx timeRange:(ZKMNREventTaskTimeRange *)timeRange
{
	unsigned j, outputCount = _numberOfSpeakers;
	float* coeffs = [source mixerCoefficients];
	for (j = 0; j < outputCount; j++) {
		UInt32 element = ElementForMatrixCrosspoint(idx, j);
		[_mixerParameterScheduler scheduleParameter: kMatrixMixerParam_Volume scope: kAudioUnitScope_Global element: element value: coeffs[j] duration: timeRange->duration];
	}
	[source setSynchedWithMixer: YES];
}

#pragma mark _____ ZKMNRPannerSourceExpanding
- (void)pannerSource:(ZKMNRPannerSource *)source spatialSampleAt:(ZKMNRRectangularCoordinate)center
{
	[self accumulateMixerLevelsForSource: source atPoint: center];
}

@end

@implementation ZKMNRPannerSource

#pragma mark _____ NSObject overrides
- (void)dealloc
{
	if (_panner) {
		[_panner unregisterPannerSource: self];
		_panner = nil;
	}
	if (_activeTriangles) [_activeTriangles release];
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
		
	_activeTriangles = [[NSMutableSet alloc] init];
	_initialCenter.azimuth = 0.f; _initialCenter.zenith = 0.f; _initialCenter.radius = 1.f;
	_initialSpan.azimuthSpan = 0.f; _initialSpan.zenithSpan = 0.f;
	_initialGain = 1.f;
	_center.azimuth = 0.f; _center.zenith = 0.f; _center.radius = 1.f;
	_span.azimuthSpan = 0.f; _span.zenithSpan = 0.f;
	_gain = 1.f;
	_tag = nil;
	_isSynchedWithMixer = NO;
	_isMute = NO;
	
	return self;
}

#pragma mark _____ Accessors
- (ZKMNRSphericalCoordinate)initialCenter { return _initialCenter; }
- (void)setInitialCenter:(ZKMNRSphericalCoordinate)initialCenter { _initialCenter = initialCenter; }

- (ZKMNRSphericalCoordinateSpan)initialSpan { return _initialSpan; }
- (void)setInitialSpan:(ZKMNRSphericalCoordinateSpan)initialSpan { _initialSpan = initialSpan; }

- (float)initialGain { return _initialGain; }
- (void)setInitialGain:(float)initialGain { _initialGain = initialGain; }

- (void)setInitialCenter:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain
{
	_initialCenter = center; _initialSpan = span; _initialGain = gain;
}

- (ZKMNRSphericalCoordinate)center { return _center; }
- (void)setCenter:(ZKMNRSphericalCoordinate)center { [self setCenter: center span: _span gain: _gain]; }
- (ZKMNRSphericalCoordinateSpan)span { return _span; }
- (void)setSpan:(ZKMNRSphericalCoordinateSpan)span { [self setCenter: _center span: span gain: _gain]; }
- (ZKMNRRectangularCoordinateSpan)spanRectangular
{
	ZKMNRRectangularCoordinateSpan spanRect = { 0.f, 0.f, 0.f };
	if (_isRectangular) 
		spanRect = _spanRect;
	return spanRect;
}

- (float)gain { return _gain; }
- (void)setGain:(float)gain { [self setCenter: _center span: _span gain: gain]; }
- (BOOL)isMute { return _isMute; }
- (void)setMute:(BOOL)isMute { _isMute = isMute; }
- (void)setCenter:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain
{
	// N.B. This method is very similar to the method setCenterRectangular. Changes made here may 
	// need to be made to there as well.
	_isRectangular = NO;
	
	// massage the incoming data
	span.azimuthSpan = ZKMORClamp(span.azimuthSpan, 0.f, 2.f);
	span.zenithSpan = ZKMORClamp(span.zenithSpan, 0.f, 0.5f);
	
	_center = center; _span = span; _gain = gain;
	memset(_mixerCoefficients, 0, _numberOfMixerCoefficients * sizeof(float));
	if (!_panner) return;
	
	
//	if (_isPlanar) center.zenith = 0.f, span.zenithSpan = 0.f;
	if (_isPlanar) 
	{
		// use the zenith to compute an azimuth span;
			// fold zenith to 0. <-> 0.5 and scale that to the range 0. <-> 2.0
		if (center.zenith > 0.f) {
			span.azimuthSpan = ZKMORFold0ToMax(center.zenith, 0.5f) * 4.f;
		}
		// set the zenith and zenith span to 0
		center.zenith = 0.f, span.zenithSpan = 0.f;
	}
	
	[self privateExpandSphericalFor: _panner center: center span: span];
	[self privateNormalizeCoefficients];
	
	_isSynchedWithMixer = NO;
}

- (void)setCenterRectangular:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain
{
	// N.B. This method is very similar to the method setCenter. Changes made here may 
	// need to be made to there as well.
	_isRectangular = YES;
	
	// massage the incoming data
	span.xSpan = ZKMORClamp(span.xSpan, 0.f, 2.f);
	span.ySpan = ZKMORClamp(span.ySpan, 0.f, 2.f);
	
//	_center = ZKMNRRectangularCoordinateToSpherical(center); _spanRect = span; _gain = gain;
	_center = ZKMNRPlanarCoordinateLiftedToSphere(center); _spanRect = span; _gain = gain;
	if (_isPlanar) 
	{
		// use the zenith to compute an azimuth span;
			// fold zenith to 0. <-> 0.5 and scale that to the range 0. <-> 1.0
		if (_center.zenith > 0.f) {
			span.xSpan = ZKMORFold0ToMax(_center.zenith, 0.5f) * 2.f;
			span.ySpan = ZKMORFold0ToMax(_center.zenith, 0.5f) * 2.f;
		}
	}
	
	memset(_mixerCoefficients, 0, _numberOfMixerCoefficients * sizeof(float));
	if (!_panner) return;

	[self privateExpandRectangularFor: _panner center: center span: span];
	[self privateNormalizeCoefficients];
	
	_isSynchedWithMixer = NO;
}

- (unsigned)numberOfMixerCoefficients { return _numberOfMixerCoefficients; }
- (float *)mixerCoefficients { return _mixerCoefficients; }
- (NSMutableSet *)activeTriangles { return _activeTriangles; }
- (id)tag { return _tag; }
- (void)setTag:(id)tag { _tag = tag; }
- (BOOL)isSynchedWithMixer { return _isSynchedWithMixer; }
- (void)setSynchedWithMixer:(BOOL)isSynchedWithMixer { _isSynchedWithMixer = isSynchedWithMixer; }

#pragma mark _____ Actions
- (void)moveToInitialPosition 
{
	// move to the initial position;
	
	[self acceptEvent: nil time: 0];
	[self setCenter: _initialCenter span: _initialSpan gain: _initialGain]; 
}

- (void)expandSphericalFor:(id <ZKMNRPannerSourceExpanding>)evaluator useInitial:(BOOL)useInitial
{
	ZKMNRSphericalCoordinate center = useInitial ? [self initialCenter] : [self center];
	ZKMNRSphericalCoordinateSpan span = useInitial ? [self initialSpan] : [self span];
	
	[self privateExpandSphericalFor: evaluator center: center span: span];
}

- (void)expandRectangularFor:(id <ZKMNRPannerSourceExpanding>)evaluator useInitial:(BOOL)useInitial
{
	ZKMNRRectangularCoordinate center = ZKMNRSphericalCoordinateToRectangular([self center]);
	ZKMNRRectangularCoordinateSpan span = _spanRect;
	
	[self privateExpandRectangularFor: evaluator center: center span: span];
}


- (void)expandFor:(id <ZKMNRPannerSourceExpanding>)evaluator useInitial:(BOOL)useInitial
{
	if (!useInitial && _isRectangular) 
		[self expandRectangularFor: evaluator useInitial: NO];
	else 
		[self expandSphericalFor: evaluator useInitial: useInitial];
}

#pragma mark _____ ZKMNRPannerPositionInternal
- (void)privateSetPanner:(ZKMNRVBAPPanner *)panner
{
	_panner = panner;
	if (_panner) [self speakerLayoutChanged];
}

- (void)speakerLayoutChanged
{
	// this is not thread safe -- if this is called while the object is accessed
	// in another thread, there will be problems
	_numberOfMixerCoefficients = [[_panner speakerLayout] numberOfSpeakers];
	if (_mixerCoefficients) free(_mixerCoefficients), _mixerCoefficients = NULL;
	if (_numberOfMixerCoefficients < 1) return;
	
	_mixerCoefficients = (float*) malloc(_numberOfMixerCoefficients * sizeof(float));
	_isPlanar = [[_panner speakerLayout] isPlanar];
		// recompute the coefficients
	[self setCenter: _center span: _span gain: _gain];
}

- (float)pannerGain
{
	unsigned i, count = _numberOfMixerCoefficients;
	float sumSquare = 0.f;
	for (i = 0; i < count; i++) {
		float coeff = _mixerCoefficients[i];
		sumSquare += coeff * coeff;
	}

	float gain = (sumSquare > 0.f) ? sqrtf(sumSquare) :	0.f;
	return gain;
}

#pragma mark _____ ZKMNRPannerPositionPrivate
- (void)privateNormalizeCoefficients
{
	// normalize to yield a gain of 1
		// compute the normailzation factor
	float pannerGain = [self pannerGain];
	float normalization = (pannerGain > 0.001) ? 1.f / pannerGain : 0.f;
	if (pannerGain < 0.001) {
		ZKMORLogError(kZKMORLogSource_Panner, CFSTR("Panner Position [{ %.2f, %.2f }, { %.2f, %.2f }] yielded a gain of 0."), _center.azimuth, _center.zenith, _span.azimuthSpan, _span.zenithSpan);
		[_panner logAtLevel: kZKMORLogLevel_Error | kZKMORLogLevel_Continue source: kZKMORLogSource_Panner indent: 1];
		return;
	}
		// carry out the normalization
	normalization *= (_isMute) ? 0.f : _gain;
	unsigned i, count = _numberOfMixerCoefficients;
	for (i = 0; i < count; i++) _mixerCoefficients[i] *= normalization;
}

- (void)privateExpandSphericalFor:(id <ZKMNRPannerSourceExpanding>)evaluator center:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span
{
	float minSpan = 0.1f;
	
	// sample the space to generate virtual sound sources at each sampled point
	
		// 0.1 is the smallest span we take into account. 10 is (1.0 / 0.1)
	unsigned numAzimuthSamples = floorf(span.azimuthSpan * 10.f);
	unsigned numZenithSamples = floorf(span.zenithSpan * 10.f);
		// adjust the span to give round numbers
	span.azimuthSpan = numAzimuthSamples * minSpan;  span.zenithSpan = numZenithSamples * minSpan;
		// increase the num samples to insure the function runs at least once (must happen after the above line)
	++numAzimuthSamples; ++numZenithSamples;
	
		// fold the center zenith to the top hemisphere. N.B. the setter clamps the zenith span to a max of 0.5.
	center.zenith = ZKMORFold0ToMax(center.zenith, 1.f);
	float azimuthStart = center.azimuth - (span.azimuthSpan * 0.5f);
	float zenithStart = MAX(center.zenith - (span.zenithSpan * 0.5f), 0.f);
	float zenithEnd = zenithStart + span.zenithSpan;
	if (zenithEnd > 1.f) zenithStart -= (zenithEnd - 1.f);

	ZKMNRSphericalCoordinate samplePoint = { azimuthStart, zenithStart, 1.f };
	unsigned i, j;
	for (i = 0; i < numAzimuthSamples; i++) {
		for (j = 0; j < numZenithSamples; j++) {
			ZKMNRRectangularCoordinate rectCoord = ZKMNRSphericalCoordinateToRectangular(samplePoint);
			if (rectCoord.z < 0.f) rectCoord.z = 0.f;
		
			[evaluator pannerSource: self spatialSampleAt: rectCoord];

			samplePoint.zenith += minSpan;
		}
		samplePoint.azimuth += minSpan;
		samplePoint.zenith = zenithStart;		
	}

	// CR Testing Support for speakers below the audience.
//	float azimuthStart = center.azimuth - (span.azimuthSpan * 0.5f);
//	float zenithStart = center.zenith - (span.zenithSpan * 0.5f);
//	
//	ZKMNRSphericalCoordinate samplePoint = { azimuthStart, zenithStart, 1.f };
//	unsigned i, j;
//	for (i = 0; i < numAzimuthSamples; i++) {
//		for (j = 0; j < numZenithSamples; j++) {
//			ZKMNRRectangularCoordinate rectCoord = ZKMNRSphericalCoordinateToRectangular(samplePoint);
//		
//			[evaluator pannerSource: self spatialSampleAt: rectCoord];
//
//			samplePoint.zenith += minSpan;
//		}
//		samplePoint.azimuth += minSpan;
//		samplePoint.zenith = zenithStart;		
//	}
}

- (void)privateExpandRectangularFor:(id <ZKMNRPannerSourceExpanding>)evaluator center:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span
{
	float minSpan = 0.1f;
	
	// sample the space to generate virtual sound sources at each sampled point
	
		// 0.05 is the smallest span we take into account. 10 is (1.0 / 0.1)
	unsigned numXSamples = floorf(span.xSpan * 10.f);
	unsigned numYSamples = floorf(span.ySpan * 10.f);
		// adjust the span to give round numbers
	_spanRect.xSpan = numXSamples * minSpan;  _spanRect.ySpan = numYSamples * minSpan;
		// increase the num samples to insure the function runs at least once (must happen after the above line)
	++numXSamples; ++numYSamples;
	
	float xStart = center.x - (span.xSpan * 0.5f);
	float yStart = center.y - (span.ySpan * 0.5);
	
	ZKMNRRectangularCoordinate samplePoint = { xStart, yStart, 0.f };
	
	unsigned i, j;
	for (i = 0; i < numXSamples; i++) {
		for (j = 0; j < numYSamples; j++) {
			ZKMNRRectangularCoordinate rectCoord = ZKMNRSphericalCoordinateToRectangular(ZKMNRPlanarCoordinateLiftedToSphere(samplePoint));
				// make sure we are in the upper half of the sphere
			if (rectCoord.z < 0.f) rectCoord.z = 0.f;
			[evaluator pannerSource: self spatialSampleAt: rectCoord];
			samplePoint.y += minSpan;
		}
		samplePoint.x += minSpan;
		samplePoint.y = yStart;		
	}
}

#pragma mark _____ ZKMNRTimeDependent
- (void)acceptEvent:(ZKMNREvent *)event time:(Float64)now
{
	if (_activePannerEvent) {
		[_activePannerEvent cleanup: now];
		[_activePannerEvent release], _activePannerEvent = nil;
	}
	_activePannerEvent = (ZKMNRPannerEvent *)event;
	if (_activePannerEvent) {
		[_activePannerEvent retain];
		[_activePannerEvent initializeAtTime: now];
	}
}

- (void)task:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler
{
	if (_activePannerEvent) [_activePannerEvent task: timeRange scheduler: scheduler];
}

- (void)scrub:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler
{
	if (_activePannerEvent) [_activePannerEvent task: timeRange scheduler: scheduler];
}

#pragma mark _____ Logging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(level, source, CFSTR("%s %@ C {%.2f, %.2f} S {%.2f, %.2f} G %.2f"), indentStr, self, _center.azimuth, _center.zenith, _span.azimuthSpan, _span.zenithSpan, _gain);
}

@end

@implementation ZKMNRSpeakerMeshElement
#pragma mark _____ NSObject overrides
- (void)dealloc
{
	if (_speakers) [_speakers release];
	if (_A) free(_A);
	if (_LU) free(_LU);
	[super dealloc];
}

- (id)init 
{
	if (!(self = [super init])) return nil;

	_speakers = [[NSMutableArray alloc] initWithCapacity: 3];
	_A = NULL; _LU = NULL;
	
	return self;
}

#pragma mark _____ Accessors
- (unsigned)numberOfSpeakers { return _numberOfSpeakers; }
- (NSArray *)speakers { return _speakers; }
- (BOOL)isInvertable { return _isInvertable; }

- (void)getCoeffs:(float *)coeffs atPosition:(ZKMNRRectangularCoordinate)pos
{
	if (!_isInvertable) { ZKMORLogError(kZKMORLogSource_Panner, CFSTR("VBAP Linear System not invertable")); return; }

	float B[3]; B[0] = pos.x; B[1] = pos.y; B[2] = pos.z;
	int result = ZKMNRLUSolve(_LU, _pivots, B, _numberOfSpeakers);

	if (result < 0) { ZKMORLogError(kZKMORLogSource_Panner, CFSTR("VBAP Linear System had error in arguments %i"), result); return; }

	coeffs[0] = B[0]; coeffs[1] = B[1]; coeffs[2] = B[2];
}

#pragma mark _____ ZKMNRSpeakerMeshElementPrivate
- (void)addSpeaker:(ZKMNRSpeakerPosition *)speaker 
{
	[_speakers addObject: speaker];
}

- (void)initializeAfterSpeakerPositionsUpdate
{
	unsigned numberOfSpeakers = [_speakers count];
	_numberOfSpeakers = numberOfSpeakers;
	_byteSizeOfA = _numberOfSpeakers * _numberOfSpeakers * sizeof(float);
	// this method is only called once during the lifetime of this object -- no need to free this memory
	_A = (float*) malloc(_byteSizeOfA);
	_LU = (float*) malloc(_byteSizeOfA);
	unsigned i;
	for (i = 0; i < numberOfSpeakers; i++) {
		ZKMNRSphericalCoordinate coordPlatonic = [[_speakers objectAtIndex: i] coordPlatonic];
		ZKMNRRectangularCoordinate speaker =  ZKMNRSphericalCoordinateToRectangular(coordPlatonic);
		// Column i gets the speaker position
		// In C this would look like:
//		if (2 == numberOfSpeakers) {
//			_A[i] = speaker.x; _A[2 + i] = speaker.y;
//		} else {
//			_A[i] = speaker.x; _A[3 + i] = speaker.y; _A[6 + i] = speaker.z;
//		}
		
		// but Fortran is column-major, so
		if (2 == numberOfSpeakers) {
			_A[2*i] = speaker.x; _A[2*i + 1] = speaker.y;
		} else {
			_A[3*i] = speaker.x; _A[3*i + 1] = speaker.y; _A[3*i + 2] = speaker.z;
		}
	}
	
	memcpy(_LU, _A, _byteSizeOfA);
	_isInvertable = YES;
	int result = ZKMNRLUDecomposition(_LU, _pivots, _numberOfSpeakers);
	
	if (result > 0) {
		[self logAtLevel: kZKMORLogLevel_Error source: kZKMORLogSource_Panner indent: 0 tag: @"VBAP Linear System is singular: "];
		_isInvertable = NO;
	}
	
	if (result < 0) {
		ZKMORLogError(kZKMORLogSource_Panner, CFSTR("VBAP Could not compute LU decomposition %i"), result);
		_isInvertable = NO;
	}
}

#pragma mark _____ Computations
- (float)perimeter
{
	float perimeter = 0.f;
	ZKMNRRectangularCoordinate side1 = ZKMNRRectangularCoordinateSubtract([[_speakers objectAtIndex: 1] coordRectangular], [[_speakers objectAtIndex: 0] coordRectangular]);
	ZKMNRRectangularCoordinate side2 = ZKMNRRectangularCoordinateSubtract([[_speakers objectAtIndex: 2] coordRectangular], [[_speakers objectAtIndex: 0] coordRectangular]);
	ZKMNRRectangularCoordinate side3 = ZKMNRRectangularCoordinateSubtract([[_speakers objectAtIndex: 2] coordRectangular], [[_speakers objectAtIndex: 1] coordRectangular]);
			
	perimeter = ZKMNRRectangularCoordinateMagnitude(&side1) + ZKMNRRectangularCoordinateMagnitude(&side2) + ZKMNRRectangularCoordinateMagnitude(&side3);
		
	return perimeter;
}

- (float)area
{
	float area = 0.f;
	ZKMNRRectangularCoordinate side1 = ZKMNRRectangularCoordinateSubtract([[_speakers objectAtIndex: 1] coordRectangular], [[_speakers objectAtIndex: 0] coordRectangular]);
	ZKMNRRectangularCoordinate side2 = ZKMNRRectangularCoordinateSubtract([[_speakers objectAtIndex: 2] coordRectangular], [[_speakers objectAtIndex: 0] coordRectangular]);	

	area = 0.5f * ZKMNRRectangularCoordinateMagnitude(&side1) * ZKMNRRectangularCoordinateMagnitude(&side2);
	return area;
}

- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	
	unsigned myLevel = level | kZKMORLogLevel_Continue;

	// This code logs the rectangular coordinates, but we want the spherical ones
//	ZKMORLog(myLevel, source, 
//		@"%s\t{ {%1.2f, %1.2f, %1.2f}, {%1.2f, %1.2f, %1.2f}, {%1.2f, %1.2f, %1.2f} }", indentStr,
//		_A[0][0], _A[1][0], _A[2][0],
//		_A[0][1], _A[1][1], _A[2][1],
//		_A[0][2], _A[1][2], _A[2][2]);
//

	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(myLevel, source, CFSTR("%s{ "), indentStr);
	unsigned numberOfSpeakers = [_speakers count];
	unsigned i;
	for (i = 0; i < numberOfSpeakers; i++) {
		ZKMNRSphericalCoordinate coord = [[_speakers objectAtIndex: i] coordPlatonic];
		if (2 == _numberOfSpeakers)
			ZKMORLog(myLevel, source, CFSTR("%s\tPos { %1.2f, %1.2f }, A { %1.2f, %1.2f }"), indentStr, coord.azimuth, coord.zenith, _A[i], _A[2 + i]);
		else
			ZKMORLog(myLevel, source, CFSTR("%s\tPos { %1.2f, %1.2f }, A { %1.2f, %1.2f, %1.2f }"), indentStr, coord.azimuth, coord.zenith, _A[i], _A[3 + i], _A[6 + i]);
	}
	ZKMORLog(myLevel, source, CFSTR("%s}"), indentStr);	
}

@end