//
//  ZKMRNLightController.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 17.10.07.
//  Copyright 2007 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VVOSC/VVOSC.h"

extern NSString* ZKMRNLightControllerTableNameKey;
extern NSString* ZKMRNLightControllerTableDataKey;

@class ZKMRNZirkoniumSystem;

@interface ZKMRNLightController : NSObject {
	ZKMRNZirkoniumSystem*	_zirkoniumSystem;
	BOOL					_isSendingLighting;
	unsigned				_numberOfLights;

	NSTimer*				_lightTimer;
	NSTimeInterval			_lightTimerInterval;

	//  Network State
	
	OSCManager*		_oscManager; 
	OSCOutPort*		_outPort; 
	
	//  db / rgb table
	float					_dbLightTable[64*3];
	
	unsigned				_dbLightTableSize;
	float					lightGain;
	
	//  Storing multiple tables
	NSMutableArray*			_lightTables;
	NSDictionary*			loadedLightTable;
}

@property float lightGain; 
@property (nonatomic, retain) NSDictionary* loadedLightTable; 

//  Initialize
- (id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)zirkoniumSystem;
- (void)initializeOSC; 
//  Accessors
- (BOOL)isSendingLighting;
- (void)setSendingLighting:(BOOL)isSendingLighting;

- (NSTimeInterval)lightTimerInterval;
- (void)setLightTimerInterval:(NSTimeInterval)lightTimerInterval;

- (float *)dbLightTable;
- (unsigned)dbLightTableSize;

- (NSData *)dbLightTableData;
- (void)setDBLightTableData:(NSData *)dbLightTableData;

- (NSMutableArray *)lightTables;

- (void)removeLightTable:(NSString *)lightTableName;

- (void)loadLightTable:(NSString *)lightTableName;
- (void)saveLightTable;

- (NSString *)lightTableName;
- (void)setLightTableName:(NSString *)lightTableName;

- (void)speakerSetupChanged;

- (void)setDBLightTableToDefault;
- (void)sendAllLightsOff;

@end
