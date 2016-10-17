//
//  ViewController.m
//  VideoFileWriter
//
//  Created by Clover on 16/10/2016.
//  Copyright © 2016 Clover Peng. All rights reserved.
//

#import "ViewController.h"
#import "FJVideoFileWriter.h"
#import "FJVideoCapture.h"
@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) IBOutlet UIView *displayView;
@property (assign, nonatomic) BOOL isRecording;
@property (strong, nonatomic) FJVideoCapture *videoCapture;
@property (strong, nonatomic) FJVideoFileWriter *fileWriter;
- (IBAction)choosePixel:(id)sender;
- (IBAction)chooseSamBuffer:(id)sender;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _isRecording = NO;
    
    _videoCapture = [[FJVideoCapture alloc] initWithDisplayView:_displayView andDelegate:self];
    _fileWriter = [[FJVideoFileWriter alloc] initWithFileUrl:NULL BufferType:FJ_SAMPLEBUFFER VideoSize: CGSizeMake(720, 1280) andVideoSource:FJ_DATA];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)viewWillLayoutSubviews {
    [_videoCapture setDisplayViewBounds:self.displayView.bounds];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -- AVCaptureVideoDataOutputSampleBufferDelegate
- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{

    
    if (_isRecording) {
//        CVPixelBufferRef pxbuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        [_fileWriter appendSampleBuffer:sampleBuffer];
        
    }
    
}


- (IBAction)choosePixel:(id)sender {
    NSLog(@"choosePixel");
    _isRecording = !_isRecording;
    
    _isRecording? [_fileWriter startWriting]:[_fileWriter stopWriting];
}

- (IBAction)chooseSamBuffer:(id)sender {
     NSLog(@"chooseSamBuffer");
    _isRecording = !_isRecording;
    
    _isRecording? [_fileWriter startWriting]:[_fileWriter stopWriting];
}
@end
