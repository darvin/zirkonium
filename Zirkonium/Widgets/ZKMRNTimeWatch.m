//
//  ZKMRNTimeWatch.m
//  Zirkonium
//
//  Created by Jens on 17.09.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNTimeWatch.h"


@implementation ZKMRNTimeWatch

-(id)initWithPiece:(id)pieceDocument
{
	if(self = [super init]) {
		_pieceDocument = pieceDocument; 
	
	}
	return self; 
}

-(void)dealloc
{
	_pieceDocument = nil; 
	[super dealloc];
}

#pragma mark -

- (Float64)currentTime
{
	//NSLog(@"Get Current Time: %f", _currentTime);
	return _currentTime;
}

-(void)setCurrentTime:(Float64)currentTime
{
	//NSLog(@"CurrentTime: %f", currentTime);
	[self willChangeValueForKey: @"currentMM"];
	[self willChangeValueForKey: @"currentSS"];
	[self willChangeValueForKey: @"currentMS"];
	[self willChangeValueForKey: @"currentMMToGo"];
	[self willChangeValueForKey: @"currentSSToGo"];
	[self willChangeValueForKey: @"currentMSToGo"];
	_currentTime = currentTime;
	[self didChangeValueForKey: @"currentMM"];
	[self didChangeValueForKey: @"currentSS"];
	[self didChangeValueForKey: @"currentMS"];	
	[self didChangeValueForKey: @"currentMMToGo"];
	[self didChangeValueForKey: @"currentSSToGo"];
	[self didChangeValueForKey: @"currentMSToGo"];	
}

#pragma mark -

- (float)currentPosition
{
	if(0==[self duration]) return 0; 
	
	return MAX(0.0, MIN(1.0, [self currentTime] / [self duration]));
}

- (void)setCurrentPosition:(float)pos
{
	//pos = MAX(0.0, MIN(1.0, pos)); //?
	
	//NSLog(@"Set Current Position To: %f", pos);
	
	if([self duration] <= 0) return;
	
	pos = ZKMORClamp(pos, 0.f, 1.f); 
	
	[self setCurrentTime: pos * [self duration]];
	
	if(_pieceDocument) {
		//NSLog(@"Sync Position");
		[(ZKMRNPieceDocument*)_pieceDocument synchronizePosition];
	}
}

#pragma mark -

- (Float64)duration
{
	if(!_pieceDocument) {
		//NSLog(@"Duration: -1");
		return -1.;
	}
	
	NSArray* sources = [(ZKMRNPieceDocument*)_pieceDocument orderedAudioSources];
	if (!sources || ([sources count] < 1)) {
		//NSLog(@"Duration: 3600");
		return 3600.;
	}
	
	Float64 duration = 0.;
	id aSource;
	for (aSource in sources) {
		if([aSource isKindOfClass:[ZKMRNFileSource class]]) {
			duration = MAX(duration, [[(ZKMRNFileSource*)aSource duration] doubleValue]);
		}
	}
	//NSLog(@"Duration: %f", duration);
	
	return (0==duration) ? 3600. : duration;
}

#pragma mark -

- (unsigned)currentMM
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	return mm; //([self duration]<=0) ? 0 : mm; 
}

- (unsigned)currentSS
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	return ss; //([self duration]<=0) ? 0 : ss; 
}

- (unsigned)currentMS
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	return ms; //([self duration]<=0) ? 0 : ms; 
}

#pragma mark -

- (void)setCurrentMM:(unsigned)currentMM
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	MMSSMSToSeconds(currentMM, ss, ms, &_currentTime);
	
	//if([self duration] > 0)
		[self setCurrentPosition:(_currentTime / [self duration])];
	
	[self synchronize];
}


- (void)setCurrentSS:(unsigned)currentSS
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	MMSSMSToSeconds(mm, currentSS, ms, &_currentTime);
	
	//if([self duration] > 0)
		[self setCurrentPosition:(_currentTime / [self duration])];
	
	[self synchronize];
}


- (void)setCurrentMS:(unsigned)currentMS 
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	MMSSMSToSeconds(mm, ss, currentMS, &_currentTime);
	
	//if([self duration] > 0)
		[self setCurrentPosition:(_currentTime / [self duration])];
	
	[self synchronize];
}

#pragma mark -

- (unsigned)currentMMToGo
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS([self duration]-now, &mm, &ss, &ms);
	
	return ([self currentPosition]==1. || [self currentPosition]==0.) ? 0 : mm; 
}
- (unsigned)currentSSToGo
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS([self duration]-now, &mm, &ss, &ms);
		
	return ([self currentPosition]==1. || [self currentPosition]==0.) ? 0 : ss; 
}
- (unsigned)currentMSToGo
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS([self duration]-now, &mm, &ss, &ms);
	
	if(ms>=1000) ms = 0;
	
	return ([self currentPosition]==1. || [self currentPosition]==0.) ? 0 : ms; 
}

#pragma mark -

-(void)synchronize
{
	if(!_pieceDocument) return; 
	
	if ([(ZKMRNPieceDocument*)_pieceDocument isPlaying]) 
		[(ZKMRNPieceDocument*)_pieceDocument synchronizeCurrentTimeToGraph];	
}




@end
