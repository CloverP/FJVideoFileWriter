//
//  FJVideoFileWriter.m
//  VideoFileWriter
//
//  Created by Clover on 16/10/2016.
//  Copyright © 2016 Clover Peng. All rights reserved.
//

#import "FJVideoFileWriter.h"

#define SCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)

@interface FJVideoFileWriter ()
//data structure
@property (strong, nonatomic) NSURL *fileUrl;
@property (assign, nonatomic) CFMutableArrayRef bufferArray;
@property (strong, nonatomic) dispatch_queue_t writingQueue;
@property (assign, nonatomic) CGSize videoSize;
@property (assign, nonatomic) BOOL isAdding;
@property (assign, nonatomic) long frameCount;
@property (assign, nonatomic) int  videoFPS;


@property (strong, nonatomic) AVAssetWriter *videoWriter;
@property (strong, nonatomic) AVAssetWriterInput *writerInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *adaptor;

//writer
@property (assign, nonatomic) FJ_BUFFERTYPE bufferType;
@property (assign, nonatomic) FJ_VIDEOSOURCE videoSource;


CFMutableArrayRef CreateDispatchHoldingArray();

- (void) setFilePath;

- (void) setupVideoWriter;
- (void) removeVideoWriter;

- (BOOL)appendToAdapter:(AVAssetWriterInputPixelBufferAdaptor*)adaptor
            pixelBuffer:(CVPixelBufferRef)buffer
                 atTime:(CMTime)presentTime
              withInput:(AVAssetWriterInput*)writerInput;

- (void) writePixelBuffer;
- (void) writeSampleBUffer;
- (void) writeMuxBUffer;

- (void) writeToFile;

- (CVPixelBufferRef)deepCopyPixelBuffer:(CVPixelBufferRef) pxbuffer;

@end

@implementation FJVideoFileWriter

- (instancetype) initWithFileUrl:(NSURL *)fileUrl
                      BufferType:(FJ_BUFFERTYPE) bufferType
                       VideoSize:(CGSize) videoSize
                  andVideoSource:(FJ_VIDEOSOURCE) videoSource {
    if (self  = [super init]) {
        if (!fileUrl) {
            NSString *fileName = [NSString stringWithFormat:@"%f.m4v",[[NSDate date] timeIntervalSince1970]];
            NSString *betaCompressionDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:fileName];
            _fileUrl = [NSURL fileURLWithPath:betaCompressionDirectory];
        } else if ([fileUrl.absoluteString isEqualToString:_fileUrl.absoluteString]) {
            NSString *start = [fileUrl.absoluteString componentsSeparatedByString:@"."][0];
            NSString *end = [fileUrl.absoluteString componentsSeparatedByString:@"."][1];
            NSString *new = [NSString stringWithFormat:@"%@-1.%@", start, end];
            _fileUrl = [NSURL URLWithString:new];
        }
        
        if (bufferType == FJ_UNKNOWN) {
            bufferType = FJ_SAMPLEBUFFER;
        } else {
            _bufferType = bufferType;
        }
        
        if (CGSizeEqualToSize(videoSize, CGSizeZero)) {
            _videoSize = CGSizeMake(SCREEN_WIDTH, SCREEN_HEIGHT);
        } else {
            _videoSize = videoSize;
        }
        
        _isAdding = NO;
        _frameCount = 0;
        _videoFPS = 30;
        _videoSource = videoSource;
        [self setupVideoWriter];
    }
    return  self;
}


