//
//  ZKMRNLightController.m
//  Zirkonium
//
//  Created by C. Ramakrishnan on 17.10.07.
//  Copyright 2007 Illposed Software. All rights reserved.
//

#import "ZKMRNLightController.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNSpeakerSetup.h"
#include <netinet/in.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>

NSString* ZKMRNLightControllerTableNameKey = @"ZKMRNLightControllerTableNameKey";
NSString* ZKMRNLightControllerTableDataKey = @"ZKMRNLightControllerTableDataKey";
NSString* ZKMRNLightControllerTableSelectionKey = @"ZKMRNLightControllerTableSelectionKey";

@interface ZKMRNLightController (ZKMRNLightControllerPrivate)
- (void)initializeLightTable;
- (void)createLightTimer;
- (void)destroyLightTimer;
//- (void)createLightServerAddressData;
//- (void)clearMessageData;
- (void)sendInitialLightState;
- (void)sendNumberOfLights;
- (void)sendLightPositions;
- (void)sendRunningLightState;
@end


@implementation ZKMRNLightController
@synthesize loadedLightTable; 
@synthesize lightGain; 

#pragma mark -
#pragma mark Initialize
#pragma mark -

- (id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)zirkoniumSystem
{
	if (!(self = [super init])) return nil;
	
	_zirkoniumSystem = zirkoniumSystem;
	_isSendingLighting = NO;
	
	self.lightGain = 1.f;
	
	_lightTimerInterval = 0.1;
	_lightTables = [[NSMutableArray alloc] init];

	_dbLightTableSize = 64;

	[self initializeLightTable];
	
	[self initializeOSC];

	return self;
}


- (void)initializeLightTable
{
	[self setDBLightTableToDefault];
}

- (void)setDBLightTableToDefault
{
	unsigned i;
	float oneOverSize = 1.f / _dbLightTableSize;
	for (i = 0; i < _dbLightTableSize; i++) 
	{
		float scale = i * oneOverSize;
		scale = powf(scale, 4.f);
		_dbLightTable[3*i] = MIN(2.f * scale, 1.f);
		_dbLightTable[3*i + 1] = MIN(4.f * scale, 1.f);
		_dbLightTable[3*i + 2] = MIN(0.7f * scale, 1.f);			
	}
}

#pragma mark -
#pragma mark OSC
#pragma mark -

-(void)initializeOSC 
{

	if(_oscManager) {
		[_oscManager setDelegate:nil];
		[_oscManager deleteAllInputs];
		[_oscManager deleteAllOutputs];
		[_oscManager release];
		_oscManager = nil; 
	}

	if(_outPort)		
		[_outPort release];
	
	_oscManager = [[OSCManager alloc] init]; 
	
	OSCOutPort* outPort = [_oscManager createNewOutputToAddress:@"127.0.0.1" atPort:50808];
	
	if(outPort==nil)
		NSLog(@"Error: OSC Output Port could not be created.");
		
	_outPort = [outPort retain];
	
} 


#pragma mark -
#pragma mark Send Light
#pragma mark -

- (BOOL)isSendingLighting 
{ 
	return _isSendingLighting; 
}

- (void)setSendingLighting:(BOOL)isSendingLighting
{
	_isSendingLighting = isSendingLighting;
	if (_isSendingLighting) {
		[self createLightTimer];
		[self sendInitialLightState];
	} else {
		[self destroyLightTimer];
		[self sendAllLightsOff];
	}
}

#pragma mark -
#pragma mark Timer
#pragma mark -

- (NSTimeInterval)lightTimerInterval { return _lightTimerInterval; }

- (void)setLightTimerInterval:(NSTimeInterval)lightTimerInterval
{
	_lightTimerInterval = lightTimerInterval;

	if (_isSendingLighting) 
		[self createLightTimer];
}

- (void)createLightTimer
{
	[self destroyLightTimer];
	
	_lightTimer = [[NSTimer timerWithTimeInterval: _lightTimerInterval target: self selector: @selector(tick:) userInfo: nil repeats: YES] retain];

	[[NSRunLoop currentRunLoop] addTimer: _lightTimer forMode: NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _lightTimer forMode: NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _lightTimer forMode: NSEventTrackingRunLoopMode];
}

- (void)destroyLightTimer
{
	if(_lightTimer) {
		[_lightTimer invalidate];
		[_lightTimer release];
	} 
	_lightTimer = nil;
}

- (void)tick:(id)timer
{
	if (![_zirkoniumSystem isPlaying] && ![_zirkoniumSystem isGraphTesting]) return;
	[self sendRunningLightState];
}

