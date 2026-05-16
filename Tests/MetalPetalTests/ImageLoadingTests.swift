//
//  File.swift
//  
//
//  Created by YuAo on 2021/2/2.
//

import XCTest
import MetalPetal
import MetalPetalTestHelpers
import MetalPetalObjectiveC.Extension
import VideoToolbox

final class ImageLoadingTests: XCTestCase {
    
    func testExplicitYCbCrConversion_rec709VideoRange8Bit() throws {
        let pixelBuffer = try make8BitBiPlanarPixelBuffer(pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, y: 235, cb: 128, cr: 128)
        let cgImage = try renderExplicitYCbCr(pixelBuffer, range: 0, matrix: 1, primaries: 0, transferFunction: 0, bitDepth: 8)
        assertUniformPixel(in: cgImage, r: 255, g: 255, b: 255)
    }
    
    func testExplicitYCbCrConversion_rec709FullRange8Bit() throws {
        let pixelBuffer = try make8BitBiPlanarPixelBuffer(pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, y: 128, cb: 128, cr: 255)
        let cgImage = try renderExplicitYCbCr(pixelBuffer, range: 1, matrix: 1, primaries: 0, transferFunction: 0, bitDepth: 8)
        assertUniformPixel(in: cgImage, r: 255, g: 68, b: 128, tolerance: 2)
    }
    
    func testExplicitYCbCrConversion_rec2020VideoRange10Bit() throws {
        let pixelBuffer = try make10BitBiPlanarPixelBuffer(pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, y: 502, cb: 512, cr: 960)
        let cgImage = try renderExplicitYCbCr(pixelBuffer, range: 0, matrix: 2, primaries: 1, transferFunction: 3, bitDepth: 10)
        assertUniformPixel(in: cgImage, r: 255, g: 55, b: 128, tolerance: 2)
    }
    
    func testExplicitYCbCrConversionRejectsUnsupportedConstantLuminance() throws {
        let pixelBuffer = try make10BitBiPlanarPixelBuffer(pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, y: 502, cb: 512, cr: 512)
        let conversion = MTIYCbCrPixelBufferConversion(
            range: MTIYCbCrRange(rawValue: 0)!,
            matrix: MTIYCbCrMatrix(rawValue: 3)!,
            primaries: MTIColorPrimaries(rawValue: 1)!,
            transferFunction: MTITransferFunction(rawValue: 3)!,
            bitDepth: 10,
            alphaMode: MTIYCbCrAlphaMode(rawValue: 0)!
        )
        let options = MTICVPixelBufferRenderingOptions(
            renderingAPI: MTICVPixelBufferRenderingAPI(rawValue: 1)!,
            sRGB: false,
            explicitYCbCrConversion: conversion
        )
        let image = MTIImage(cvPixelBuffer: pixelBuffer, options: options, alphaType: .alphaIsOne)
        let context = try makeContext()
        XCTAssertThrowsError(try context.makeCGImage(from: image))
    }
    
