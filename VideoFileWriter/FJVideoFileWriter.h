//
//  FJVideoFileWriter.h
//  VideoFileWriter v0.1 only video, no audio
//
//  Created by Clover on 16/10/2016.
//  Copyright © 2016 Clover Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
typedef enum {
    FJ_UNKNOWN = 0,
    FJ_SAMPLEBUFFER,
    FJ_PIXELBUFFER,
    FJ_MUXBUFFER //buffer and audio
}FJ_BUFFERTYPE;

typedef enum {
    FJ_FILE = 4,
    FJ_DATA,
}FJ_VIDEOSOURCE;


@interface FJVideoFileWriter : NSObject

- (instancetype) initWithFileUrl:(NSURL *)fileUrl
                      BufferType:(FJ_BUFFERTYPE) bufferType
                       VideoSize:(CGSize) videoSize
                  andVideoSource:(FJ_VIDEOSOURCE) videoSource;

- (void) appendPixelBuffer:(CVPixelBufferRef) pixelBuffer;
- (void) appendSampleBuffer:(CMSampleBufferRef) sampleBuffer;

- (void) startWriting;
- (void) stopWriting;

@end
