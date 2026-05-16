//
//  MTICVPixelBufferRendering.m
//  MetalPetal
//
//  Created by Yu Ao on 08/04/2018.
//

#import "MTICVPixelBufferRendering.h"

@implementation MTIYCbCrPixelBufferConversion

- (instancetype)initWithRange:(MTIYCbCrRange)range
                       matrix:(MTIYCbCrMatrix)matrix
                    primaries:(MTIColorPrimaries)primaries
             transferFunction:(MTITransferFunction)transferFunction
                     bitDepth:(NSUInteger)bitDepth
                    alphaMode:(MTIYCbCrAlphaMode)alphaMode {
    if (self = [super init]) {
        _range = range;
        _matrix = matrix;
        _primaries = primaries;
        _transferFunction = transferFunction;
        _bitDepth = bitDepth;
        _alphaMode = alphaMode;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

@end

@implementation MTICVPixelBufferRenderingOptions

- (instancetype)initWithRenderingAPI:(MTICVPixelBufferRenderingAPI)renderingAPI sRGB:(BOOL)sRGB {
    return [self initWithRenderingAPI:renderingAPI sRGB:sRGB explicitYCbCrConversion:nil];
}

- (instancetype)initWithRenderingAPI:(MTICVPixelBufferRenderingAPI)renderingAPI
                                 sRGB:(BOOL)sRGB
             explicitYCbCrConversion:(MTIYCbCrPixelBufferConversion *)explicitYCbCrConversion {
    if (self = [super init]) {
        _renderingAPI = renderingAPI;
        _sRGB = sRGB;
        _explicitYCbCrConversion = explicitYCbCrConversion;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

+ (MTICVPixelBufferRenderingOptions *)defaultOptions {
    static MTICVPixelBufferRenderingOptions *options;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        options = [[MTICVPixelBufferRenderingOptions alloc] initWithRenderingAPI:MTICVPixelBufferRenderingAPIDefault sRGB:NO];
    });
    return options;
}

@end