    func testCVPixelBufferLoading_cvMetalTextureCache() throws {
        var buffer: CVPixelBuffer?
        let r = CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &buffer)
        guard let pixelBuffer = buffer, r == kCVReturnSuccess else {
            XCTFail("Cannot create pixel buffer.")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let pixels = CVPixelBufferGetBaseAddress(pixelBuffer)?.assumingMemoryBound(to: UInt8.self) {
            pixels.advanced(by: 0).assign(repeating: 255, count: 1)
            pixels.advanced(by: 1).assign(repeating: 0, count: 1)
            pixels.advanced(by: 2).assign(repeating: 0, count: 1)
            pixels.advanced(by: 3).assign(repeating: 255, count: 1)
            pixels.advanced(by: 0 + CVPixelBufferGetBytesPerRow(pixelBuffer)).assign(repeating: 0, count: 1)
            pixels.advanced(by: 1 + CVPixelBufferGetBytesPerRow(pixelBuffer)).assign(repeating: 255, count: 1)
            pixels.advanced(by: 2 + CVPixelBufferGetBytesPerRow(pixelBuffer)).assign(repeating: 0, count: 1)
            pixels.advanced(by: 3 + CVPixelBufferGetBytesPerRow(pixelBuffer)).assign(repeating: 255, count: 1)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        let image = MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .nonPremultiplied)
        let options = MTIContextOptions()
        options.coreVideoMetalTextureBridgeClass = MTICVMetalTextureCache.self
        let context = try makeContext(options: options)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 0)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 0)
            }
        }
    }
    
    func testCVPixelBufferLoading_ioSurface() throws {
        var buffer: CVPixelBuffer?
        let r = CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &buffer)
        guard let pixelBuffer = buffer, r == kCVReturnSuccess else {
            XCTFail("Cannot create pixel buffer.")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let pixels = CVPixelBufferGetBaseAddress(pixelBuffer)?.assumingMemoryBound(to: UInt8.self) {
            pixels.advanced(by: 0).assign(repeating: 255, count: 1)
            pixels.advanced(by: 1).assign(repeating: 0, count: 1)
            pixels.advanced(by: 2).assign(repeating: 0, count: 1)
            pixels.advanced(by: 3).assign(repeating: 255, count: 1)
            pixels.advanced(by: 0 + CVPixelBufferGetBytesPerRow(pixelBuffer)).assign(repeating: 0, count: 1)
            pixels.advanced(by: 1 + CVPixelBufferGetBytesPerRow(pixelBuffer)).assign(repeating: 255, count: 1)
            pixels.advanced(by: 2 + CVPixelBufferGetBytesPerRow(pixelBuffer)).assign(repeating: 0, count: 1)
            pixels.advanced(by: 3 + CVPixelBufferGetBytesPerRow(pixelBuffer)).assign(repeating: 255, count: 1)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        let image = MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .nonPremultiplied)
        let options = MTIContextOptions()
        options.coreVideoMetalTextureBridgeClass = MTICVMetalIOSurfaceBridge.self
        let context = try makeContext(options: options)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 0)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 0)
            }
        }
    }
    
    func testBitmapDataLoading() throws {
        let bitmapData: [UInt8] = [
            255, 255, 255, 255,
            255, 255, 0, 255,
        ]
        let image = MTIImage(bitmapData: Data(bytes: bitmapData, count: bitmapData.count), width: 2, height: 1, bytesPerRow: 8, pixelFormat: .rgba8Unorm, alphaType: .alphaIsOne)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    private func renderExplicitYCbCr(_ pixelBuffer: CVPixelBuffer, range: Int, matrix: Int, primaries: Int, transferFunction: Int, bitDepth: Int) throws -> CGImage {
        let conversion = MTIYCbCrPixelBufferConversion(
            range: MTIYCbCrRange(rawValue: range)!,
            matrix: MTIYCbCrMatrix(rawValue: matrix)!,
            primaries: MTIColorPrimaries(rawValue: primaries)!,
            transferFunction: MTITransferFunction(rawValue: transferFunction)!,
            bitDepth: UInt(bitDepth),
            alphaMode: MTIYCbCrAlphaMode(rawValue: 0)!
        )
        let options = MTICVPixelBufferRenderingOptions(
            renderingAPI: MTICVPixelBufferRenderingAPI(rawValue: 1)!,
            sRGB: false,
            explicitYCbCrConversion: conversion
        )
        let image = MTIImage(cvPixelBuffer: pixelBuffer, options: options, alphaType: .alphaIsOne)
        let context = try makeContext()
        return try context.makeCGImage(from: image)
    }
    
    private func make8BitBiPlanarPixelBuffer(pixelFormat: OSType, y: UInt8, cb: UInt8, cr: UInt8) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            pixelFormat,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else {
            throw NSError(domain: "MetalPetalTests", code: Int(status), userInfo: nil)
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!.assumingMemoryBound(to: UInt8.self)
        let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        for row in 0..<2 {
            yBase.advanced(by: row * yBytesPerRow).assign(repeating: y, count: 2)
        }
        
        let cbcrBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)!.assumingMemoryBound(to: UInt8.self)
        cbcrBase[0] = cb
        cbcrBase[1] = cr
        
        return pixelBuffer
    }
    
    private func make10BitBiPlanarPixelBuffer(pixelFormat: OSType, y: UInt16, cb: UInt16, cr: UInt16) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            pixelFormat,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else {
            throw NSError(domain: "MetalPetalTests", code: Int(status), userInfo: nil)
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!.assumingMemoryBound(to: UInt16.self)
        let yElementsPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) / MemoryLayout<UInt16>.stride
        for row in 0..<2 {
            yBase[row * yElementsPerRow] = y << 6
            yBase[row * yElementsPerRow + 1] = y << 6
        }
        
        let cbcrBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)!.assumingMemoryBound(to: UInt16.self)
        cbcrBase[0] = cb << 6
        cbcrBase[1] = cr << 6
        
        return pixelBuffer
    }
    
    private func assertUniformPixel(in cgImage: CGImage, r: UInt8, g: UInt8, b: UInt8, tolerance: UInt8 = 1) {
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, _ in
            XCTAssertLessThanOrEqual(abs(Int(pixel.r) - Int(r)), Int(tolerance))
            XCTAssertLessThanOrEqual(abs(Int(pixel.g) - Int(g)), Int(tolerance))
            XCTAssertLessThanOrEqual(abs(Int(pixel.b) - Int(b)), Int(tolerance))
            XCTAssertEqual(pixel.a, 255)
        }
    }
}


