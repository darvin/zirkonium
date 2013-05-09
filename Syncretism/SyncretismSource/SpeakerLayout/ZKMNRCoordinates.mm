//
//  ZKMNRCoordinates.cpp
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 24.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRCoordinates.h"


#pragma mark _____ Utility Functions
BOOL IsZero(float value) { return fabsf(value) < 0.000001f; }
BOOL IsPositive(float value) { return value >= 0.f; }
BOOL IsNonNegative(float value) { return value >= -0.f || IsZero(value); }

static inline float XYToAzimuth(float x, float y)
{ 
	if (IsZero(y)) {
		if (IsPositive(x))
			return 0.f;
		else
			return 1.f;
	} else {
		float theta = atanf( y / x) / M_PI;
			// theta is between -0.5 and 0.5
		if (IsPositive(x))
			return theta;
		else {
			if (IsPositive(y))
				return 1 + theta;
			else
				return -1 + theta;
		}
	}
}

#pragma mark _____ ZKMNRSphericalCoordinateCPP
ZKMNRRectangularCoordinate	ZKMNRSphericalCoordinateCPP::AsRectangular() const
{ 
	float rcosZenith = radius * cosf(zenith * M_PI);
	ZKMNRRectangularCoordinate rectCoord;
	rectCoord.x = cosf(azimuth * M_PI) * rcosZenith;
	rectCoord.y = sinf(azimuth * M_PI) * rcosZenith;
	rectCoord.z = radius * sinf(zenith * M_PI);
	
	return rectCoord;
}

#pragma mark _____ ZKMNRRectangularCoordinateCPP
ZKMNRSphericalCoordinate ZKMNRRectangularCoordinateCPP::AsSpherical() const
{
	float r = sqrtf(x*x + y*y + z*z);
	ZKMNRSphericalCoordinate sphCoord;
	
	sphCoord.azimuth = XYToAzimuth(x, y);
	sphCoord.zenith = asinf(z / r) / M_PI;	
	sphCoord.radius = r;
	
	return sphCoord;
}

ZKMNRSphericalCoordinate ZKMNRRectangularCoordinateCPP::LiftToSphere() const
{
	ZKMNRRectangularCoordinateCPP rect = *this;
	rect.z = sqrtf(1 - (MIN(1, x * x + y * y)));
	ZKMNRSphericalCoordinateCPP sphereCoord = rect.AsSpherical();
	sphereCoord.radius = 1;
	return sphereCoord;
}

ZKMNRRectangularCoordinateCPP ZKMNRRectangularCoordinateCPP::operator +(ZKMNRRectangularCoordinateCPP right)
{
	return ZKMNRRectangularCoordinateCPP(	this->x + right.x,
											this->y + right.y,
											this->z + right.z);
}

ZKMNRRectangularCoordinateCPP ZKMNRRectangularCoordinateCPP:: operator *(float scalar)
{
	return ZKMNRRectangularCoordinateCPP(	scalar * this->x,
											scalar * this->y,
											scalar * this->z);
}

#pragma mark _____ C API
float	ZKMNRSphericalCoordinateMixer3DAzimuth(const ZKMNRSphericalCoordinate* coord)
{
	ZKMNRSphericalCoordinateCPP point(*coord);
	return point.Mixer3DAzimuth();
}

float	ZKMNRSphericalCoordinateMixer3DElevation(const ZKMNRSphericalCoordinate* coord)
{
	ZKMNRSphericalCoordinateCPP point(*coord);
	return point.Mixer3DElevation();
}

float	ZKMNRSphericalCoordinateMixer3DDistance(const ZKMNRSphericalCoordinate* coord)
{
	ZKMNRSphericalCoordinateCPP point(*coord);
	return point.Mixer3DDistance();
}

float	ZKMNRRectangularCoordinateMagnitude(const ZKMNRRectangularCoordinate* coord)
{
	ZKMNRRectangularCoordinateCPP point(*coord);
	return point.Magnitude();
}

ZKMNRSphericalCoordinate	ZKMNRRectangularCoordinateToSpherical(ZKMNRRectangularCoordinate coord)
{
	ZKMNRRectangularCoordinateCPP point = coord;
	return point.AsSpherical();	
}

ZKMNRRectangularCoordinate	ZKMNRSphericalCoordinateToRectangular(ZKMNRSphericalCoordinate coord)
{
	ZKMNRSphericalCoordinateCPP point = coord;
	return point.AsRectangular();	
}

ZKMNRSphericalCoordinate	ZKMNRPlanarCoordinateLiftedToSphere(ZKMNRRectangularCoordinate coord)
{
	ZKMNRRectangularCoordinateCPP point = coord;
	return point.LiftToSphere();
}

ZKMNRSphericalCoordinate	ZKMNRRectangularCoordinateToCircular(ZKMNRRectangularCoordinate coord)
{
	ZKMNRSphericalCoordinate point;
	point.zenith = 0.f;	
	point.radius = sqrt((coord.x * coord.x) + (coord.y * coord.y));
	point.azimuth = XYToAzimuth(coord.x, coord.y);
	return point;
}

ZKMNRRectangularCoordinate	ZKMNRCircularCoordinateToRectangular(ZKMNRSphericalCoordinate coord)
{
	ZKMNRRectangularCoordinate point;
	point.z = 0.f;	
	point.x = coord.radius * cosf(coord.azimuth * M_PI);
	point.y = coord.radius * sinf(coord.azimuth * M_PI);	
	return point;	
}

