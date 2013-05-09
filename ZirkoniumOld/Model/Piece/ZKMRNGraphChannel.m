//
//  ZKMRNGraphChannel.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 22.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNGraphChannel.h"
#import "ZKMRNZirkoniumSystem.h"

NSString* ZKMRNGraphChannelChangedInitalNotification = @"ZKMRNGraphChannelChangedInitalNotification";


@implementation ZKMRNGraphChannel
#pragma mark _____ NSManagedObject Overrides
- (void)dealloc
{
//	[self removeObserver: self forKeyPath: @"initialAzimuth"];
//	[self removeObserver: self forKeyPath: @"initialZenith"];
		// this line causes a crash for some reason
//	[self removeObserver: self forKeyPath: @"source.numberOfChannels"];
	[super dealloc];
}

- (id)initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(NSManagedObjectContext *)context
{
	if (!(self = [super initWithEntity: entity insertIntoManagedObjectContext: context])) return nil;

	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{

}

#pragma mark _____ Accessors
- (void)setGraphChannelNumber:(NSNumber *)graphChannelNumber
{
	[self willChangeValueForKey: @"graphChannelNumber"];
	[self willChangeValueForKey: @"displayGraphChannelNumber"];
	[self willChangeValueForKey: @"displayString"];	
	[self setPrimitiveValue: graphChannelNumber forKey: @"graphChannelNumber"];
	[self setPrimitiveValue: nil forKey: @"displayString"];
	[self didChangeValueForKey: @"graphChannelNumber"];
	[self didChangeValueForKey: @"displayGraphChannelNumber"];
	[self didChangeValueForKey: @"displayString"];
}

- (void)setSourceChannelNumber:(NSNumber *)sourceChannelNumber
{
	[self willChangeValueForKey: @"sourceChannelNumber"];
	[self willChangeValueForKey: @"displaySourceChannelNumber"];
	[self setPrimitiveValue: sourceChannelNumber forKey: @"sourceChannelNumber"];
	[self didChangeValueForKey: @"sourceChannelNumber"];
	[self didChangeValueForKey: @"displaySourceChannelNumber"];
}

- (void)setSource:(NSManagedObject *)source
{
	[self willChangeValueForKey: @"source"];
	[self setPrimitiveValue: source forKey: @"source"];
	[self didChangeValueForKey: @"source"];
}

- (void)setInitialAzimuth:(NSNumber *)azimuth
{
	[self willChangeValueForKey: @"initialAzimuth"];
	[self setPrimitiveValue: azimuth forKey: @"initialAzimuth"];
	[self didChangeValueForKey: @"initialAzimuth"];
	
	ZKMNRPannerSource* source = [self pannerSource];
	ZKMNRSphericalCoordinate initialCenter = [source initialCenter];
	initialCenter.azimuth = [azimuth floatValue];
	[source setInitialCenter: initialCenter];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNGraphChannelChangedInitalNotification object: source];
}

- (void)setInitialZenith:(NSNumber *)zenith
{
	[self willChangeValueForKey: @"initialZenith"];
	[self setPrimitiveValue: zenith forKey: @"initialZenith"];
	[self didChangeValueForKey: @"initialZenith"];
	
	ZKMNRPannerSource* source = [self pannerSource];
	ZKMNRSphericalCoordinate initialCenter = [source initialCenter];
	initialCenter.zenith = [zenith floatValue];
	[source setInitialCenter: initialCenter];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNGraphChannelChangedInitalNotification object: source];
}

- (void)setInitialAzimuthSpan:(NSNumber *)azimuthSpan
{
	[self willChangeValueForKey: @"initialAzimuthSpan"];
	[self setPrimitiveValue: azimuthSpan forKey: @"initialAzimuthSpan"];
	[self didChangeValueForKey: @"initialAzimuthSpan"];
	
	ZKMNRPannerSource* source = [self pannerSource];
	ZKMNRSphericalCoordinateSpan initialSpan = [source initialSpan];
	initialSpan.azimuthSpan = [azimuthSpan floatValue];
	[source setInitialSpan: initialSpan];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNGraphChannelChangedInitalNotification object: source];
}

- (void)setInitialZenithSpan:(NSNumber *)zenithSpan
{
	[self willChangeValueForKey: @"initialZenithSpan"];
	[self setPrimitiveValue: zenithSpan forKey: @"initialZenithSpan"];
	[self didChangeValueForKey: @"initialZenithSpan"];
	
	ZKMNRPannerSource* source = [self pannerSource];
	ZKMNRSphericalCoordinateSpan initialSpan = [source initialSpan];
	initialSpan.zenithSpan = [zenithSpan floatValue];
	[source setInitialSpan: initialSpan];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNGraphChannelChangedInitalNotification object: source];
}

- (void)setInitialGain:(NSNumber *)gain
{
	[self willChangeValueForKey: @"initialGain"];
	[self setPrimitiveValue: gain forKey: @"initialGain"];
	[self didChangeValueForKey: @"initialGain"];
	
	ZKMNRPannerSource* source = [self pannerSource];
	[source setInitialGain: [gain floatValue]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNGraphChannelChangedInitalNotification object: source];
}

