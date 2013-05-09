//
//  ZKMRLOSCController.m
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 23.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRLOSCController.h"
#import "ZKMRLZirkoniumLightSystem.h"

/*
#include "OscReceivedElements.h"
#include "OscPacketListener.h"
#include "IpEndpointName.h"
#include <netinet/in.h>


static void ZKMRLOSCSocketCallback(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
	ZKMRLOSCController* oscController = (ZKMRLOSCController *) info;
	[oscController processPacketAddress: address data: (CFDataRef) data];
}

class ZKMRLOSCListener : public osc::OscPacketListener {
public:
	ZKMRLOSCListener(ZKMRLOSCController* controller) : OscPacketListener(), mController(controller) { }

protected:
//  Internal Functions
    virtual void ProcessMessage( const osc::ReceivedMessage& m, const IpEndpointName& remoteEndpoint )
    {
        try {
            // example of parsing single messages. osc::OsckPacketListener
            // handles the bundle traversal.
			osc::ReceivedMessage::const_iterator arg = m.ArgumentsBegin();
			osc::ReceivedMessage::const_iterator end = m.ArgumentsEnd();

			// arguments: id az zn aspan zspan (optional: r g b) -- if not provided, rgb stays the same.
			// rgb may be float (0 - 1) or int (0 - 255)
			if (0 == strcmp(m.AddressPattern(), "/lpan/az")) PanAz(arg, end);			
			if (0 == strcmp(m.AddressPattern(), "/lpan/xy")) PanXy(arg, end);
			
			// look for an exact match on the command name first
			if (0 == strcmp(m.AddressPattern(), "/lpan/lamp/az")) PanLampAz(arg, end);
			if (0 == strcmp(m.AddressPattern(), "/lpan/lamp/xy")) PanLampXy(arg, end);

			// arguments: number of ids (int)
			if (0 == strcmp(m.AddressPattern(), "/lconfig/numberOfIds")) SetNumberOfIds(arg, end);
			// arguments: id r g b
			if (0 == strcmp(m.AddressPattern(), "/lconfig/color")) SetColor(arg, end);			
			
        } catch(osc::Exception& e) {
            // any parsing errors such as unexpected argument types, or 
            // missing arguments get thrown as exceptions.
			ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not parse OSC %s:%s"), m.AddressPattern(), e.what());
        }
    }
	
	int ReadOSCInt(osc::ReceivedMessage::const_iterator arg, osc::ReceivedMessage::const_iterator end, const char* name, int defaultValue)
	{
		int value = defaultValue;
		if (end == arg) return value;
		
		if (arg->IsInt32()) value = arg->AsInt32();
		else if (arg->IsFloat()) value = (int) arg->AsFloat();
		else ZKMORLogDebug(CFSTR("%s not sent as number -- default to %i"), name, value);
		return value;
	}

	float ReadOSCFloat(osc::ReceivedMessage::const_iterator arg, osc::ReceivedMessage::const_iterator end, const char* name, float defaultValue)
	{
		float value = defaultValue;
		if (end == arg) return value;
		
		if (arg->IsFloat())	value = arg->AsFloat();
		else if (arg->IsInt32()) value = (float) arg->AsInt32();
		else ZKMORLogDebug(CFSTR("%s not sent as number -- default to %.2f"), name, value);
		return value;
	}
	
	const char* ReadOSCString(osc::ReceivedMessage::const_iterator arg, osc::ReceivedMessage::const_iterator end, const char* name, const char* defaultValue)
	{
		const char* value = defaultValue;
		if (end == arg) return value;
		
		if (arg->IsString()) value = arg->AsString();
		else ZKMORLogDebug(CFSTR("%s not sent as string -- default to %s"), name, value);
		return value;
	}
	
	NSColor* ReadColor(osc::ReceivedMessage::const_iterator arg, osc::ReceivedMessage::const_iterator end)
	{
		if (arg == end) return nil;
		
		float r = 0.f, g = 0.f, b = 0.f;
		if (arg->IsFloat()) r = (arg++)->AsFloat();
		else if (arg->IsInt32()) r = (float) ((arg++)->AsInt32()) / 255.f;
		if (arg->IsFloat()) g = (arg++)->AsFloat();
		else if (arg->IsInt32()) g = (float) ((arg++)->AsInt32()) / 255.f;
		if (arg->IsFloat()) b = (arg++)->AsFloat();
		else if (arg->IsInt32()) b = (float) ((arg++)->AsInt32()) / 255.f;
		
		return [NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.];
	}

    void PanAz(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int lightId;
		ZKMNRSphericalCoordinate center;
		ZKMNRSphericalCoordinateSpan span;
		
		lightId = ReadOSCInt(arg++, end, "Id", 0);
		center.azimuth = ReadOSCFloat(arg++, end, "Azimuth", 0.f);
		center.zenith = ReadOSCFloat(arg++, end, "Zenith", 0.f);
		center.radius = 1.f;

		span.azimuthSpan = ReadOSCFloat(arg++, end, "Azimuth span", 0.f);
		span.zenithSpan = ReadOSCFloat(arg++, end, "Zenith span", 0.f);

		if (span.azimuthSpan < 0.f) span.azimuthSpan = 0.f;
		if (span.azimuthSpan > 2.f) span.azimuthSpan = 2.f;
		if (span.zenithSpan < 0.f) span.zenithSpan = 0.f;
		if (span.zenithSpan > 0.5f) span.zenithSpan = 0.5f;
		
		NSColor* color = ReadColor(arg, end);
		
		[mController->_system panId: lightId az: center span: span color: color];
    }
	
    void PanXy(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int lightId;
		ZKMNRRectangularCoordinate center;
		ZKMNRRectangularCoordinateSpan span;
		lightId = ReadOSCInt(arg++, end, "Id", 0);
		center.x = ReadOSCFloat(arg++, end, "X", 0.f);
		center.y = ReadOSCFloat(arg++, end, "Y", 0.f);
		center.z = 0.f;
		
		span.xSpan = ReadOSCFloat(arg++, end, "X span", 0.f);
		span.ySpan = ReadOSCFloat(arg++, end, "Y span", 0.f);
		span.zSpan = 0.f;

		if (span.xSpan < 0.f) span.xSpan = 0.f;
		if (span.xSpan > 2.f) span.xSpan = 2.f;
		if (span.ySpan < 0.f) span.ySpan = 0.f;
		if (span.ySpan > 2.f) span.ySpan = 2.f;
		
		NSColor* color = ReadColor(arg, end);
		
		[mController->_system panId: lightId xy: center span: span color: color];
    }
	
    void PanLampAz(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int lightId;
		ZKMNRSphericalCoordinate center;
		lightId = ReadOSCInt(arg++, end, "Id", 0);
		center.azimuth = ReadOSCFloat(arg++, end, "Azimuth", 0.f);
		center.zenith = ReadOSCFloat(arg++, end, "Zenith", 0.f);
		center.radius = 1.f;
		NSColor* color = ReadColor(arg, end);
		
		[mController->_system panId: lightId lampAz: center color: color];
    }
	
    void PanLampXy(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int lightId;
		ZKMNRRectangularCoordinate center;
		lightId = ReadOSCInt(arg++, end, "Id", 0);
		center.x = ReadOSCFloat(arg++, end, "X", 0.f);
		center.y = ReadOSCFloat(arg++, end, "Y", 0.f);
		center.z = 0.f;
		NSColor* color = ReadColor(arg, end);
		
		[mController->_system panId: lightId lampXy: center color: color];
    }
	
    void SetNumberOfIds(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int numberOfIds;
		numberOfIds = ReadOSCInt(arg++, end, "Number of Ids", 0);
		[mController->_system setNumberOfLightIds: numberOfIds];
    }
	
    void SetColor(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int lightId;
		lightId = ReadOSCInt(arg++, end, "Id", 0);
		NSColor* color = ReadColor(arg, end);
		
		[mController->_system setColor: color forId: lightId];
    }

//  State
	ZKMRLOSCController* mController;
};
*/

