/*	Copyright © 2007 Apple Inc. All Rights Reserved.
	
	Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
			Apple Inc. ("Apple") in consideration of your agreement to the
			following terms, and your use, installation, modification or
			redistribution of this Apple software constitutes acceptance of these
			terms.  If you do not agree with these terms, please do not use,
			install, modify or redistribute this Apple software.
			
			In consideration of your agreement to abide by the following terms, and
			subject to these terms, Apple grants you a personal, non-exclusive
			license, under Apple's copyrights in this original Apple software (the
			"Apple Software"), to use, reproduce, modify and redistribute the Apple
			Software, with or without modifications, in source and/or binary forms;
			provided that if you redistribute the Apple Software in its entirety and
			without modifications, you must retain this notice and the following
			text and disclaimers in all such redistributions of the Apple Software. 
			Neither the name, trademarks, service marks or logos of Apple Inc. 
			may be used to endorse or promote products derived from the Apple
			Software without specific prior written permission from Apple.  Except
			as expressly stated in this notice, no other rights or licenses, express
			or implied, are granted by Apple herein, including but not limited to
			any patent rights that may be infringed by your derivative works or by
			other works in which the Apple Software may be incorporated.
			
			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
			MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
			THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
			FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
			OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
			
			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
			OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
			SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
			INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
			MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
			AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
			STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
			POSSIBILITY OF SUCH DAMAGE.
*/
//==================================================================================================
//	Includes
//==================================================================================================

//	PublicUtility Includes
#include "CAAudioHardwareSystem.h"
#include "CACFString.h"
#include "CAHALIOCycleTelemetryClient.h"

//	Standard Library Includes
#include <getopt.h>
#include <stdlib.h>

//==================================================================================================
//	Globals
//==================================================================================================

static bool				gProcessShouldExit				= false;
static CFRunLoopRef		gMainRunLoop					= NULL;
static const char*		gShortCommandLineArgs			= "pducreolt:";
static struct option	gCommandLineArgsDescriptor[]	=	{	{	"pid",					required_argument,	NULL,	'p' },
																{	"device",				required_argument,	NULL,	'd' },
																{	"update",				required_argument,	NULL,	'u' },
																{	"cycles",				no_argument,		NULL,	'c' },
																{	"raw",					no_argument,		NULL,	'r' },
																{	"errors",				no_argument,		NULL,	'e'	},
																{	"traceonoverload",		no_argument,		NULL,	'o' },
																{	"traceonlatewake",		required_argument,	NULL,	'l' },
																{	"traceoncycleduration",	required_argument,	NULL,	't'	},
																{	"help",					required_argument,	NULL,	'?'	},
																{	NULL,					0,					NULL,	0	}};

//==================================================================================================
//	Implementation
//==================================================================================================

static void	SignalHandler(int inSignalNumber)
{
	if(inSignalNumber == SIGTERM)
	{
		gProcessShouldExit = true;
		if(gMainRunLoop != NULL)
		{
			CFRunLoopStop(gMainRunLoop);
		}
	}
}

static void	usage()
{
	printf(	"Usage: %25s  -pid <target process ID>\n"
			"                                  [-device <target device UID>]\n"
			"                                  [-update <seconds between updates>]\n"
			"                                  [-cycles | -raw | -errors]\n"
			"                                  [-traceonoverload]\n"
			"                                  [-traceonlatewake <milliseconds>]\n"
			"                                  [-traceoncycleduration <milliseconds>]\n"
			"                                  [-help]", getprogname());
}

