//
//  OSCController.m
//  OSCTestProgram
//
//  Created by Jens on 30.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "OSCController.h"


@implementation OSCController

-(id)init
{
	if(self = [super init]) {
				
		_oscManager = [[OSCManager alloc] init]; 
		[_oscManager setDelegate:self];
		
		_inPort = nil; 
		_outPorts = nil; 
		
		_isSending = NO; 
		
		startTime = [[NSDate date] timeIntervalSince1970]; 
		
		_zirkoniumSystem = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
		
		_startToggled = NO;
		_stopToggled  = NO;
		
		
		[self updateTimers];
	}
	
	return self; 
}

-(void)dealloc
{
	[self stopOscSendTimer];
	
	if(_oscManager) {
		[_oscManager setDelegate:nil];
		[_oscManager deleteAllInputs];
		[_oscManager deleteAllOutputs];
		[_oscManager release];
		_oscManager = nil; 
	}
	
	if(_inPort)		[_inPort release];
	if(_outPorts)	[_outPorts release];
	
	[super dealloc];
}

#pragma mark -

-(void)setEnableReceive:(BOOL)flag { _enableReceive = flag; }
-(BOOL)enableReceive { return _enableReceive; }


#pragma mark -

-(void)configureInput:(NSNumber*)port
{
	if(_inPort && [_inPort port] == [port intValue]) return; 
	
	if(_inPort) {
		[_oscManager removeInput:_inPort];
		[_inPort release];
	}
	
	NSLog(@"Input Port: %d", [port intValue]);
	
	_inPort = [_oscManager createNewInputForPort:[port intValue]];
	
	if(_inPort==nil)
		NSLog(@"Error: OSC Input Port could not be created.");
		
	[_inPort retain]; 
}

-(void)configureOutputs:(NSArrayController*)outputs
{
	if(_outPorts) {
		[_oscManager deleteAllOutputs];
		[_outPorts release];
	}
	
	_outPorts = [[NSMutableArray alloc] init]; 
	
	id output;
	for(output in [outputs arrangedObjects]) {
		OSCOutPort* outPort = [_oscManager createNewOutputToAddress:[output valueForKey:@"address"] atPort:[[output valueForKey:@"port"] intValue]];
		[_outPorts addObject:outPort];
		if(outPort==nil)
			NSLog(@"Error: OSC Output Port could not be created.");
	}
}

#pragma mark -

-(void)postOSCStart:(BOOL)flag 
{ 
	id outPort; 
	for(outPort in _outPorts) {
		
		// prepare start message ...
		OSCMessage		*msgStart			= nil;
		OSCPacket		*packetStart		= nil;
	
		msgStart = [OSCMessage createWithAddress:@"/start"];
		if(flag)
			[msgStart addInt:1];
		else 
			[msgStart addInt:0];
			
		packetStart = [OSCPacket createWithContent:msgStart];
		
		//send ...
		[outPort sendThisPacket:packetStart];
//					[self postOSC];
	}
}

-(void)postOSCStop:(BOOL)flag 
{  
	id outPort; 
	for(outPort in _outPorts) {
		
		// prepare stop message ...
		OSCMessage		*msgStop			= nil;
		OSCPacket		*packetStop			= nil;
	
		msgStop = [OSCMessage createWithAddress:@"/stop"];
		if(flag)
			[msgStop addInt:1];
		else
			[msgStop addInt:0];
			
		packetStop = [OSCPacket createWithContent:msgStop];
		
		//	send ...
		[outPort sendThisPacket:packetStop];
	}
}

#pragma mark -

-(void)postOSC
{
	id outPort; 
	for(outPort in _outPorts) {
		
		// prepare time message ...
		OSCMessage		*msgTime			= nil;
		OSCPacket		*packetTime			= nil;
	
		msgTime = [OSCMessage createWithAddress:@"/time"];
		[msgTime addFloat:[[[_zirkoniumSystem playingPiece] timeWatch] currentTime]];
		packetTime = [OSCPacket createWithContent:msgTime];
		
		//	send ...
		[outPort sendThisPacket:packetTime];
	}
}

