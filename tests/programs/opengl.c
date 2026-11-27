/* OpenGL.framework without a window: a CGL context (offscreen), a framebuffer object, a draw
   call, glReadPixels.  Tries a core profile context and a legacy context, each with the
   renderer that the system picks and then with Apple's software renderer
   (kCGLRendererGenericFloatID); succeeds if one of them draws the expected pixels. */
#include <OpenGL/OpenGL.h>
#include <OpenGL/CGLRenderers.h>
#include <OpenGL/gl3.h>
#include <OpenGL/gl.h>
#include <OpenGL/glext.h>
#include <stdio.h>
#include <string.h>

#define W 64
#define H 64

static int read_center(unsigned char *px, const char *what, int r, int g, int b) {
  glReadPixels(W / 2, H / 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
  printf("  %s: pixel %d %d %d %d, error 0x%x\n", what, px[0], px[1], px[2], px[3], glGetError());
  return px[0] == r && px[1] == g && px[2] == b && px[3] == 255;
}

static int draw_core(void) {
  static const char *vs = "#version 150\nvoid main() { vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);"
                          " gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0); }\n";
  static const char *fs = "#version 150\nout vec4 c;\nvoid main() { c = vec4(1.0, 0.0, 0.0, 1.0); }\n";
  GLuint fbo, rb, vao, prog, sh[2];
  unsigned char px[4];
  int ok, i;
  glGenFramebuffers(1, &fbo); glBindFramebuffer(GL_FRAMEBUFFER, fbo);
  glGenRenderbuffers(1, &rb); glBindRenderbuffer(GL_RENDERBUFFER, rb);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, W, H);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, rb);
  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) { printf("  framebuffer incomplete\n"); return 0; }
  glViewport(0, 0, W, H);
  glClearColor(0, 0, 1, 1); glClear(GL_COLOR_BUFFER_BIT);
  if (!read_center(px, "clear", 0, 0, 255)) return 0;
  prog = glCreateProgram();
  for (i = 0; i < 2; i++) {
    GLint st = 0; const char *src = i ? fs : vs;
    sh[i] = glCreateShader(i ? GL_FRAGMENT_SHADER : GL_VERTEX_SHADER);
    glShaderSource(sh[i], 1, &src, NULL); glCompileShader(sh[i]); glGetShaderiv(sh[i], GL_COMPILE_STATUS, &st);
    if (!st) { char log[512]; glGetShaderInfoLog(sh[i], sizeof log, NULL, log); printf("  shader %d: %s\n", i, log); return 0; }
    glAttachShader(prog, sh[i]);
  }
  glLinkProgram(prog); glUseProgram(prog);
  glGenVertexArrays(1, &vao); glBindVertexArray(vao);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  ok = read_center(px, "triangle", 255, 0, 0);
  glBindVertexArray(0); glDeleteVertexArrays(1, &vao); glUseProgram(0); glDeleteProgram(prog);
  glBindFramebuffer(GL_FRAMEBUFFER, 0); glDeleteRenderbuffers(1, &rb); glDeleteFramebuffers(1, &fbo);
  return ok;
}

static int draw_legacy(void) {
  GLuint fbo, rb;
  unsigned char px[4];
  int ok;
  glGenFramebuffersEXT(1, &fbo); glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo);
  glGenRenderbuffersEXT(1, &rb); glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, rb);
  glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA8, W, H);
  glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_RENDERBUFFER_EXT, rb);
  if (glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) != GL_FRAMEBUFFER_COMPLETE_EXT) { printf("  framebuffer incomplete\n"); return 0; }
  glViewport(0, 0, W, H);
  glClearColor(0, 0, 1, 1); glClear(GL_COLOR_BUFFER_BIT);
  if (!read_center(px, "clear", 0, 0, 255)) return 0;
  glColor3f(0, 1, 0);
  glBegin(GL_TRIANGLES); glVertex2f(-1, -1); glVertex2f(3, -1); glVertex2f(-1, 3); glEnd();
  ok = read_center(px, "triangle", 0, 255, 0);
  glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0); glDeleteRenderbuffersEXT(1, &rb); glDeleteFramebuffersEXT(1, &fbo);
  return ok;
}

static int try_one(int core, int software) {
  CGLPixelFormatAttribute attr[8];
  CGLPixelFormatObj pf = NULL; CGLContextObj ctx = NULL;
  GLint npf = 0; int n = 0, ok = 0; CGLError e;
  attr[n++] = kCGLPFAOpenGLProfile; attr[n++] = (CGLPixelFormatAttribute)(core ? kCGLOGLPVersion_3_2_Core : kCGLOGLPVersion_Legacy);
  if (software) { attr[n++] = kCGLPFARendererID; attr[n++] = (CGLPixelFormatAttribute)kCGLRendererGenericFloatID; }
  attr[n++] = kCGLPFAColorSize; attr[n++] = (CGLPixelFormatAttribute)24;
  attr[n] = (CGLPixelFormatAttribute)0;
  printf("%s profile, %s renderer\n", core ? "core" : "legacy", software ? "software" : "default");
  if ((e = CGLChoosePixelFormat(attr, &pf, &npf)) || !pf) { printf("  CGLChoosePixelFormat: %s\n", CGLErrorString(e)); return 0; }
  e = CGLCreateContext(pf, NULL, &ctx); CGLDestroyPixelFormat(pf);
  if (e || !ctx) { printf("  CGLCreateContext: %s\n", CGLErrorString(e)); return 0; }
  if ((e = CGLSetCurrentContext(ctx))) { printf("  CGLSetCurrentContext: %s\n", CGLErrorString(e)); CGLDestroyContext(ctx); return 0; }
  printf("  %s | %s | %s\n", (const char *)glGetString(GL_VENDOR), (const char *)glGetString(GL_RENDERER), (const char *)glGetString(GL_VERSION));
  ok = core ? draw_core() : draw_legacy();
  CGLSetCurrentContext(NULL); CGLDestroyContext(ctx);
  return ok;
}

int main(void) {
  GLint major = 0, minor = 0;
  int core, software, passed = 0;
  CGLGetVersion(&major, &minor);
  printf("CGL %d.%d\n", major, minor);
  for (core = 1; core >= 0; core--)
    for (software = 0; software <= 1; software++)
      if (try_one(core, software)) { printf("ok\n"); passed++; }
  printf("%d of 4 combinations drew the expected pixels\n", passed);
  return passed ? 0 : 1;
}
