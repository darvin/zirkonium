//
//  ZKMNRValueTransformer.mm
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 17.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRValueTransformer.h"
#import "ZKMORLogger.h"

class ZKMNRTransformerRegistrer
{
public:
	//  CTOR
	ZKMNRTransformerRegistrer() 
	{
		// just touch the classes to force an initialize
		[ZKMNRIndexTransformer class];
	}
};

ZKMNRTransformerRegistrer gTransformerRegistrer;


@implementation ZKMNRIndexTransformer
#pragma mark _____ NSObject Overrides
+ (void)initialize
{
	if (self == [ZKMNRIndexTransformer class]) {
		// register the transformer
		ZKMNRIndexTransformer* transformer = [[ZKMNRIndexTransformer alloc] init];
		[NSValueTransformer setValueTransformer: transformer forName: @"ZKMNRIndexTransformer"];
		[transformer release];
	}
}

#pragma mark _____ NSValueTransformer Overrides
+ (Class)transformedValueClass { return [NSNumber self]; }
+ (BOOL)allowsReverseTransformation { return YES; }

- (id)transformedValue:(id)value 
{
	if (nil == value) return nil;
	if (![value respondsToSelector: @selector(intValue)]) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Attempt to use non-numerical value as an index: %@"), [value description]);
		return nil;
	}
	
	int theIndex = [value intValue];
	if (theIndex < 0)
		theIndex = 0;

	return [NSNumber numberWithInt: theIndex + 1];
}

- (id)reverseTransformedValue:(id)value
{
	if (nil == value) return nil;
	if (![value respondsToSelector: @selector(intValue)]) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Attempt to input non-numerical value as an index: %@"), [value description]);
		return nil;
	}
	
	int theIndex = [value intValue];
	if (theIndex < 1)
		theIndex = 1;

	return [NSNumber numberWithInt: theIndex - 1];
}

@end

#pragma mark _____ Convenience Functions
void	SecondsToHHMMSSMS(Float64 seconds, unsigned* hours, unsigned* mins, unsigned* secs, unsigned* msecs)
{
	Float64 remaining = seconds;
	Float64 hh, mm, ss, ms;
	hh = floor(remaining / 3600.); remaining = remaining - hh * 3600.;
	mm = floor(remaining / 60.); remaining = remaining - mm * 60.;
	ss = floor(remaining); remaining = remaining - ss;
	ms = remaining * 1000.;
	*hours = lrint(hh); *mins = lrint(mm); *secs = lrint(ss); *msecs = lrint(ms);
}

void	HHMMSSMSToSeconds(unsigned hours, unsigned mins, unsigned secs, unsigned msecs, Float64* total)
{
	Float64 sum = (Float64) ((hours * 3600.) + (mins * 60.) + ((Float64) secs) + (msecs * 0.001));
	*total = sum;
}

void	SecondsToMMSSMS(Float64 seconds, unsigned* mins, unsigned* secs, unsigned* msecs)
{
	Float64 remaining = seconds;
	Float64 mm, ss, ms;
	mm = floor(remaining / 60.); remaining = remaining - mm * 60.;
	ss = floor(remaining); remaining = remaining - ss;
	ms = remaining * 1000.;
	*mins = lrint(mm); *secs = lrint(ss); *msecs = lrint(ms);
}

void	MMSSMSToSeconds(unsigned mins, unsigned secs, unsigned msecs, Float64* total)
{
	Float64 sum = (Float64) ((mins * 60.) + ((Float64) secs) + (msecs * 0.001));
	*total = sum;
}