- (void) startWriting {
    [_videoWriter startWriting];
    [_videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    _isAdding = YES;
    [self writeToFile];
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error
  contextInfo:(void *)contextInfo {
    [self clearAllVideos];
    [self setFilePath];
}

- (void) stopWriting {
    [_writerInput markAsFinished];
    [_videoWriter finishWritingWithCompletionHandler:^{
        //deal the file with your own way.
        UISaveVideoAtPathToSavedPhotosAlbum(_fileUrl.relativePath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        [self removeVideoWriter];
        [self setupVideoWriter];
        NSLog(@"Successfully closed video writer");
        
    }];
    CVPixelBufferPoolRelease(_adaptor.pixelBufferPool);
    
    _frameCount = 0;
    _isAdding = NO;
    NSLog (@"Done");
}

- (void) clearAllVideos {
    
    NSString *extension = @"m4v";
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths.lastObject;
    
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:documentsDirectory error:NULL];
    NSEnumerator *e = [contents objectEnumerator];
    NSString *filename;
    while ((filename = [e nextObject])) {
        
        if ([[filename pathExtension] isEqualToString:extension]) {
            
            [fileManager removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:filename] error:NULL];
        }
    }
}

//internal
- (CVPixelBufferRef)deepCopyPixelBuffer:(CVPixelBufferRef) pxbuffer
{
    CVPixelBufferRef copy = NULL;
    
    CVPixelBufferCreate(nil,
                        CVPixelBufferGetWidth(pxbuffer),
                        CVPixelBufferGetHeight(pxbuffer),
                        CVPixelBufferGetPixelFormatType(pxbuffer),
                        CVBufferGetAttachments(pxbuffer, kCVAttachmentMode_ShouldPropagate),
                        &copy);
    
    CVPixelBufferLockBaseAddress(pxbuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(copy, 0);
    
    for (int i = 0; i < CVPixelBufferGetPlaneCount(pxbuffer); i++) {
        void *dest = CVPixelBufferGetBaseAddressOfPlane(copy, i);
        void *source = CVPixelBufferGetBaseAddressOfPlane(pxbuffer, i);
        size_t height =CVPixelBufferGetHeightOfPlane(pxbuffer, i);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pxbuffer, i);
        memcpy(dest, source, height * bytesPerRow);
    }
    CVPixelBufferUnlockBaseAddress(copy, 0);
    CVPixelBufferUnlockBaseAddress(pxbuffer, kCVPixelBufferLock_ReadOnly);
    return copy;
}

- (void) appendPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CFArrayAppendValue(_bufferArray, pixelBuffer);
}

- (void) appendSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    if (_videoSource == FJ_DATA) {
        CMSampleBufferRef newbuffer = NULL;
        
        CVPixelBufferRef pixbuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        CMVideoFormatDescriptionRef videoDes = CMSampleBufferGetFormatDescription(sampleBuffer);
        CMSampleTimingInfo info;
        info.decodeTimeStamp = CMTimeMake(_frameCount, _videoFPS);
        info.duration = kCMTimeInvalid;
        info.presentationTimeStamp = CMTimeMake(_frameCount, _videoFPS);
        
        OSStatus status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixbuffer, videoDes, &info, &newbuffer);
        
        if (status == noErr) {
            _frameCount++;
            CFArrayAppendValue(_bufferArray, newbuffer);
            CFRelease(newbuffer);
        }
    } else {
        CFArrayAppendValue(_bufferArray, sampleBuffer);
    }
    

    
}

static const void * ObjectRetainCallBack(CFAllocatorRef allocator, const void *value) {
    
    if (value) {
        CFRetain(value);
    }
    return value;
}

static void ObjectReleaseCallBack(CFAllocatorRef allocator, const void *value) {
    if (value) {
        CFRelease(value);
    }
}

CFMutableArrayRef CreateDispatchHoldingArray() {
    CFArrayCallBacks callBacks = {
        0,
        ObjectRetainCallBack,
        ObjectReleaseCallBack,
        NULL,
        NULL
    };
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, &callBacks);
}

- (void) setFilePath {
    NSString *fileName = [NSString stringWithFormat:@"%f.m4v",[[NSDate date] timeIntervalSince1970]];
    NSString *betaCompressionDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:fileName];
    _fileUrl = [NSURL fileURLWithPath:betaCompressionDirectory];
}

