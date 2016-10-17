//
//  FJVideoFileReader.m
//  VideoFileWriter
//  
//  Created by Clover on 17/10/2016.
//  Copyright © 2016 Clover Peng. All rights reserved.
//

#import "FJVideoFileReader.h"

@interface FJVideoFileReader ()

@property (assign, nonatomic) CGSize videoSize;


@property (strong, nonatomic) AVAssetReader *reader;
@property (strong, nonatomic) dispatch_queue_t videoReaderQueue;
@property (strong, nonatomic) AVAssetTrack *videoTrack;
@property (strong, nonatomic) AVAssetReaderTrackOutput *videoReaderOutput;

- (void) setupVideoReader;
- (void) removeVideoReader;

@end

@implementation FJVideoFileReader


- (instancetype) initWithSize:(CGSize) size andFileUrl:(NSURL *)fileUrl {
    if (self = [super init]) {
        _fileUrl = fileUrl;
        _videoSize = size;
        [self setupVideoReader];
    }
    
    return self;
}

- (BOOL) isReading {
    return _reader.startReading;
}

- (void) startReadingWithHandler:(FJVideoFileReaderBlock) handler {
    [_reader startReading];
    
    dispatch_async(_videoReaderQueue, ^{
        while ([_reader status] == AVAssetReaderStatusReading && _videoTrack.nominalFrameRate > 0) {
            if (!_isPause) {
                
                CMSampleBufferRef videoBuffer = [_videoReaderOutput copyNextSampleBuffer];
                if (videoBuffer) {
                    if (handler) {
                        handler(videoBuffer);
                    }
                    
                    CMTime time = CMSampleBufferGetPresentationTimeStamp(videoBuffer);
                    [NSThread sleepForTimeInterval:CMTimeGetSeconds(time)];

                    
                } else {
                    _isReading = NO;
                    _isPause = NO;
                    if (handler) {
                        handler(NULL);
                    }
                }
                
            } else if (!_isReading){
                _isReading = NO;
                _isPause = NO;
                break;
            }
            
            
        }

    });
}

- (void) stopReading {
    // remember to reset the file url.
    _isReading = NO;
    [self removeVideoReader];
    [self setupVideoReader];
}

- (void) setupVideoReader {
    
    if (!_videoReaderQueue) {
         _videoReaderQueue = dispatch_queue_create("fj_video_reader_queue", DISPATCH_QUEUE_SERIAL);
    }
    
    if (!_reader) {
        AVAsset *asset = [[AVURLAsset alloc] initWithURL:_fileUrl options:nil];
        NSError *error = nil;
        
        _reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
        
        NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        
        _videoTrack = [videoTracks objectAtIndex:0];
        
        NSDictionary* options = @{
                                  (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
                                  (id)kCVPixelBufferWidthKey : [NSNumber numberWithInt:_videoSize.width*2],
                                  (id)kCVPixelBufferHeightKey : [NSNumber numberWithInt:_videoSize.height*2],
                                  (id)kCVPixelBufferOpenGLCompatibilityKey : [NSNumber numberWithBool:YES]
                                  };
        
        _videoReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:_videoTrack outputSettings:options];
        [_reader addOutput:_videoReaderOutput];
    }
    
}

- (void) removeVideoReader {
    _reader = nil;
    _videoTrack = nil;
    _videoReaderQueue = NULL;
}

@end
