//
//  ZKMORListAUExample.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 04.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Sycamore/Sycamore.h>

static void Usage()
{
	printf("auls: List information about audio units\n");
	printf("usage: auls [AUType AUSubType AUManufacturer]\n");
	printf("Examples:\n");
	printf("  auls\n");	
	printf("  auls aumx smxr appl\n");
	printf("\n");
}

static NSArray* GetArrayAndStringForCategory(unsigned category, NSString** categoryName)
{
	ZKMORAudioUnitSystem* auSystem = [ZKMORAudioUnitSystem sharedAudioUnitSystem];
	NSArray* theArray;
	switch (category) {
		case 0: 
			theArray = [auSystem outputAudioUnits];
			*categoryName = @"Output";
			break;
		case 1: 
			theArray = [auSystem musicDeviceAudioUnits];
			*categoryName = @"Music Device";
			break;
		case 2: 
			theArray = [auSystem musicEffectAudioUnits];
			*categoryName = @"Music Effect";
			break;
		case 3: 
			theArray = [auSystem formatConverterAudioUnits];
			*categoryName = @"Format Converter";
			break;
		case 4: 
			theArray = [auSystem effectAudioUnits];
			*categoryName = @"Effect";
			break;	
		case 5: 
			theArray = [auSystem mixerAudioUnits];
			*categoryName = @"Mixer";
			break;
		default: 
			return nil;
	}
	return theArray;
}

static bool CreateComponentDescription(int argc, char * const argv[], ComponentDescription* cd)
{

	if (argc < 4) {
		Usage();
		return false;
	}
	
		// some example arguments:
	// aumf OdCr IllP
	// aumx smxr appl
	// aumx 3dmx appl
	// aufx mrev appl
	// aumf SEbl DFP!
	// aumf dcmp IllP
	cd->componentType = *((OSType*)argv[1]);
	cd->componentSubType 	= *((OSType*)argv[2]);
	cd->componentManufacturer = *((OSType*)argv[3]);

    cd->componentFlags 		= 0;
    cd->componentFlagsMask 	= 0;
	return true;
}

void IntrospectOnAudioUnit(ZKMORAudioUnit* audioUnit)
{
	ZKMORAudioUnitMirror* mirror = [[ZKMORAudioUnitMirror alloc] initWithConduit: audioUnit];
	[mirror logAtLevel: kZKMORLogLevel_Info source: kZKMORLogSource_GUI indent: 0];
	[mirror release];
}

void IntrospectOnAudioUnits(NSArray* audioUnits)
{
	unsigned i, count = [audioUnits count];
	for (i = 0; i < count; i++) {
		ZKMORAudioUnit* au = [audioUnits objectAtIndex: i];
		[au logAtLevel: kZKMORLogLevel_Info source: kZKMORLogSource_GUI indent: 0];
		ZKMORLog(kZKMORLogLevel_Continue, kZKMORLogSource_GUI, CFSTR(""));
	}
}

void ListAllAudioUnits()
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	unsigned cat;
	NSString* categoryName;
	NSArray* theArray;
	ZKMORLog(kZKMORLogLevel_Info, kZKMORLogSource_GUI, CFSTR("Printing info on all AUs\n\n"));
	for (cat = 0; theArray = GetArrayAndStringForCategory(cat, &categoryName); cat++) {
		ZKMORLog(kZKMORLogLevel_Continue, kZKMORLogSource_GUI, CFSTR("\n\t\t----------  %@  ----------\n"), categoryName);
		IntrospectOnAudioUnits(theArray);
		ZKMORLogPrinterFlush();
	}
	
	[pool release];
}

void ListSpecificAudioUnit(int argc, char** argv)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
	ComponentDescription cd;	
		// if we can't find the cd, bail
	if (!CreateComponentDescription(argc, argv, &cd)) {
		ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_GUI, CFSTR("A component description must have a type, subtype and manufacturer, e.g., aumx smxr appl"));
		return;
	}
	
	ZKMORAudioUnitSystem* auSystem = [ZKMORAudioUnitSystem sharedAudioUnitSystem];
	ZKMORAudioUnit* theAudioUnit = [auSystem audioUnitWithComponentDescription: cd];
	if (!theAudioUnit) {
		ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_GUI,
			CFSTR("Could not find ComponentDescription %4.4s - %4.4s - %4.4s\n"), (char*)&cd.componentType, (char*)&cd.componentSubType, (char*)&cd.componentManufacturer);
		return;
	}
	
	IntrospectOnAudioUnit(theAudioUnit);
	[pool release];
}


int main(int argc, char** argv)
{
		// start logging
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
	
	if (argc < 2)
		ListAllAudioUnits();
	else if ((0 == strcmp(argv[1], "-h")) || (0 == strcmp(argv[1], "--help")) || (0 == strcmp(argv[1], "help")))
		Usage();
	else
		ListSpecificAudioUnit(argc, argv);
	
	ZKMORLogPrinterFlush();
	ZKMORLoggerSetIsLogging(NO);
	
    return 0;
}