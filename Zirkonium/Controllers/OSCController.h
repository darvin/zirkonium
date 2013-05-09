//
//  OSCController.h
//  OSCTestProgram
//
//  Created by Jens on 30.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VVOSC/VVOSC.h"

#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNStudioSetupDocument.h" 

@interface OSCController : NSObject {
	
	ZKMRNZirkoniumSystem* _zirkoniumSystem;
	
	OSCManager*		_oscManager; 
	OSCInPort*		_inPort; 
	NSMutableArray*	_outPorts; 
	
	BOOL _enableReceive; 
	
	float startTime; 
	
	float _sendInterval; 
	
	NSTimer* _oscSendTimer;
	NSThread* _oscSendTimerThread; 
	
	BOOL _startToggled;
	BOOL _stopToggled; 
			
	BOOL _isSending; 
}


-(void)postOSCStart:(BOOL)flag;
-(void)postOSCStop:(BOOL)flag;
-(void)postOSC;

-(void)configureInput:(NSNumber*)port;
-(void)configureOutputs:(NSArrayController*)outputs;

-(void)setEnableReceive:(BOOL)flag;
-(BOOL)enableReceive; 

-(void)updateTimers;
-(void)startOscSendTimer;
-(void)stopOscSendTimer; 

- (void)panAz:(OSCMessage*)message;
- (void)panXy:(OSCMessage*)message;
- (void)panSpeakerAz:(OSCMessage*)message;
- (void)panSpeakerXy:(OSCMessage*)message;

- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain target:(NSString*)target;
- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain target:(NSString*)target;
- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain target:(NSString*)target;
- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain target:(NSString*)target;
- (void)masterGain:(float)gain;

@end
