//
//  ZKMRLZirkoniumLightSystem.m
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRLZirkoniumLightSystem.h"
#import "ZKMRLPannerLight.h"
#import "ZKMRLOutputDMX.h"
#import "ZKMRLLightSetupDocument.h"
#import "ZKMRLMixerLight.h"
#import "ZKMRLOSCController.h"

ZKMRLZirkoniumLightSystem* gSharedZirkoniumLightSystem = nil;

@interface ZKMRLZirkoniumLightSystem (ZKMRLZirkoniumLightSystemPrivate)
- (void)initializeLightSetup;
- (void)createOutputTimer;
- (void)destroyOutputTimer;
- (ZKMNRSpeakerLayout *)computeSpeakerLayout;
@end

@implementation ZKMRLZirkoniumLightSystem
#pragma mark _____ NSObject Overrides
- (void)dealloc 
{
	gSharedZirkoniumLightSystem = nil;
	
//	[[NSNotificationCenter defaultCenter] removeObserver: self];
	if (_panner) [_panner release], _panner = nil;
	if (_lampLayout) [_lampLayout release], _lampLayout = nil;
	if (_lightIds) [_lightIds release], _lightIds = nil;
	if (_outputTimer) [self destroyOutputTimer];
	if (_oscController) [_oscController release], _oscController = nil;
	
    [super dealloc];
}

- (void)awakeFromNib
{
	// this is obviously not thread safe, but doesn't need to be either -- at the time this method
	// is called, there is only one thread running.
	gSharedZirkoniumLightSystem = self;
	
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
//	ZKMORLogPrinterStart();
//	_loggerClient = [ZKMORLoggerClient sharedLoggerClient];
	[self initializeLightSetup];

	_mixer = [[ZKMRLMixerLight alloc] init];
	_outputDMX = [[ZKMRLOutputDMX alloc] init];
	[_outputDMX setAddress: [_lightSetup lanBoxAddress]];
	// load the default speaker layout from Zirkonium
	_lampLayout = [self computeSpeakerLayout];
	
	// set the mixer's number of default output channels to the same as the speaker layout
	[_mixer setNumberOfOutputChannels: [_lampLayout numberOfSpeakers]];
	
	[_outputDMX setMixer: _mixer];
	
	_panner = [[ZKMRLPannerLight alloc] init];
	[_panner setLampLayout: _lampLayout];
//	[_panner bind: @"speakerLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[_panner setMixer: _mixer];
	
	_lightIds = [[NSMutableArray alloc] init];
	[self setNumberOfLightIds: 1];
	// change default the light to a different color
	[_mixer setColor: [NSColor greenColor] forInput: 0];
	
	[self createOutputTimer];
	
	_oscController = [[ZKMRLOSCController alloc] init];
}


#pragma mark _____ Singleton
	// The MainMenu.nib automatically creates an instance of ZKMRLZirkoniumLightSystem
+ (ZKMRLZirkoniumLightSystem *)sharedZirkoniumLightSystem { return gSharedZirkoniumLightSystem; }

#pragma mark _____ Accessors
- (ZKMRLPannerLight *)panner { return _panner; }
- (ZKMRLMixerLight *)mixer { return _mixer; }
- (ZKMNRSpeakerLayout *)lampLayout { return _lampLayout; }

- (ZKMRLLightSetupDocument *)lightSetup { return _lightSetup; }

- (NSString *)lanBoxAddress { return [_outputDMX address]; }
- (void)setLanBoxAddress:(NSString *)lanBoxAddress
{
	[_outputDMX setAddress: lanBoxAddress];
}

- (NSString *)defaultLanBoxAddress { return [_outputDMX defaultLanBoxAddress]; }

- (id)appDelegate { return _appDelegate; }
- (void)setAppDelegate:(id)appDelegate { _appDelegate = appDelegate; }