@interface ZKMRLOSCController (ZKMRLOSCControllerPrivate)
-(void)panAz:(OSCMessage *)m;
-(void)panXy:(OSCMessage *)m;
-(void)panLampAz:(OSCMessage *)m;
-(void)panLampXy:(OSCMessage *)m;	
-(void)setNumberOfIds:(OSCMessage *)m;
-(void)setColor:(OSCMessage *)m;	
-(NSColor*)colorFromOSCRed:(OSCValue*)red green:(OSCValue*)green blue:(OSCValue*)blue;
@end

@implementation ZKMRLOSCController

- (void)dealloc
{
	_system = nil; 
	
	[self destroyOSC];
	
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	_system = [ZKMRLZirkoniumLightSystem sharedZirkoniumLightSystem];
	
	[self createOSC];

	return self;
}

#pragma mark -
#pragma mark OSC Manager
#pragma mark -

-(void)destroyOSC
{
	if(_oscManager) {
		[_oscManager setDelegate:nil];
		[_oscManager deleteAllInputs];
		[_oscManager deleteAllOutputs];
		[_oscManager release];
		_oscManager = nil; 
	}
	
	if(_inPort)		
		[_inPort release];
}

-(void)createOSC
{
	[self destroyOSC];
	
	_oscManager = [[OSCManager alloc] init]; 
	
	[_oscManager setDelegate:self];

	_inPort = [_oscManager createNewInputForPort:50808];
	
	if(_inPort==nil)
		NSLog(@"Error: OSC Input Port could not be created.");
		
	[_inPort retain]; 
}