// Callback for received Messages ...
- (void) receivedOSCMessage:(OSCMessage *)m	
{
	//NSLog(@"%@", [m address]);
	
	if(_enableReceive) {
		
		NSString* address = [m address];
				
		if([address isEqualToString:@"/pan/az"]) {
			[self panAz:m];
		} else if([address isEqualToString:@"/pan/speaker/az"]) {
			[self panSpeakerAz:m];
		} else if([address isEqualToString:@"/pan/speaker/xy"]) {
			[self panSpeakerXy:m];
		} else if([address isEqualToString:@"/pan/speaker"]) {
			[self panSpeakerAz:m];
		} else if([address isEqualToString:@"/pan/xy"]) {
			[self panXy:m];
		} else if([address isEqualToString:@"/master/gain"]) {
			float gain = 1.f; 
			if([m valueCount]==1) {
				if(OSCValFloat==[[m value] type]) 
					gain = [[m value] floatValue];
				if(OSCValInt==[[m value] type]) 
					gain = [[m value] intValue];
			}	
			[self masterGain:gain];
		} else if([address isEqualToString:@"/start"]) {
			
			// Start ...
			if([m valueCount]==1 && [[m value] intValue]==1) {
				if([_zirkoniumSystem playingPiece]) {
					if(![[_zirkoniumSystem playingPiece] isPlaying])
						[[NSNotificationCenter defaultCenter] postNotificationName:@"OSCSenderToggledPlayNotification" object:nil];
				}
				else {
					if(![[_zirkoniumSystem currentPieceDocument] isPlaying])
						[[NSNotificationCenter defaultCenter] postNotificationName:@"OSCSenderToggledPlayNotification" object:nil];
				}
			}
		} else if([address isEqualToString:@"/stop"]) {
			
			// Stop ...
			if([m valueCount]==1 && [[m value] intValue]==1) {
				if([_zirkoniumSystem playingPiece]) {
					if([[_zirkoniumSystem playingPiece] isPlaying])
						[[NSNotificationCenter defaultCenter] postNotificationName:@"OSCSenderToggledPlayNotification" object:nil];
				}
			}
		} else if([address isEqualToString:@"/moveToStart"]) {
			
			// Move To Start ...
			if([m valueCount]==1 && [[m value] intValue]==1) {
				if([_zirkoniumSystem playingPiece]) {
					if(![[_zirkoniumSystem playingPiece] isPlaying])
						[[NSNotificationCenter defaultCenter] postNotificationName:@"OSCSenderMoveToStartNotification" object:nil];
				}
			}
		}
		
	}
}

#pragma mark -

-(void)panAz:(OSCMessage*)message
{
	int n = [message valueCount];
	NSArray* values = [message valueArray];
	
	int channel;
	ZKMNRSphericalCoordinate center;
	ZKMNRSphericalCoordinateSpan span;
	float gain;
	NSString* target;
	center.radius = 1.f;

	if(n==6 || n==7) {
		channel				= (OSCValInt   ==[(OSCValue*)[values objectAtIndex:0] type]) ? [(OSCValue*)[values objectAtIndex:0] intValue] : 0; 
		if(OSCValFloat ==[(OSCValue*)[values objectAtIndex:0] type]) 
			channel = (int)[(OSCValue*)[values objectAtIndex:0] floatValue]; 
			
		center.azimuth		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:1] type]) ? [(OSCValue*)[values objectAtIndex:1] floatValue]  : 0.f; 
		center.zenith		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:2] type]) ? [(OSCValue*)[values objectAtIndex:2] floatValue]  : 0.f;
		span.azimuthSpan	= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:3] type]) ? [(OSCValue*)[values objectAtIndex:3] floatValue]  : 0.f;
		span.zenithSpan		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:4] type]) ? [(OSCValue*)[values objectAtIndex:4] floatValue]  : 0.f;
		
		
		gain = 1.0; 
		if(OSCValFloat ==[(OSCValue*)[values objectAtIndex:5] type]) {
			gain = [(OSCValue*)[values objectAtIndex:5] floatValue];
		} else if(OSCValInt ==[(OSCValue*)[values objectAtIndex:5] type]) {
			gain = [(OSCValue*)[values objectAtIndex:5] intValue];
		}

		target		= (n==7 && OSCValString==[(OSCValue*)[values objectAtIndex:6] type]) ? [(OSCValue*)[values objectAtIndex:6] stringValue] : @"";
		
		if (span.azimuthSpan < 0.f) span.azimuthSpan = 0.f;
		if (span.azimuthSpan > 2.f) span.azimuthSpan = 2.f;
		if (span.zenithSpan < 0.f) span.zenithSpan = 0.f;
		if (span.zenithSpan > 0.5f) span.zenithSpan = 0.5f;
		[self panChannel: channel az: center span: span gain: gain target: target];
	} else {
		NSLog(@"Incoming OSC Message needs 6 or 7 parameters ...");
	}	
}