#pragma mark _____ Actions
- (unsigned)numberOfLightIds { return [_lightIds count]; }
- (void)setNumberOfLightIds:(unsigned)numberOfIds
{
	// remove the old ids
	int i = [_lightIds count] - 1;
	for ( ; i > -1; --i) 
	{
		[_panner unregisterPannerSource: [_lightIds objectAtIndex: i]];
		[_lightIds removeObjectAtIndex: i];
	}

	// set the number of ids on the mixer	
	[_mixer setNumberOfInputChannels: numberOfIds];
	
	NSColor* blackColor = [[NSColor blackColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
	// register the ids with the panner
	for (i = 0; i < numberOfIds; ++i)
	{
		ZKMNRPannerSource* newId = [[ZKMNRPannerSource alloc] init];
		[_panner registerPannerSource: newId];
		ZKMNRSphericalCoordinate center;
		center.azimuth = 0.f; center.zenith = 0.f; center.radius = 1.f;
		ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
		[newId setInitialCenter: center span: span gain: 1.f];
		[newId setCenter: center span: span gain: 1.f];
		[_mixer setColor: blackColor forInput: i];	

		[_lightIds addObject: newId];
	}
	
	// activate the new Ids
	[_panner beginEditingActiveSources];		
		[_panner setActiveSources: _lightIds];
	[_panner endEditingActiveSources];
}

- (void)panId:(unsigned)idNumber az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span color:(NSColor *)color
{
	if (idNumber >= [_lightIds count]) return;
	ZKMNRPannerSource* source = [_lightIds objectAtIndex: idNumber];
//	[source setCenter: center];
	[source setCenter: center span: span gain: 1.f];
	[self setColor: color forId: idNumber];
}

- (void)panId:(unsigned)idNumber xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span color:(NSColor *)color 
{
	if (idNumber >= [_lightIds count]) return;
	ZKMNRPannerSource* source = [_lightIds objectAtIndex: idNumber];
	[source setCenterRectangular: center span: span gain: 1.f];
	[self setColor: color forId: idNumber];
}

- (void)panId:(unsigned)idNumber lampAz:(ZKMNRSphericalCoordinate)center color:(NSColor *)color 
{
	// find the nearest lamp
	ZKMNRSpeakerPosition* lampPos = [_panner lampClosestToPoint: center];
	if (!lampPos) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not find lamp near point { %.2f, %.2f, %.2f}"), center.azimuth, center.zenith, center.radius);
		return;
	}

	// pan to that lamp
	ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
	[self panId: idNumber az: [lampPos coordPlatonic] span: span color: color];
}

- (void)panId:(unsigned)idNumber lampXy:(ZKMNRRectangularCoordinate)center color:(NSColor *)color 
{
	ZKMNRSphericalCoordinate sphericalCenter = ZKMNRPlanarCoordinateLiftedToSphere(center);
	
	// find the nearest lamp
	ZKMNRSpeakerPosition* lampPos = [_panner lampClosestToPoint: sphericalCenter];
	if (!lampPos) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not find lamp near point { %.2f, %.2f, %.2f}"), center.x, center.y, center.z);
		return;
	}

	// pan to that lamp
	ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
	[self panId: idNumber az: [lampPos coordPlatonic] span: span color: color];
}

- (void)setColor:(NSColor *)color forId:(unsigned)idNumber
{
	if (color) [_mixer setColor: color forInput: idNumber];	
}

#pragma mark _____ ZKMRLZirkoniumLightSystemPrivate
- (NSString *)applicationSupportFolder 
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex: 0] : NSTemporaryDirectory();
	return [basePath stringByAppendingPathComponent: @"ZirkoniumLicht"];

}

