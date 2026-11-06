//
//  MTIRenderGraphMerge.m
//  MetalPetal
//
//  Created by Yu Ao on 20/11/2017.
//

#import "MTIRenderGraphOptimization.h"
#import "MTIImagePromise.h"
#import "MTIImage+Promise.h"
#import "MTIRenderPipelineKernel.h"
#import "MTIMultilayerCompositeKernel.h"

@interface MTIRenderGraphNode ()

@property (nonatomic, strong) NSMutableSet *outputs;

@end

@implementation MTIRenderGraphNode

- (instancetype)init {
    if (self = [super init]) {
        _inputs = nil;
        _outputs = [NSMutableSet set];
    }
    return self;
}

- (NSInteger)uniqueDependentCount {
    return _outputs.count;
}

@end

@implementation MTIRenderGraphOptimizer

+ (MTIRenderGraphNode *)nodeForImage:(MTIImage *)image dependent:(MTIRenderGraphNode *)dependent nodeTable:(NSMapTable *)nodeTable {
    MTIRenderGraphNode *node = [nodeTable objectForKey:image];
    if (!node) {
        node = [[MTIRenderGraphNode alloc] init];
        [nodeTable setObject:node forKey:image];
        node.image = image;
        NSMutableArray *inputs = [NSMutableArray array];
        for (MTIImage *img in image.promise.dependencies) {
            [inputs addObject:[self nodeForImage:img dependent:node nodeTable:nodeTable]];
        }
        node.inputs = inputs;
    }
    [node.outputs addObject:dependent.image.promise];
    return node;
}

+ (BOOL)performOptimizationOnNode:(MTIRenderGraphNode *)node promiseTable:(NSMapTable<id<MTIImagePromise>, id<MTIImagePromise>> *)promiseTable visited:(NSHashTable<MTIRenderGraphNode *> *)visited {
    // A node shared by several consumers is optimized once; walking it again per path is exponential in the shared depth.
    if (node.image.cachePolicy != MTIImageCachePolicyTransient || [visited containsObject:node]) {
        return NO;
    }
    [visited addObject:node];

    BOOL optimized = NO;
    for (MTIRenderGraphNode *inputNode in node.inputs) {
        if ([self performOptimizationOnNode:inputNode promiseTable:promiseTable visited:visited]) {
            optimized = YES;
        }
    }
    id<MTIImagePromise> promise = [promiseTable objectForKey:node.image.promise];
    if (promise) {
        if (node.image.promise != promise) {
            node.image = [[MTIImage alloc] initWithPromise:promise samplerDescriptor:node.image.samplerDescriptor cachePolicy:node.image.cachePolicy];
        }
    } else {
        id<MTIImagePromise> orgPromise = node.image.promise;
        MTIColorMatrixRenderGraphNodeOptimize(node);
        MTIMultilayerCompositingRenderGraphNodeOptimize(node);
        [promiseTable setObject:node.image.promise forKey:orgPromise];
        if (node.image.promise != orgPromise) {
            optimized = YES;
        }
    }
    return optimized;
}

+ (MTIImage *)generateOptimizedImageForNode:(MTIRenderGraphNode *)node promiseTable:(NSMapTable<id<MTIImagePromise>, id<MTIImagePromise>> *)promiseTable {
    if (node.inputs.count == 0 || node.image.cachePolicy != MTIImageCachePolicyTransient) {
        return node.image;
    }
    
    id<MTIImagePromise> promise = [promiseTable objectForKey:node.image.promise];
    if (!promise) {
        NSMutableArray<MTIImage *> *dependencies = [NSMutableArray array];
        for (MTIRenderGraphNode *inputNode in node.inputs) {
            [dependencies addObject:[self generateOptimizedImageForNode:inputNode promiseTable:promiseTable]];
        }
        promise = [node.image.promise promiseByUpdatingDependencies:dependencies];
        [promiseTable setObject:promise forKey:node.image.promise];
    }
    return [[MTIImage alloc] initWithPromise:promise samplerDescriptor:node.image.samplerDescriptor cachePolicy:node.image.cachePolicy];
}

+ (id<MTIImagePromise>)promiseByOptimizingRenderGraphOfPromise:(id<MTIImagePromise>)promise {
    //return promise;
    
    NSMapTable *table = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory|NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory];
    
    //Build nodes graph
    MTIRenderGraphNode *rootNode = [[MTIRenderGraphNode alloc] init];
    rootNode.image = [[MTIImage alloc] initWithPromise:promise];
    NSMutableArray *inputs = [NSMutableArray array];
    for (MTIImage *image in promise.dependencies) {
        [inputs addObject:[self nodeForImage:image dependent:rootNode nodeTable:table]];
    }
    rootNode.inputs = inputs;
    
    //Optimize render graph
    [table removeAllObjects];
    BOOL optimized = [self performOptimizationOnNode:rootNode promiseTable:table visited:[NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality]];
    if (optimized) {
        //Create merged promise
        [table removeAllObjects];
        return [self generateOptimizedImageForNode:rootNode promiseTable:table].promise;
    } else {
        return promise;
    }
}

@end