-(void)panXy:(OSCMessage*)message
{
	int n = [message valueCount];
	NSArray* values = [message valueArray];
	
	int channel;
	ZKMNRRectangularCoordinate center;
	ZKMNRRectangularCoordinateSpan span;
	float gain;
	NSString* target;
	center.z = 0.f;
	span.zSpan = 0.f; 

	if(n==6 || n==7) {
		channel			= (OSCValInt   ==[(OSCValue*)[values objectAtIndex:0] type]) ? [(OSCValue*)[values objectAtIndex:0] intValue]    : 0; 
		if(OSCValFloat ==[(OSCValue*)[values objectAtIndex:0] type]) 
			channel = (int)[(OSCValue*)[values objectAtIndex:0] floatValue]; 
		center.x		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:1] type]) ? [(OSCValue*)[values objectAtIndex:1] floatValue]  : 0.f; 
		center.y		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:2] type]) ? [(OSCValue*)[values objectAtIndex:2] floatValue]  : 0.f;
		span.xSpan		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:3] type]) ? [(OSCValue*)[values objectAtIndex:3] floatValue]  : 0.f;
		span.ySpan		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:4] type]) ? [(OSCValue*)[values objectAtIndex:4] floatValue]  : 0.f;
		
		gain = 1.0; 
		if(OSCValFloat ==[(OSCValue*)[values objectAtIndex:5] type]) {
			gain = [(OSCValue*)[values objectAtIndex:5] floatValue];
		} else if(OSCValInt ==[(OSCValue*)[values objectAtIndex:5] type]) {
			gain = [(OSCValue*)[values objectAtIndex:5] intValue];
		}
		
		target		    = (n==7 && OSCValString==[(OSCValue*)[values objectAtIndex:6] type]) ? [(OSCValue*)[values objectAtIndex:6] stringValue] : @"";
		
		if (span.xSpan < 0.f) span.xSpan = 0.f;
		if (span.xSpan > 2.f) span.xSpan = 2.f;
		if (span.ySpan < 0.f) span.ySpan = 0.f;
		if (span.ySpan > 2.f) span.ySpan = 2.f;
		[self panChannel: channel xy: center span: span gain: gain target: target];
	} else {
		NSLog(@"Incoming OSC Message needs 6 or 7 parameters ...");
	}	
}

