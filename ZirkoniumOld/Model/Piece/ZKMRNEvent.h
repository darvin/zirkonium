//
//  ZKMRNEvent.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 05.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ZKMNREventScheduler;
@interface ZKMRNEvent : NSManagedObject {

}

//  Accessors
- (void)setStartTime:(NSNumber *)startTime;
- (void)setDuration:(NSNumber *)duration;

//  Actions
- (void)scheduleEvents:(ZKMNREventScheduler *)scheduler;

//  Start Time Accessors
- (NSNumber *)startTimeHH;
- (void)setStartTimeHH:(NSNumber *)anUnsigned;
- (NSNumber *)startTimeMM;
- (void)setStartTimeMM:(NSNumber *)anUnsigned;
- (NSNumber *)startTimeSS;
- (void)setStartTimeSS:(NSNumber *)anUnsigned;
- (NSNumber *)startTimeMS;
- (void)setStartTimeMS:(NSNumber *)anUnsigned;
- (NSString *)startTimeMMSSMS;
- (void)setStartTimeMMSSMS:(NSString *)startTimeMMSSMS;

//  End Time Accessors
- (Float64)endTimeSeconds;
- (NSNumber *)endTimeHH;
- (void)setEndTimeHH:(NSNumber *)anUnsigned;
- (NSNumber *)endTimeMM;
- (void)setEndTimeMM:(NSNumber *)anUnsigned;
- (NSNumber *)endTimeSS;
- (void)setEndTimeSS:(NSNumber *)anUnsigned;
- (NSNumber *)endTimeMS;
- (void)setEndTimeMS:(NSNumber *)anUnsigned;

//  A string description of the event parameters
- (NSString *)summary;

@end


@interface ZKMRNEvent (ZKMRNEventInternal)

- (void)privateSetStartTime:(NSNumber *)startTime;
- (void)privateSetDuration:(NSNumber *)duration;
- (void)privateClearStartTimeSeconds;
- (void)privateClearEndTimeSeconds;

- (NSString *)computeSummary;
- (BOOL)isSpherical;
- (BOOL)isCartesian;
- (NSString *)eventType;

@end