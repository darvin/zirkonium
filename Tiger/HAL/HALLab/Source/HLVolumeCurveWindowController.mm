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
//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#include "HLVolumeCurveWindowController.h"

//	Local Includes
#include "HLApplicationDelegate.h"
#include "HLDeviceMenuController.h"
//#include "HLFileSystem.h"

//	PublicUtility Includes
//#include "CAAudioBufferList.h"
#include "CAAudioHardwareDevice.h"
#include "CAAudioHardwareSystem.h"
//#include "CAAudioTimeStamp.h"
//#include "CAAutoDisposer.h"
//#include "CACFString.h"
#include "CADebugMacros.h"
#include "CAException.h"
//#include "CAHostTimeBase.h"
//#include "CAStreamBasicDescription.h"

//	System Includes
#import <string.h>

//=============================================================================
//	HLVolumeCurveWindowController
//=============================================================================

@implementation HLVolumeCurveWindowController

-(id)	initWithApplicationDelegate:	(HLApplicationDelegate*)inApplicationDelegate
{
	CATry;
	
	//	initialize the super class
    [super initWithWindowNibName: @"VolumeCurveWindow"];
	
	//	initialize the tinks
	mAudioDevicePropertyListenerTink = new CATink<AudioDevicePropertyListenerProc>((AudioDevicePropertyListenerProc)HLVolumeCurveWindowControllerAudioDevicePropertyListenerProc);
	
	//	initialize the basic stuff
	mApplicationDelegate = inApplicationDelegate;
	
	//	initialize the device stuff
	[self SetupDevice: CAAudioHardwareSystem::GetDefaultDevice(false, false)];
	
	CACatch;
	
	return self;
}

-(void)	windowDidLoad
{
	CATry;
	
	//	get the device
	mDevice = [mDeviceMenuController GetSelectedAudioDevice];
	
	//	update the volume UI
	[self UpdateVolumeItems];
	
	CACatch;
}

-(void)	dealloc
{
	CATry;
	
	[self TeardownDevice: mDevice];
	
	delete mAudioDevicePropertyListenerTink;
	
	CACatch;

	[super dealloc];
}

-(AudioDeviceID)	GetAudioDeviceID
{
	return [mDeviceMenuController GetSelectedAudioDevice];
}

-(void)	windowWillClose:	(NSNotification*)inNotification
{
	#pragma unused(inNotification)

	//	the window is closing, so arrange to get cleaned up
	[mApplicationDelegate DestroyVolumeCurveWindow: self];
}

-(IBAction)	DeviceInfoButtonAction:	(id)inSender
{
	#pragma unused(inSender)

	CATry;
	
	if(mDevice != 0)
	{
		[mApplicationDelegate ShowDeviceWindow: mDevice];
	}
	
	CACatch;
}

