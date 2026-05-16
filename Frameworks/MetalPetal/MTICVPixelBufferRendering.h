//
//  MTICVPixelBufferRendering.h
//  MetalPetal
//
//  Created by Yu Ao on 08/04/2018.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MTICVPixelBufferRenderingAPI) {
    MTICVPixelBufferRenderingAPIDefault = 1,
    MTICVPixelBufferRenderingAPIMetalPetal = 1,
    MTICVPixelBufferRenderingAPICoreImage = 2
};

typedef NS_ENUM(NSInteger, MTIYCbCrRange) {
    MTIYCbCrRangeVideo = 0,
    MTIYCbCrRangeFull = 1
};

typedef NS_ENUM(NSInteger, MTIYCbCrMatrix) {
    MTIYCbCrMatrixITU_R_601_4 = 0,
    MTIYCbCrMatrixITU_R_709_2 = 1,
    MTIYCbCrMatrixITU_R_2020 = 2,
    MTIYCbCrMatrixITU_R_2020_ConstantLuminance = 3
};

typedef NS_ENUM(NSInteger, MTIColorPrimaries) {
    MTIColorPrimariesITU_R_709_2 = 0,
    MTIColorPrimariesITU_R_2020 = 1,
    MTIColorPrimariesP3_D65 = 2,
    MTIColorPrimariesUnknown = 255
};

typedef NS_ENUM(NSInteger, MTITransferFunction) {
    MTITransferFunctionITU_R_709_2 = 0,
    MTITransferFunctionSRGB = 1,
    MTITransferFunctionSMPTE_ST_2084_PQ = 2,
    MTITransferFunctionITU_R_2100_HLG = 3,
    MTITransferFunctionUnknown = 255
};

typedef NS_ENUM(NSInteger, MTIYCbCrAlphaMode) {
    MTIYCbCrAlphaModeAlphaIsOne = 0
};

__attribute__((objc_subclassing_restricted))
@interface MTIYCbCrPixelBufferConversion: NSObject <NSCopying>

@property (nonatomic, readonly) MTIYCbCrRange range;
@property (nonatomic, readonly) MTIYCbCrMatrix matrix;
@property (nonatomic, readonly) MTIColorPrimaries primaries;
@property (nonatomic, readonly) MTITransferFunction transferFunction;
@property (nonatomic, readonly) NSUInteger bitDepth;
@property (nonatomic, readonly) MTIYCbCrAlphaMode alphaMode;

+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithRange:(MTIYCbCrRange)range
                       matrix:(MTIYCbCrMatrix)matrix
                    primaries:(MTIColorPrimaries)primaries
             transferFunction:(MTITransferFunction)transferFunction
                     bitDepth:(NSUInteger)bitDepth
                    alphaMode:(MTIYCbCrAlphaMode)alphaMode NS_DESIGNATED_INITIALIZER;

@end

__attribute__((objc_subclassing_restricted))
@interface MTICVPixelBufferRenderingOptions: NSObject <NSCopying>

@property (nonatomic, readonly) MTICVPixelBufferRenderingAPI renderingAPI;

@property (nonatomic, readonly) BOOL sRGB; //An option for treating the pixel buffer data as sRGB image data. Specifying whether to create the texture with an sRGB (gamma corrected) pixel format.

@property (nonatomic, strong, nullable, readonly) MTIYCbCrPixelBufferConversion *explicitYCbCrConversion;

+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithRenderingAPI:(MTICVPixelBufferRenderingAPI)renderingAPI sRGB:(BOOL)sRGB;

- (instancetype)initWithRenderingAPI:(MTICVPixelBufferRenderingAPI)renderingAPI
                                 sRGB:(BOOL)sRGB
             explicitYCbCrConversion:(nullable MTIYCbCrPixelBufferConversion *)explicitYCbCrConversion NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, class, readonly) MTICVPixelBufferRenderingOptions *defaultOptions;

@end

NS_ASSUME_NONNULL_END