ZKMNRRectangularCoordinate	ZKMNRRectangularCoordinateSubtract(		const ZKMNRRectangularCoordinate coord1, 
																	const ZKMNRRectangularCoordinate coord2)
{
	ZKMNRRectangularCoordinateCPP point1 = coord1;
	ZKMNRRectangularCoordinateCPP point2 = coord2;
	
	return point1 - point2;
}

static inline BOOL FloatsAreEffectivelyEqual(float float1, float float2)
{
	return fabsf(float2 - float1) < 0.001;
}

BOOL	ZKMNRRectangularCoordinatesAreEqual(	const ZKMNRRectangularCoordinate coord1,
												const ZKMNRRectangularCoordinate coord2)
{
	return 
		FloatsAreEffectivelyEqual(coord1.x, coord2.x) &&
		FloatsAreEffectivelyEqual(coord1.y, coord2.y) &&
		FloatsAreEffectivelyEqual(coord1.z, coord2.z);
}												
												
BOOL	ZKMNRSphericalCoordinatesAreEqual(	const ZKMNRSphericalCoordinate coord1,
											const ZKMNRSphericalCoordinate coord2)
{
	return 
		FloatsAreEffectivelyEqual(coord1.azimuth, coord2.azimuth) &&
		FloatsAreEffectivelyEqual(coord1.zenith, coord2.zenith) &&
		FloatsAreEffectivelyEqual(coord1.radius, coord2.radius);
}

void	ZKMNRSphericalCoordinateEncode(ZKMNRSphericalCoordinate coord1, NSString* prefix, NSCoder* aCoder)
{
	if ([aCoder allowsKeyedCoding]) {
		NSString* keyString;
		keyString = [[NSString alloc] initWithFormat: @"%@Azimuth", prefix];
		[aCoder encodeFloat: coord1.azimuth forKey: keyString];
		[keyString release];
	
		keyString = [[NSString alloc] initWithFormat: @"%@Zenith", prefix];
		[aCoder encodeFloat: coord1.zenith forKey: keyString];
		[keyString release];
	
		keyString = [[NSString alloc] initWithFormat: @"%@Radius", prefix];
		[aCoder encodeFloat: coord1.radius forKey: keyString];
		[keyString release];
	} else {
		[aCoder encodeValueOfObjCType:@encode(float) at: &coord1.azimuth];
		[aCoder encodeValueOfObjCType:@encode(float) at: &coord1.zenith];
		[aCoder encodeValueOfObjCType:@encode(float) at: &coord1.radius];
	}
}

ZKMNRSphericalCoordinate	ZKMNRSphericalCoordinateDecode(NSString* prefix, NSCoder* aDecoder)
{
	ZKMNRSphericalCoordinate coord1;
	if ([aDecoder allowsKeyedCoding]) {
		NSString* keyString;
		keyString = [[NSString alloc] initWithFormat: @"%@Azimuth", prefix];
		coord1.azimuth = [aDecoder decodeFloatForKey: keyString];
		[keyString release];
	
		keyString = [[NSString alloc] initWithFormat: @"%@Zenith", prefix];
		coord1.zenith = [aDecoder decodeFloatForKey: keyString];
		[keyString release];
	
		keyString = [[NSString alloc] initWithFormat: @"%@Radius", prefix];
		coord1.radius = [aDecoder decodeFloatForKey: keyString];
		[keyString release];		
	} else {
		[aDecoder decodeValueOfObjCType:@encode(float) at: &coord1.azimuth];
		[aDecoder decodeValueOfObjCType:@encode(float) at: &coord1.zenith];
		[aDecoder decodeValueOfObjCType:@encode(float) at: &coord1.radius];
	}
	
	return coord1;
}

void	ZKMNRSphericalCoordinateSpanEncode(ZKMNRSphericalCoordinateSpan span1, NSString* prefix, NSCoder* aCoder)
{
	if ([aCoder allowsKeyedCoding]) {
		NSString* keyString;
		keyString = [[NSString alloc] initWithFormat: @"%@AzimuthSpan", prefix];
		[aCoder encodeFloat: span1.azimuthSpan forKey: keyString];
		[keyString release];
	
		keyString = [[NSString alloc] initWithFormat: @"%@ZenithSpan", prefix];
		[aCoder encodeFloat: span1.zenithSpan forKey: keyString];
		[keyString release];
	} else {
		[aCoder encodeValueOfObjCType:@encode(float) at: &span1.azimuthSpan];
		[aCoder encodeValueOfObjCType:@encode(float) at: &span1.zenithSpan];
	}
}

ZKMNRSphericalCoordinateSpan	ZKMNRSphericalCoordinateSpanDecode(NSString* prefix, NSCoder* aDecoder)
{
	ZKMNRSphericalCoordinateSpan span1;
	if ([aDecoder allowsKeyedCoding]) {
		NSString* keyString;
		keyString = [[NSString alloc] initWithFormat: @"%@AzimuthSpan", prefix];
		span1.azimuthSpan = [aDecoder decodeFloatForKey: keyString];
		[keyString release];
	
		keyString = [[NSString alloc] initWithFormat: @"%@ZenithSpan", prefix];
		span1.zenithSpan = [aDecoder decodeFloatForKey: keyString];
		[keyString release];
	} else {
		[aDecoder decodeValueOfObjCType:@encode(float) at: &span1.azimuthSpan];
		[aDecoder decodeValueOfObjCType:@encode(float) at: &span1.zenithSpan];
	}
	
	return span1;
}