final class CGImageLoadingTests: XCTestCase {
    
    func testCGImageLoading_normal() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeCheckboardImage(), options: .default, isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_monochrome() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeCheckboardImageWithMonochromeColorSpace(), options: .default, isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_5bpc() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeCheckboardImageWith5BitPerComponent(), options: .default, isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_bigEndianAlphaLast() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeR0G128B255CheckboardImageWithBigEndianAlphaLast(), options: .default, isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_bigEndianAlphaFirst() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeR0G128B255CheckboardImageWithBigEndianAlphaFirst(), options: .default, isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_defaultEndianAlphaFirst() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeR0G128B255CheckboardImageWithDefaultEndianAlphaFirst(), options: .default, isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_premultiplied() throws {
        let context = try makeContext()
        
        let cgContext = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let color: [CGFloat] = [1, 0, 0, 0.5]
        try cgContext?.setFillColor(XCTUnwrap(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: color)))
        cgContext?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let inputCGImage = try XCTUnwrap(cgContext?.makeImage())
        let image = MTIImage(cgImage: inputCGImage, options: .default, isOpaque: false)
        XCTAssert(image.alphaType == .premultiplied)
        
        let cgImage = try context.makeCGImage(from: image) //output is premultiplied
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            XCTAssert(pixel.r == 128 && pixel.g == 0 && pixel.b == 0 && pixel.a == 128)
        }
    }
    
    func testCGImageLoading_semiTransparentPNG() throws {
        let context = try makeContext()
        let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: #file)
                                                        .deletingLastPathComponent().deletingLastPathComponent()
                                                        .appendingPathComponent("Fixture")
                                                        .appendingPathComponent("semi-transparent-red.png") as CFURL, nil)
        let inputCGImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(XCTUnwrap(imageSource), 0, nil))
        let image = MTIImage(cgImage: inputCGImage, options: .default, isOpaque: false)
        XCTAssert(image.alphaType == .premultiplied)
        
        let cgImage = try context.makeCGImage(from: image) //output is premultiplied
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            XCTAssert(pixel.r == 128 && pixel.g == 0 && pixel.b == 0 && pixel.a == 128)
        }
    }
    
    func testCGImageLoading_sRGB() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([[128]]), options: MTICGImageLoadingOptions(colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!), isOpaque: true)
        let linearImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: linearImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                let c = 128.0/255.0
                
                // Should we use `round` here? https://developer.apple.com/documentation/metal/mtlrenderpipelinestate/3608177-texturewriteroundingmode
                let linearValue = UInt8(round((c <= 0.04045) ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) * 255.0))
                XCTAssert(pixel.r == linearValue && pixel.g == linearValue && pixel.b == linearValue && pixel.a == 255)
            }
        }
        let sRGBImage = try context.makeCGImage(from: image, sRGB: true)
        PixelEnumerator.enumeratePixels(in: sRGBImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 128 && pixel.g == 128 && pixel.b == 128 && pixel.a == 255)
            }
        }
    }
    
    func testURLImageLoading_orientations() throws {
        let context = try makeContext()
        for orientation in 1...8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                                    .deletingLastPathComponent().deletingLastPathComponent()
                                    .appendingPathComponent("Fixture")
                                    .appendingPathComponent("f\(orientation).png")
                                 , options: .default, isOpaque: true)
            guard let inputImage = image else {
                XCTFail()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }
    
    func testURLImageLoading_grayColorSpace_orientations() throws {
        let context = try makeContext()
        for orientation in 1...8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                                    .deletingLastPathComponent().deletingLastPathComponent()
                                    .appendingPathComponent("Fixture")
                                    .appendingPathComponent("fgray\(orientation).png")
                                 , options: .default, isOpaque: true)
            guard let inputImage = image else {
                XCTFail()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }
    
    func testURLImageLoading_grayColorSpace_orientations_flip() throws {
        let context = try makeContext()
        for orientation in 1...8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                                    .deletingLastPathComponent().deletingLastPathComponent()
                                    .appendingPathComponent("Fixture")
                                    .appendingPathComponent("fgray\(orientation).png")
                                 , options: MTICGImageLoadingOptions(colorSpace: nil, flipsVertically: true), isOpaque: true)
            guard let inputImage = image else {
                XCTFail()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 255, 255],
                [0, 255, 255],
                [0, 0, 255],
                [0, 0, 0],
            ]))
        }
    }
}

final class TextureLoaderImageLoadingTests: XCTestCase {
    
