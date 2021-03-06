//
//  ReadabilityParserAppDelegate.h
//  iPhoneReadabilityParsing
//
//  Created by Vo Khang on 6/11/11.
//  Copyright (c) 2011 KDLab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GGReadability.h"

@class ReadabilityParserViewController;

@interface ReadabilityParserAppDelegate : UIResponder <UIApplicationDelegate, GGReadabilityDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ReadabilityParserViewController *viewController;

@end