-(IBAction)	VolumeSliderAction:	(id)inSender
{
	CATry;
	
	if(mDevice != 0)
	{
		NSSlider* theVolumeSlider = NULL;
		NSTextField* theVolumeTextField = NULL;
		NSPopUpButton* theVolumeCurvePopUp = NULL;
		
		//	figure out which UI parts we're talking about
		if(inSender == mVolume0Slider)
		{
			theVolumeSlider = mVolume0Slider;
			theVolumeTextField = mVolume0TextField;
			theVolumeCurvePopUp = mVolume0CurvePopUp;
		}
		else if(inSender == mVolume1Slider)
		{
			theVolumeSlider = mVolume1Slider;
			theVolumeTextField = mVolume1TextField;
			theVolumeCurvePopUp = mVolume1CurvePopUp;
		}
		else if(inSender == mVolume2Slider)
		{
			theVolumeSlider = mVolume2Slider;
			theVolumeTextField = mVolume2TextField;
			theVolumeCurvePopUp = mVolume2CurvePopUp;
		}
		
		//	set the value in the hardware
		if(theVolumeSlider != NULL)
		{
			CAAudioHardwareDevice theDevice(mDevice);
			UInt32 theNumberOutputChannels = theDevice.GetTotalNumberChannels(kAudioDeviceSectionOutput);
			
			//	get the value of the slider
			Float32 theSliderValue = [theVolumeSlider floatValue];
			
			//	get the value of the curve pop-up
			SInt32 theCurveType = [[theVolumeCurvePopUp selectedItem] tag];
			
			//	iterate through the channels
			for(UInt32 theChannelNumber = 0; theChannelNumber <= theNumberOutputChannels; ++theChannelNumber)
			{
				if(theDevice.HasVolumeControl(theChannelNumber, kAudioDeviceSectionOutput))
				{
					//	tell the control what volume curve to use
					theDevice.SetPropertyData(theChannelNumber, kAudioDeviceSectionOutput, 'vctf' /*kAudioDevicePropertyVolumeDecibelsToScalarTransferFunction*/, sizeof(SInt32), &theCurveType, NULL);
				
					//	convert the slider value to dB
					Float32 theDBValue = theDevice.GetVolumeControlDecibelForScalarValue(theChannelNumber, kAudioDeviceSectionOutput, theSliderValue);
					
					//	get the current dB value
					Float32 theCurrentDBValue = theDevice.GetVolumeControlDecibelValue(theChannelNumber, kAudioDeviceSectionOutput);
					
					//	only set the hardware value if it's different
					if(theDBValue != theCurrentDBValue)
					{
						theDevice.SetVolumeControlDecibelValue(theChannelNumber, kAudioDeviceSectionOutput, theDBValue);
					}
					
					//	tell the control to use the normal volume curve
					SInt32 theNormalCurveType = 5;
					theDevice.SetPropertyData(theChannelNumber, kAudioDeviceSectionOutput, 'vctf' /*kAudioDevicePropertyVolumeDecibelsToScalarTransferFunction*/, sizeof(SInt32), &theNormalCurveType, NULL);
				}
			}
		}
	}
	
	CACatch;
}

-(IBAction)	VolumePopUpAction:	(id)inSender
{
	#pragma unused(inSender)

	[self UpdateVolumeItems];
}

