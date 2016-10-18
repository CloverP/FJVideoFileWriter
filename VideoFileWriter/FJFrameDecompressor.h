//
//  FJFrameDecompressor.h
//  VideoFileWriter
//
//  Created by Clover on 18/10/2016.
//  Copyright © 2016 mylib. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>

typedef void(^FJFrameDecompressorBufferBlock)(CVPixelBufferRef pixelBuffer, CMTime PTS, CMVideoFormatDescriptionRef videoFormatDescription);

@interface FJFrameDecompressor : NSObject

- (instancetype) init;

-(void) decompressData:(uint8_t *)data withSize:(uint32_t)dataLength andBlock:(FJFrameDecompressorBufferBlock)bufferBlock;

@end