-(void)panSpeakerAz:(OSCMessage*)message
{
	int n = [message valueCount];
	NSArray* values = [message valueArray];
	
	int channel;
	ZKMNRSphericalCoordinate center;
	float gain;
	NSString* target;
	center.radius = 1.f;

	if(n==4 || n==5) {
		channel				= (OSCValInt   ==[(OSCValue*)[values objectAtIndex:0] type]) ? [(OSCValue*)[values objectAtIndex:0] intValue]    : 0; 
		if(OSCValFloat ==[(OSCValue*)[values objectAtIndex:0] type]) 
			channel = (int)[(OSCValue*)[values objectAtIndex:0] floatValue]; 
		center.azimuth		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:1] type]) ? [(OSCValue*)[values objectAtIndex:1] floatValue]  : 0.f; 
		center.zenith		= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:2] type]) ? [(OSCValue*)[values objectAtIndex:2] floatValue]  : 0.f;
		
		gain = 1.0; 
		if(OSCValFloat ==[(OSCValue*)[values objectAtIndex:3] type]) {
			gain = [(OSCValue*)[values objectAtIndex:3] floatValue];
		} else if(OSCValInt ==[(OSCValue*)[values objectAtIndex:3] type]) {
			gain = [(OSCValue*)[values objectAtIndex:3] intValue];
		}
		
		target				= (n==5 && OSCValString==[(OSCValue*)[values objectAtIndex:4] type]) ? [(OSCValue*)[values objectAtIndex:4] stringValue] : @"";
		[self panChannel: channel speakerAz: center gain: gain target: target];
	} else {
		NSLog(@"Incoming OSC Message needs 4 or 5 parameters ...");
	}	
}

-(void)panSpeakerXy:(OSCMessage*)message
{
	int n = [message valueCount];
	NSArray* values = [message valueArray];
	
	int channel;
	ZKMNRRectangularCoordinate center;
	float gain;
	NSString* target;
	center.z = 0.f;

	if(n==4 || n==5) {
		channel				= (OSCValInt   ==[(OSCValue*)[values objectAtIndex:0] type]) ? [(OSCValue*)[values objectAtIndex:0] intValue]    : 0;
		if(OSCValFloat ==[(OSCValue*)[values objectAtIndex:0] type]) 
			channel = (int)[(OSCValue*)[values objectAtIndex:0] floatValue];  
		center.x			= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:1] type]) ? [(OSCValue*)[values objectAtIndex:1] floatValue]  : 0.f; 
		center.y			= (OSCValFloat ==[(OSCValue*)[values objectAtIndex:2] type]) ? [(OSCValue*)[values objectAtIndex:2] floatValue]  : 0.f;
		gain = 1.0; 
		if(OSCValFloat ==[(OSCValue*)[values objectAtIndex:3] type]) {
			gain = [(OSCValue*)[values objectAtIndex:3] floatValue];
		} else if(OSCValInt ==[(OSCValue*)[values objectAtIndex:3] type]) {
			gain = [(OSCValue*)[values objectAtIndex:3] intValue];
		}

		target				= (n==5 && OSCValString==[(OSCValue*)[values objectAtIndex:4] type]) ? [(OSCValue*)[values objectAtIndex:4] stringValue] : @"";
		
		[self panChannel: channel speakerXy: center gain: gain target: target];
	} else {
		NSLog(@"Incoming OSC Message needs 4 or 5 parameters ...");
	}	
}

#pragma mark -

- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain target:(NSString*)target
{
	NSDictionary* arguments = [NSDictionary dictionaryWithObjectsAndKeys:	
							   [NSNumber numberWithUnsignedInt:channel], @"channel",
							   [NSNumber numberWithFloat:center.azimuth], @"azimuth",
							   [NSNumber numberWithFloat:center.zenith], @"zenith",
							   [NSNumber numberWithFloat:span.azimuthSpan], @"azimuthSpan",
							   [NSNumber numberWithFloat:span.zenithSpan], @"zenithSpan",
							   [NSNumber numberWithFloat:gain], @"gain", nil];
	
	// The OSCController receives events in it's own run loop, to asure that panning only takes 
	// place in the main run loop use performSelectorOnMainThread instead direct calling of function
	// in Zirkonium. Else sound has "holes" from time to time.
	
	[_zirkoniumSystem performSelectorOnMainThread:@selector(panChannelAz:) withObject:arguments waitUntilDone:NO];
	//[_zirkoniumSystem panChannel: channel az: center span: span gain: gain];		
}

- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain target:(NSString*)target
{
	NSDictionary* arguments = [NSDictionary dictionaryWithObjectsAndKeys:	
							   [NSNumber numberWithUnsignedInt:channel], @"channel",
							   [NSNumber numberWithFloat:center.x], @"x",
							   [NSNumber numberWithFloat:center.y], @"y",
							   [NSNumber numberWithFloat:span.xSpan], @"xSpan",
							   [NSNumber numberWithFloat:span.ySpan], @"ySpan",
							   [NSNumber numberWithFloat:gain], @"gain", nil];

	[_zirkoniumSystem performSelectorOnMainThread:@selector(panChannelXy:) withObject:arguments waitUntilDone:NO];
	//[_zirkoniumSystem panChannel: channel xy: center span: span gain: gain];
}

- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain target:(NSString*)target
{
	NSDictionary* arguments = [NSDictionary dictionaryWithObjectsAndKeys:	
							   [NSNumber numberWithUnsignedInt:channel], @"channel",
							   [NSNumber numberWithFloat:center.azimuth], @"azimuth",
							   [NSNumber numberWithFloat:center.zenith], @"zenith",
							   [NSNumber numberWithFloat:gain], @"gain", nil];

	[_zirkoniumSystem performSelectorOnMainThread:@selector(panChannelSpeakerAz:) withObject:arguments waitUntilDone:NO];		
	//[_zirkoniumSystem panChannel: channel speakerAz: center gain: gain];
}

- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain target:(NSString*)target
{

	NSDictionary* arguments = [NSDictionary dictionaryWithObjectsAndKeys:	
							   [NSNumber numberWithUnsignedInt:channel], @"channel",
							   [NSNumber numberWithFloat:center.x], @"x",
							   [NSNumber numberWithFloat:center.y], @"y",
							   [NSNumber numberWithFloat:gain], @"gain", nil];

	[_zirkoniumSystem performSelectorOnMainThread:@selector(panChannelSpeakerYy:) withObject:arguments waitUntilDone:NO];
	//[_zirkoniumSystem panChannel: channel speakerXy: center gain: gain];
}


- (void)masterGain:(float)gain
{
	[[_zirkoniumSystem preferencesController] performSelectorOnMainThread:@selector(setMasterGain:) withObject:[NSNumber numberWithFloat:gain] waitUntilDone:NO];
}

#pragma mark -

-(void)updateTimers
{
	[self startOscSendTimer];
}

-(void)startOscSendTimer
{
	[self stopOscSendTimer];
	
	//validate ...
	int value = [[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] valueForKey:@"sendInterval"] intValue];
	if(value < 1) {
		[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] willChangeValueForKey:@"sendInterval"];
		[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] setValue:[NSNumber numberWithInt:1] forKey:@"sendInterval"]; 
		[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] didChangeValueForKey:@"sendInterval"];
	}
	if(value > 100) {
		[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] willChangeValueForKey:@"sendInterval"];
		[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] setValue:[NSNumber numberWithInt:100] forKey:@"sendInterval"]; 
		[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] didChangeValueForKey:@"sendInterval"];
	}
	
	_sendInterval = 1.f / [[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] valueForKey:@"sendInterval"] intValue]; 
		
	_isSending = [[[[_zirkoniumSystem studioSetupDocument] oscConfiguration] valueForKey:@"enableSend"] boolValue];
	
	if(_isSending) {
		_oscSendTimerThread = [[NSThread alloc] initWithTarget:self selector:@selector(startOscSendTimerThread) object:nil]; //Create a new thread
		[_oscSendTimerThread start]; //start the thread
	}
}

-(void) startOscSendTimerThread
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
	_oscSendTimer = [[NSTimer scheduledTimerWithTimeInterval:_sendInterval target:self selector:@selector(tickOscSend:) userInfo:nil repeats:YES] retain];
	[_oscSendTimer retain];
	
	[runLoop run];
	
	[pool release];
}


-(void)stopOscSendTimer
{
	_isSending = NO; 
	if(_oscSendTimer) {		
		[_oscSendTimer invalidate];
		[_oscSendTimer release];
		_oscSendTimer = nil; 
	}
}

#pragma mark -

-(void)tickOscSend:(NSTimer*)timer
{	
	[self postOSC]; 
}

@end