    func testCGImageLoading_normal() throws {
        let context = try makeContext()
        let image = MTIImage(cgImage: try ImageGenerator.makeCheckboardImage(), options: [.SRGB: false], isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_monochrome() throws {
        let context = try makeContext()
        let image = MTIImage(cgImage: try ImageGenerator.makeCheckboardImageWithMonochromeColorSpace(), options: [.SRGB: false], isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_5bpc() throws {
        let context = try makeContext()
        let image = MTIImage(cgImage: try ImageGenerator.makeCheckboardImageWith5BitPerComponent(), options: [.SRGB: false], isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_bigEndianAlphaLast() throws {
        let context = try makeContext()
        let image = MTIImage(cgImage: try ImageGenerator.makeR0G128B255CheckboardImageWithBigEndianAlphaLast(), options: [.SRGB: false], isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_bigEndianAlphaFirst() throws {
        let context = try makeContext()
        let image = MTIImage(cgImage: try ImageGenerator.makeR0G128B255CheckboardImageWithBigEndianAlphaFirst(), options: [.SRGB: false], isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    func testCGImageLoading_defaultEndianAlphaFirst() throws {
        let context = try makeContext()
        let image = MTIImage(cgImage: try ImageGenerator.makeR0G128B255CheckboardImageWithDefaultEndianAlphaFirst(), options: [.SRGB: false], isOpaque: true)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }
    
    
    func testCGImageLoading_sRGB() throws {
        let context = try makeContext()
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([[128]]), options: [.SRGB: true], isOpaque: true)
        let linearImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: linearImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                let c = 128.0/255.0
                
                // Should we use `round` here? https://developer.apple.com/documentation/metal/mtlrenderpipelinestate/3608177-texturewriteroundingmode
                let linearValue = UInt8(round((c <= 0.04045) ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) * 255.0))
                XCTAssert(pixel.r == linearValue && pixel.g == linearValue && pixel.b == linearValue && pixel.a == 255)
            }
        }
        let sRGBImage = try context.makeCGImage(from: image, sRGB: true)
        PixelEnumerator.enumeratePixels(in: sRGBImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 128 && pixel.g == 128 && pixel.b == 128 && pixel.a == 255)
            }
        }
    }
    
    func testURLImageLoading_orientations() throws {
        let context = try makeContext()
        for orientation in 1...8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                                    .deletingLastPathComponent().deletingLastPathComponent()
                                    .appendingPathComponent("Fixture")
                                    .appendingPathComponent("f\(orientation).png"),
                                 options: [.SRGB: false],
                                 alphaType: .alphaIsOne)
            guard let inputImage = image else {
                XCTFail()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }
    
    func testURLImageLoading_grayColorSpace_orientations() throws {
        let context = try makeContext()
        for orientation in 1...8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                                    .deletingLastPathComponent().deletingLastPathComponent()
                                    .appendingPathComponent("Fixture")
                                    .appendingPathComponent("fgray\(orientation).png"),
                                 options: [.SRGB: false],
                                 alphaType: .alphaIsOne)
            guard let inputImage = image else {
                XCTFail()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }
    
    func testURLImageLoading_grayColorSpace_orientations_flip() throws {
        let context = try makeContext()
        for orientation in 1...8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                                    .deletingLastPathComponent().deletingLastPathComponent()
                                    .appendingPathComponent("Fixture")
                                    .appendingPathComponent("fgray\(orientation).png"),
                                 options: [.SRGB: false, .origin: MTKTextureLoader.Origin.flippedVertically],
                                 alphaType: .alphaIsOne)
            guard let inputImage = image else {
                XCTFail()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 255, 255],
                [0, 255, 255],
                [0, 0, 255],
                [0, 0, 0],
            ]))
        }
    }
    
    func testURLImageLoading_grayColorSpace_mtkfallback_orientations() throws {
        let context = try makeContext()
        for orientation in 1...8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                                    .deletingLastPathComponent().deletingLastPathComponent()
                                    .appendingPathComponent("Fixture")
                                    .appendingPathComponent("fgray\(orientation).png"),
                                 options: [.SRGB: false, .generateMipmaps: true],
                                 alphaType: .alphaIsOne)
            guard let inputImage = image else {
                XCTFail()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }
    
    func testURLImageLoading_grayColorSpace_mtkfallback_mipmap() throws {
        let context = try makeContext()
        let url = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixture")
            .appendingPathComponent("fgray1.png")
        let textureLoader = MTIDefaultTextureLoader.makeTextureLoader(device: context.device)
        let texture = try textureLoader.newTexture(withContentsOf: url, options: [.SRGB: false, .generateMipmaps: true])
        XCTAssert(texture.mipmapLevelCount > 1)
    }
}