- (void)createLightSetupURL:(NSURL *)studioURL
{
	NSError* error = nil;
	NSDocumentController* documentController = [NSDocumentController sharedDocumentController];

	// look for the defaultstudio.zrkstu and copy it over
	NSString* defaultStudioPath = [[NSBundle mainBundle] pathForResource: @"defaultsetup" ofType: @"zrklts"];
	if (defaultStudioPath) {
		NSFileManager* fileManager = [NSFileManager defaultManager];
		NSString* studioPath = [studioURL path];
		NSString* applicationSupportFolder = [self applicationSupportFolder];
		BOOL success = YES;
		BOOL dirExists = [fileManager fileExistsAtPath: applicationSupportFolder];
		if (!dirExists) success = [fileManager createDirectoryAtPath: applicationSupportFolder attributes: nil];
		if (!success) NSLog(@"Could not create directory %@", applicationSupportFolder);		
		success = [fileManager copyPath: defaultStudioPath toPath: studioPath handler: nil];
		if (!success) NSLog(@"Could not copy studio setup %@", studioPath);
		_lightSetup = [documentController makeDocumentWithContentsOfURL: studioURL ofType: @"LightSetup" error: &error];
		if (error) {
			[[NSApplication sharedApplication] presentError: error];
			return;
		}
		[_lightSetup retain];
		[documentController addDocument: _lightSetup];	
		return;
	}
	
	_lightSetup = [documentController makeUntitledDocumentOfType: @"LightSetup" error: &error];
	if (error) {
		[[NSApplication sharedApplication] presentError: error];
		return;
	}
	
	[_lightSetup retain];
	[documentController addDocument: _lightSetup];
}

- (void)initializeLightSetup
{
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSURL* studioURL = 
		[NSURL fileURLWithPath: [[self applicationSupportFolder] stringByAppendingPathComponent: @"light.zrklts"]];
	if (![fileManager fileExistsAtPath: [studioURL path]]) { [self createLightSetupURL: studioURL]; return; }
		
	NSError* error = nil;
	_lightSetup = [[ZKMRLLightSetupDocument alloc] initWithContentsOfURL: studioURL ofType: @"LightSetup" error: &error];
	if (error) {
		[[NSApplication sharedApplication] presentError: error];
		return;
	}
}

- (void)tick:(id)sender
{
	[_panner updatePanningToMixer];
	[_outputDMX tick: sender];
	if (_appDelegate) ([_appDelegate tick: sender]);
}

