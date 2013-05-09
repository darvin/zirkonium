//
//  LightController.m
//  Zirkonium
//
//  Created by Jens on 03.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LightController.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNSpeakerSetup.h"

NSString* ZKMRNLightControllerTableNameKey = @"ZKMRNLightControllerTableNameKey";
NSString* ZKMRNLightControllerTableDataKey = @"ZKMRNLightControllerTableDataKey";
NSString* ZKMRNLightControllerTableSelectionKey = @"ZKMRNLightControllerTableSelectionKey";

@implementation LightController
@synthesize numberOfLights; 

#pragma mark -
#pragma mark Initialize
#pragma mark -

-(id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)zirkoniumSystem
{
	self = [super init];

	if(self) {
	
		_zirkoniumSystem = zirkoniumSystem;
	}
	return self; 
}

-(void)setLightTablesArrayController:(NSArrayController*)arrayController
{
	lightTablesArrayController = arrayController; 
	
	// Initialize once UI is set up ...
	[self initialize];
}

-(void)initialize
{
	[self initializeUserDefaults];
	
	[self startOSC];
	
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.lightInterval" options:0 context:nil]; 
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.lightSend" options:0 context:nil]; 	
	
	[self selectionChanged]; 
	[self activeChanged];
	
	[self startLightTimer];
}

#pragma mark -
#pragma mark User Defaults ...
#pragma mark -

-(void)initializeUserDefaults
{
	
	// First Initial Light Table ...
	NSData* defaultLightTableData = [self defaultLightTableData];
	
	NSString* defaultName = @"Default"; 
	
	NSDictionary* defaultLightTable = [NSDictionary dictionaryWithObjectsAndKeys:
												defaultName, ZKMRNLightControllerTableNameKey, 
												defaultLightTableData, ZKMRNLightControllerTableDataKey,
												[NSNumber numberWithBool:YES], ZKMRNLightControllerTableSelectionKey,
												nil];
	// First Initial Preference Values ...
	NSDictionary* initialValues =	[NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithFloat:0.5], @"lightGain",
										[NSNumber numberWithBool:YES], @"lightSend",
										[NSNumber numberWithFloat:0.1], @"lightInterval",
										[NSArray arrayWithObject:defaultLightTable], @"lightTables", 
										nil];
	
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initialValues];
	
	if(![[NSUserDefaults standardUserDefaults] valueForKey:@"lightSend"]) {
		[[NSUserDefaultsController sharedUserDefaultsController] revertToInitialValues:self];
	}
}

-(NSData*)defaultLightTableData
{
	float lightTable[dbLightTableSize*3];
	
	float oneOverSize = 1.f / dbLightTableSize;
	
	unsigned i; 
	for(i = 0; i < dbLightTableSize; i++) {
	
		float scale = i * oneOverSize;
		scale = powf(scale, 4.f);
		lightTable[3*i] = MIN(2.f * scale, 1.f);
		lightTable[3*i + 1] = MIN(4.f * scale, 1.f);
		lightTable[3*i + 2] = MIN(0.7f * scale, 1.f);	
				
	}

	int length = dbLightTableSize * sizeof(float) * 3; 
	
	return [NSData dataWithBytes:lightTable length:length];
}

#pragma mark -
#pragma mark OSC
#pragma mark -

-(void)startOSC 
{
	[self stopOSC];
		
	_oscManager = [[OSCManager alloc] init]; 
	
	OSCOutPort* outPort = [_oscManager createNewOutputToAddress:@"127.0.0.1" atPort:50808];
	
	if(outPort==nil)
		NSLog(@"Error: OSC Output Port could not be created.");
		
	_outPort = [outPort retain];	
} 

-(void)stopOSC 
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
} 


#pragma mark -
#pragma mark Timer
#pragma mark -

-(void)startLightTimer
{
	[self stopLightTimer]; 
	
	BOOL send = [[[NSUserDefaults standardUserDefaults] valueForKey:@"lightSend"] boolValue]; 
	
	if(send) {
	
		float interval = [[[NSUserDefaults standardUserDefaults] valueForKey:@"lightInterval"] floatValue]; 
	
		lightTimer = [[NSTimer timerWithTimeInterval:interval target: self selector: @selector(tick:) userInfo: nil repeats: YES] retain];

		[[NSRunLoop currentRunLoop] addTimer: lightTimer forMode: NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer: lightTimer forMode: NSModalPanelRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer: lightTimer forMode: NSEventTrackingRunLoopMode];
		
		[self sendInitialLightState];
	}
}

-(void)stopLightTimer
{
	if(lightTimer) {
		[lightTimer invalidate];
		[lightTimer release];
		
		[self sendAllLightsOff];
	}
	lightTimer = nil; 
}

-(void)tick:(NSTimer*)timer
{
	if (![_zirkoniumSystem isPlaying] && ![_zirkoniumSystem isGraphTesting]) 
		return;
	
	[self sendRunningLightState];
}

#pragma mark -
#pragma mark Selected Table
#pragma mark -

-(NSDictionary*)selectedLightTable
{
	NSDictionary* selectedLightTable = nil; 
	
	if(lightTablesArrayController) {
		
		NSArray* selectedObjects = [lightTablesArrayController selectedObjects];
		
		if(selectedObjects && [selectedObjects count] > 0) {
			selectedLightTable = [selectedObjects objectAtIndex:0];
		}
	}
	
	return selectedLightTable;
}

