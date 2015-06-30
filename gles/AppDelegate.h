//
//  AppDelegate.h
//  gles
//
//  Created by Li Jie on 15/6/25.
//  Copyright (c) 2015年 Li Jie. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MainView.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    MainView * _glView;
}

@property (strong, nonatomic) UIWindow * window;
@property (strong, retain) IBOutlet MainView * glView;

@end

