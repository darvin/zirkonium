//
//  ZKMRNGraph.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 05.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* ZKMRNGraphNumberOfDirectOutsChanged;


@interface ZKMRNGraph : NSManagedObject {

}

-(void)addChannel;
-(void)removeChannelWithNumber:(NSNumber*)number;
//-(BOOL)canRemoveChannel;


//  Accessors
- (void)setNumberOfChannels:(NSNumber *)numberOfChannels;
- (void)setNumberOfDirectOuts:(NSNumber *)numberOfDirectOuts;
- (void)setDuration:(NSNumber *)duration;

//  Duration Accessors
- (NSNumber *)durationHH;
- (void)setDurationHH:(NSNumber *)anUnsigned;
- (NSNumber *)durationMM;
- (void)setDurationMM:(NSNumber *)anUnsigned;
- (NSNumber *)durationSS;
- (void)setDurationSS:(NSNumber *)anUnsigned;
- (NSNumber *)durationMS;
- (void)setDurationMS:(NSNumber *)anUnsigned;

@end