#pragma mark -
#pragma mark Receive
#pragma mark -

// Callback for received Messages ...
- (void) receivedOSCMessage:(OSCMessage *)m	
{
	NSString* address = [m address];
	
	// arguments: id az zn aspan zspan (optional: r g b) -- if not provided, rgb stays the same.
	// rgb may be float (0 - 1) or int (0 - 255)
		
	if([address isEqualToString:@"/lpan/az"]) {
		[self panAz:m];
	} else if([address isEqualToString:@"/lpan/xy"]) {
		[self panXy:m];
	} else if([address isEqualToString:@"/lpan/lamp/az"]) {
		[self panLampAz:m];
	} else if([address isEqualToString:@"/lpan/lamp/xy"]) {
		[self panLampXy:m];
	} else if([address isEqualToString:@"/lconfig/numberOfIds"]) {
		// arguments: number of ids (int)
		[self setNumberOfIds:m];
	} else if([address isEqualToString:@"/lconfig/color"]) {
		// arguments: id r g b
		[self setColor:m];
	}
			
}

#pragma mark -
#pragma mark Processing 
#pragma mark -

-(void)panAz:(OSCMessage *)m	
{
	int lightId;
	ZKMNRSphericalCoordinate center;
	ZKMNRSphericalCoordinateSpan span;
	
	lightId = [[m valueAtIndex:0] intValue]; 
	
	center.azimuth = [[m valueAtIndex:1] floatValue]; 
	center.zenith  = [[m valueAtIndex:2] floatValue]; 
	center.radius  = 1.f;
	
	span.azimuthSpan = [[m valueAtIndex:3] floatValue]; 
	span.zenithSpan  = [[m valueAtIndex:4] floatValue]; 
	
	if (span.azimuthSpan < 0.f) span.azimuthSpan = 0.f;
	if (span.azimuthSpan > 2.f) span.azimuthSpan = 2.f;
	if (span.zenithSpan < 0.f) span.zenithSpan = 0.f;
	if (span.zenithSpan > 0.5f) span.zenithSpan = 0.5f;
	
	NSColor* color = nil;
	if([m valueCount] > 5) {
		OSCValue* red   = [m valueAtIndex:5];
		OSCValue* green = [m valueAtIndex:6];
		OSCValue* blue  = [m valueAtIndex:7];
		color = [self colorFromOSCRed:red green:green blue:blue];
	}
	
	[_system panId: lightId az: center span: span color: color];
}