- (void)createOutputTimer
{
	if (_outputTimer) [self destroyOutputTimer];
	_outputTimer = [NSTimer timerWithTimeInterval: 0.05 target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	[_outputTimer retain];
	[[NSRunLoop currentRunLoop] addTimer: _outputTimer forMode: NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _outputTimer forMode: NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _outputTimer forMode: NSEventTrackingRunLoopMode];
}

- (void)destroyOutputTimer
{
	[_outputTimer invalidate];
	[_outputTimer release], _outputTimer = nil;
}

- (ZKMNRSpeakerLayout *)computeSpeakerLayout
{
	NSString* plistString = @" <?xml version=\"1.0\" encoding=\"UTF-8\"?> <!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"> <plist version=\"1.0\"> <dict> 	<key>SpeakerLayoutName</key> 	<string>Dome 43 Alt</string> 	<key>Speakers</key> 	<array> 		<array> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>1</real> 				<key>PhysicalRadius</key> 				<real>1</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>1</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.81430661678314209</real> 				<key>PhysicalRadius</key> 				<real>1.1981652975082397</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>0.81430661678314209</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.69440007209777832</real> 				<key>PhysicalRadius</key> 				<real>1.2206555604934692</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>0.69440007209777832</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.59277355670928955</real> 				<key>PhysicalRadius</key> 				<real>1.0440306663513184</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>0.59277355670928955</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.40722641348838806</real> 				<key>PhysicalRadius</key> 				<real>1.0440306663513184</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>0.40722641348838806</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.30559989809989929</real> 				<key>PhysicalRadius</key> 				<real>1.2206555604934692</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>0.30559989809989929</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.1856933981180191</real> 				<key>PhysicalRadius</key> 				<real>1.1981652975082397</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>0.1856933981180191</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.0</real> 				<key>PhysicalRadius</key> 				<real>1</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>0.0</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.1856933981180191</real> 				<key>PhysicalRadius</key> 				<real>1.1981652975082397</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>-0.1856933981180191</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.30559989809989929</real> 				<key>PhysicalRadius</key> 				<real>1.2206555604934692</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>-0.30559989809989929</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.40722641348838806</real> 				<key>PhysicalRadius</key> 				<real>1.0440306663513184</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>-0.40722641348838806</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.59277355670928955</real> 				<key>PhysicalRadius</key> 				<real>1.0440306663513184</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>-0.59277355670928955</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.69440007209777832</real> 				<key>PhysicalRadius</key> 				<real>1.2206555604934692</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>-0.69440007209777832</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.81430661678314209</real> 				<key>PhysicalRadius</key> 				<real>1.1981652975082397</real> 				<key>PhysicalZenith</key> 				<real>0.0</real> 				<key>PlatonicAzimuth</key> 				<real>-0.81430661678314209</real> 				<key>PlatonicZenith</key> 				<real>0.0</real> 			</dict> 		</array> 		<array> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.83475065231323242</real> 				<key>PhysicalRadius</key> 				<real>0.94868326187133789</real> 				<key>PhysicalZenith</key> 				<real>0.17670057713985443</real> 				<key>PlatonicAzimuth</key> 				<real>0.83475065231323242</real> 				<key>PlatonicZenith</key> 				<real>0.17670057713985443</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.76178383827209473</real> 				<key>PhysicalRadius</key> 				<real>1.0781928300857544</real> 				<key>PhysicalZenith</key> 				<real>0.15349243581295013</real> 				<key>PlatonicAzimuth</key> 				<real>0.76178383827209473</real> 				<key>PlatonicZenith</key> 				<real>0.15349243581295013</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.70871436595916748</real> 				<key>PhysicalRadius</key> 				<real>0.960468590259552</real> 				<key>PhysicalZenith</key> 				<real>0.17428396642208099</real> 				<key>PlatonicAzimuth</key> 				<real>0.70871436595916748</real> 				<key>PlatonicZenith</key> 				<real>0.17428396642208099</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.5</real> 				<key>PhysicalRadius</key> 				<real>0.82006096839904785</real> 				<key>PhysicalZenith</key> 				<real>0.20871439576148987</real> 				<key>PlatonicAzimuth</key> 				<real>0.5</real> 				<key>PlatonicZenith</key> 				<real>0.20871439576148987</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.29128560423851013</real> 				<key>PhysicalRadius</key> 				<real>0.960468590259552</real> 				<key>PhysicalZenith</key> 				<real>0.17428396642208099</real> 				<key>PlatonicAzimuth</key> 				<real>0.29128560423851013</real> 				<key>PlatonicZenith</key> 				<real>0.17428396642208099</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.23821613192558289</real> 				<key>PhysicalRadius</key> 				<real>1.0781928300857544</real> 				<key>PhysicalZenith</key> 				<real>0.15349243581295013</real> 				<key>PlatonicAzimuth</key> 				<real>0.23821613192558289</real> 				<key>PlatonicZenith</key> 				<real>0.15349243581295013</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.16524934768676758</real> 				<key>PhysicalRadius</key> 				<real>0.94868326187133789</real> 				<key>PhysicalZenith</key> 				<real>0.17670057713985443</real> 				<key>PlatonicAzimuth</key> 				<real>0.16524934768676758</real> 				<key>PlatonicZenith</key> 				<real>0.17670057713985443</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.16524934768676758</real> 				<key>PhysicalRadius</key> 				<real>0.94868326187133789</real> 				<key>PhysicalZenith</key> 				<real>0.17670057713985443</real> 				<key>PlatonicAzimuth</key> 				<real>-0.16524934768676758</real> 				<key>PlatonicZenith</key> 				<real>0.17670057713985443</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.23821613192558289</real> 				<key>PhysicalRadius</key> 				<real>1.0781928300857544</real> 				<key>PhysicalZenith</key> 				<real>0.15349243581295013</real> 				<key>PlatonicAzimuth</key> 				<real>-0.23821613192558289</real> 				<key>PlatonicZenith</key> 				<real>0.15349243581295013</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.29128560423851013</real> 				<key>PhysicalRadius</key> 				<real>0.960468590259552</real> 				<key>PhysicalZenith</key> 				<real>0.17428396642208099</real> 				<key>PlatonicAzimuth</key> 				<real>-0.29128560423851013</real> 				<key>PlatonicZenith</key> 				<real>0.17428396642208099</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.5</real> 				<key>PhysicalRadius</key> 				<real>0.82006096839904785</real> 				<key>PhysicalZenith</key> 				<real>0.20871439576148987</real> 				<key>PlatonicAzimuth</key> 				<real>-0.5</real> 				<key>PlatonicZenith</key> 				<real>0.20871439576148987</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.70871436595916748</real> 				<key>PhysicalRadius</key> 				<real>0.960468590259552</real> 				<key>PhysicalZenith</key> 				<real>0.17428396642208099</real> 				<key>PlatonicAzimuth</key> 				<real>-0.70871436595916748</real> 				<key>PlatonicZenith</key> 				<real>0.17428396642208099</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.76178383827209473</real> 				<key>PhysicalRadius</key> 				<real>1.0781928300857544</real> 				<key>PhysicalZenith</key> 				<real>0.15349243581295013</real> 				<key>PlatonicAzimuth</key> 				<real>-0.76178383827209473</real> 				<key>PlatonicZenith</key> 				<real>0.15349243581295013</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.83475065231323242</real> 				<key>PhysicalRadius</key> 				<real>0.94868326187133789</real> 				<key>PhysicalZenith</key> 				<real>0.17670057713985443</real> 				<key>PlatonicAzimuth</key> 				<real>-0.83475065231323242</real> 				<key>PlatonicZenith</key> 				<real>0.17670057713985443</real> 			</dict> 		</array> 		<array> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.82797908782958984</real> 				<key>PhysicalRadius</key> 				<real>0.94999998807907104</real> 				<key>PhysicalZenith</key> 				<real>0.28964641690254211</real> 				<key>PlatonicAzimuth</key> 				<real>0.82797908782958984</real> 				<key>PlatonicZenith</key> 				<real>0.28964641690254211</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.64758360385894775</real> 				<key>PhysicalRadius</key> 				<real>0.93541437387466431</real> 				<key>PhysicalZenith</key> 				<real>0.29611539840698242</real> 				<key>PlatonicAzimuth</key> 				<real>0.64758360385894775</real> 				<key>PlatonicZenith</key> 				<real>0.29611539840698242</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.35241639614105225</real> 				<key>PhysicalRadius</key> 				<real>0.93541437387466431</real> 				<key>PhysicalZenith</key> 				<real>0.29611539840698242</real> 				<key>PlatonicAzimuth</key> 				<real>0.35241639614105225</real> 				<key>PlatonicZenith</key> 				<real>0.29611539840698242</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.17202088236808777</real> 				<key>PhysicalRadius</key> 				<real>0.94999998807907104</real> 				<key>PhysicalZenith</key> 				<real>0.28964641690254211</real> 				<key>PlatonicAzimuth</key> 				<real>0.17202088236808777</real> 				<key>PlatonicZenith</key> 				<real>0.28964641690254211</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.17202088236808777</real> 				<key>PhysicalRadius</key> 				<real>0.94999998807907104</real> 				<key>PhysicalZenith</key> 				<real>0.28964641690254211</real> 				<key>PlatonicAzimuth</key> 				<real>-0.17202088236808777</real> 				<key>PlatonicZenith</key> 				<real>0.28964641690254211</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.35241639614105225</real> 				<key>PhysicalRadius</key> 				<real>0.93541437387466431</real> 				<key>PhysicalZenith</key> 				<real>0.29611539840698242</real> 				<key>PlatonicAzimuth</key> 				<real>-0.35241639614105225</real> 				<key>PlatonicZenith</key> 				<real>0.29611539840698242</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.64758360385894775</real> 				<key>PhysicalRadius</key> 				<real>0.93541437387466431</real> 				<key>PhysicalZenith</key> 				<real>0.29611539840698242</real> 				<key>PlatonicAzimuth</key> 				<real>-0.64758360385894775</real> 				<key>PlatonicZenith</key> 				<real>0.29611539840698242</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.82797908782958984</real> 				<key>PhysicalRadius</key> 				<real>0.94999998807907104</real> 				<key>PhysicalZenith</key> 				<real>0.28964641690254211</real> 				<key>PlatonicAzimuth</key> 				<real>-0.82797908782958984</real> 				<key>PlatonicZenith</key> 				<real>0.28964641690254211</real> 			</dict> 		</array> 		<array> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.75</real> 				<key>PhysicalRadius</key> 				<real>0.89582365751266479</real> 				<key>PhysicalZenith</key> 				<real>0.39774900674819946</real> 				<key>PlatonicAzimuth</key> 				<real>0.75</real> 				<key>PlatonicZenith</key> 				<real>0.39774900674819946</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.5</real> 				<key>PhysicalRadius</key> 				<real>0.90138781070709229</real> 				<key>PhysicalZenith</key> 				<real>0.39199984073638916</real> 				<key>PlatonicAzimuth</key> 				<real>0.5</real> 				<key>PlatonicZenith</key> 				<real>0.39199984073638916</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.25</real> 				<key>PhysicalRadius</key> 				<real>0.89582365751266479</real> 				<key>PhysicalZenith</key> 				<real>0.39774900674819946</real> 				<key>PlatonicAzimuth</key> 				<real>0.25</real> 				<key>PlatonicZenith</key> 				<real>0.39774900674819946</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.25</real> 				<key>PhysicalRadius</key> 				<real>0.89582365751266479</real> 				<key>PhysicalZenith</key> 				<real>0.39774900674819946</real> 				<key>PlatonicAzimuth</key> 				<real>-0.25</real> 				<key>PlatonicZenith</key> 				<real>0.39774900674819946</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.5</real> 				<key>PhysicalRadius</key> 				<real>0.90138781070709229</real> 				<key>PhysicalZenith</key> 				<real>0.39199984073638916</real> 				<key>PlatonicAzimuth</key> 				<real>-0.5</real> 				<key>PlatonicZenith</key> 				<real>0.39199984073638916</real> 			</dict> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>-0.75</real> 				<key>PhysicalRadius</key> 				<real>0.89582365751266479</real> 				<key>PhysicalZenith</key> 				<real>0.39774900674819946</real> 				<key>PlatonicAzimuth</key> 				<real>-0.75</real> 				<key>PlatonicZenith</key> 				<real>0.39774900674819946</real> 			</dict> 		</array> 		<array> 			<dict> 				<key>PhysicalAzimuth</key> 				<real>0.0</real> 				<key>PhysicalRadius</key> 				<real>1</real> 				<key>PhysicalZenith</key> 				<real>0.5</real> 				<key>PlatonicAzimuth</key> 				<real>0.0</real> 				<key>PlatonicZenith</key> 				<real>0.5</real> 			</dict> 		</array> 	</array> </dict> </plist> ";
	NSData* plistData = [plistString dataUsingEncoding: NSASCIIStringEncoding];
	NSString* error;
	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0; 
	NSDictionary* plist = [NSPropertyListSerialization propertyListFromData: plistData mutabilityOption: NSPropertyListImmutable format: &format errorDescription: &error]; 
	ZKMNRSpeakerLayout* speakerLayout = [[ZKMNRSpeakerLayout alloc] init];
	[speakerLayout setFromDictionaryRepresentation: plist];
	return speakerLayout;
}

@end
