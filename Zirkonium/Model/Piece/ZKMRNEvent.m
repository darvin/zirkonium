//
//  ZKMRNEvent.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 05.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNEvent.h"


@implementation ZKMRNEvent

#pragma mark _____ Accessors
- (void)setStartTime:(NSNumber *)startTime
{
	[self privateSetStartTime: startTime];
	[self privateClearStartTimeSeconds];
}

- (void)setDuration:(NSNumber *)duration
{
	[self privateSetDuration: duration];
	[self privateClearEndTimeSeconds];
}

#pragma mark -
#pragma mark Actions
	// subclass responsibility
- (void)scheduleEvents:(ZKMNREventScheduler *)scheduler { }

#pragma mark _____ Start Time Accessors
- (NSNumber *)startTimeHH
{
	[self willAccessValueForKey: @"startTimeHH"];
	NSNumber* startTimeHH = [self primitiveValueForKey: @"startTimeHH"];
	[self didAccessValueForKey: @"startTimeHH"];

	if (startTimeHH == nil) {
		NSNumber* startTime = [self valueForKey: @"startTime"];
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([startTime doubleValue], &hh, &mm, &ss, &ms);
		startTimeHH = [NSNumber numberWithUnsignedInt: hh];
		[self setPrimitiveValue: startTimeHH  forKey: @"startTimeHH"];
	}
	return startTimeHH;
}

- (void)setStartTimeHH:(NSNumber *)anUnsigned
{
	NSNumber* startTime = [self valueForKey: @"startTime"];
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([startTime doubleValue], &hh, &mm, &ss, &ms);
	Float64 secs; HHMMSSMSToSeconds([anUnsigned unsignedIntValue], mm, ss, ms, &secs);
	
	[self willChangeValueForKey: @"startTimeHH"];
	[self setPrimitiveValue: anUnsigned forKey: @"startTimeHH"];
	[self didChangeValueForKey: @"startTimeHH"];
	[self privateSetStartTime: [NSNumber numberWithDouble: secs]];
}

- (NSNumber *)startTimeMM
{
	[self willAccessValueForKey: @"startTimeMM"];
	NSNumber* startTimeMM = [self primitiveValueForKey: @"startTimeMM"];
	[self didAccessValueForKey: @"startTimeMM"];
	if (startTimeMM == nil) {
		NSNumber* startTime = [self valueForKey: @"startTime"];
		unsigned mm, ss, ms; SecondsToMMSSMS([startTime doubleValue], &mm, &ss, &ms);
		startTimeMM = [NSNumber numberWithUnsignedInt: mm];
		[self setPrimitiveValue: startTimeMM  forKey: @"startTimeMM"];
	}
	return startTimeMM;
}

- (void)setStartTimeMM:(NSNumber *)anUnsigned
{
	NSNumber* startTime = [self valueForKey: @"startTime"];
	unsigned mm, ss, ms; SecondsToMMSSMS([startTime doubleValue], &mm, &ss, &ms);
	Float64 secs; MMSSMSToSeconds([anUnsigned unsignedIntValue], ss, ms, &secs);
	
	[self willChangeValueForKey: @"startTimeMM"];
	[self setPrimitiveValue: anUnsigned forKey: @"startTimeMM"];
	[self didChangeValueForKey: @"startTimeMM"];
	[self privateSetStartTime: [NSNumber numberWithDouble: secs]];
}

- (NSNumber *)startTimeSS
{
	[self willAccessValueForKey: @"startTimeSS"];
	NSNumber* startTimeSS = [self primitiveValueForKey: @"startTimeSS"];
	[self didAccessValueForKey: @"startTimeSS"];
	if (startTimeSS == nil) {
		NSNumber* startTime = [self valueForKey: @"startTime"];
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([startTime doubleValue], &hh, &mm, &ss, &ms);
		startTimeSS = [NSNumber numberWithUnsignedInt: ss];
		[self setPrimitiveValue: startTimeSS  forKey: @"startTimeSS"];
	}
	return startTimeSS;
}

