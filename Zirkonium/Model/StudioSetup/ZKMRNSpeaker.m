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
	if(!_x && !_isManipulating) _x = [[self valueForKey:@"positionX"] retain];
	
	if(!_isManipulating) {
		[[[self managedObjectContext] undoManager] registerUndoWithTarget:self selector:@selector(setPositionX:) object:_x];
		[[[self managedObjectContext] undoManager] setActionName:NSLocalizedString(@"Speaker Position Change", @"speaker position x undo")];
	} else {
		[[[self managedObjectContext] undoManager] disableUndoRegistration];
	}

	
	[self willChangeValueForKey: @"positionX"];
	[self setPrimitiveValue: pos forKey: @"positionX"];
	[self didChangeValueForKey: @"positionX"];
	
	if(!_isManipulating) {
		if(_x) [_x release];
		_x = [pos retain];
	} else {
		[[[self managedObjectContext] undoManager] enableUndoRegistration];
	}
	
	[self updateSpeakerPosition];
	
	[[self valueForKey: @"speakerRing"] speakerRingChanged];
}

- (void)setPositionY:(NSNumber *)pos
{
	if(!_y && !_isManipulating) _y = [[self valueForKey:@"positionY"] retain];
	
	if(!_isManipulating) {
		[[[self managedObjectContext] undoManager] registerUndoWithTarget:self selector:@selector(setPositionY:) object:_y];
		[[[self managedObjectContext] undoManager] setActionName:NSLocalizedString(@"Speaker Position Change", @"speaker position y undo")];
	} else {
		[[[self managedObjectContext] undoManager] disableUndoRegistration];
	}

	
	[self willChangeValueForKey: @"positionY"];
	[self setPrimitiveValue: pos forKey: @"positionY"];
	[self didChangeValueForKey: @"positionY"];

	if(!_isManipulating) {
		if(_y) [_y release];
		_y = [pos retain];
	} else {
		[[[self managedObjectContext] undoManager] enableUndoRegistration];
	}
	
	[self updateSpeakerPosition];

	[[self valueForKey: @"speakerRing"] speakerRingChanged];
}

-(NSNumber*)positionZ
{
	if(0==[[[self valueForKey:@"speakerRing"] ringNumber] intValue]) {
		return[NSNumber numberWithFloat:0.0]; 
	}	
	[self willAccessValueForKey: @"positionZ"];
	NSNumber* value = [self primitiveValueForKey:@"positionZ"];
	[self didAccessValueForKey: @"positionZ"];
	return value; 

}

- (void)setPositionZ:(NSNumber *)pos
{
		
	if(!_z && !_isManipulating) _z = [[self valueForKey:@"positionZ"] retain];
	
	if(!_isManipulating) {
		[[[self managedObjectContext] undoManager] registerUndoWithTarget:self selector:@selector(setPositionZ:) object:_z];
		[[[self managedObjectContext] undoManager] setActionName:NSLocalizedString(@"Speaker Position Change", @"speaker position z undo")];
	} else {
		[[[self managedObjectContext] undoManager] disableUndoRegistration];
	}

	[self willChangeValueForKey: @"positionZ"];
	[self setPrimitiveValue: pos forKey: @"positionZ"];
	[self didChangeValueForKey: @"positionZ"];
	
	if(!_isManipulating) {
		if(_z) [_z release];
		_z = [pos retain];
	} else {
		[[[self managedObjectContext] undoManager] enableUndoRegistration];
	}
	
	[self updateSpeakerPosition];
	
	[[self valueForKey: @"speakerRing"] speakerRingChanged];
}

- (ZKMNRSpeakerPosition *)speakerPosition
{
	[self willAccessValueForKey: @"speakerPosition"];
	ZKMNRSpeakerPosition* speakerPosition = [self primitiveSpeakerPosition];
	[self didAccessValueForKey: @"speakerPosition"];
	
	if (!speakerPosition) {
		speakerPosition = [[ZKMNRSpeakerPosition alloc] init];
		[speakerPosition setTag: self];
		
		//DEBUG UNDO FAILURE here ...
		[[[self managedObjectContext] undoManager] disableUndoRegistration];
		[self setPrimitiveSpeakerPosition: speakerPosition];
		[[[self managedObjectContext] undoManager] enableUndoRegistration];

		[self updateSpeakerPosition];
		[speakerPosition autorelease];
	}

	return speakerPosition;
}

-(void)setPrimitiveSpeakerPosition:(ZKMNRSpeakerPosition*)newSpeakerPosition {
	if(_speakerPosition) {
		[_speakerPosition release];
		_speakerPosition = nil; 
	}
	if(newSpeakerPosition)
		_speakerPosition = [newSpeakerPosition retain];
}

-(ZKMNRSpeakerPosition*)primitiveSpeakerPosition
{
	return _speakerPosition;
}

#pragma mark _____ ZKMRNSpeakerPrivate
- (void)updateSpeakerPosition
{
	[self willAccessValueForKey: @"speakerPosition"];
	ZKMNRSpeakerPosition* speakerPosition = [self primitiveSpeakerPosition];
	[self didAccessValueForKey: @"speakerPosition"];

	ZKMNRRectangularCoordinate coord;
	coord.x = [[self valueForKey: @"positionX"] floatValue];
	coord.y = [[self valueForKey: @"positionY"] floatValue];
	coord.z = [[self valueForKey: @"positionZ"] floatValue];								
	[speakerPosition setCoordRectangular: coord];
	[speakerPosition computeCoordPlatonicFromPhysical];

	[[[self managedObjectContext] undoManager] disableUndoRegistration];
	//[self willChangeValueForKey: @"speakerPosition"];
	[self setPrimitiveSpeakerPosition: speakerPosition];
	//[self didChangeValueForKey: @"speakerPosition"];
	[[[self managedObjectContext] undoManager] enableUndoRegistration];
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

#pragma mark -

-(void)startManipulating
{
	if(_isManipulating) return; 
	
	_isManipulating = YES; 
	
	if(_oldX) [_oldX release];
	_oldX = [[self valueForKey:@"positionX"] retain];
	if(_oldY) [_oldY release];
	_oldY = [[self valueForKey:@"positionY"] retain];
	if(_oldZ) [_oldZ release];
	_oldZ = [[self valueForKey:@"positionZ"] retain];

}

-(void)stopManipulating
{
	if(!_isManipulating) return; 
	
	if(_newX) [_newX release];
	_newX = [[self valueForKey:@"positionX"] retain];
	if(_newY) [_newY release];
	_newY = [[self valueForKey:@"positionY"] retain];
	if(_newZ) [_newZ release];
	_newZ = [[self valueForKey:@"positionZ"] retain];

	[self setPositionX:_oldX];
	[self setPositionY:_oldY];
	[self setPositionZ:_oldZ];
	
	_isManipulating = NO;
	
	// this one is recorded in the undo stack
   [self setPositionX:_newX];
   [self setPositionY:_newY];
   [self setPositionZ:_newZ];
}

@end