-(NSData*)selectedLightTableData
{
	NSDictionary* selectedLightTable = [self selectedLightTable];
		
	if(selectedLightTable) {
		return [selectedLightTable valueForKey:ZKMRNLightControllerTableDataKey];
	}
	
	return nil; 
}


-(float *)uiSelectedLightTable
{
	return _dbLightTable;
}

- (NSData *)uiSelectedLightTableData
{
	return [NSData dataWithBytes: _dbLightTable length: dbLightTableSize * sizeof(float) * 3];
}


#pragma mark -
#pragma mark Active Table
#pragma mark -

-(float *)activeLightTable
{
	return _activeDbLightTable;
}

-(NSData*)activeLightTableData
{
	NSArray* lightTables = [[NSUserDefaults standardUserDefaults] valueForKey:@"lightTables"]; 
	
	for(NSDictionary* lightTable in lightTables) {
		BOOL isSelected = [[lightTable valueForKey:ZKMRNLightControllerTableSelectionKey] boolValue]; 
		if(isSelected) {
			return [lightTable valueForKey:ZKMRNLightControllerTableDataKey];
		}
	}
	
	return nil; 
}

#pragma mark -
#pragma mark Update
#pragma mark -

-(void)selectionChanged
{
	// Copy values to array ...
	
	NSData* data = [self selectedLightTableData]; 
	if(data) {
		unsigned lengthToCopy = MIN(dbLightTableSize * sizeof(float) * 3, [data length]);
		memcpy(_dbLightTable, [data bytes], lengthToCopy);
	}
	
}

-(void)activeChanged
{
	NSData* data = [self activeLightTableData];
	if(data) {
		unsigned lengthToCopy = MIN(dbLightTableSize * sizeof(float) * 3, [data length]);
		memcpy(_activeDbLightTable, [data bytes], lengthToCopy);
	}
}

#pragma mark -
#pragma mark External Loading
#pragma mark -

-(void)loadLightTable:(NSString*)tableName
{
	NSDictionary* lightTable = nil; 
	NSArray* lightTables = [lightTablesArrayController arrangedObjects];
	
	// Find table for name ...
	for(NSDictionary* aLightTable in lightTables) {
		
		NSString* aName = [aLightTable valueForKey:ZKMRNLightControllerTableNameKey]; 
		if([tableName isEqualToString:aName]) {
			lightTable = aLightTable; 
			break; 
		}
		
	}
		
	if(!lightTable && lightTables && [lightTables count] > 0) {
		// Name does not exist ...
		lightTable = [lightTables objectAtIndex:0];
	}
	
	if(lightTable) {
		for(NSDictionary* aLightTable in lightTables) {
			// Deactivate ...
			[aLightTable setValue:[NSNumber numberWithBool:NO] forKey:ZKMRNLightControllerTableSelectionKey];
		}
		
		//Activate ...
		[lightTable setValue:[NSNumber numberWithBool:YES] forKey:ZKMRNLightControllerTableSelectionKey];
		
		//Save to User Defaults ...
		[[NSUserDefaultsController sharedUserDefaultsController] setValue:lightTables forKeyPath:@"values.lightTables"]; 

		[self activeChanged];
	}						
}

#pragma mark -
#pragma mark User Defaults Observation
#pragma mark -

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	
	
	if( [keyPath isEqualToString:@"values.lightInterval"] ||
		[keyPath isEqualToString:@"values.lightSend"]) {
	
		// Time Interval or Send Flag Changed...
		[self startLightTimer];
		
	}
}

#pragma mark -
#pragma mark Speaker Setup Notification
#pragma mark -

-(void)speakerSetupChanged
{
	[self sendInitialLightState];
}

#pragma mark -
#pragma mark Send
#pragma mark -

- (void)sendInitialLightState
{
	self.numberOfLights = [[_zirkoniumSystem speakerSetup] numberOfSpeakers];
	
	[self sendNumberOfLights];
	[self sendLightPositions];
}

- (void)sendAllLightsOff
{

	if(_outPort) {
		
		float r, g, b;
		r = 0.f; g = 0.f; b = 0.f;

		int i; 	
		for(i = 0; i < self.numberOfLights; ++i) {		
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
	
		[msg addInt:self.numberOfLights];
			
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
		
		int i; 
		for (i = 0; i < self.numberOfLights; ++i) {

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
		unsigned maxIndex = dbLightTableSize - 1;

		float lightGain = [[[NSUserDefaults standardUserDefaults] valueForKey:@"lightGain"] floatValue]; 

		int i; 
		for(i = 0; i < self.numberOfLights; ++i) {
		
			float scale = ZKMORDBToNormalizedDB([spatMixer postAveragePowerForOutput: i]);
			unsigned tableIndex = MAX(0, MIN((unsigned) (scale * dbLightTableSize), maxIndex));
			float r, g, b;
			
			r = _activeDbLightTable[3*tableIndex]; 
			g = _activeDbLightTable[3*tableIndex + 1]; 
			b = _activeDbLightTable[3*tableIndex + 2];
			
			r *= lightGain; 
			g *= lightGain; 
			b *= lightGain;
			
			r = MAX(0.0, MIN(1.0, r)); 
			g = MAX(0.0, MIN(1.0, g)); 
			b = MAX(0.0, MIN(1.0, b)); 
			
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

-(void)dealloc
{
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.lightInterval"]; 
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.lightSend"]; 
	
	[self stopLightTimer];
	[self stopOSC];
	
	lightTablesArrayController = nil; 
	
	[super dealloc];
}

@end
