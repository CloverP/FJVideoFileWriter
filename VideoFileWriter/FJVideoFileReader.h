//
//  FJVideoFileReader.h
//  VideoFileWriter
//
//  Created by Clover on 17/10/2016.
//  Copyright © 2016 Clover Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef void(^FJVideoFileReaderBlock)(CMSampleBufferRef sampleBuffer);

@interface FJVideoFileReader : NSObject

@property (strong, nonatomic) NSURL *fileUrl;

@property (assign, nonatomic) BOOL isPause;
@property (assign, nonatomic) BOOL isReading;

- (instancetype) initWithSize:(CGSize) size andFileUrl:(NSURL *)fileUrl;

- (void) startReadingWithHandler:(FJVideoFileReaderBlock) handler;
- (void) stopReading;

@end
