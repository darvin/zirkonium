//
//  ZKMRNGraphChannel.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 22.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

extern NSString* ZKMRNGraphChannelChangedInitalNotification;

@interface ZKMRNGraphChannel : NSManagedObject {

}

//  Accessors
- (void)setGraphChannelIndex:(NSNumber *)graphChannelIndex;
- (void)setGraphChannelNumber:(NSNumber *)graphChannelNumber;
- (void)setSourceChannelNumber:(NSNumber *)sourceChannelNumber;
- (void)setSource:(NSManagedObject *)source;

- (void)setInitialAzimuth:(NSNumber *)azimuth;
- (void)setInitialZenith:(NSNumber *)zenith;
- (void)setInitialAzimuthSpan:(NSNumber *)azimuthSpan;
- (void)setInitialZenithSpan:(NSNumber *)zenithSpan;
- (void)setInitialGain:(NSNumber *)gain;

// Mute / Solo support
- (BOOL)isMute;
- (void)setMute:(BOOL)isMute;
	// Solo not yet implemented.
- (BOOL)isSolo;
- (void)setSolo:(BOOL)isSolo;

- (NSColor *)color;
- (void)setColor:(NSColor *)color;

- (NSImage *)colorImage;

- (NSNumber *)displayGraphChannelNumber;
- (NSNumber *)displaySourceChannelNumber;
- (NSString *)displayString;

- (ZKMNRPannerSource *)pannerSource;
- (NSArray *)pannerSources;

@end
