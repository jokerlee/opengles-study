//
//  Util.m
//  gles
//
//  Created by Li Jie on 15/6/25.
//  Copyright (c) 2015年 Li Jie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <fstream>
#include <vector>
#include <map>


#import "Util.h"

typedef std::map<GLuint, std::map<std::string, GLuint>> LocationMap;

static LocationMap s_uniforms;
static LocationMap s_attributes;

GLuint GetUniformLocation(GLuint programId, const char * name) {
    auto uniforms = s_uniforms[programId];
    if (uniforms.find(name) == uniforms.end()) {
        GLuint slot = glGetUniformLocation(programId, name);
        uniforms[name] = slot;
        return slot;
    } else {
        return uniforms[name];
    }
}

GLuint GetAttributeLocation(GLuint programId, const char * name) {
    auto attrs = s_attributes[programId];
    if (attrs.find(name) == attrs.end()) {
        GLuint slot = glGetAttribLocation(programId, name);
        attrs[name] = slot;
        return slot;
    } else {
        return attrs[name];
    }
}

GLuint CreateVBO(GLenum type, GLvoid * data, long size) {
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(type, buffer);
    glBufferData(type, size, data, GL_STATIC_DRAW);
    return buffer;
}

GLuint CreateVAO() {
    GLuint vao;
    glGenVertexArraysOES(1, &vao);
    glBindVertexArrayOES(vao);
    return vao;
}

GLuint LoadShader(std::string shader_path, int shaderType) {
    GLuint shaderID = glCreateShader(shaderType);
    
    // Read the Shader code from the file
    std::ifstream shaderStream(shader_path, std::ios::in);
    if (!shaderStream.is_open()) {
        printf("[LoadShader] shader file not found: %s\n", shader_path.c_str());
        return shaderID;
    }
    std::string shaderCode;
    std::string line;
    while (getline(shaderStream, line)) {
        shaderCode += "\n" + line;
    }
    shaderStream.close();

    // Compile Shader
    std::string fileName = shader_path.substr(shader_path.find_last_of("/") + 1);
    printf("[LoadShader] Compiling shader: %s\n", fileName.c_str());
    char const * vertexSourcePointer = shaderCode.c_str();
    glShaderSource(shaderID, 1, &vertexSourcePointer, NULL);
    glCompileShader(shaderID);
    
    // Check Shader
    GLint result = GL_FALSE;
    int infoLogLength;
    glGetShaderiv(shaderID, GL_COMPILE_STATUS, &result);
    glGetShaderiv(shaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
    if (!result || infoLogLength > 0) {
        GLchar shaderErrorMessage[infoLogLength];
        glGetShaderInfoLog(shaderID, infoLogLength, NULL, &shaderErrorMessage[0]);
        printf("%s\n", &shaderErrorMessage[0]);
    }
    
    return shaderID;
}


GLuint LoadShaders(const char * vertex_file_path, const char * fragment_file_path) {

    // Create the shaders
    GLuint vertexShaderID = LoadShader(vertex_file_path, GL_VERTEX_SHADER);
    GLuint fragmentShaderID = LoadShader(fragment_file_path, GL_FRAGMENT_SHADER);
    
    // Link the program
    GLuint programID = glCreateProgram();
    glAttachShader(programID, vertexShaderID);
    glAttachShader(programID, fragmentShaderID);
    glLinkProgram(programID);
    
    // Check the program
    GLint result = GL_FALSE;
    int infoLogLength;
    glGetProgramiv(programID, GL_LINK_STATUS, &result);
    glGetProgramiv(programID, GL_INFO_LOG_LENGTH, &infoLogLength);
    if (!result || infoLogLength > 0) {
        GLchar programErrorMessage[std::max(infoLogLength, int(1))];
        glGetProgramInfoLog(programID, infoLogLength, NULL, &programErrorMessage[0]);
        printf("[LoadShaders] %s\n", &programErrorMessage[0]);
    }
    
    glDeleteShader(vertexShaderID);
    glDeleteShader(fragmentShaderID);
    
    return programID;
}


GLuint LoadTexture(const char * imageName) {

    // load Image and get pixel data
    CGImageRef image = [UIImage imageNamed: [NSString stringWithUTF8String: imageName]].CGImage;
    GLuint width = (int)CGImageGetWidth(image), height = (int)CGImageGetHeight(image);
    GLubyte * imageData = (GLubyte *)malloc(width * height * 4);
    CGContextRef imageContext = CGBitmapContextCreate(imageData, width, height,
                                                      8, 4 * width,
                                                      CGColorSpaceCreateDeviceRGB(),
                                                      kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(imageContext, CGRectMake(0.0, 0.0, width, height), image);
    CGContextRelease(imageContext);

    GLuint textureId;
    glGenTextures(1, &textureId);
    glBindTexture(GL_TEXTURE_2D, textureId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    free(imageData);
    
    printf("[LoadTexture] load %s %dx%d\n", imageName, width, height);
    return textureId;
}
