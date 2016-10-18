//
//  FJFrameCompressor.h
//  VideoFileWriter
//
//  Created by Clover on 18/10/2016.
//  Copyright © 2016 mylib. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

//for header h264 Data
typedef void(^FJHeaderCompressorDataBlock)(NSData* spsData, NSData *ppsData);
typedef void(^FJFrameCompressorDataBlock)(NSData* h264Data);
//for compressed samplebuffer
typedef void(^FJFrameCompressorBufferBlock)(CMSampleBufferRef comSampleBuffer);

@interface FJFrameCompressor : NSObject

- (instancetype) initWithSize:(CGSize) videoSize;
- (void) compressBuffer:(CMSampleBufferRef) sampleBuffer
        withHeaderBlock:(FJHeaderCompressorDataBlock)headerBlock
          h264DataBlock:(FJFrameCompressorDataBlock)datablock
         andBufferBlock:(FJFrameCompressorBufferBlock)bufferBlock;

@end
