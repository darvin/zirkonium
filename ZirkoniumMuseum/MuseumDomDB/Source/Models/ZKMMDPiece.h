//
//  ZKMMDPiece.h
//  MuseumDomDB
//
//  Created by C. Ramakrishnan on 10.07.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@protocol ZKMMDPieceDelegate; 

@interface ZKMMDPiece :  NSManagedObject {
	id<ZKMMDPieceDelegate> delegate; 
}
@property (nonatomic, assign) id<ZKMMDPieceDelegate> delegate; 

@property (nonatomic, retain) NSString * composer;
@property (nonatomic, retain) NSString * index;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * path;

@property (nonatomic, retain) NSString * textEN;
@property (nonatomic, retain) NSString * textDE;

@property (nonatomic, retain) NSAttributedString * textENAttributed;
@property (nonatomic, retain) NSAttributedString * textDEAttributed;

@property (nonatomic, retain) NSNumber * masterGain;

@property (nonatomic, retain) NSString* lightPresetName; 

- (NSArray *)children;

- (NSString *)composerTitleString;
- (NSString *)duration; 

@end

@protocol ZKMMDPieceDelegate

-(NSString*)durationString; 
-(NSString*)ellapsedString;
@end

