//
//  FJFrameCompressor.m
//  VideoFileWriter
//
//  Created by Clover on 18/10/2016.
//  Copyright © 2016 mylib. All rights reserved.
//

#import "FJFrameCompressor.h"

#import <VideoToolbox/VideoToolbox.h>

@interface FJFrameCompressor ()

@property (assign, nonatomic) VTCompressionSessionRef EncodingSession;
@property (assign, nonatomic) CMFormatDescriptionRef  format;
@property (assign, nonatomic) CMSampleTimingInfo *timingInfo;

@property (strong, nonatomic) dispatch_queue_t compressQueue;

@property (strong, nonatomic) NSData *sps;
@property (strong, nonatomic) NSData *pps;

@property (assign, nonatomic) CGSize videoSize;
@property (assign, nonatomic) long frameCount;

- (void) removeCompressor;
- (void) setupCompressor;


@end

@implementation FJFrameCompressor

- (instancetype) initWithSize:(CGSize) videoSize {
    if (self = [super init]) {
        _videoSize = videoSize;
        _frameCount = 0;
        [self setupCompressor];
    }
    return self;
    
}
- (void) compressBuffer:(CMSampleBufferRef) sampleBuffer
        withHeaderBlock:(FJHeaderCompressorDataBlock)headerBlock
          h264DataBlock:(FJFrameCompressorDataBlock)datablock
         andBufferBlock:(FJFrameCompressorBufferBlock)bufferBlock {
    
    if (_EncodingSession == NULL)
    {
        return;
    }
    dispatch_sync(_compressQueue, ^{
        
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime presentationTimeStamp = CMTimeMake(_frameCount, 30);
        _frameCount++;
        VTEncodeInfoFlags flags;
        OSStatus statusCode = VTCompressionSessionEncodeFrameWithOutputHandler(_EncodingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, &flags, ^(OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef  _Nullable sampleBuffer) {
            if (status != 0) return;
            
            if (!CMSampleBufferDataIsReady(sampleBuffer))
            {
                NSLog(@"didCompressH264 data is not ready ");
                return;
            }
            
            if (bufferBlock) {
                bufferBlock(sampleBuffer);
            }
            
            bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
            
            if (keyframe)
            {
                CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
                size_t sparameterSetSize, sparameterSetCount;
                const uint8_t *sparameterSet;
                OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
                if (statusCode == noErr)
                {
                    size_t pparameterSetSize, pparameterSetCount;
                    const uint8_t *pparameterSet;
                    OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
                    if (statusCode == noErr)
                    {
                        NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                        NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                        if (headerBlock)
                        {
                            headerBlock(sps, pps);
                        }
                    }
                }
            }
            
            CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
            size_t length, totalLength;
            char *dataPointer;
            OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
            if (statusCodeRet == noErr) {
                
                size_t bufferOffset = 0;
                static const int AVCCHeaderLength = 4;
                while (bufferOffset < totalLength - AVCCHeaderLength)
                {
                    uint32_t NALUnitLength = 0;
                    memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
                    NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
                    NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
                    if (datablock) {
                        datablock(data);
                    }
                    bufferOffset += AVCCHeaderLength + NALUnitLength;
                }
                
            }
            
        });

        if (statusCode != noErr)
        {
            if (_EncodingSession!=NULL)
            {
                VTCompressionSessionInvalidate(_EncodingSession);
                CFRelease(_EncodingSession);
                _EncodingSession = NULL;
                return;
            }
        }
    });
}

- (void) setupCompressor {
    if (!_compressQueue) {
        _compressQueue = dispatch_queue_create("fj_video_compressor_queue", DISPATCH_QUEUE_SERIAL);
    }
    
    dispatch_sync(_compressQueue, ^{
        OSStatus status = VTCompressionSessionCreate(NULL, _videoSize.width, _videoSize.height, kCMVideoCodecType_H264, NULL, NULL, NULL, NULL, NULL,  &_EncodingSession);
        if (status != 0)
        {
            NSLog(@"Error by VTCompressionSessionCreate");
            return ;
        }
        
        VTSessionSetProperty(_EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(_EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_5_0);
        
        SInt32 bitRate = _videoSize.width*_videoSize.height*50;  //50 the limited, I don't know why
        CFNumberRef ref = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
        VTSessionSetProperty(_EncodingSession, kVTCompressionPropertyKey_AverageBitRate, ref);
        CFRelease(ref);
        
        int frameInterval = 10; //key frame interval
        CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(_EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval,frameIntervalRef);
        CFRelease(frameIntervalRef);
        VTCompressionSessionPrepareToEncodeFrames(_EncodingSession);
    });
}

- (void) removeCompressor {
    _EncodingSession = nil;
    _compressQueue = nil;
    _sps = nil;
    _pps = nil;
    
    _frameCount = 0;
}

@end
