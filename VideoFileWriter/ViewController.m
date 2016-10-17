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
#import "FJVideoFileReader.h"

#import <MobileCoreServices/MobileCoreServices.h>

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UIView *displayView;
@property (assign, nonatomic) BOOL isRecording;
@property (strong, nonatomic) FJVideoCapture *videoCapture;
@property (strong, nonatomic) FJVideoFileWriter *fileWriter;
@property (strong, nonatomic) FJVideoFileReader *fileReader;
@property (strong, nonatomic) NSURL *localVideoUrl;
- (IBAction)choosePixel:(id)sender;
- (IBAction)chooseSamBuffer:(id)sender;
- (IBAction)chooseImagePicker:(id)sender;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _isRecording = NO;
    
    _videoCapture = [[FJVideoCapture alloc] initWithDisplayView:_displayView andDelegate:self];
    _fileWriter = [[FJVideoFileWriter alloc] initWithFileUrl:NULL BufferType:FJ_MUXBUFFER VideoSize: CGSizeMake(720, 1280) andVideoSource:FJ_DATA];
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
        
        BOOL isvideo = [_videoCapture connectionIsVideo:connection];
        
        if (isvideo) {
//            CVPixelBufferRef pxbuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            [_fileWriter appendSampleBuffer:sampleBuffer];
        } else {
//            NSLog(@"audio");
            [_fileWriter appendSampleBuffer:sampleBuffer];
        }
        

        
        
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

- (IBAction)chooseImagePicker:(id)sender {
    [self swipeToVideoPicker];
}


- (void) swipeToVideoPicker
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.allowsEditing = YES;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes =  [[NSArray alloc] initWithObjects: (NSString *)kUTTypeMovie, nil];
    [self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark -
#pragma UIImagePickerController Delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    if ([[info objectForKey:UIImagePickerControllerMediaType] isEqualToString:(NSString*)kUTTypeMovie]) {
        _localVideoUrl = [info objectForKey:UIImagePickerControllerMediaURL];
        _fileReader = [[FJVideoFileReader alloc] initWithSize:CGSizeMake(720, 1280) andFileUrl:_localVideoUrl];
        
    }
//Please don't try this way for now, memory leak.
    [picker dismissViewControllerAnimated:YES completion:^{
        [_fileWriter startWriting];
        [_fileReader startReadingWithHandler:^(CMSampleBufferRef sampleBuffer) {
            if (sampleBuffer) {
                [_fileWriter appendSampleBuffer:sampleBuffer];
//                CFRelease(sampleBuffer);
            } else {
                [_fileWriter stopWriting];
            }
            
        }];
    }];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end
