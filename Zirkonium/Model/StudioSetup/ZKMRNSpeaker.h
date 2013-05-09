//
//  ZKMRNSpeaker.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 31.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>


@interface ZKMRNSpeaker : NSManagedObject {
	NSNumber* _x; 
	NSNumber* _y;  
	NSNumber* _z; 
	
	NSNumber* _oldX; 
	NSNumber* _oldY;  
	NSNumber* _oldZ; 
	
	NSNumber* _newX; 
	NSNumber* _newY;  
	NSNumber* _newZ; 
	  
	BOOL _isManipulating; //flag for undo of mouse changes 
	
	ZKMNRSpeakerPosition * _speakerPosition; 
} 

//  Accessors
- (void)setPositionX:(NSNumber *)pos;
- (void)setPositionY:(NSNumber *)pos;
- (void)setPositionZ:(NSNumber *)pos;
- (ZKMNRSpeakerPosition *)speakerPosition;

// for undo / redo of mouse 
-(void)startManipulating;
-(void)stopManipulating; 

@end
