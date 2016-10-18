//
//  FJFrameDecompressor.m
//  VideoFileWriter
//
//  Created by Clover on 18/10/2016.
//  Copyright © 2016 mylib. All rights reserved.
//

#import "FJFrameDecompressor.h"

@interface FJFrameDecompressor ()

@property(assign, nonatomic) VTDecompressionSessionRef deocderSession;
@property(assign, nonatomic) CMVideoFormatDescriptionRef decoderFormatDescription;

@property(assign, nonatomic) uint8_t *sps;
@property(assign, nonatomic) NSInteger spsSize;
@property(assign, nonatomic) uint8_t *pps;
@property(assign, nonatomic) NSInteger ppsSize;

@property (assign, nonatomic) CGSize videoSize;

- (void) internalDecompressData:(uint8_t *)data withSize:(uint32_t)dataLength andBlock:(FJFrameDecompressorBufferBlock)bufferBlock;

- (BOOL) setupDecompressor;
- (void) removeDecompressor;

@end

@implementation FJFrameDecompressor

- (instancetype) initWithSize:(CGSize) videoSize {
    if (self = [super init]) {
        
        _videoSize = videoSize;
        
    }
    return self;
}

- (void) internalDecompressData:(uint8_t *)data withSize:(uint32_t)dataLength andBlock:(FJFrameDecompressorBufferBlock)bufferBlock {
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                          (void *)data,
                                                          dataLength,
                                                          kCFAllocatorNull,
                                                          NULL,
                                                          0,
                                                          dataLength,
                                                          FALSE,
                                                          &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {dataLength};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
            VTDecodeInfoFlags flagOut = kVTDecodeInfo_Asynchronous;
            
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrameWithOutputHandler(_deocderSession, sampleBuffer, flags, &flagOut, ^(OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef  _Nullable imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration) {
                
                if (bufferBlock) {
                    bufferBlock(imageBuffer, presentationTimeStamp, _decoderFormatDescription);
                }
            });
            
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Other error)", decodeStatus);
                
            }
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
}

-(void) decompressData:(uint8_t *)data withSize:(uint32_t)dataLength andBlock:(FJFrameDecompressorBufferBlock)bufferBlock {
    if (!data) {
        return;
    }
    
    //    NSLog(@">>>>>>>>>>开始解码");
    int nalu_type = (data[4] & 0x1F);
    uint32_t nalSize = (uint32_t)(dataLength - 4);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    data[0] = *(pNalSize + 3);
    data[1] = *(pNalSize + 2);
    data[2] = *(pNalSize + 1);
    data[3] = *(pNalSize);
    //传输的时候。关键帧不能丢数据 否则绿屏   B/P可以丢  这样会卡顿
    switch (nalu_type)
    {
        case 0x05:
            //           NSLog(@"nalu_type:%d Nal type is IDR frame",nalu_type);  //关键帧
            if([self setupDecompressor])
            {
                [self internalDecompressData:data withSize:dataLength andBlock:bufferBlock];
            }
            break;
        case 0x06:
            //            NSLog(@"nalu_type = %d", nalu_type);
            break;
        case 0x07:
            //           NSLog(@"nalu_type:%d Nal type is SPS",nalu_type);   //sps
            _spsSize = dataLength - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, &data[4], _spsSize);
            break;
        case 0x08:
        {
            //            NSLog(@"nalu_type:%d Nal type is PPS",nalu_type);   //pps
            _ppsSize = dataLength - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, &data[4], _ppsSize);
            break;
        }
        case 0x03:
        {
            //NSLog(@"Nal type is B frame") no B frame in normal type;
            
            break;
        }
        default:
        {
            //            NSLog(@"Nal type is B/P frame");

            [self internalDecompressData:data withSize:dataLength andBlock:bufferBlock];
            break;
        }
            
            
    }
    
}

- (BOOL) setupDecompressor {
    if(_deocderSession) {
        return YES;
    }
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
    if(status == noErr) {
        NSDictionary* destinationPixelBufferAttributes = @{
                                                           (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                                                           //decompress type kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                                                           //                                                           或者是kCVPixelFormatType_420YpCbCr8Planar
                                                           //iOS is  nv12  other is nv21
                                                           (id)kCVPixelBufferWidthKey : [NSNumber numberWithInt:_videoSize.width*2],
                                                           (id)kCVPixelBufferHeightKey : [NSNumber numberWithInt:_videoSize.height*2],
                                                           //这里款高和编码反的
                                                           (id)kCVPixelBufferOpenGLCompatibilityKey : [NSNumber numberWithBool:YES]
                                                           };
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL,
                                              (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
                                              NULL,
                                              &_deocderSession);
        VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:10]);
        VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    } else {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
        return  NO;
    }
    return YES;
}

- (void) removeDecompressor {
    if(_deocderSession) {
        VTDecompressionSessionInvalidate(_deocderSession);
        CFRelease(_deocderSession);
        _deocderSession = NULL;
    }
    
    if(_decoderFormatDescription) {
        CFRelease(_decoderFormatDescription);
        _decoderFormatDescription = NULL;
    }
    
    free(_sps);
    free(_pps);
    _spsSize = _ppsSize = 0;
}


@end
