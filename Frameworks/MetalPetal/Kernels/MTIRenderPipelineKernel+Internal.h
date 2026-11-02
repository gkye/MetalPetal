//
//  MTIRenderPipelineKernel+Internal.h
//  MetalPetal
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#if __has_include(<MetalPetal/MetalPetal.h>)
#import <MetalPetal/MTIImagePromise.h>
#import <MetalPetal/MTIRenderPipelineKernel.h>
#else
#import "MTIImagePromise.h"
#import "MTIRenderPipelineKernel.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class MTIContext;

/// The draws of a render-pipeline image. With `deliveryTexture` set, the pass draws into a memoryless attachment and ends with a tile copy into that texture, so the result never lands in a pooled texture.
__attribute__((objc_subclassing_restricted))
@interface MTIImageRenderingRecipe : NSObject

@property (nonatomic, copy, readonly) NSArray<MTIRenderCommand *> *renderCommands;

@property (nonatomic, copy, readonly) NSArray<MTIRenderPassOutputDescriptor *> *outputDescriptors;

@property (nonatomic, readonly) NSUInteger rasterSampleCount;

@property (nonatomic, strong, readonly, nullable) id<MTLTexture> deliveryTexture;

@end

__attribute__((objc_subclassing_restricted))
@interface MTIImageRenderingPromise : NSObject <MTIImagePromise>

@property (nonatomic, strong, readonly) MTIImageRenderingRecipe *recipe;

@property (nonatomic, readonly) NSUInteger outputIndex;

/// The same draws delivered into `texture`; nil when they cannot be: several outputs, multisampling, another size, or a context without memoryless textures and programmable blending.
- (nullable instancetype)promiseByDeliveringToTexture:(id<MTLTexture>)texture context:(MTIContext *)context;

@end

NS_ASSUME_NONNULL_END
