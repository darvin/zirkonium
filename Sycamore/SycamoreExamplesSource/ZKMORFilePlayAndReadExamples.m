//
//  ZKMORFilePlaybackExample.m
//  Sycamore
//
//  Created by C. Ramakrishnan on 16.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Sycamore/Sycamore.h>

void PlayMP3()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSError* error = nil;
		// create a file player
	ZKMORAudioFilePlayer* filePlayer = [[ZKMORAudioFilePlayer alloc] init];
	[filePlayer setFilePath: @"../../examplefiles/Kiku.mp3" error: &error];
	if (error) {
		NSLog(@"ZKMORAudioFilePlayer>>setFilePath: failed -- %@", error);
		return;
	}
	
		// create a graph
	ZKMORGraph* graph = [[ZKMORGraph alloc] init];
	[graph beginPatching];
		[graph setHead: filePlayer];
		[graph initialize];
	[graph endPatching];
		// the graph owns the file player now
	[filePlayer release];
	
		// create an output
	ZKMORDeviceOutput* deviceOutput = [[ZKMORDeviceOutput alloc] init];
	[deviceOutput setGraph: graph];
	[deviceOutput start];

	NSLog(@"Playing 10 seconds of %@", [filePlayer fileURL]);
	sleep(10);
	NSLog(@"Stopping.");
	[deviceOutput stop];

	[deviceOutput release];
	[graph release];
    [pool release];
}

void RecordAIFF(NSString* fileName)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSError* error = nil;
		// create an output
	ZKMORDeviceOutput* deviceOutput = [[ZKMORDeviceOutput alloc] init];
	if (![deviceOutput canDeliverInput]) {
		NSLog(@"Device %@ has no input", [[deviceOutput outputDevice] audioDeviceDescription]);
		[deviceOutput release];
		[pool release];
		return;
	}
	
		// input is enabled by default, if the device has input
	ZKMORDeviceInput* input = [deviceOutput deviceInput];
		// create and initialize the file recorder
	ZKMORAudioFileRecorder* recorder = [[ZKMORAudioFileRecorder alloc] init];
	AudioStreamBasicDescription dataFormat;
	[ZKMORAudioFileRecorder getAIFFInt16Format: &dataFormat channels: 2];
	dataFormat.mSampleRate = 44100.;
	[recorder setFilePath: fileName fileType: kAudioFileAIFFType dataFormat: dataFormat error: &error];
	if (error) {
		NSLog(@"Could not create sound file: %@", error);
		[deviceOutput release];
		[pool release];
		return;
	}
		
		// create a graph
	ZKMORGraph* graph = [[ZKMORGraph alloc] init];
	[graph beginPatching];
		[graph setHead: recorder];
		[graph patchBus: [input outputBusAtIndex: 0] into: [recorder inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
		// give the graph ownership of the recorder
	[recorder release];
	

	[deviceOutput setGraph: graph];
		// the device output owns the graph
	[graph release];
	[deviceOutput start];

	NSLog(@"Recording 10 seconds of input to %@", [recorder fileURL]);
	sleep(10);
	NSLog(@"Stopping.");
	[deviceOutput stop];
	
	[recorder flushAndClose];

	[deviceOutput release];
    [pool release];
}

void PlayRecordedAIFF(NSString* fileName)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSError* error = nil;
		// create a file player
	ZKMORAudioFilePlayer* filePlayer = [[ZKMORAudioFilePlayer alloc] init];
	[filePlayer setFilePath: fileName error: &error];
	if (error) {
		NSLog(@"ZKMORAudioFilePlayer>>setFilePath: failed -- %@", error);
		return;
	}
	
		// create a graph
	ZKMORGraph* graph = [[ZKMORGraph alloc] init];
	[graph beginPatching];
		[graph setHead: filePlayer];
		[graph initialize];
	[graph endPatching];
		// the graph owns the file player now
	[filePlayer release];
	
		// create an output
	ZKMORDeviceOutput* deviceOutput = [[ZKMORDeviceOutput alloc] init];
	[deviceOutput setGraph: graph];
	[deviceOutput start];

	NSLog(@"Playing 10 seconds of %@", [filePlayer fileURL]);
	sleep(10);
	NSLog(@"Stopping.");
	[deviceOutput stop];

	[deviceOutput release];
	[graph release];
    [pool release];
}


int main(int argc, char** argv)
{
	// playback an MP3
	PlayMP3();
	
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		// create a file name
	NSCalendarDate* date = [NSCalendarDate calendarDate];
	NSString* fileName = 
		[NSString stringWithFormat: @"%i%i%i-%i%i%i-record.aiff", [date yearOfCommonEra], [date monthOfYear], [date dayOfMonth], 
			[date hourOfDay], [date minuteOfHour], [date secondOfMinute]];

		// record to that file
	RecordAIFF(fileName);
		// play it back
	PlayRecordedAIFF(fileName);

	[pool release];
    return 0;
}
