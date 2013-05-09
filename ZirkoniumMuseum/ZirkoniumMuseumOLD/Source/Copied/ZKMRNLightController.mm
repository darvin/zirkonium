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
#include "osc/OscOutboundPacketStream.h"
#include <netinet/in.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>

NSString* ZKMRNLightControllerTableNameKey = @"ZKMRNLightControllerTableNameKey";
NSString* ZKMRNLightControllerTableDataKey = @"ZKMRNLightControllerTableDataKey";


@interface ZKMRNLightController (ZKMRNLightControllerPrivate)
- (void)initializeLightTable;
- (void)createLightTimer;
- (void)destroyLightTimer;
- (void)createLightServerAddressData;
- (void)clearMessageData;
- (void)sendInitialLightState;
- (void)sendNumberOfLights;
- (void)sendLightPositions;
- (void)sendRunningLightState;
@end


@implementation ZKMRNLightController
#pragma mark -
#pragma mark NSObject Overrides
- (void)dealloc
{
	if (_lightTimer) [self destroyLightTimer];
	if (_socket) CFSocketInvalidate(_socket), CFRelease(_socket);	
	if (_lightServerAddressData) CFRelease(_lightServerAddressData);
	if (_messageData) CFRelease(_messageData);
	if (_lightTables) [_lightTables release];
	if (_loadedLightTableName) [_loadedLightTableName release];
	[super dealloc];
}

#pragma mark -
#pragma mark Initialize
- (id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)zirkoniumSystem
{
	if (!(self = [super init])) return nil;
	
	_zirkoniumSystem = zirkoniumSystem;
	_isSendingLighting = NO;
	_lightTimerInterval = 0.1;
	_lightGain = 1.f;
	
	CFSocketContext socketContext;

	socketContext.version = 0;
	socketContext.info = (void *) self;
	socketContext.retain = NULL;
	socketContext.release = NULL;
	socketContext.copyDescription = NULL;

	_socket = CFSocketCreate(NULL, PF_INET, SOCK_DGRAM, IPPROTO_UDP, kCFSocketNoCallBack, NULL, &socketContext);
	if (!_socket) {
		[self autorelease];
		ZKMORThrow(@"SocketErr", @"Could not create light sending socket");
	}
	
	_messageDataSize = IP_MTU_SIZE;
	_messageData = CFDataCreateMutable(NULL, _messageDataSize);
	
	_lightTables = [[NSMutableArray alloc] init];
	
		// can't make the resolution too high because then it becomes impossible to edit.
	_dbLightTableSize = 64;
	[self initializeLightTable];
	
	[self createLightServerAddressData];
	return self;
}

#pragma mark -
#pragma mark Accessors
- (BOOL)isSendingLighting { return _isSendingLighting; }
- (void)setSendingLighting:(BOOL)isSendingLighting
{
	_isSendingLighting = isSendingLighting;
	if (_isSendingLighting) {
		[self createLightTimer];
		[self sendInitialLightState];
	} else
		[self destroyLightTimer];
		[self sendAllLightsOff];
}

- (NSTimeInterval)lightTimerInterval { return _lightTimerInterval; }
- (void)setLightTimerInterval:(NSTimeInterval)lightTimerInterval
{
	_lightTimerInterval = lightTimerInterval;
		// recreate the timer if I'm currently sending light data
	if (_isSendingLighting) [self createLightTimer];
}

- (float *)dbLightTable { return _dbLightTable; }
- (unsigned)dbLightTableSize { return _dbLightTableSize; }

- (NSData *)dbLightTableData
{
	return [NSData dataWithBytes: _dbLightTable length: _dbLightTableSize * sizeof(float) * 3];
}

- (void)setDBLightTableData:(NSData *)dbLightTableData
{	
	unsigned lengthToCopy = MIN(_dbLightTableSize * sizeof(float) * 3, [dbLightTableData length]);
	memcpy(_dbLightTable, [dbLightTableData bytes], lengthToCopy);
}

- (float)lightGain { return _lightGain; }
- (void)setLightGain:(float)lightGain { _lightGain = lightGain; }

