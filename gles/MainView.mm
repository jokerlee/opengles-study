//
//  ViewController.m
//  gles
//
//  Created by Li Jie on 15/6/25.
//  Copyright (c) 2015年 Li Jie. All rights reserved.
//

#import "MainView.h"
#import "Util.h"
#import "ksMatrix.h"

#include <map>
#include <string>

#define IOS_MAX_TOUCHES_COUNT   10

@implementation MainView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    _frameCount = 0;
    _framebuffer = 0;
    _renderbuffer = 0;
    _depthbuffer = 0;
    _msaaFramebuffer = 0;
    _msaaRenderbuffer = 0;
    _enableMultiSampling = true;
    _cubeOffset = {0.0, 0.0};
    _cubeScale = 1.0;
    _cubeRotation = 0.0;
    
    auto * pinchRecognizer = [[UIPinchGestureRecognizer alloc]initWithTarget:self action:@selector(onScale:)];
    [pinchRecognizer setDelegate:self];
    [self addGestureRecognizer:pinchRecognizer];

    auto * rotateRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(onRotate:)];
    [rotateRecognizer setDelegate:self];
    [self addGestureRecognizer:rotateRecognizer];
    
    auto * panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onMove:)];
    [panRecognizer setMinimumNumberOfTouches:1];
    [panRecognizer setMaximumNumberOfTouches:1];
    [panRecognizer setDelegate:self];
    [self addGestureRecognizer:panRecognizer];
    
    
    _eaglLayer = (CAEAGLLayer*) self.layer;
    _eaglLayer.opaque = YES;
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
                                     kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    _context = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES2];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    // 设置为当前上下文
    if (![EAGLContext setCurrentContext: _context]) {
        _context = nil;
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
    
    // init
    glClearDepthf(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    //glEnable(GL_CULL_FACE);
    //glCullFace(GL_BACK);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glClearColor(0, 1.0, 1.0, 1.0);
    
    return self;
}


std::map<std::string, int> s_programs;
- (GLuint)setupProgram:(NSString *)name
{
    std::string key = [name UTF8String];
    GLuint programId;
    if (s_programs.find(key) == s_programs.end()) {
        NSString * vert = [[NSBundle mainBundle] pathForResource:name ofType:@"vert"];
        NSString * frag = [[NSBundle mainBundle] pathForResource:name ofType:@"frag"];
        programId = LoadShaders([vert UTF8String], [frag UTF8String]);
        if (programId == 0) {
            NSLog(@" >> Error: Failed to setup program.");
            return -1;
        }
        s_programs[key] = programId;
    } else {
        programId = s_programs[key];
    }
    
    glUseProgram(programId);
    return programId;
}

- (void)setupBuffers
{
    // setup default framebuffer
    glGenRenderbuffers(1, &_renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    GLint backingWidth, backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    // setup frame buffer for multisampling
    GLint samplesToUse = 2;
    if (_enableMultiSampling) {
        glGenFramebuffers(1, &_msaaFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
        glGenRenderbuffers(1, &_msaaRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _msaaRenderbuffer);

        GLint maxSamplesAllowed;
        glGetIntegerv(GL_MAX_SAMPLES_APPLE, &maxSamplesAllowed);
        samplesToUse = MIN(maxSamplesAllowed, 4);
        glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, samplesToUse, GL_RGBA8_OES, backingWidth, backingHeight);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _msaaRenderbuffer);
    }

    // setup depth buffer
    glGenRenderbuffers(1, &_depthbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthbuffer);
    if (_enableMultiSampling)
        glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, samplesToUse, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
    else
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthbuffer);
    //glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _depthbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);

    GLenum error;
    if ((error = glCheckFramebufferStatus(GL_FRAMEBUFFER)) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object 0x%X", error);
    }
}

- (void)destroyBuffers
{
    FREE_BUFFER(_framebuffer, Frame);
    FREE_BUFFER(_renderbuffer, Render);
    FREE_BUFFER(_msaaFramebuffer, Frame);
    FREE_BUFFER(_msaaRenderbuffer, Render);
    FREE_BUFFER(_depthbuffer, Render);
}

std::map<std::string, int> s_textures;
- (GLuint)setupTexture:(const char *)name
{
    GLuint textureId;
    if (s_textures.find(name) == s_textures.end()) {
        GLuint textureId = LoadTexture(name);
        if (textureId == 0) {
            NSLog(@" >> Error: Failed to setup program.");
            return -1;
        }
        s_textures[name] = textureId;
    } else {
        textureId = s_textures[name];
    }
    
    static GLuint lastTextureId = -1;
    if (textureId != lastTextureId) {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, textureId);
        lastTextureId = textureId;
    }
    return textureId;
}

- (void)layoutSubviews
{
    [EAGLContext setCurrentContext:_context];
    
    [self destroyBuffers];
    [self setupBuffers];
    
    if (_displayLink == nil) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
        [_displayLink setFrameInterval: 1.0/60.0];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        [_displayLink invalidate];
        [_displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        _displayLink = nil;
    }

    [self render];
}