- (void)setStartTimeSS:(NSNumber *)anUnsigned
{
	NSNumber* startTime = [self valueForKey: @"startTime"];
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([startTime doubleValue], &hh, &mm, &ss, &ms);
	Float64 secs; HHMMSSMSToSeconds(hh, mm, [anUnsigned unsignedIntValue], ms, &secs);
	
	[self willChangeValueForKey: @"startTimeSS"];
	[self setPrimitiveValue: anUnsigned forKey: @"startTimeSS"];
	[self didChangeValueForKey: @"startTimeSS"];
	[self privateSetStartTime: [NSNumber numberWithDouble: secs]];
}

- (NSNumber *)startTimeMS
{
	[self willAccessValueForKey: @"startTimeMS"];
	NSNumber* startTimeMS = [self primitiveValueForKey: @"startTimeMS"];
	[self didAccessValueForKey: @"startTimeMS"];
	if (startTimeMS == nil) {
		NSNumber* startTime = [self valueForKey: @"startTime"];
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([startTime doubleValue], &hh, &mm, &ss, &ms);
		startTimeMS = [NSNumber numberWithUnsignedInt: ms];
		[self setPrimitiveValue: startTimeMS  forKey: @"startTimeMS"];
	}
	return startTimeMS;
}

- (void)setStartTimeMS:(NSNumber *)anUnsigned
{
	NSNumber* startTime = [self valueForKey: @"startTime"];
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([startTime doubleValue], &hh, &mm, &ss, &ms);
	Float64 secs; HHMMSSMSToSeconds(hh, mm, ss, [anUnsigned unsignedIntValue], &secs);

	[self willChangeValueForKey: @"startTimeMS"];
	[self setPrimitiveValue: anUnsigned forKey: @"startTimeMS"];
	[self didChangeValueForKey: @"startTimeMS"];
	[self privateSetStartTime: [NSNumber numberWithDouble: secs]];
}

- (NSString *)startTimeMMSSMS
{
	[self willAccessValueForKey: @"startTimeMMSSMS"];
	NSNumber* startTime = [self valueForKey: @"startTime"];
	[self didAccessValueForKey: @"startTimeMMSSMS"];
	
	unsigned mm, ss, ms; SecondsToMMSSMS([startTime doubleValue], &mm, &ss, &ms);
	return [NSString stringWithFormat: @"%u:%.2u:%.3u", mm, ss, ms];
}

