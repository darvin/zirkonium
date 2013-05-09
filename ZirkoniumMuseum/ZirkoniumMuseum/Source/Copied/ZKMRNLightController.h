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


#define IP_MTU_SIZE 1536
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
	
	/*
	CFSocketRef				_socket;
	CFDataRef				_lightServerAddressData;
	CFMutableDataRef		_messageData;
	CFIndex					_messageDataSize;
	char					_messageBuffer[IP_MTU_SIZE];
	*/
	
	//  db / rgb table
	float					_dbLightTable[64*3];
	unsigned				_dbLightTableSize;
	float					_lightGain;
	
	//  Storing multiple tables
	NSMutableArray*			_lightTables;
	NSDictionary*			_loadedLightTable;
	NSString*				_loadedLightTableName;
}

//  Initialize
- (id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)zirkoniumSystem;

//  Accessors
- (BOOL)isSendingLighting;
- (void)setSendingLighting:(BOOL)isSendingLighting;

- (NSTimeInterval)lightTimerInterval;
- (void)setLightTimerInterval:(NSTimeInterval)lightTimerInterval;

- (float *)dbLightTable;
- (unsigned)dbLightTableSize;

- (NSData *)dbLightTableData;
- (void)setDBLightTableData:(NSData *)dbLightTableData;

- (float)lightGain;
- (void)setLightGain:(float)lightGain;

/// An array of dictionaries containing names and NSData for the table.
- (NSMutableArray *)lightTables;
- (void)loadLightTable:(NSString *)lightTableName;
- (void)saveLightTable;
- (NSString *)lightTableName;
- (void)setLightTableName:(NSString *)lightTableName;
- (void)removeLightTable:(NSString *)lightTableName;

//  Actions
- (void)speakerSetupChanged;
- (void)setDBLightTableToDefault;
- (void)sendAllLightsOff;

- (void)sendRunningLightState;


@end