- (void) setupVideoWriter {
    
    if (!_writingQueue) {
        _writingQueue = dispatch_queue_create("fj_videowriting_queue", DISPATCH_QUEUE_SERIAL);
    }
    
    if (!_videoWriter) {
//----initialize compression engine
        NSError *error = nil;
        _videoWriter = [[AVAssetWriter alloc] initWithURL:_fileUrl
                                                 fileType:AVFileTypeQuickTimeMovie
                                                    error:&error];
        
        NSParameterAssert(_videoWriter);
        
        switch (_videoSource) {
            case FJ_FILE: {
                NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
                                               [NSNumber numberWithInt:_videoSize.width*2], AVVideoWidthKey,
                                               [NSNumber numberWithInt:_videoSize.height*2], AVVideoHeightKey, nil];
                _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
//                _writerInput.transform = CGAffineTransformMakeRotation(M_PI/2);
            }

                break;
            case FJ_DATA: {
                NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
                                               [NSNumber numberWithInt:_videoSize.width*2], AVVideoWidthKey,
                                               [NSNumber numberWithInt:_videoSize.height*2], AVVideoHeightKey, nil];
                _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
            }

                break;
            default:
                break;
        }

        _writerInput.expectsMediaDataInRealTime = YES;
        
        NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                               [NSNumber numberWithInt:kCVPixelFormatType_64ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
        
        _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_writerInput
                                                                                    sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
        NSParameterAssert(_writerInput);
        NSParameterAssert([_videoWriter canAddInput:_writerInput]);
        
        if ([_videoWriter canAddInput:_writerInput])
            [_videoWriter addInput:_writerInput];
        
    }
    _bufferArray = CreateDispatchHoldingArray();
    
}

- (void) removeVideoWriter {
    CFArrayRemoveAllValues(_bufferArray);
    _bufferArray = NULL;
    
    _videoWriter = nil;
    _writerInput = nil;
    _adaptor = nil;
    _writingQueue = NULL;
}

- (BOOL)appendToAdapter:(AVAssetWriterInputPixelBufferAdaptor*)adaptor
            pixelBuffer:(CVPixelBufferRef)buffer
                 atTime:(CMTime)presentTime
              withInput:(AVAssetWriterInput*)writerInput
{
    return [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
}


- (void) writePixelBuffer {
    [_writerInput requestMediaDataWhenReadyOnQueue:_writingQueue usingBlock:^{
        
        while ([_writerInput isReadyForMoreMediaData])
        {
            if (CFArrayGetCount(_bufferArray) == 0) {
                if (_isAdding) {
                    continue;
                }
                else {
                    [self stopWriting];
                    break;
                }
                
            }
            
            CVPixelBufferRef buffer = (CVPixelBufferRef)CFArrayGetValueAtIndex(_bufferArray, 0);
            if (buffer) {
                CMTime PTS = CMTimeMake(_frameCount, _videoFPS);
                BOOL appendSuccess = [self appendToAdapter:_adaptor
                                               pixelBuffer:buffer
                                                    atTime:PTS
                                                 withInput:_writerInput];
                if (appendSuccess) {
                    _frameCount++;
                    CFArrayRemoveValueAtIndex(_bufferArray, 0);
                } else {
                    NSLog(@"writePixelBuffer Failed");
                }
            } else {
                [self stopWriting];
                break;
            }
            
        }
    }];
}

- (void)writeSampleBUffer {
    [_writerInput requestMediaDataWhenReadyOnQueue:_writingQueue usingBlock:^{
        
        while ([_writerInput isReadyForMoreMediaData])
        {
            if (CFArrayGetCount(_bufferArray) == 0) {
                if (_isAdding) {
                    continue;
                }
                else {
                    [self stopWriting];
                    break;
                }
                
            }
            
            CMSampleBufferRef nextSampleBuffer = (CMSampleBufferRef)CFArrayGetValueAtIndex(_bufferArray, 0);
            if (nextSampleBuffer) {
                
                BOOL appendSuccess = [_writerInput appendSampleBuffer:nextSampleBuffer];
                
                if (appendSuccess) {
                    CFArrayRemoveValueAtIndex(_bufferArray, 0);
                } else {
                    NSLog(@"writeSampleBUffer Failed");
                }
                
            } else {
                [self stopWriting];
                break;
            }
        }
    }];
}

- (void) writeMuxBUffer {
    //todo
}

- (void) writeToFile {
    
    if (_bufferType == FJ_PIXELBUFFER) {
        [self writePixelBuffer];
    } else  if (_bufferType == FJ_SAMPLEBUFFER) {
        [self writeSampleBUffer];
    } else {
        [self writeMuxBUffer];
    }
    
}


@end
