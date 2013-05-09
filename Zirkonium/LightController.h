//
//  LightController.h
//  Zirkonium
//
//  Created by Jens on 03.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VVOSC/VVOSC.h"

#define dbLightTableSize 64

@class ZKMRNZirkoniumSystem;

extern NSString* ZKMRNLightControllerTableNameKey;
extern NSString* ZKMRNLightControllerTableDataKey;
extern NSString* ZKMRNLightControllerTableSelectionKey;

@interface LightController : NSObject {
	
	ZKMRNZirkoniumSystem*	_zirkoniumSystem;
	
	NSArrayController* lightTablesArrayController; 
	
	OSCManager*		_oscManager; 
	OSCOutPort*		_outPort; 
	
	NSTimer* lightTimer; 
	float _dbLightTable[dbLightTableSize * 3]; 
	float _activeDbLightTable[dbLightTableSize * 3]; 
	

	int numberOfLights; 
}
@property int numberOfLights; 

-(id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)zirkoniumSystem;
-(void)setLightTablesArrayController:(NSArrayController*)arrayController;

-(void)initialize;
-(void)initializeUserDefaults; 

-(NSData*)defaultLightTableData;
-(NSData*)selectedLightTableData;

// UI Selection
-(float *)uiSelectedLightTable;
-(NSData *)uiSelectedLightTableData;

-(float *)activeLightTable;
-(NSData *)activeLightTableData;

-(void)loadLightTable:(NSString*)tableName;

-(void)startOSC; 
-(void)stopOSC; 

-(void)startLightTimer; 
-(void)stopLightTimer; 

-(void)selectionChanged; 
-(void)activeChanged;
-(void)speakerSetupChanged;


- (void)sendInitialLightState;
- (void)sendAllLightsOff;
- (void)sendNumberOfLights;
- (void)sendLightPositions;
- (void)sendRunningLightState;

@end
