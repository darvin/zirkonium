//
//  ZKMNRCoordinatesTest.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 24.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRCoordinatesTest.h"

static BOOL FloatsAreEffectivelyEqual(float float1, float float2)
{
	return fabsf(float2 - float1) < 0.001;
}


@implementation ZKMNRCoordinatesTest

- (void)testCoordinates
{
	{
		// straight ahead, 1 unit away
		ZKMNRSphericalCoordinate	sphereCoord = { 0.f, 0.f, 1.f };
		ZKMNRRectangularCoordinate	rectCoord = ZKMNRSphericalCoordinateToRectangular(sphereCoord);
		BOOL isCorrect =
			FloatsAreEffectivelyEqual(rectCoord.x, 1.f) && 
			FloatsAreEffectivelyEqual(rectCoord.y, 0.f) && 
			FloatsAreEffectivelyEqual(rectCoord.z, 0.f);
		STAssertTrue(isCorrect,
				@"Sphere { 0.f, 0.f, 1.f } should be rect { 1.f, 0.f, 0.f }, not { %1.2f, %1.2f, %1.2f }",
				rectCoord.x, rectCoord.y, rectCoord.z);
	}
	
	{
		// to the left, 0.5 units away
		ZKMNRSphericalCoordinate	sphereCoord = { 0.5f, 0.f, 0.5f };
		ZKMNRRectangularCoordinate	rectCoord = ZKMNRSphericalCoordinateToRectangular(sphereCoord);
		BOOL isCorrect =
			FloatsAreEffectivelyEqual(rectCoord.x, 0.f) && 
			FloatsAreEffectivelyEqual(rectCoord.y, 0.5f) && 
			FloatsAreEffectivelyEqual(rectCoord.z, 0.f);		
		STAssertTrue(isCorrect,
				@"Sphere { 0.5f, 0.f, 0.5f } should be rect { 0.f, 0.5f, 0.f }, not { %1.2f, %1.2f, %1.2f }",
				rectCoord.x, rectCoord.y, rectCoord.z);
	}
	
	{
		ZKMNRSphericalCoordinate	sphereCoord = { 0.75f, 0.f, 1.f };
		ZKMNRRectangularCoordinate	rectCoord = ZKMNRSphericalCoordinateToRectangular(sphereCoord);
		ZKMNRRectangularCoordinate	answer = { -0.707f, 0.707f, 0.f };
		BOOL isCorrect = ZKMNRRectangularCoordinatesAreEqual(rectCoord, answer);
		STAssertTrue(isCorrect,
				@"Sphere { 0.75f, 0.f, 1.f } should be rect { -0.71f, 0.71f, 0.f }, not { %1.2f, %1.2f, %1.2f }",
				rectCoord.x, rectCoord.y, rectCoord.z);
	}
	
	{
		ZKMNRSphericalCoordinate	sphereCoord = { -0.75f, 0.f, 1.f };
		ZKMNRRectangularCoordinate	rectCoord = ZKMNRSphericalCoordinateToRectangular(sphereCoord);
		ZKMNRRectangularCoordinate	answer = { -0.707f, -0.707f, 0.f };

		BOOL isCorrect = ZKMNRRectangularCoordinatesAreEqual(rectCoord, answer);
		STAssertTrue(isCorrect,
				@"Sphere { -0.75f, 0.f, 1.f } should be rect { -0.71f, -0.71f, 0.f }, not { %1.2f, %1.2f, %1.2f }",
				rectCoord.x, rectCoord.y, rectCoord.z);
	}		
	
	{
		ZKMNRRectangularCoordinate	rectCoord = { 1.f, 0.f, 1.f } ;
		ZKMNRSphericalCoordinate	sphereCoord = 
			ZKMNRRectangularCoordinateToSpherical(rectCoord);		
		BOOL isCorrect =
			FloatsAreEffectivelyEqual(sphereCoord.azimuth, 0.f) && 
			FloatsAreEffectivelyEqual(sphereCoord.zenith, 0.25f) && 
			FloatsAreEffectivelyEqual(sphereCoord.radius, sqrtf(2.f));
		STAssertTrue(isCorrect,
				@"Rect { 1.f, 0.f, 1.f } should be sphere { 0.25f, 0.25f, 1.41f }, not { %1.2f, %1.2f, %1.2f }",
				sphereCoord.azimuth, sphereCoord.zenith, sphereCoord.radius);
	}
	
	{
		ZKMNRRectangularCoordinate	rectCoord = { 0.f, 0.f, 1.f } ;
		ZKMNRSphericalCoordinate	sphereCoord = 
			ZKMNRRectangularCoordinateToSpherical(rectCoord);		
		BOOL isCorrect =
			FloatsAreEffectivelyEqual(sphereCoord.azimuth, 0.f) && 
			FloatsAreEffectivelyEqual(sphereCoord.zenith, 0.5f) && 
			FloatsAreEffectivelyEqual(sphereCoord.radius, 1.f);
		STAssertTrue(isCorrect,
				@"Rect { 0.f, 0.f, 1.f } should be sphere { 0.f, 0.5f, 1.f }, not { %1.2f, %1.2f, %1.2f }",
				sphereCoord.azimuth, sphereCoord.zenith, sphereCoord.radius);
	}
	
	{
		ZKMNRSphericalCoordinate	sphereCoord = { 0.f, 1.f, 1.f };
		ZKMNRRectangularCoordinate	rectCoord = 
			ZKMNRSphericalCoordinateToRectangular(sphereCoord);
		BOOL isCorrect =
			FloatsAreEffectivelyEqual(rectCoord.x, -1.f) && 
			FloatsAreEffectivelyEqual(rectCoord.y, 0.f) && 
			FloatsAreEffectivelyEqual(rectCoord.z, 0.f);
		STAssertTrue(isCorrect,
				@"Sphere { 0.f, 1.f, 1.f } should be rect { -1.f, 0.f, 0.f }, not { %1.2f, %1.2f, %1.2f }",
				rectCoord.z, rectCoord.y, rectCoord.z);
	}
	
	{
		ZKMNRRectangularCoordinate	rectCoord = { 0.f, 0.f, 0.f };
		ZKMNRSphericalCoordinate	sphereCoord = ZKMNRPlanarCoordinateLiftedToSphere(rectCoord);

		BOOL isCorrect =
			FloatsAreEffectivelyEqual(sphereCoord.azimuth, 0.f) && 
			FloatsAreEffectivelyEqual(sphereCoord.zenith, 0.5f) && 
			FloatsAreEffectivelyEqual(sphereCoord.radius, 1.f);
		STAssertTrue(isCorrect,
				@"Rect { 0.f, 0.f, 0.f } lifted to sphere should be { 0.f, 0.5f, 1.f }, not { %1.2f, %1.2f, %1.2f }",
				sphereCoord.azimuth, sphereCoord.zenith, sphereCoord.radius);
	}
	
	{
		ZKMNRRectangularCoordinate	rectCoord = { 1.f, 0.f, 0.f };
		ZKMNRSphericalCoordinate	sphereCoord = ZKMNRPlanarCoordinateLiftedToSphere(rectCoord);

		BOOL isCorrect =
			FloatsAreEffectivelyEqual(sphereCoord.azimuth, 0.f) && 
			FloatsAreEffectivelyEqual(sphereCoord.zenith, 0.f) && 
			FloatsAreEffectivelyEqual(sphereCoord.radius, 1.f);
		STAssertTrue(isCorrect,
				@"Rect { 1.f, 0.f, 0.f } lifted to sphere should be { 0.f, 0.f, 1.f }, not { %1.2f, %1.2f, %1.2f }",
				sphereCoord.azimuth, sphereCoord.zenith, sphereCoord.radius);
	}
	
	{
		ZKMNRRectangularCoordinate	rectCoord;
		rectCoord.x = 1.f/sqrtf(3.f);
		rectCoord.y = 1.f/sqrtf(3.f);		
		ZKMNRSphericalCoordinate	sphereCoord = ZKMNRPlanarCoordinateLiftedToSphere(rectCoord);

		BOOL isCorrect =
			FloatsAreEffectivelyEqual(sphereCoord.azimuth, 0.25f) && 
			FloatsAreEffectivelyEqual(sphereCoord.zenith, 0.195913f) && 
			FloatsAreEffectivelyEqual(sphereCoord.radius, 1.f);
		STAssertTrue(isCorrect,
				@"Rect { 0.f, 0.f, 1.f } lifted to sphere should be { 0.25f, 0.195913f, 1.f }, not { %1.2f, %1.2f, %1.2f }",
				sphereCoord.azimuth, sphereCoord.zenith, sphereCoord.radius);
	}
}

@end