-(void)	UpdateVolumeItems
{
	CATry;
	
	if(mDevice != 0)
	{
		CAAudioHardwareDevice theDevice(mDevice);
		UInt32 theNumberOutputChannels = theDevice.GetTotalNumberChannels(kAudioDeviceSectionOutput);
		
		//	find the first volume control on the device
		UInt32 theChannelNumber = 0;
		bool hasVolumeControl = theDevice.HasVolumeControl(theChannelNumber, kAudioDeviceSectionOutput);
		while(!hasVolumeControl && (theChannelNumber <= theNumberOutputChannels))
		{
			++theChannelNumber;
			hasVolumeControl = theDevice.HasVolumeControl(theChannelNumber, kAudioDeviceSectionOutput);
		}
		
		if(hasVolumeControl)
		{
			//	get the curve type for volume 0
			SInt32 theCurveType = [[mVolume0CurvePopUp selectedItem] tag];
			
			//	tell the control what volume curve to use
			theDevice.SetPropertyData(theChannelNumber, kAudioDeviceSectionOutput, 'vctf' /*kAudioDevicePropertyVolumeDecibelsToScalarTransferFunction*/, sizeof(SInt32), &theCurveType, NULL);
			
			//	set the value of the volume 0 slider
			[mVolume0Slider setFloatValue: theDevice.GetVolumeControlScalarValue(theChannelNumber, kAudioDeviceSectionOutput)];
			
			//	set the value of the volume 0 text field
			[mVolume0TextField setStringValue: [NSString stringWithFormat: @"%8.3f", theDevice.GetVolumeControlDecibelValue(theChannelNumber, kAudioDeviceSectionOutput)]];
			
			//	get the curve type for volume 1
			theCurveType = [[mVolume1CurvePopUp selectedItem] tag];
			
			//	tell the control what volume curve to use
			theDevice.SetPropertyData(theChannelNumber, kAudioDeviceSectionOutput, 'vctf' /*kAudioDevicePropertyVolumeDecibelsToScalarTransferFunction*/, sizeof(SInt32), &theCurveType, NULL);
			
			//	set the value of the volume 1 slider
			[mVolume1Slider setFloatValue: theDevice.GetVolumeControlScalarValue(theChannelNumber, kAudioDeviceSectionOutput)];
			
			//	set the value of the volume 1 text field
			[mVolume1TextField setStringValue: [NSString stringWithFormat: @"%8.3f", theDevice.GetVolumeControlDecibelValue(theChannelNumber, kAudioDeviceSectionOutput)]];
			
			//	get the curve type for volume 2
			theCurveType = [[mVolume2CurvePopUp selectedItem] tag];
			
			//	tell the control what volume curve to use
			theDevice.SetPropertyData(theChannelNumber, kAudioDeviceSectionOutput, 'vctf' /*kAudioDevicePropertyVolumeDecibelsToScalarTransferFunction*/, sizeof(SInt32), &theCurveType, NULL);
			
			//	set the value of the volume 2 slider
			[mVolume2Slider setFloatValue: theDevice.GetVolumeControlScalarValue(theChannelNumber, kAudioDeviceSectionOutput)];
			
			//	set the value of the volume 2 text field
			[mVolume2TextField setStringValue: [NSString stringWithFormat: @"%8.3f", theDevice.GetVolumeControlDecibelValue(theChannelNumber, kAudioDeviceSectionOutput)]];
			
			//	tell the control to use the normal volume curve
			theCurveType = 5;
			theDevice.SetPropertyData(theChannelNumber, kAudioDeviceSectionOutput, 'vctf' /*kAudioDevicePropertyVolumeDecibelsToScalarTransferFunction*/, sizeof(SInt32), &theCurveType, NULL);
		}
		else
		{
			[mVolume0Slider setFloatValue: 1.0];
			[mVolume0Slider setEnabled: NO];
			[mVolume0TextField setStringValue: [NSString stringWithFormat: @"%8.3f", 1.0]];
			[mVolume0TextField setEnabled: NO];
			[mVolume0CurvePopUp setEnabled: NO];
			
			[mVolume1Slider setFloatValue: 1.0];
			[mVolume1Slider setEnabled: NO];
			[mVolume1TextField setStringValue: [NSString stringWithFormat: @"%8.3f", 1.0]];
			[mVolume1TextField setEnabled: NO];
			[mVolume1CurvePopUp setEnabled: NO];
			
			[mVolume2Slider setFloatValue: 1.0];
			[mVolume2Slider setEnabled: NO];
			[mVolume2TextField setStringValue: [NSString stringWithFormat: @"%8.3f", 1.0]];
			[mVolume2TextField setEnabled: NO];
			[mVolume2CurvePopUp setEnabled: NO];
		}
	}
	else
	{
		//	no device, disable all the controls
		
		[mVolume0Slider setFloatValue: 1.0];
		[mVolume0Slider setEnabled: NO];
		[mVolume0TextField setStringValue: [NSString stringWithFormat: @"%8.3f", 1.0]];
		[mVolume0TextField setEnabled: NO];
		[mVolume0CurvePopUp setEnabled: NO];
		
		[mVolume1Slider setFloatValue: 1.0];
		[mVolume1Slider setEnabled: NO];
		[mVolume1TextField setStringValue: [NSString stringWithFormat: @"%8.3f", 1.0]];
		[mVolume1TextField setEnabled: NO];
		[mVolume1CurvePopUp setEnabled: NO];
		
		[mVolume2Slider setFloatValue: 1.0];
		[mVolume2Slider setEnabled: NO];
		[mVolume2TextField setStringValue: [NSString stringWithFormat: @"%8.3f", 1.0]];
		[mVolume2TextField setEnabled: NO];
		[mVolume2CurvePopUp setEnabled: NO];
	}
	
	CACatch;
}