int	main(int inNumberArguments, char* const inArguments[])
{
	//	add the signal handlers
	struct sigaction theSignalHandler;
	theSignalHandler.sa_handler = SignalHandler;
	sigemptyset(&theSignalHandler.sa_mask);
	theSignalHandler.sa_flags = SA_RESTART;
	sigaction(SIGHUP, &theSignalHandler, NULL);
	sigaction(SIGPIPE, &theSignalHandler, NULL);
	sigaction(SIGTERM, &theSignalHandler, NULL);
		
	//	initialize the arguments
	pid_t			theTargetPID = -1;
	AudioDeviceID	theTargetDevice = CAAudioHardwareSystem::GetDefaultDevice(false, false);
	Float64			theUpdateInterval = 1.0;
	bool			theOutputIsCycles = false;
	bool			theOutputIsRaw = false;
	bool			theOutputIsErrors = false;
	bool			doTraceOnOverload = false;
	bool			doTraceOnLate = false;
	Float64			theLateThreshold = 5.0;
	bool			doTraceOnCycle = false;
	Float64			theCycleDuration = 9.0;
	
	//	parse the command line arguments
	bool theArgsAreValid = true;
	int theCurrentArg = getopt_long_only(inNumberArguments, inArguments, gShortCommandLineArgs, gCommandLineArgsDescriptor, NULL);
	while(theArgsAreValid && (theCurrentArg != -1))
	{
		//	process the current argument
		switch(theCurrentArg)
		{
			//	the target PID
			case 'p':
				theTargetPID = atol(optarg);
				break;
			
			//	the UID of the target device
			case 'd':
				{
					CACFString theUID(optarg);
					theTargetDevice = CAAudioHardwareSystem::GetDeviceForUID(theUID.GetCFString());
				}
				break;
			
			//	the time between telemetry updates in seconds
			case 'u':
				theUpdateInterval = atof(optarg);
				break;
			
			//	whether or not to output as cycles
			case 'c':
				theOutputIsCycles = true;
				break;
			
			//	whether or not to output as raw event data
			case 'r':
				theOutputIsRaw = true;
				break;
			
			//	whether or not to just output errors
			case 'e':
				theOutputIsErrors = true;
				break;
			
			//	whether or not to do a latency trace on an overload
			case 'o':
				doTraceOnOverload = true;
				break;
			
			//	the amount of scheduling latency (in milliseconds) that triggers a latency trace
			case 'l':
				doTraceOnLate = true;
				theLateThreshold = atof(optarg);
				break;
			
			//	the IO cycle duration (in milliseconds) that triggers a latency trace
			case 't':
				doTraceOnCycle = true;
				theCycleDuration = atof(optarg);
				break;
			
			//	anything not explicitly called out isn't supported
			case '?':
			default:
				theArgsAreValid = false;
				break;
		};
		
		//	go to the next argument
		theCurrentArg = getopt_long_only(inNumberArguments, inArguments, gShortCommandLineArgs, gCommandLineArgsDescriptor, NULL);
	}
	
	//	make sure that we have at least the bare mininum to function
	theArgsAreValid = theArgsAreValid && (theTargetPID != -1) && (theTargetDevice != 0);
	if(!theArgsAreValid)
	{
		usage();
	}
	else
	{
		try
		{
			//	configure the telemetry object
			CAHALIOCycleTelemetryClient theTelemetry("/tmp/HALLab Latency Trace", ".txt");
			theTelemetry.Initialize(theTargetPID, theTargetDevice);
			if(theTelemetry.CanDoLatencyTracing() && (doTraceOnOverload || doTraceOnLate || doTraceOnCycle))
			{
				theTelemetry.SetIsLatencyTracingEnabled(true);
				theTelemetry.SetOverloadTrigger(doTraceOnOverload);
				if(doTraceOnLate)
				{
					theTelemetry.SetIOCycleDurationTrigger(theLateThreshold);
				}
				if(doTraceOnCycle)
				{
					theTelemetry.SetIOThreadSchedulingLatencyTrigger(theCycleDuration);
				}
			}
			
			//	capture the main thread's run loop
			gMainRunLoop = CFRunLoopGetCurrent();
			
			//	print the header
			char theCString[2048];
			if(theOutputIsRaw)
			{
				theTelemetry.CreateSummaryHeaderForRawEvent(theCString);
			}
			else if(theOutputIsErrors)
			{
				theTelemetry.CreateSummaryHeaderForIOCycle(theCString, false);
			}
			else
			{
				theTelemetry.CreateSummaryHeaderForIOCycle(theCString, false);
			}
			printf("%s\n", theCString);
			
			//	enter the work loop
			while(!gProcessShouldExit)
			{
				UInt32 theTelemetryIndex = 0;
				UInt32 theNumberTelemetryEvents = 0;
				UInt32 theNumberEventsInCycle = 0;
				UInt32 theCycleEventIndex = 0;
			
				//	task the run loop for the duration of the timer
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, theUpdateInterval, FALSE);
				
				//	update the telemetry
				theTelemetry.Update();
				
				//	output the new data
				if(theOutputIsRaw)
				{
					//	we're outputing the raw event info
					theNumberTelemetryEvents = theTelemetry.GetNumberRawEvents();
					while(theTelemetryIndex < theNumberTelemetryEvents)
					{
						theTelemetry.CreateSummaryForRawEvent(theTelemetryIndex, theCString);
						printf("%s\n", theCString);
						++theTelemetryIndex;
					}
				}
				else if(theOutputIsErrors)
				{
					//	we're outputting just the cycles with errors, along with the raw data for that cycle
					theNumberTelemetryEvents = theTelemetry.GetNumberIOCycles();
					theTelemetryIndex = theTelemetry.GetNextErrorIOCycleIndex(theTelemetryIndex);
					while(theTelemetryIndex < theNumberTelemetryEvents)
					{
						//	print the cycle info
						theTelemetry.CreateSummaryForIOCycle(theTelemetryIndex, theCString, false);
						printf("%s\n", theCString);
						
						//	print the events in the cycle
						theNumberEventsInCycle = theTelemetry.GetNumberEventsInIOCycle(theTelemetryIndex);
						for(theCycleEventIndex = 0; theCycleEventIndex < theNumberEventsInCycle; ++theCycleEventIndex)
						{
							//	print the event info
							theTelemetry.CreateSummaryForEventInIOCycle(theTelemetryIndex, theCycleEventIndex, theCString);
							printf("%s\n", theCString);
						}
						
						//	get the next cycle with an error
						theTelemetryIndex = theTelemetry.GetNextErrorIOCycleIndex(theTelemetryIndex);
					}
					
				}
				else
				{
					//	we're outputing just the cycle info
					theNumberTelemetryEvents = theTelemetry.GetNumberIOCycles();
					while(theTelemetryIndex < theNumberTelemetryEvents)
					{
						theTelemetry.CreateSummaryForIOCycle(theTelemetryIndex, theCString, false);
						printf("%s\n", theCString);
						++theTelemetryIndex;
					}
				}
				
				//	no need to keep the outputted data around
				theTelemetry.Clear(false);
			}
		}
		catch(...)
		{
		}
	}
	
	return 0;
}