-(void)panXy:(OSCMessage *)m	
{
	int lightId;
	ZKMNRRectangularCoordinate center;
	ZKMNRRectangularCoordinateSpan span;
	lightId = [[m valueAtIndex:0] intValue]; 
	center.x = [[m valueAtIndex:1] floatValue]; 
	center.y = [[m valueAtIndex:2] floatValue];
	center.z = 0.f;
	
	span.xSpan = [[m valueAtIndex:3] floatValue];
	span.ySpan = [[m valueAtIndex:4] floatValue];
	span.zSpan = 0.f;
	
	if (span.xSpan < 0.f) span.xSpan = 0.f;
	if (span.xSpan > 2.f) span.xSpan = 2.f;
	if (span.ySpan < 0.f) span.ySpan = 0.f;
	if (span.ySpan > 2.f) span.ySpan = 2.f;
	
	NSColor* color = nil;
	if([m valueCount] > 5) {
		OSCValue* red   = [m valueAtIndex:5];
		OSCValue* green = [m valueAtIndex:6];
		OSCValue* blue  = [m valueAtIndex:7];
		color = [self colorFromOSCRed:red green:green blue:blue];
	}

	
	[_system panId: lightId xy: center span: span color: color];
}

-(void)panLampAz:(OSCMessage *)m	
{
	int lightId;
	ZKMNRSphericalCoordinate center;
	lightId = [[m valueAtIndex:0] intValue]; 
	
	center.azimuth = [[m valueAtIndex:1] floatValue]; 
	center.zenith  = [[m valueAtIndex:2] floatValue]; 
	center.radius  = 1.f;
	
	NSColor* color = nil;
	if([m valueCount] > 3) {
		OSCValue* red   = [m valueAtIndex:3];
		OSCValue* green = [m valueAtIndex:4];
		OSCValue* blue  = [m valueAtIndex:5];
		color = [self colorFromOSCRed:red green:green blue:blue];
	}

	
	[_system panId: lightId lampAz: center color: color];
}

-(void)panLampXy:(OSCMessage *)m	
{
	int lightId;
	ZKMNRRectangularCoordinate center;
	lightId  = [[m valueAtIndex:0] intValue]; 
	
	center.x = [[m valueAtIndex:1] floatValue]; 
	center.y = [[m valueAtIndex:2] floatValue];
	center.z = 0.f;
	
	NSColor* color = nil;
	if([m valueCount] > 3) {
		OSCValue* red   = [m valueAtIndex:3];
		OSCValue* green = [m valueAtIndex:4];
		OSCValue* blue  = [m valueAtIndex:5];
		color = [self colorFromOSCRed:red green:green blue:blue];
	}
	
	[_system panId: lightId lampXy: center color: color];
}

-(void)setNumberOfIds:(OSCMessage *)m	
{
	int numberOfIds;
	numberOfIds = [[m valueAtIndex:0] intValue]; 
	
	[_system setNumberOfLightIds: numberOfIds];
}

-(void)setColor:(OSCMessage *)m	
{
	int lightId;
	lightId  = [[m valueAtIndex:0] intValue]; 
	
	OSCValue* red   = [m valueAtIndex:1];
	OSCValue* green = [m valueAtIndex:2];
	OSCValue* blue  = [m valueAtIndex:3];
	
	NSColor* color = [self colorFromOSCRed:red green:green blue:blue];	
	
	[_system setColor: color forId: lightId];
}

#pragma mark -
#pragma mark Helper
#pragma mark -

-(NSColor*)colorFromOSCRed:(OSCValue*)red green:(OSCValue*)green blue:(OSCValue*)blue
{
	float r, g, b; 
	
	if([red type] == OSCValFloat)
	  r = [red floatValue];
	else if ([red type] == OSCValInt)
	  r = [red intValue] / 255.f; 
	if([green type] == OSCValFloat)
	  g = [green floatValue];
	else if ([green type] == OSCValInt)
	  g = [green intValue] / 255.f; 
	if([blue type] == OSCValFloat)
	  b = [blue floatValue];
	else if ([blue type] == OSCValInt)
	  b = [blue intValue] / 255.f; 
	  
	r = MAX(0.0, MIN(1.0, r)); 
	g = MAX(0.0, MIN(1.0, g)); 
	b = MAX(0.0, MIN(1.0, b)); 

	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}

@end
