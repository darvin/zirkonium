//
//  ZKMRNTimeWatch.h
//  Zirkonium
//
//  Created by Jens on 17.09.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNFileSource.h"

@class ZKMRNPieceDocument;
@interface ZKMRNTimeWatch : NSObject {
	
	id _pieceDocument; 
	
	Float64	_currentTime;
}

-(id)initWithPiece:(id)pieceDocument; 

- (Float64)currentTime;
- (void)setCurrentTime:(Float64)currentTime; 
- (Float64)duration;

- (float)currentPosition;
- (void)setCurrentPosition:(float)pos;

- (unsigned)currentMM;
- (unsigned)currentSS;
- (unsigned)currentMS;

- (void)setCurrentMM:(unsigned)currentMM;
- (void)setCurrentSS:(unsigned)currentSS;
- (void)setCurrentMS:(unsigned)currentMS;

- (unsigned)currentMMToGo;
- (unsigned)currentSSToGo;
- (unsigned)currentMSToGo;

- (void)synchronize;


@end
