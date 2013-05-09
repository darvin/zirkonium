//
//  ZKMRNSpeaker.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 31.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNSpeaker.h"
#import "ZKMRNSpeakerRing.h"

@interface ZKMRNSpeaker (ZKMRNSpeakerPrivate)
- (void)updateSpeakerPosition;
@end


@implementation ZKMRNSpeaker
#pragma mark _____ Accessors
- (void)setPositionX:(NSNumber *)pos
{
	[self willChangeValueForKey: @"positionX"];
	[self setPrimitiveValue: pos forKey: @"positionX"];
	[self didChangeValueForKey: @"positionX"];

	[self willChangeValueForKey: @"speakerPosition"];
	[self updateSpeakerPosition];
	[self didChangeValueForKey: @"speakerPosition"];
	
	[[self valueForKey: @"speakerRing"] speakerRingChanged];
}

- (void)setPositionY:(NSNumber *)pos
{
	[self willChangeValueForKey: @"positionY"];
	[self setPrimitiveValue: pos forKey: @"positionY"];
	[self didChangeValueForKey: @"positionY"];
	
	[self willChangeValueForKey: @"speakerPosition"];
	[self updateSpeakerPosition];
	[self didChangeValueForKey: @"speakerPosition"];

	[[self valueForKey: @"speakerRing"] speakerRingChanged];
}

- (void)setPositionZ:(NSNumber *)pos
{
	[self willChangeValueForKey: @"positionZ"];
	[self setPrimitiveValue: pos forKey: @"positionZ"];
	[self didChangeValueForKey: @"positionZ"];
	
	[self willChangeValueForKey: @"speakerPosition"];
	[self updateSpeakerPosition];
	[self didChangeValueForKey: @"speakerPosition"];
	
	[[self valueForKey: @"speakerRing"] speakerRingChanged];
}

- (ZKMNRSpeakerPosition *)speakerPosition
{
	[self willAccessValueForKey: @"speakerPosition"];
	ZKMNRSpeakerPosition* speakerPosition = [self primitiveValueForKey: @"speakerPosition"];
	[self didAccessValueForKey: @"speakerPosition"];
	
	if (!speakerPosition) {
		speakerPosition = [[ZKMNRSpeakerPosition alloc] init];
		[speakerPosition setTag: self];
		[self setPrimitiveValue: speakerPosition forKey: @"speakerPosition"];
		[self updateSpeakerPosition];
		[speakerPosition release];
	}

	return speakerPosition;
}

#pragma mark _____ ZKMRNSpeakerPrivate
- (void)updateSpeakerPosition
{
	ZKMNRSpeakerPosition* speakerPosition = [self primitiveValueForKey: @"speakerPosition"];
	ZKMNRRectangularCoordinate coord;
	coord.x = [[self valueForKey: @"positionX"] floatValue];
	coord.y = [[self valueForKey: @"positionY"] floatValue];
	coord.z = [[self valueForKey: @"positionZ"] floatValue];								
	[speakerPosition setCoordRectangular: coord];
	[speakerPosition computeCoordPlatonicFromPhysical];
	[self setPrimitiveValue: speakerPosition forKey: @"speakerPosition"];
}

#pragma mark _____ ZKMRNManagedObjectExtensions
+ (NSArray *)copyKeys 
{ 
	static NSArray* copyKeys = nil;
	if (!copyKeys) {
		copyKeys = [[NSArray alloc] initWithObjects: @"positionX", @"positionY", @"positionZ", nil];
	}
	
	return copyKeys;
}

@end