- (void)displayLinkCallback:(CADisplayLink*)displayLink
{
    [EAGLContext setCurrentContext: _context];
    [self render];
    _frameCount ++;
}

- (void)render
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    
    [self renderTriangles];
    [self renderTexture];
    [self renderCube];

    if (_enableMultiSampling) {
        //Bind both MSAA and View FrameBuffers.
        glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, _msaaFramebuffer);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, _framebuffer);
        // Call a resolve to combine both buffers
        glResolveMultisampleFramebufferAPPLE();
        GLenum attachments[] = {GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT};
        glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 2, attachments);
        // Present final image to screen
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    } else {
        GLenum attachments[] = {GL_DEPTH_ATTACHMENT};
        glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 1, attachments);
    }
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
    if (_enableMultiSampling) {
        glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _msaaRenderbuffer);
    }
}

- (void)renderTriangles
{
    // prepare vertices data
    struct VertexData {
        GLubyte color[4];
        GLfloat position[2];
    };
    
    const VertexData vertices[] = {
        {{255,   0,   0, 255}, { 0.0, 1.0}},
        {{  0, 255,   0, 255}, {-1.0, 0.5}},
        {{  0,   0, 255, 255}, { 0.0, 0.5}},
       
        {{ 10,  10,  10, 100}, { 0.0,  1.0}},
        {{100, 100, 100, 255}, {-1.0,  0.5}},
        {{255, 255, 255, 255}, {-1.0,  1.0}},
    };

    GLuint programId = [self setupProgram: @"triangle"];
    static GLuint vaoId = -1;
    if (vaoId == -1) {
        // setup vertex buffer
        vaoId = CreateVAO();
        CREATE_VBO(GL_ARRAY_BUFFER, vertices);
        // setup position and color attributes for vertex shader
        GLuint aPosition = GetAttributeLocation(programId, "a_position");
        glVertexAttribPointer(aPosition, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), (void*)sizeof(vertices[0].color));
        glEnableVertexAttribArray(aPosition);
        GLuint aColor = GetAttributeLocation(programId, "a_color");
        glVertexAttribPointer(aColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(VertexData), (void*)0);
        glEnableVertexAttribArray(aColor);
        
        glBindVertexArrayOES(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
    
    glBindVertexArrayOES(vaoId);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArrayOES(0);
}

- (void) renderTexture
{
    const GLfloat quadData[][2] = {
        // vertex positions
        {0.0f, 0.5f}, {0.0f, 1.0f},
        {1.0f, 0.5f}, {1.0f, 1.0f},
        // texture coordinates
        {0.0f, 1.0f}, {0.0f, 0.0f},
        {1.0f, 1.0f}, {1.0f, 0.0f}
    };
    
    GLuint programId = [self setupProgram: @"texture"];
    [self setupTexture: "gles_logo.png"];
    
    static GLuint vaoId = -1;
    if (vaoId == -1) {
        vaoId = CreateVAO();
        CREATE_VBO(GL_ARRAY_BUFFER, quadData);
        
        GLuint uTexUnit = GetUniformLocation(programId, "u_texUnit");
        glUniform1i(uTexUnit, 0);
        
        GLuint aPosition = GetAttributeLocation(programId, "a_position");
        glVertexAttribPointer(aPosition, 2, GL_FLOAT, GL_TRUE, 0, (void *)0);
        glEnableVertexAttribArray(aPosition);
        GLuint aTexCoord = GetAttributeLocation(programId, "a_texCoord");
        glVertexAttribPointer(aTexCoord, 2, GL_FLOAT, GL_TRUE, 0, (void *)(8 * sizeof(GLfloat)));
        glEnableVertexAttribArray(aTexCoord);
        
        glBindVertexArrayOES(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
    
    glBindVertexArrayOES(vaoId);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArrayOES(0);
}


- (void)setupProjection:(GLuint)programId
{
    // Generate a perspective matrix with a 60 degree FOV
    float aspect = self.frame.size.width / self.frame.size.height;
    ksMatrix4 projectionMatrix;
    ksMatrixLoadIdentity(&projectionMatrix);
    ksPerspective(&projectionMatrix, 60.0, aspect, 1.0f, 20.0f);
    
    // Load projection matrix
    GLuint uProjection = GetUniformLocation(programId, "u_projection");
    glUniformMatrix4fv(uProjection, 1, GL_FALSE, (GLfloat*)&projectionMatrix.m[0][0]);
}

- (void)updateCubeTransform:(GLuint)programId
{
    ksMatrix4 modelViewMatrix;
    ksMatrixLoadIdentity(&modelViewMatrix);
    ksMatrixTranslate(&modelViewMatrix, _cubeOffset.x, _cubeOffset.y, -5.5);
    ksMatrixScale(&modelViewMatrix, _cubeScale, _cubeScale, _cubeScale);
    ksMatrixRotate(&modelViewMatrix, _cubeRotation, 0.0, 0.0, 1.0);
    ksMatrixRotate(&modelViewMatrix, _frameCount, 1.0, 0.0, 0.0);
    GLuint uModelView = GetUniformLocation(programId, "u_modelView");
    glUniformMatrix4fv(uModelView, 1, GL_FALSE, (GLfloat*) &modelViewMatrix.m[0][0]);
}

- (void)renderCube
{
    struct Vertex {
        float Position[3];
        float Color[4];
    };

    Vertex data[] = {
        // Front
        {{ 1.0f, -1.0f,  1.0f},   RED}, {{ 1.0,  1.0,  1.0},   RED},
        {{-1.0f,  1.0f,  1.0f},   RED}, {{-1.0, -1.0,  1.0},   RED},
        // Back
        {{ 1.0f, -1.0f, -1.0f},  BLUE}, {{ 1.0,  1.0, -1.0},  BLUE},
        {{-1.0f,  1.0f, -1.0f},  BLUE}, {{-1.0, -1.0, -1.0},  BLUE},
        // Left
        {{-1.0f, -1.0f,  1.0f}, GREEN}, {{-1.0,  1.0,  1.0}, GREEN},
        {{-1.0f,  1.0f, -1.0f}, GREEN}, {{-1.0, -1.0, -1.0}, GREEN},
        // Right
        {{ 1.0f, -1.0f, -1.0f}, BLACK}, {{ 1.0,  1.0, -1.0}, BLACK},
        {{ 1.0f,  1.0f,  1.0f}, BLACK}, {{ 1.0, -1.0,  1.0}, BLACK},
        // Top
        {{ 1.0f,  1.0f,  1.0f},YELLOW}, {{ 1.0,  1.0, -1.0},YELLOW},
        {{-1.0f,  1.0f, -1.0f},YELLOW}, {{-1.0,  1.0,  1.0},YELLOW},
        // Bottom
        {{-1.0f, -1.0f, -1.0f}, WHITE}, {{-1.0, -1.0,  1.0}, WHITE},
        {{ 1.0f, -1.0f,  1.0f}, WHITE}, {{ 1.0, -1.0, -1.0}, WHITE}
    };
    
    GLushort indices[] = {
        0,  1,  2,  2,  3,  0, // Front
         4,  5,  6,  6,  7,  4, // Back
         8,  9, 10, 10, 11,  8, // Left
        12, 13, 14, 14, 15, 12, // Right
        16, 17, 18, 18, 19, 16, // Top
        20, 21, 22, 22, 23, 20,  // Bottom
    };
    
    GLuint programId = [self setupProgram: @"cube"];
    [self updateCubeTransform: programId];

    static GLuint vaoId = -1;
    if (vaoId == -1) {
        vaoId = CreateVAO();
        [self setupProjection: programId];
        
        CREATE_VBO(GL_ARRAY_BUFFER, data);
        GLuint aPosition = glGetAttribLocation(programId, "a_position");
        glVertexAttribPointer(aPosition, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*)offsetof(Vertex, Position));
        glEnableVertexAttribArray(aPosition);
        GLuint aColor = glGetAttribLocation(programId, "a_color");
        glVertexAttribPointer(aColor, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*)offsetof(Vertex, Color));
        glEnableVertexAttribArray(aColor);

        CREATE_VBO(GL_ELEMENT_ARRAY_BUFFER, indices);

        glBindVertexArrayOES(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }
    
    glBindVertexArrayOES(vaoId);
    glDrawElements(GL_TRIANGLES, sizeof(indices)/sizeof(GLushort), GL_UNSIGNED_SHORT, (GLvoid*)0);
    glBindVertexArrayOES(0);
}



- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)onScale:(UIPinchGestureRecognizer *)gesture
{
    static float scaleStart = 1.0f;
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            scaleStart = _cubeScale;
            break;
        case UIGestureRecognizerStateChanged:
            _cubeScale = scaleStart * gesture.scale;
            break;
        default:
            break;
    }
}

- (void)onRotate:(UIRotationGestureRecognizer *)gesture
{
    static float rotationStart = 0.0f;
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            rotationStart = _cubeRotation;
            break;
        case UIGestureRecognizerStateChanged:
            _cubeRotation = rotationStart + RADIAN_TO_DEGREE(gesture.rotation);
            break;
        default:
            break;
    }
}

- (void)onMove:(UIPanGestureRecognizer *)gesture
{
    static CGPoint moveStart;
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            moveStart = _cubeOffset;
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint offset = [gesture translationInView:self];
            _cubeOffset.x = moveStart.x + offset.x / self.frame.size.width * 2;
            _cubeOffset.y = moveStart.y - offset.y / self.frame.size.height * 6;
            break;
        }
        default:
            break;
    }
}

@end