-(void)	SetupDevice:	(AudioDeviceID)inDevice
{
	//	This routine is for configuring the IO device and installing
	//	IOProcs and listeners. The strategy for this window is to only
	//	respond to changes in the device. If the user wants to change
	//	things about the device that affect IO, it will be done in the
	//  device info window.
	CATry;
	
	if(inDevice != 0)
	{
		//	make a device object
		CAAudioHardwareDevice theDevice(inDevice);
		
		//	install a listener for the device dying
		theDevice.AddPropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionOutput, kAudioDevicePropertyDeviceIsAlive, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink, self);
		
		//	install a listener for volume control changes
		theDevice.AddPropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionOutput, kAudioDevicePropertyVolumeScalar, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink, self);
	}
	
	CACatch;
}

-(void)	TeardownDevice:	(AudioDeviceID)inDevice
{
	CATry;
	
	if(inDevice != 0)
	{
		//	make a device object
		CAAudioHardwareDevice theDevice(inDevice);
		
		//	remove the listener for the device dying
		theDevice.RemovePropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionOutput, kAudioDevicePropertyDeviceIsAlive, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink);
		
		//	remove the listener for volume control changes
		theDevice.RemovePropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionOutput, kAudioDevicePropertyVolumeScalar, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink);
	}

	CACatch;
}

-(AudioDeviceID)	GetInitialSelectedDevice:	(HLDeviceMenuController*)inDeviceMenuControl
{
	#pragma unused(inDeviceMenuControl)

	//	the initial selection of the device menu is the default output device
	return CAAudioHardwareSystem::GetDefaultDevice(false, false);
}

-(void)	SelectedDeviceChanged:	(HLDeviceMenuController*)inDeviceMenuControl
		OldDevice:				(AudioDeviceID)inOldDeviceID
		NewDevice:				(AudioDeviceID)inNewDeviceID
{
	#pragma unused(inDeviceMenuControl)

	//	teardown the current device
	[self TeardownDevice: inOldDeviceID];
	
	mDevice = inNewDeviceID;

	//	setup the new device
	[self SetupDevice: inNewDeviceID];
	
	//	update the UI
	[self UpdateVolumeItems];
}

-(BOOL)	ShouldDeviceBeInMenu:	(HLDeviceMenuController*)inDeviceMenuControl
		Device:					(AudioDeviceID)inDeviceID
{
	#pragma unused(inDeviceMenuControl)

	CAAudioHardwareDevice theDevice(inDeviceID);
	
	BOOL theAnswer = NO;
	
	if(theDevice.HasSection(kAudioDeviceSectionOutput))
	{
		theAnswer = YES;
	}
	
	return theAnswer;
}

@end

OSStatus	HLVolumeCurveWindowControllerAudioDevicePropertyListenerProc(AudioDeviceID inDevice, UInt32 /*inChannel*/, Boolean /*inIsInput*/, AudioDevicePropertyID inPropertyID, HLVolumeCurveWindowController* inVolumeCurveWindowController)
{
	NS_DURING
	CATry;
	
	if(inDevice == [inVolumeCurveWindowController GetAudioDeviceID])
	{
		CAAudioHardwareDevice theDevice(inDevice);
	
		switch(inPropertyID)
		{
			case kAudioDevicePropertyDeviceIsAlive:
				{
					//	teardown the device
					[inVolumeCurveWindowController TeardownDevice: inDevice];
					
					//	change the device to the default device
					[inVolumeCurveWindowController SetupDevice: CAAudioHardwareSystem::GetDefaultDevice(false, false)];
					
					//	update the info
					[inVolumeCurveWindowController UpdateVolumeItems];
				}
				break;
				
			case kAudioDevicePropertyVolumeScalar:
				{
					[inVolumeCurveWindowController UpdateVolumeItems];
				}
				break;
		};
	}
	
	CACatch;
	NS_HANDLER
	NS_ENDHANDLER

	return 0;
}
