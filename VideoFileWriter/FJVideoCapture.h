//
//  FJVideoCapture.h
//  VideoFileWriter
//
//  Created by Clover on 16/10/2016.
//  Copyright © 2016 Clover Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
@interface FJVideoCapture : NSObject

- (instancetype) initWithDisplayView:(UIView *)disView
                         andDelegate:(id) object;

- (void) setDisplayViewBounds:(CGRect) bounds;

@end
