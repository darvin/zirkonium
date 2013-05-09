//
//  ZKMRNFileSource.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 23.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNFileSource.h"
#import "ZKMRNZirkoniumSystem.h"

@interface ZKMRNFileSource (ZKMRNFileSourcePrivate)
- (BOOL)isFilePathValid:(NSString *)path;
- (NSString *)locateLocalFileForPath:(NSString *)path;
@end


@implementation ZKMRNFileSource
#pragma mark _____ NSManagedObject Overrides
+ (void)initialize
{
	[self setKeys: [NSArray arrayWithObject: @"path"] triggerChangeNotificationsForDependentKey: @"conduit"];
	[self setKeys: [NSArray arrayWithObject: @"path"] triggerChangeNotificationsForDependentKey: @"duration"];
	[self setKeys: [NSArray arrayWithObject: @"path"] triggerChangeNotificationsForDependentKey: @"numberOfChannels"];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	NSString *path = [self valueForKey: @"path"];
	//NSLog(@"Awake From Fetch: %@", path);
	if (![self isFilePathValid: path]) {
		NSLog(@"Awake From Fetch: Not Valid");
		
		NSString* replacementPath = [self locateLocalFileForPath: path];
		if (replacementPath) 
			[self setPath: replacementPath];
	}
}

#pragma mark _____ ZKMRNAudioSource Overrides
- (ZKMORConduit *)conduit
{
	[self willAccessValueForKey: @"conduit"];
	ZKMORAudioFilePlayer* conduit = [self primitiveValueForKey: @"conduit"];
	[self didAccessValueForKey: @"conduit"];

	if (conduit == nil) {
		ZKMRNZirkoniumSystem* system = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
		conduit = [[ZKMORAudioFilePlayer alloc] initWithNumberOfInternalBuffers: [system filePlayerNumberOfBuffers] size: [system filePlayerBufferSize]];
		[conduit setSRCQuality: [system sampleRateConverterQuality]];
		NSString* path = [self valueForKey: @"path"];
			// only set the path if the path is valid
		if ([self isFilePathValid: path]) [conduit setFilePath: path error: &_lastError];
		[self setPrimitiveValue: conduit forKey: @"conduit"];
		[conduit release];
	}
	return conduit;
}

- (BOOL)isConduitValid 
{ 
	return [(ZKMORAbstractAudioFile *) [self conduit] isFileFSRefValid] != nil;
}

- (void)setCurrentTime:(Float64)seconds
{
	if (![self isConduitValid]) return;
	
	ZKMORAudioFilePlayer* conduit = (ZKMORAudioFilePlayer *)[self conduit];
	[conduit setCurrentSeconds: seconds];
}


#pragma mark _____ Accessors
- (NSNumber *)duration
{
	[self willAccessValueForKey: @"duration"];
	NSNumber* duration = [self primitiveValueForKey: @"duration"];
	[self didAccessValueForKey: @"duration"];

	if (duration == nil) {
		ZKMORAudioFilePlayer* conduit = (ZKMORAudioFilePlayer *)[self conduit];
		double primitiveDuration = [conduit isFileFSRefValid] ? [conduit duration] : 0.;
		duration = [[NSNumber alloc] initWithDouble: primitiveDuration];
		[self setPrimitiveValue: duration forKey: @"duration"];
		[duration release];
	}
	return duration;
}

- (void)setPath:(NSString *)path
{
	ZKMORAudioFilePlayer* conduit = (ZKMORAudioFilePlayer *)[self conduit];
	[self willChangeValueForKey: @"path"];
	[self setPrimitiveValue: path forKey: @"path"];
	
	if ([self isFilePathValid: path]) 
		[conduit setFilePath: path error: &_lastError];
	
	[self setPrimitiveValue: nil forKey: @"duration"];
	[self didChangeValueForKey: @"path"];
	
	if ([self isConduitValid]) 
		[self setValue: [NSNumber numberWithInt: [conduit numberOfChannels]] forKey: @"numberOfChannels"];
	else
		[self setValue: [NSNumber numberWithInt: 0] forKey: @"numberOfChannels"];		
	[self setValue: [[path lastPathComponent] stringByDeletingPathExtension] forKey: @"name"];
}

#pragma mark _____ ZKMRNFileSourcePrivate
- (BOOL)isFilePathValid:(NSString *)path
{
	BOOL success = (path && [[NSFileManager defaultManager] fileExistsAtPath: path]); 
		
	return success; 
}

- (NSString *)locateLocalFileForPath:(NSString *)path
{
	//NSLog(@"locateLocalFileForPath: %@", path);
	// try to locate the file...
	NSFileManager* fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath: path]) {

		NSString* fileName = [path lastPathComponent];
		//NSLog(@"locateLocalFileForPath: Path Last Component: %@", path);
		
		if ([fileManager fileExistsAtPath: fileName]) {
			return fileName;
		}
	}
	return nil;
}

+ (NSArray *)copyKeys 
{ 
	static NSArray* copyKeys = nil;
	if (!copyKeys) {
		copyKeys = [[NSArray alloc] initWithObjects: @"name", @"numberOfChannels", @"path", nil];
	}
	
	return copyKeys;
}
@end