#pragma mark -
#pragma mark Active Light Table
#pragma mark -

- (float *)dbLightTable 
{ 
	return _dbLightTable; 
}

- (unsigned)dbLightTableSize 
{ 
	return _dbLightTableSize; 
}

- (NSData *)dbLightTableData
{
	return [NSData dataWithBytes: _dbLightTable length: _dbLightTableSize * sizeof(float) * 3];
}

- (void)setDBLightTableData:(NSData *)dbLightTableData
{	
	unsigned lengthToCopy = MIN(_dbLightTableSize * sizeof(float) * 3, [dbLightTableData length]);
	memcpy(_dbLightTable, [dbLightTableData bytes], lengthToCopy);
}

#pragma mark -

- (NSString *)lightTableName 
{ 
	if (!self.loadedLightTable) 
		return nil;
	
	return [self.loadedLightTable objectForKey: ZKMRNLightControllerTableNameKey];
}

- (void)setLightTableName:(NSString *)lightTableName
{
	NSDictionary* oldTable = self.loadedLightTable;
	
	self.loadedLightTable = 
			[NSDictionary dictionaryWithObjectsAndKeys: 
				lightTableName, ZKMRNLightControllerTableNameKey,
				[self dbLightTableData], ZKMRNLightControllerTableDataKey, 
				nil];

	int i = [_lightTables indexOfObject: oldTable];
	NSIndexSet* indices = [NSIndexSet indexSetWithIndex: i];
	[self willChange: NSKeyValueChangeRemoval valuesAtIndexes: indices forKey: @"lightTables"];
	[_lightTables removeObjectAtIndex: i];
	[self didChange: NSKeyValueChangeRemoval valuesAtIndexes: indices forKey: @"lightTables"];
	
	indices = [NSIndexSet indexSetWithIndex: [_lightTables count]];
	[self willChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];			
	[_lightTables addObject: self.loadedLightTable];
	[self didChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];
	
	[oldTable release];
}

#pragma mark -
#pragma mark Light Tables
#pragma mark -

- (NSMutableArray *)lightTables { return _lightTables; }

#pragma mark -
#pragma mark Load / Save / Remove
#pragma mark -

- (void)loadLightTable:(NSString *)lightTableName
{
	NSDictionary* activeTable =  nil;

	for(NSDictionary* aTable in _lightTables) {
		if ([[aTable objectForKey: ZKMRNLightControllerTableNameKey] isEqualToString: lightTableName]) {
			activeTable = [aTable retain]; 
			break;
		}
	}
	
	if(!activeTable && [_lightTables count] > 0) {
		// load first light table ...
		activeTable = [[_lightTables objectAtIndex:0] retain]; 
	}
	
	if(activeTable) {
		[self setDBLightTableData: [activeTable objectForKey: ZKMRNLightControllerTableDataKey]];
		
		[self willChangeValueForKey: @"lightTableName"];
				
		self.loadedLightTable = activeTable;
		
		[self didChangeValueForKey: @"lightTableName"];	
		
		[activeTable release];
	}
	
}

- (void)saveLightTable
{
	if (!self.loadedLightTable) 
		return;
	
	NSEnumerator* tables = [_lightTables objectEnumerator];
	NSDictionary* table;
	int i;
	for (i = 0; table = [tables nextObject]; ++i) {
		if ([[table objectForKey: ZKMRNLightControllerTableNameKey] isEqualToString: [self lightTableName]]) {
			NSDictionary* tableNew = 
				[NSDictionary dictionaryWithObjectsAndKeys: 
					[self lightTableName], ZKMRNLightControllerTableNameKey,
					[self dbLightTableData], ZKMRNLightControllerTableDataKey, 
					nil];
			NSIndexSet* indices = [NSIndexSet indexSetWithIndex: i];
			[self willChange: NSKeyValueChangeRemoval valuesAtIndexes: indices forKey: @"lightTables"];
			[_lightTables removeObjectAtIndex: i];
			[self didChange: NSKeyValueChangeRemoval valuesAtIndexes: indices forKey: @"lightTables"];
			
			indices = [NSIndexSet indexSetWithIndex: [_lightTables count]];
			[self willChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];			
			[_lightTables addObject: tableNew];
			[self didChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];			
			break;
		}
	}
}