- (void)setStartTimeMMSSMS:(NSString *)startTimeMMSSMS
{
	int mm, ss, ms;
	NSMutableCharacterSet* mmssmsCharacterSetToSkip = [[NSMutableCharacterSet alloc] init];
	[mmssmsCharacterSetToSkip formUnionWithCharacterSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[mmssmsCharacterSetToSkip addCharactersInString: @":"];
	
	NSScanner* mmssmsScanner = [NSScanner scannerWithString: startTimeMMSSMS];	
	[mmssmsScanner setCharactersToBeSkipped: mmssmsCharacterSetToSkip];
	[mmssmsCharacterSetToSkip release];
	
	[mmssmsScanner scanInt: &mm];
	[mmssmsScanner scanInt: &ss];
	[mmssmsScanner scanInt: &ms];
	
	mm = MAX(mm, 0);
	ss = MAX(ss, 0); ss = MIN(ss, 59);
	ms = MAX(ms, 0); ms = MIN(ms, 999);

	Float64 secs; MMSSMSToSeconds(mm, ss, ms, &secs);
	[self setStartTime: [NSNumber numberWithDouble: secs]];	
}

#pragma mark _____ End Time Accessors
- (Float64)endTimeSeconds { return [[self valueForKey: @"startTime"] doubleValue] + [[self valueForKey: @"duration"] doubleValue]; }
- (NSNumber *)endTimeHH
{
	[self willAccessValueForKey: @"endTimeHH"];
	NSNumber* endTimeHH = [self primitiveValueForKey: @"endTimeHH"];
	[self didAccessValueForKey: @"endTimeHH"];

	if (endTimeHH == nil) {
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([self endTimeSeconds], &hh, &mm, &ss, &ms);
		endTimeHH = [NSNumber numberWithUnsignedInt: hh];
		[self setPrimitiveValue: endTimeHH  forKey: @"endTimeHH"];
	}
	return endTimeHH;
}

- (void)setEndTimeHH:(NSNumber *)anUnsigned
{
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([self endTimeSeconds], &hh, &mm, &ss, &ms);
	Float64 endSecs; HHMMSSMSToSeconds([anUnsigned unsignedIntValue], mm, ss, ms, &endSecs);
	NSNumber* startTime = [self valueForKey: @"startTime"];	
	double durSecs = endSecs - [startTime doubleValue];
	
	[self willChangeValueForKey: @"endTimeHH"];
	[self setPrimitiveValue: anUnsigned forKey: @"endTimeHH"];
	[self didChangeValueForKey: @"endTimeHH"];
	[self privateSetDuration: [NSNumber numberWithDouble: durSecs]];
}

- (NSNumber *)endTimeMM
{
	[self willAccessValueForKey: @"endTimeMM"];
	NSNumber* endTimeMM = [self primitiveValueForKey: @"endTimeMM"];
	[self didAccessValueForKey: @"endTimeMM"];

	if (endTimeMM == nil) {
		unsigned mm, ss, ms; SecondsToMMSSMS([self endTimeSeconds], &mm, &ss, &ms);
		endTimeMM = [NSNumber numberWithUnsignedInt: mm];
		[self setPrimitiveValue: endTimeMM  forKey: @"endTimeMM"];
	}
	return endTimeMM;
}

- (void)setEndTimeMM:(NSNumber *)anUnsigned
{
	unsigned mm, ss, ms; SecondsToMMSSMS([self endTimeSeconds], &mm, &ss, &ms);
	Float64 endSecs; MMSSMSToSeconds([anUnsigned unsignedIntValue], ss, ms, &endSecs);
	NSNumber* startTime = [self valueForKey: @"startTime"];	
	double durSecs = endSecs - [startTime doubleValue];
	
	[self willChangeValueForKey: @"endTimeMM"];
	[self setPrimitiveValue: anUnsigned forKey: @"endTimeMM"];
	[self didChangeValueForKey: @"endTimeMM"];
	[self privateSetDuration: [NSNumber numberWithDouble: durSecs]];
}

- (NSNumber *)endTimeSS
{
	[self willAccessValueForKey: @"endTimeSS"];
	NSNumber* endTimeSS = [self primitiveValueForKey: @"endTimeSS"];
	[self didAccessValueForKey: @"endTimeSS"];

	if (endTimeSS == nil) {
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([self endTimeSeconds], &hh, &mm, &ss, &ms);
		endTimeSS = [NSNumber numberWithUnsignedInt: ss];
		[self setPrimitiveValue: endTimeSS  forKey: @"endTimeSS"];
	}
	return endTimeSS;
}

- (void)setEndTimeSS:(NSNumber *)anUnsigned
{
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([self endTimeSeconds], &hh, &mm, &ss, &ms);
	Float64 endSecs; HHMMSSMSToSeconds(hh, mm, [anUnsigned unsignedIntValue], ms, &endSecs);
	NSNumber* startTime = [self valueForKey: @"startTime"];	
	double durSecs = endSecs - [startTime doubleValue];
	
	[self willChangeValueForKey: @"endTimeSS"];
	[self setPrimitiveValue: anUnsigned forKey: @"endTimeSS"];
	[self didChangeValueForKey: @"endTimeSS"];
	[self privateSetDuration: [NSNumber numberWithDouble: durSecs]];
}

- (NSNumber *)endTimeMS
{
	[self willAccessValueForKey: @"endTimeMS"];
	NSNumber* endTimeMS = [self primitiveValueForKey: @"endTimeMS"];
	[self didAccessValueForKey: @"endTimeMS"];

	if (endTimeMS == nil) {
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([self endTimeSeconds], &hh, &mm, &ss, &ms);
		endTimeMS = [NSNumber numberWithUnsignedInt: ms];
		[self setPrimitiveValue: endTimeMS  forKey: @"endTimeMS"];
	}
	return endTimeMS;
}

- (void)setEndTimeMS:(NSNumber *)anUnsigned
{
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS([self endTimeSeconds], &hh, &mm, &ss, &ms);
	Float64 endSecs; HHMMSSMSToSeconds(hh, mm, ss, [anUnsigned unsignedIntValue], &endSecs);
	NSNumber* startTime = [self valueForKey: @"startTime"];	
	double durSecs = endSecs - [startTime doubleValue];
	
	[self willChangeValueForKey: @"endTimeMS"];
	[self setPrimitiveValue: anUnsigned forKey: @"endTimeMS"];
	[self didChangeValueForKey: @"endTimeMS"];
	[self privateSetDuration: [NSNumber numberWithDouble: durSecs]];
}

#pragma mark -

- (NSString *)summary
{
	NSString* summary = [self computeSummary];
	return summary;
}

-(NSString*)comment
{
	[self willAccessValueForKey:@"comment"];
	NSString* comment = [self primitiveValueForKey:@"comment"];
	[self didAccessValueForKey:@"comment"];
	
	if(comment==nil)
	{
		comment = [NSString stringWithString:@"None"];
		[self setPrimitiveValue: comment  forKey: @"comment"];
	}
	return comment;
	
}

-(void)setComment:(NSString*)comment
{
	[self willChangeValueForKey:@"comment"];
	NSString* aComment = [NSString stringWithString:comment];
	[self setPrimitiveValue:aComment forKey:@"comment"];
	[self didChangeValueForKey:@"comment"];
}


#pragma mark _____ ZKMRNEventInternal
- (void)privateSetStartTime:(NSNumber *)startTime
{
	[self willChangeValueForKey: @"startTime"];
	[self setPrimitiveValue: startTime forKey: @"startTime"];
	[self didChangeValueForKey: @"startTime"];
	[self privateClearEndTimeSeconds];
}

- (void)privateSetDuration:(NSNumber *)duration
{
	[self willChangeValueForKey: @"duration"];
	[self setPrimitiveValue: duration forKey: @"duration"];
	[self didChangeValueForKey: @"duration"];	
}

- (void)privateClearStartTimeSeconds
{
	[self willChangeValueForKey: @"startTimeHH"];
	[self setPrimitiveValue: nil  forKey: @"startTimeHH"];
	[self didChangeValueForKey: @"startTimeHH"];
	
	[self willChangeValueForKey: @"startTimeMM"];
	[self setPrimitiveValue: nil  forKey: @"startTimeMM"];
	[self didChangeValueForKey: @"startTimeMM"];
	
	[self willChangeValueForKey: @"startTimeSS"];
	[self setPrimitiveValue: nil  forKey: @"startTimeSS"];
	[self didChangeValueForKey: @"startTimeSS"];
	
	[self willChangeValueForKey: @"startTimeMS"];
	[self setPrimitiveValue: nil  forKey: @"startTimeMS"];
	[self didChangeValueForKey: @"startTimeMS"];
}

- (void)privateClearEndTimeSeconds
{
	[self willChangeValueForKey: @"endTimeHH"];
	[self setPrimitiveValue: nil  forKey: @"endTimeHH"];
	[self didChangeValueForKey: @"endTimeHH"];
	
	[self willChangeValueForKey: @"endTimeMM"];
	[self setPrimitiveValue: nil  forKey: @"endTimeMM"];
	[self didChangeValueForKey: @"endTimeMM"];
	
	[self willChangeValueForKey: @"endTimeSS"];
	[self setPrimitiveValue: nil  forKey: @"endTimeSS"];
	[self didChangeValueForKey: @"endTimeSS"];
	
	[self willChangeValueForKey: @"endTimeMS"];
	[self setPrimitiveValue: nil  forKey: @"endTimeMS"];
	[self didChangeValueForKey: @"endTimeMS"];
}

- (NSString*)computeSummary { return @"None"; }

- (BOOL)isSpherical { return NO; }
- (BOOL)isCartesian { return NO; }
- (NSString *)eventType { return @"ZKMRNEvent"; }

@end
