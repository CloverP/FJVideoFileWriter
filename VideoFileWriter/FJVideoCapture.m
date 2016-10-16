//
//  FJVideoCapture.m
//  VideoFileWriter
//
//  Created by Clover on 16/10/2016.
//  Copyright © 2016 Clover Peng. All rights reserved.
//

#import "FJVideoCapture.h"
#import "FJVideoFileWriter.h"

@interface FJVideoCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDevice *videoDevice;
@property (strong, nonatomic) AVCaptureDevice *audioDevice;
@property (strong, nonatomic) AVCaptureDeviceInput *videoInput;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong, nonatomic) dispatch_queue_t myVideoOutputQueue;
@property (strong, nonatomic) id object;
@property (weak, nonatomic) UIView *disView;



- (void) setupcaptureSession;
- (void)startSession;
- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
                               withPostion:(AVCaptureDevicePosition) postion
                                   andTime:(CMTime) timeStamp;
@end

@implementation FJVideoCapture

- (instancetype) initWithDisplayView:(UIView *)disView
                         andDelegate:(id) object {
    if (self = [super init]) {
        
        _disView = disView;
        _object = object;
        [self setupcaptureSession];
    }
    return self;
}

- (void) dealloc {
    _object = nil;
}

- (void) setDisplayViewBounds:(CGRect)bounds
{
    _previewLayer.frame = bounds;
}

- (void) setupcaptureSession {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionBack) {
            _videoDevice = device;
            
            break;
        }
    }
    
    _audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *error = nil;
    _videoInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice error:&error];
    if (error) {
        return;
    }
    
    _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    if ([_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }

    _myVideoOutputQueue = dispatch_queue_create("fj_video_capture_output_queue", DISPATCH_QUEUE_SERIAL);
    if ([_captureSession canAddOutput:_videoDataOutput]) {
        [_captureSession addOutput:_videoDataOutput];
        [_videoDataOutput setSampleBufferDelegate:_object queue:_myVideoOutputQueue];
        }
    [self configureCameraForHighestFrameRate:_videoDevice withPostion:_videoDevice.position andTime:CMTimeMake(20, 600)];

    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    [_disView.layer addSublayer:_previewLayer];
    
    [self startSession];
}

- (void)startSession {
    if(![_captureSession isRunning]) {
        [_captureSession startRunning];
    }
}

- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
                               withPostion:(AVCaptureDevicePosition) postion
                                   andTime:(CMTime) timeStamp
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    if ( bestFormat ) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            
            if (postion == AVCaptureDevicePositionBack) {
                device.activeVideoMinFrameDuration = timeStamp;
                device.activeVideoMaxFrameDuration = timeStamp;
            } else if (postion == AVCaptureDevicePositionFront) {
                device.activeVideoMinFrameDuration = CMTimeMake(20, 1200);
                device.activeVideoMaxFrameDuration = CMTimeMake(20, 1200);
            }
            [device unlockForConfiguration];
        }
    }
}

#pragma mark -- AVCaptureVideoDataOutputSampleBufferDelegate
- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{

    
}

@end
