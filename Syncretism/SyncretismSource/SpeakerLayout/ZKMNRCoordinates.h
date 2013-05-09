//
//  ZKMNRCoordinates.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 24.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMNRCoordinates_h__
#define __ZKMNRCoordinates_h__

#include "ZKMORCore.h"

ZKMOR_C_BEGIN

///
///  ZKMNRSphericalCoordinate
/// 
///  A spherical coordinate. See the C++ classes below for operations to manipulate these.
///
///  The format for angles is somewhat unconventional, but it can be very
///  easily converted to radians (multi by pi) or degrees (multiply by 180)
///
///  These coordinates are "right-handed" (+x -- forward, +y -- left, +z -- up)
///  To visualize the coordinate system, take your right hand and point your thumb (z),
///  index finger (x), and middle finger (y) all perpendicular to each other. This is
///  slightly different from the OpenGL coordinate system: our x-> OpenGL z, y-> -x, z->y.
///
///  To convert to OpenGL, make the above gesture, but rotate your right hand so that
///  you are looking at your thumb (the positive z-axis) and your middle finger points up (y).
///  This may be a bit of a stretch. The transformation is:
///
///  	gluLookAt( 0.f, 0.f, 5.f, 0.f, 0.f, 0.f, 0.f, 1.f, 0.f );
///
///  This coordinate system is, however, conveniently the same as the one used by the 3D Mixer
///  (divided by 180).
///
typedef struct {
	float		azimuth;	// theta,  angle,  -1.0 -> 1.0,  0 straight ahead
	float		zenith;		// phi,    angle,  -0.5 -> 0.5,  0 same elevation as listener
	float		radius;		// r,      meters
} ZKMNRSphericalCoordinate;

///
///  ZKMNRRectangularCoordinate
/// 
///	A rectangular coordinate. See the C++ classes below for operations to manipulate these.
///
///	This is the same as the spherical coordinate system, but in rectangular form.
///
typedef struct {
	float		x;	// meters
	float		y;	// meters
	float		z;	// meters
} ZKMNRRectangularCoordinate;

///
///  ZKMNRSphericalCoordinateSpan
///
///  A struct to describe the extent of a patch on a sphere
///
typedef struct {
	float	azimuthSpan;	// delta theta,  angle,  0 -> 2,  [0 a point, 2 the circle]
	float	zenithSpan;		// delta phi,    angle,  0 -> 1,  [0 a point, 1 the half-circle]
} ZKMNRSphericalCoordinateSpan;

///
///  ZKMNRRectangularCoordinateSpan
///
///  A struct to describe the extent of a patch in space.
///
typedef struct {
	float	xSpan;	// meters
	float	ySpan;	// meters
	float	zSpan;	// meters
} ZKMNRRectangularCoordinateSpan;

// Convenience Functions for working with the Coordinates
float	ZKMNRSphericalCoordinateMixer3DAzimuth(const ZKMNRSphericalCoordinate* coord);
float	ZKMNRSphericalCoordinateMixer3DElevation(const ZKMNRSphericalCoordinate* coord);
float	ZKMNRSphericalCoordinateMixer3DDistance(const ZKMNRSphericalCoordinate* coord);
float	ZKMNRRectangularCoordinateMagnitude(const ZKMNRRectangularCoordinate* coord);

ZKMNRSphericalCoordinate	ZKMNRRectangularCoordinateToSpherical(ZKMNRRectangularCoordinate coord);
ZKMNRRectangularCoordinate	ZKMNRSphericalCoordinateToRectangular(ZKMNRSphericalCoordinate coord);
		/// takes a coordinate in the XY plane and lifts it to the unit sphere
ZKMNRSphericalCoordinate	ZKMNRPlanarCoordinateLiftedToSphere(ZKMNRRectangularCoordinate coord);

//  Returns a Spherical Coordinate where R is the planar radius, and zenith is undefined
ZKMNRSphericalCoordinate	ZKMNRRectangularCoordinateToCircular(ZKMNRRectangularCoordinate coord);
ZKMNRRectangularCoordinate	ZKMNRCircularCoordinateToRectangular(ZKMNRSphericalCoordinate coord);	
	
ZKMNRRectangularCoordinate	ZKMNRRectangularCoordinateSubtract(	const ZKMNRRectangularCoordinate coord1, 
																const ZKMNRRectangularCoordinate coord2);

