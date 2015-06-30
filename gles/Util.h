//
//  Util.h
//  gles
//
//  Created by Li Jie on 15/6/25.
//  Copyright (c) 2015年 Li Jie. All rights reserved.
//

#ifndef gles_Util_h
#define gles_Util_h

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define RED     {1.0f, 0.0f, 0.0f, 1.0f}
#define GREEN   {0.0f, 1.0f, 0.0f, 1.0f}
#define BLUE    {0.0f, 0.0f, 1.0f, 1.0f}
#define YELLOW  {1.0f, 1.0f, 0.0f, 1.0f}
#define BLACK   {0.0f, 0.0f, 0.0f, 1.0f}
#define WHITE   {1.0f, 1.0f, 1.0f, 1.0f}

#define FREE_BUFFER(buffer, type) if (buffer) { glDelete##type##buffers(1, &buffer); buffer = 0; }
#define CREATE_VBO(type, data) CreateVBO(type, (GLvoid *)data, sizeof(data))

#define CHECK_GL_ERROR_DEBUG() \
    do { \
        GLenum __error = glGetError(); \
        if (__error) { \
            printf("OpenGL error 0x%04X in %s %s %d\n", __error, __FILE__, __FUNCTION__, __LINE__); \
        } \
    } while (false)


GLuint GetUniformLocation(GLuint programId, const char * name);
GLuint GetAttributeLocation(GLuint programId, const char * name);

GLuint LoadShaders(const char * vertex_file_path, const char * fragment_file_path);

GLuint LoadTexture(const char * imageName);

GLuint CreateVBO(GLenum type, GLvoid * data, long size);
GLuint CreateVAO();

#endif