- (BOOL)isMute { return [[self pannerSource] isMute]; }
- (void)setMute:(BOOL)isMute { [[self pannerSource] setMute: isMute]; }
- (BOOL)isSolo { return YES; }
- (void)setSolo:(BOOL)isSolo { }

- (NSColor *)color
{
	[self willAccessValueForKey: @"color"];
	NSColor* color = [self primitiveValueForKey: @"color"];
	[self didAccessValueForKey: @"color"];
	if (color == nil) {
		NSData* colorData = [self valueForKey: @"colorData"];
		if(colorData != nil) {
			//BUGFIX: Make sure color is rgb color //couldn't handle monochrome or gray
			color = [[NSKeyedUnarchiver unarchiveObjectWithData: colorData] colorUsingColorSpaceName:NSCalibratedRGBColorSpace device:nil]; 
		} 
		if(color==nil) 
		{	//something went wrong with conversion or colorData was nil
			color = [NSColor colorWithCalibratedRed: ZKMORFRand() green: ZKMORFRand() blue: ZKMORFRand() alpha: 1.f];
		}	
			
		// make sure the color has an adaquate brightness
		if ([color brightnessComponent] < 0.5f) {
			color = [NSColor colorWithCalibratedHue: [color hueComponent] saturation: [color saturationComponent] brightness: 0.5f alpha: 1.f];
		}
		

		[self setPrimitiveValue: color forKey:@"color"];
			// save the color I generated
		if (!colorData)	[self setValue: [NSKeyedArchiver archivedDataWithRootObject: color] forKey: @"colorData"];
	}
	return color;
} 

- (void)setColor:(NSColor *)color
{
	//BUGFIX: Make sure color is rgb color //couldn't handle monochrome or gray
	NSColor* truecolor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace device:nil]; 


	[self willChangeValueForKey: @"color"];
	[self willChangeValueForKey: @"colorImage"];
	[self setPrimitiveValue: truecolor forKey: @"color"];
	[self setPrimitiveValue: nil forKey: @"colorImage"];
	[self didChangeValueForKey: @"color"];
	[self didChangeValueForKey: @"colorImage"];
	
	[self setValue: [NSKeyedArchiver archivedDataWithRootObject: truecolor] forKey: @"colorData"];
}

- (NSImage *)colorImage
{
	[self willAccessValueForKey: @"colorImage"];
	NSImage* colorImage = [self primitiveValueForKey: @"colorImage"];
	[self didAccessValueForKey: @"colorImage"];
	if (colorImage == nil) {
		NSColor* color = [self color];
		NSSize imageSize = NSMakeSize(32.f, 32.f);
		colorImage = [[NSImage alloc] initWithSize: imageSize];
			// draw a solid single color image
		[colorImage lockFocus];
			[color set];
			NSRectFill(NSMakeRect(0.f, 0.f, 32.f, 32.f));
		[colorImage unlockFocus];
		
		[self setPrimitiveValue: colorImage forKey:  @"colorImage"];
		[colorImage release];
	}
	return colorImage;
}

- (NSNumber *)displayGraphChannelNumber
{
	return [NSNumber numberWithInt: [[self valueForKey: @"graphChannelNumber"] intValue] + 1];
}

- (NSNumber *)displaySourceChannelNumber
{
	return [NSNumber numberWithInt: [[self valueForKey: @"sourceChannelNumber"] intValue] + 1];
}

- (NSString *)displayString
{
	[self willAccessValueForKey: @"displayString"];
	NSString* displayString = [self primitiveValueForKey: @"displayString"];
	[self didAccessValueForKey: @"displayString"];
	
	if (!displayString) {
		displayString = [NSString stringWithFormat: @"%.2u", [[self valueForKey: @"graphChannelNumber"] intValue] + 1];
		[self setPrimitiveValue: displayString forKey: @"displayString"];
	}

	return displayString;
}

- (ZKMNRPannerSource *)pannerSource
{
	[self willAccessValueForKey: @"pannerSource"];
	ZKMNRPannerSource* pannerSource = [self primitiveValueForKey: @"pannerSource"];
	[self didAccessValueForKey: @"pannerSource"];
	
	if (!pannerSource) {
		pannerSource = [[ZKMNRPannerSource alloc] init]; 
		[pannerSource setTag: self];
		[[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] panner] registerPannerSource: pannerSource];
		ZKMNRSphericalCoordinate center;
		center.azimuth = [[self valueForKey: @"initialAzimuth"] floatValue]; center.zenith = [[self valueForKey: @"initialZenith"] floatValue]; center.radius = 1.f;
		ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
		[pannerSource setInitialCenter: center span: span gain: [[self valueForKey: @"initialGain"] floatValue]];
		[pannerSource setCenter: center span: span gain: [[self valueForKey: @"initialGain"] floatValue]];
		[self setPrimitiveValue: pannerSource forKey: @"pannerSource"];
		[pannerSource release];
	}

	return pannerSource;
}

- (NSArray *)pannerSources { return [NSArray arrayWithObject: [self pannerSource]]; }


@end