- (NSMutableArray *)lightTables { return _lightTables; }
- (void)loadLightTable:(NSString *)lightTableName
{
	NSEnumerator* tables = [_lightTables objectEnumerator];
	NSDictionary* table;
	while (table = [tables nextObject]) {
		if ([[table objectForKey: ZKMRNLightControllerTableNameKey] isEqualToString: lightTableName]) {
			[self setDBLightTableData: [table objectForKey: ZKMRNLightControllerTableDataKey]];
			[self willChangeValueForKey: @"lightTableName"];
			_loadedLightTable = table;
			[_loadedLightTable retain];
			_loadedLightTableName = [lightTableName retain];
			[self didChangeValueForKey: @"lightTableName"];			
			break;
		}
	}
}

- (void)saveLightTable
{
	if (!_loadedLightTable) return;
	
	NSEnumerator* tables = [_lightTables objectEnumerator];
	NSDictionary* table;
	NSUInteger i;
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

- (NSString *)lightTableName 
{ 
	if (!_loadedLightTable) return nil;
	return [_loadedLightTable objectForKey: ZKMRNLightControllerTableNameKey];
}
- (void)setLightTableName:(NSString *)lightTableName
{
	NSDictionary* oldTable = _loadedLightTable;
	
	_loadedLightTable = 
			[NSDictionary dictionaryWithObjectsAndKeys: 
				lightTableName, ZKMRNLightControllerTableNameKey,
				[self dbLightTableData], ZKMRNLightControllerTableDataKey, 
				nil];
	[_loadedLightTable retain];

	NSUInteger i = [_lightTables indexOfObject: oldTable];
	NSIndexSet* indices = [NSIndexSet indexSetWithIndex: i];
	[self willChange: NSKeyValueChangeRemoval valuesAtIndexes: indices forKey: @"lightTables"];
	[_lightTables removeObjectAtIndex: i];
	[self didChange: NSKeyValueChangeRemoval valuesAtIndexes: indices forKey: @"lightTables"];
	
	indices = [NSIndexSet indexSetWithIndex: [_lightTables count]];
	[self willChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];			
	[_lightTables addObject: _loadedLightTable];
	[self didChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];
	[oldTable release];
}

- (void)removeLightTable:(NSString *)lightTableName
{
	if ([[self lightTableName] isEqualToString: lightTableName]) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Can not remove loaded light table"));
		return;
	}
	NSEnumerator* tables = [_lightTables objectEnumerator];
	NSDictionary* table;
	NSUInteger i;
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
#pragma mark Actions
- (void)speakerSetupChanged
{
	[self sendInitialLightState];
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

- (void)sendAllLightsOff
{
		// this message is too big to send as a bundle, given the MTU (apparently).
	osc::OutboundPacketStream p(_messageBuffer, IP_MTU_SIZE);
	
	int i;
	for (i = 0; i < _numberOfLights; ++i) {
		p.Clear();
		[self clearMessageData];
		float r, g, b;
		r *= 0.f; g *= 0.f; b *= 0.f;
		p << osc::BeginMessage("/lconfig/color") << (int) i << r << g << b << osc::EndMessage;
		
		CFDataAppendBytes(_messageData, (const UInt8*) p.Data(), p.Size());
//		CFSocketError err = CFSocketSendData(_socket, _lightServerAddressData, _messageData, _lightTimerInterval);
		CFSocketSendData(_socket, _lightServerAddressData, _messageData, _lightTimerInterval);
	}
}

#pragma mark -
#pragma mark ZKMRNLightControllerPrivate
- (void)initializeLightTable
{
	[self setDBLightTableToDefault];
}

- (void)createLightTimer
{
	if (_lightTimer) [self destroyLightTimer];
	_lightTimer = [NSTimer timerWithTimeInterval: _lightTimerInterval target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	[_lightTimer retain];
	[[NSRunLoop currentRunLoop] addTimer: _lightTimer forMode: NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _lightTimer forMode: NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _lightTimer forMode: NSEventTrackingRunLoopMode];
}

- (void)destroyLightTimer
{
	[_lightTimer invalidate];
	[_lightTimer release], _lightTimer = nil;
}

- (void)createLightServerAddressData
{
	struct sockaddr_in addr;

	addr.sin_family = AF_INET;
/*
	struct hostent* host = gethostbyname("localhost");
	if (host) 
		memcpy(&addr.sin_addr, host->h_addr_list[0], host->h_length);
	else {
		NSLog(@"Provided light host is invalid, defaulting to localhost!");
		addr.sin_addr.s_addr = inet_addr("127.0.0.1");		
	}
*/
	addr.sin_addr.s_addr = inet_addr("127.0.0.1");
	addr.sin_port = htons(50818);
	
	if (_lightServerAddressData) CFRelease(_lightServerAddressData), _lightServerAddressData = NULL;
	_lightServerAddressData = CFDataCreate(NULL,  (UInt8 *)&addr, sizeof(struct sockaddr_in));
}

- (void)clearMessageData
{
	CFRange range = CFRangeMake(0, CFDataGetLength(_messageData));
	CFDataDeleteBytes(_messageData, range);
}

- (void)tick:(id)timer
{
	if (![_zirkoniumSystem isPlaying] && ![_zirkoniumSystem isGraphTesting]) return;
	[self sendRunningLightState];
}

- (void)sendInitialLightState
{
	_numberOfLights = [[_zirkoniumSystem speakerSetup] numberOfSpeakers];
	[self sendNumberOfLights];
	[self sendLightPositions];
}

- (void)sendNumberOfLights
{
	[self clearMessageData];
	
	osc::OutboundPacketStream p(_messageBuffer, IP_MTU_SIZE);
	p.Clear();
	
	p << osc::BeginMessage("/lconfig/numberOfIds") << (int) _numberOfLights << osc::EndMessage;
	CFDataAppendBytes(_messageData, (const UInt8*) p.Data(), p.Size());
	CFSocketError err = CFSocketSendData(_socket, _lightServerAddressData, _messageData, _lightTimerInterval);
	if (kCFSocketSuccess != err) {
		NSLog(@"Light Connect Failed: %i", err);
		perror("Light Connect Error");
	}
}

- (void)sendLightPositions
{
	// this message is too big to send as a bundle, given the MTU (apparently).
	osc::OutboundPacketStream p(_messageBuffer, IP_MTU_SIZE);
	
	ZKMRNSpeakerSetup* speakerSetup = [_zirkoniumSystem speakerSetup];
	NSArray* speakerPositions = [[speakerSetup speakerLayout] speakerPositions];
	int i;
	for (i = 0; i < _numberOfLights; ++i) {
		p.Clear();
		[self clearMessageData];
		
		ZKMNRSphericalCoordinate coordPlatonic = [[speakerPositions objectAtIndex: i] coordPlatonic];

		p << osc::BeginMessage("/lpan/lamp/az") << (int) i << coordPlatonic.azimuth << coordPlatonic.zenith << 0.f << 0.f << 0.f << osc::EndMessage;
		
		CFDataAppendBytes(_messageData, (const UInt8*) p.Data(), p.Size());
		CFSocketError err = CFSocketSendData(_socket, _lightServerAddressData, _messageData, _lightTimerInterval);
		if (kCFSocketSuccess != err) {
			NSLog(@"Light Connect Failed: %i", err);
			perror("Light Connect Error");
		}
	}
}

- (void)sendRunningLightState
{
	// this message is too big to send as a bundle, given the MTU (apparently).
	osc::OutboundPacketStream p(_messageBuffer, IP_MTU_SIZE);
	
	ZKMORMixerMatrix* spatMixer = [_zirkoniumSystem spatializationMixer];
	int i;
	unsigned maxIndex = _dbLightTableSize - 1;
	for (i = 0; i < _numberOfLights; ++i) {
		p.Clear();
		[self clearMessageData];
		float scale = ZKMORDBToNormalizedDB([spatMixer postAveragePowerForOutput: i]);
		unsigned tableIndex = MIN((unsigned) (scale * _dbLightTableSize), maxIndex);
		float r, g, b;
		r = _dbLightTable[3*tableIndex]; g = _dbLightTable[3*tableIndex + 1]; b = _dbLightTable[3*tableIndex + 2];
		r *= _lightGain; g *= _lightGain; b *= _lightGain;
		p << osc::BeginMessage("/lconfig/color") << (int) i << r << g << b << osc::EndMessage;
		
		CFDataAppendBytes(_messageData, (const UInt8*) p.Data(), p.Size());
		CFSocketError err = CFSocketSendData(_socket, _lightServerAddressData, _messageData, _lightTimerInterval);
		if (kCFSocketSuccess != err) {
			NSLog(@"Light Connect Failed: %i", err);
			perror("Light Connect Error");
		}
	}
}

@end