- (void)removeLightTable:(NSString *)lightTableName
{
	if ([[self lightTableName] isEqualToString: lightTableName]) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Can not remove loaded light table"));
		return;
	}
	NSEnumerator* tables = [_lightTables objectEnumerator];
	NSDictionary* table;
	int i;
	for (i = 0; table = [tables nextObject]; ++i) {
		if ([[table objectForKey: ZKMRNLightControllerTableNameKey] isEqualToString: lightTableName]) {
			NSIndexSet* indices = [NSIndexSet indexSetWithIndex: i];
			[self willChange: NSKeyValueChangeRemoval valuesAtIndexes: indices forKey: @"lightTables"];
			[_lightTables removeObjectAtIndex: i];
			[self willChange: NSKeyValueChangeRemoval valuesAtIndexes: indices forKey: @"lightTables"];			
			break;
		}
	}
}

#pragma mark -
#pragma mark Setup Changes 
#pragma mark -

- (void)speakerSetupChanged
{
	[self sendInitialLightState];
}

#pragma mark -
#pragma mark Send
#pragma mark -

- (void)sendInitialLightState
{
	_numberOfLights = [[_zirkoniumSystem speakerSetup] numberOfSpeakers];
	[self sendNumberOfLights];
	[self sendLightPositions];
}

- (void)sendAllLightsOff
{

	if(_outPort) {
		
		float r, g, b;
		r = 0.f; g = 0.f; b = 0.f;
			
		for (int i = 0; i < _numberOfLights; ++i) {		
			OSCMessage		*msg			= nil;
			OSCPacket		*packet			= nil;
	
			msg = [OSCMessage createWithAddress:@"/lconfig/color"];

			[msg addInt:i];
			[msg addFloat:r];
			[msg addFloat:g];
			[msg addFloat:b];
			
			packet = [OSCPacket createWithContent:msg];
		
			//send ...
			[_outPort sendThisPacket:packet];
		}		
	}
}

- (void)sendNumberOfLights
{
	
	if(_outPort) {
	
		// prepare start message ...
		OSCMessage		*msg			= nil;
		OSCPacket		*packet			= nil;
	
		msg = [OSCMessage createWithAddress:@"/lconfig/numberOfIds"];
	
		[msg addInt:_numberOfLights];
			
		packet = [OSCPacket createWithContent:msg];
		
		//send ...
		[_outPort sendThisPacket:packet];
	}
}

- (void)sendLightPositions
{

	if(_outPort) {
	
		ZKMRNSpeakerSetup* speakerSetup = [_zirkoniumSystem speakerSetup];
		NSArray* speakerPositions = [[speakerSetup speakerLayout] speakerPositions];
		
		for (int i = 0; i < _numberOfLights; ++i) {

			ZKMNRSphericalCoordinate coordPlatonic = [[speakerPositions objectAtIndex: i] coordPlatonic];
	
			// prepare start message ...
			OSCMessage		*msg			= nil;
			OSCPacket		*packet			= nil;
	
			msg = [OSCMessage createWithAddress:@"/lpan/lamp/az"];

			[msg addInt:i];
			[msg addFloat:coordPlatonic.azimuth];
			[msg addFloat:coordPlatonic.zenith];
			[msg addFloat:0.0f];
			[msg addFloat:0.0f];
			[msg addFloat:0.0f];
			
			packet = [OSCPacket createWithContent:msg];
		
			//send ...
			[_outPort sendThisPacket:packet];
		}		
			
	}
}

- (void)sendRunningLightState
{

	if(_outPort) {
	
		ZKMORMixerMatrix* spatMixer = [_zirkoniumSystem spatializationMixer];
		unsigned maxIndex = _dbLightTableSize - 1;
		
		for (int i = 0; i < _numberOfLights; ++i) {
		
			float scale = ZKMORDBToNormalizedDB([spatMixer postAveragePowerForOutput: i]);
			unsigned tableIndex = MIN((unsigned) (scale * _dbLightTableSize), maxIndex);
			float r, g, b;
			
			r = _dbLightTable[3*tableIndex]; 
			g = _dbLightTable[3*tableIndex + 1]; 
			b = _dbLightTable[3*tableIndex + 2];
			
			r *= self.lightGain; 
			g *= self.lightGain; 
			b *= self.lightGain;
		
			// prepare start message ...
			OSCMessage		*msg			= nil;
			OSCPacket		*packet			= nil;
	
			msg = [OSCMessage createWithAddress:@"/lconfig/color"];

			[msg addInt:i];
			[msg addFloat:r];
			[msg addFloat:g];
			[msg addFloat:b];
			
			packet = [OSCPacket createWithContent:msg];
		
			//send ...
			[_outPort sendThisPacket:packet];
		}		
			
	}
}

#pragma mark -
#pragma mark Clean Up
#pragma mark -

- (void)dealloc
{
	
	if (_lightTimer) [self destroyLightTimer];
	if (_lightTables) [_lightTables release];
	[super dealloc];
}

@end
