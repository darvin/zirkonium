//
//  ZKMRLMixerLight.m
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 08.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRLMixerLight.h"

NSString* ZKMRLMixerLightChangedSizeNotification = @"ZKMRLMixerLightChangedSizeNotification";

@interface ZKMRLMixerLight (ZKMRLMixerLightPrivate)
- (void)privateUpdateMixerSize;
@end


@implementation ZKMRLMixerLight

- (void)dealloc
{
	if (_coefficients) free(_coefficients);
	[_inputColors release];
	[_outputColors release];
	
	[super dealloc];
}

#pragma mark _____ NSObject Overrides
- (id)init
{
	if (!(self = [super init])) return nil;
	_inputColors = [[NSMutableArray alloc] init];
	_outputColors = [[NSMutableArray alloc] init];
	_numberOfInputChannels = 2;
	_numberOfOutputChannels = 2;
	_coefficients = NULL;
	[self privateUpdateMixerSize];
	
	_isSynchedWithOutput = NO;
	
	return self;
}

#pragma mark _____ Accessors
- (unsigned)numberOfInputChannels { return _numberOfInputChannels; }
- (void)setNumberOfInputChannels:(unsigned)numberOfInputChannels { _numberOfInputChannels = numberOfInputChannels; [self privateUpdateMixerSize]; }

- (unsigned)numberOfOutputChannels { return _numberOfOutputChannels; }
- (void)setNumberOfOutputChannels:(unsigned)numberOfOutputChannels { _numberOfOutputChannels = numberOfOutputChannels; [self privateUpdateMixerSize]; }

#pragma mark _____ Matrix Accessors
- (NSColor *)colorForInput:(unsigned)inputNum { return [_inputColors objectAtIndex: inputNum]; }

- (void)setColor:(NSColor *)color forInput:(unsigned)inputNum
{
	[_inputColors replaceObjectAtIndex: inputNum withObject: [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace]];
	_isSynchedWithOutput = NO;
}

- (float)valueForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum
{
	return _coefficients[inputNum * _numberOfOutputChannels + outputNum];
}

- (void)setValue:(float)value forCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum
{
	_coefficients[inputNum * _numberOfOutputChannels + outputNum] = value;
	_isSynchedWithOutput = NO;
}

- (NSColor *)colorForOutput:(unsigned)outputNum { return [_outputColors objectAtIndex: outputNum]; }

#pragma mark _____ Queries
- (BOOL)isSynchedWithOutput { return _isSynchedWithOutput; }
- (void)setSynchedWithOutput:(BOOL)isSynchedWithOutput { _isSynchedWithOutput = isSynchedWithOutput; }

- (void)updateOutputColors
{
	if (_isSynchedWithOutput) return;
	
	unsigned i, j;
	[_outputColors removeAllObjects];
	for (i = 0; i < _numberOfOutputChannels; ++i) 
	{
		float outR = 0.f, outG = 0.f, outB = 0.f;
		for (j = 0; j < _numberOfInputChannels; ++j)
		{
			float r, g, b, a;
			float coeff = _coefficients[j * _numberOfOutputChannels + i];
			if (coeff < 0.001) continue;
			NSColor* inputColor = [self colorForInput: j];
			[inputColor getRed: &r green: &g blue: &b alpha: &a];
			outR += r * coeff; outG += g * coeff; outB += b * coeff;
		}
			// colorWithCalibratedRed:green:blue:alpha: will automatically clamp values > 1.f
		[_outputColors insertObject: [NSColor colorWithCalibratedRed: outR green: outG blue: outB alpha: 1.f] atIndex: i];
	}
}

- (void)setToDiagonalLevels
{
	unsigned i, count = MAX(_numberOfInputChannels, _numberOfOutputChannels);
	memset(_coefficients, 0, _coefficientsSize);
	for (i = 0; i < count; ++i) [self setValue: 1.f forCrosspointInput: i % _numberOfInputChannels output: i % _numberOfOutputChannels];
}

- (void)setOutputsOn
{
	unsigned i;
		// set the output coefficients to 1.0
	for (i = 0; i < _numberOfOutputChannels; i++) _coefficients[_numberOfInputChannels * _numberOfOutputChannels + i] = 1.f;
}

#pragma mark _____ ZKMRLMixerLightPrivate
- (void)privateUpdateMixerSize
{
	if (_coefficients) free(_coefficients);
	_coefficientsSize = _coefficientsSize = (_numberOfInputChannels + 1) * _numberOfOutputChannels;
	_coefficients = (float *) calloc(_coefficientsSize, sizeof(float));
	
	// re-initialize the input and output colors
	[_inputColors removeAllObjects];
	[_outputColors removeAllObjects];
	unsigned i;
	NSColor* blackColor = [[NSColor blackColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
	for (i = 0; i < _numberOfInputChannels; i++) [_inputColors insertObject: blackColor atIndex: i];
	for (i = 0; i < _numberOfOutputChannels; i++) [_outputColors insertObject: blackColor atIndex: i];	
	[self setOutputsOn];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRLMixerLightChangedSizeNotification object: self];
}

@end