BOOL	ZKMNRRectangularCoordinatesAreEqual(	const ZKMNRRectangularCoordinate coord1,
												const ZKMNRRectangularCoordinate coord2);
												
BOOL	ZKMNRSphericalCoordinatesAreEqual(	const ZKMNRSphericalCoordinate coord1,
											const ZKMNRSphericalCoordinate coord2);
											
//  NSCoding help
void	ZKMNRSphericalCoordinateEncode(ZKMNRSphericalCoordinate coord1, NSString* prefix, NSCoder* aCoder);
ZKMNRSphericalCoordinate	ZKMNRSphericalCoordinateDecode(NSString* prefix, NSCoder* aDecoder);

void	ZKMNRSphericalCoordinateSpanEncode(ZKMNRSphericalCoordinateSpan span1, NSString* prefix, NSCoder* aCoder);
ZKMNRSphericalCoordinateSpan	ZKMNRSphericalCoordinateSpanDecode(NSString* prefix, NSCoder* aDecoder);

//  Utility Functions
BOOL IsZero(float value);
BOOL IsPositive(float value);
BOOL IsNonNegative(float value);

ZKMOR_C_END

#ifdef __cplusplus

class ZKMNRSphericalCoordinateCPP : public ZKMNRSphericalCoordinate
{

public:
//  CTOR
	ZKMNRSphericalCoordinateCPP() { memset(this, 0, sizeof(ZKMNRSphericalCoordinate)); }
	
	ZKMNRSphericalCoordinateCPP(float theta, float phi, float r)
	{
		azimuth = theta; zenith = phi, radius = r;
	}
	
	ZKMNRSphericalCoordinateCPP(const ZKMNRSphericalCoordinate &coord)
	{
		memcpy(this, &coord, sizeof(ZKMNRSphericalCoordinate));
	}

//  3D Mixer support	
	float Mixer3DAzimuth() const { return -180.f * azimuth; }
	float Mixer3DElevation() const { return 180.f * zenith; }
	float Mixer3DDistance() const { return radius; }		

//  Conversion
	ZKMNRRectangularCoordinate AsRectangular() const;
	
//  Operators
	ZKMNRSphericalCoordinateCPP& operator=(const ZKMNRSphericalCoordinate &coord)
	{
		memcpy(this, &coord, sizeof(ZKMNRSphericalCoordinate));
		return *this;
	}
	
	operator ZKMNRRectangularCoordinate () const { return AsRectangular(); }
};

class ZKMNRRectangularCoordinateCPP : public ZKMNRRectangularCoordinate
{

public:
//  CTOR
	ZKMNRRectangularCoordinateCPP() { memset(this, 0, sizeof(ZKMNRRectangularCoordinate)); }
	
	ZKMNRRectangularCoordinateCPP(float theX, float theY, float theZ)
	{
		x = theX; y = theY, z = theZ;
	}
	
	ZKMNRRectangularCoordinateCPP(const ZKMNRRectangularCoordinate &coord)
	{
		memcpy(this, &coord, sizeof(ZKMNRRectangularCoordinate));
	}
	
//  Conversion
	ZKMNRSphericalCoordinate AsSpherical() const;
	ZKMNRSphericalCoordinate LiftToSphere() const;
	
//  Mathematical operations
	float Magnitude() { return sqrtf((x*x + y*y + z*z)); }
	
//  Operators
	ZKMNRRectangularCoordinateCPP& operator=(const ZKMNRRectangularCoordinate &coord)
	{
		memcpy(this, &coord, sizeof(ZKMNRRectangularCoordinate));
		return *this;
	}
	
	// vector addition
	ZKMNRRectangularCoordinateCPP operator +(ZKMNRRectangularCoordinateCPP right);
	ZKMNRRectangularCoordinateCPP operator -(ZKMNRRectangularCoordinateCPP right)
	{
		return (*this) + (-1.f * right);
	}

	// scalar multiplication
	ZKMNRRectangularCoordinateCPP operator *(float scalar);	
	friend ZKMNRRectangularCoordinateCPP operator *(float scalar, ZKMNRRectangularCoordinateCPP coord) 
	{
		return coord * scalar; 
	}
	
	operator ZKMNRSphericalCoordinate () const { return AsSpherical(); }
};

#endif

#endif __ZKMNRCoordinates_h__
