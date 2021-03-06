//
//  ViewController.h
//  gles
//
//  Created by Li Jie on 15/6/25.
//  Copyright (c) 2015年 Li Jie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

#include "ksVector.h"

@interface MainView: UIView<UIGestureRecognizerDelegate> {
    CAEAGLLayer * _eaglLayer;
    EAGLContext * _context;
    GLuint _renderbuffer;
    GLuint _framebuffer;
    GLuint _depthbuffer;
    GLuint _msaaFramebuffer;
    GLuint _msaaRenderbuffer;
    Boolean _enableMultiSampling;
    CADisplayLink * _displayLink;
    int _frameCount;
    CGPoint _cubeOffset;
    float _cubeScale;
    float _cubeRotation;
}

- (void)setupBuffers;
- (void)destroyBuffers;
- (GLuint)setupProgram:(NSString *)name;
- (GLuint)setupTexture:(const char *)name;

- (void)render;
- (void)renderTriangles;
- (void)renderTexture;
- (void)renderCube;

- (void)setupProjection:(GLuint)programId;
- (void)updateCubeTransform:(GLuint)programId;
- (void)displayLinkCallback:(CADisplayLink*)displayLink;

- (void)onScale:(UIPinchGestureRecognizer *)pinchGesture;
- (void)onRotate:(UIRotationGestureRecognizer *)rotateGesture;
- (void)onMove:(UIPanGestureRecognizer *)panGesture;

@end