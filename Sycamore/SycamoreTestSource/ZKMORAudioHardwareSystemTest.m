//
//  ZKMORAudioHardwareSystemTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioHardwareSystemTest.h"
#import <Sycamore/Sycamore.h>


@implementation ZKMORAudioHardwareSystemTest

- (void)testExistenceOfDevices
{
	ZKMORAudioHardwareSystem* ahs = [ZKMORAudioHardwareSystem sharedAudioHardwareSystem];
	STAssertTrue([[ahs availableDevices] count] > 0, @"There should be some audio devices on this machine");
	STAssertTrue([[ahs outputDevices] count] > 0, @"There should be some output devices on this machine");	
	STAssertNotNil([ahs defaultOutputDevice], @"The default output device should not be nil");		
	STAssertNotNil([ahs systemOutputDevice], @"The system output device should not be nil");
	// the input device may be nil, since some machines don't have any built-in input devices
	
	ZKMORAudioDevice* audioDevice = [ahs defaultOutputDevice];
	STAssertTrue([ahs audioDeviceForUID: [audioDevice UID]] == audioDevice,
		@"Device with UID %@ should be %@ not %@", [audioDevice UID], audioDevice, 
		[ahs audioDeviceForUID: [audioDevice UID]]);
		
	STAssertTrue([audioDevice nominalSampleRate] > 8000., @"The S-Rate should be > 8000");
	STAssertTrue([audioDevice ioBufferSize] > 32, @"The io buffer size should be > 32");
	STAssertTrue([audioDevice throughput] > 0.1f, @"The throughput should be > 0.1f");
	STAssertTrue([audioDevice isAlive], @"The device should be alive");
	// These should not cause exceptions
	[audioDevice isRunning];
	[audioDevice isRunningSomewhere];
	
}

@end
