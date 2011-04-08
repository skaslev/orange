import os
import sys
import logging
import Imath
import OpenEXR
import numpy as np
import pyopencl as cl
import pyopencl.tools as cl_tools
from OpenGL.GL import *

log = logging.getLogger(__file__)

class ProgramCache(object):
    def __init__(self, ctx):
        from PyQt4.QtCore import QFileSystemWatcher
        self.ctx = ctx
        self.cache = {}
        self.watcher = QFileSystemWatcher()
        self.watcher.fileChanged.connect(self._file_changed)

    def _file_changed(self, path):
        path = str(path)
        del self.cache[path]
        self.watcher.removePath(path)

    def get(self, path):
        prog = self.cache.get(path, None)
        if not prog:
            prog = cl.Program(self.ctx, open(path).read()).build()
            log.info('%s succesfully compiled' % path)
            self.cache[path] = prog
            self.watcher.addPath(path)
        return prog

def _create_texture(width, height):
    tex = glGenTextures(1)
    glBindTexture(GL_TEXTURE_2D, tex)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, None)
    return tex

def _create_context():
    if sys.platform == 'darwin':
        props = cl_tools.get_gl_sharing_context_properties()
        ctx = cl.Context(properties=props, devices=[])
    else:
        props = [(cl.context_properties.PLATFORM, cl.get_platforms()[0])]
        props += cl_tools.get_gl_sharing_context_properties()
        ctx = cl.Context(properties=props)
    for i, dev in enumerate(ctx.devices):
        log.info('device %d: %s, driver version %s' % (i, dev.version, dev.driver_version))
        log.info('device %d: %s by %s' % (i, dev.name, dev.vendor))
    return ctx

def _read_channel(f, c):
    return np.fromstring(f.channel(c, Imath.PixelType(Imath.PixelType.FLOAT)),
                         np.float32)

def _load_exr(ctx, filename):
    f = OpenEXR.InputFile(filename)
    dw = f.header()['dataWindow']
    shape = (dw.max.x - dw.min.x + 1, dw.max.y - dw.min.y + 1)
    sz = shape[0] * shape[1]
    buf = np.empty(4 * sz, np.float32)
    buf[0::4] = _read_channel(f, 'R')
    buf[1::4] = _read_channel(f, 'G')
    buf[2::4] = _read_channel(f, 'B')
    buf[3::4] = np.ones(sz, np.float32)
    return cl.Image(ctx, cl.mem_flags.READ_ONLY | cl.mem_flags.COPY_HOST_PTR,
                    cl.ImageFormat(cl.channel_order.RGBA, cl.channel_type.FLOAT),
                    shape=shape, hostbuf=buf)

class Orange(object):
    def __init__(self, width=512, height=512):
        self.sample = 0
        self.width = width
        self.height = height
        self.tex = [_create_texture(width, height) for i in range(2)]
        self.ctx = _create_context()
        self.cache = ProgramCache(self.ctx)
        self.queue = cl.CommandQueue(self.ctx)
        mf = cl.mem_flags
        self.buf = [cl.GLTexture(self.ctx, mf.READ_WRITE, GL_TEXTURE_2D, 0, t, 2) for t in self.tex]
        self.front = 0
        ident = np.array([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1], np.float32)
        self.cam_xform = cl.Buffer(self.ctx, mf.READ_ONLY | mf.COPY_HOST_PTR, hostbuf=ident)
        self.env = _load_exr(self.ctx, 'images/MeadowTrail.exr')

    def __del__(self):
        glDeleteTextures(self.tex)

    def render(self):
        self.sample += 1
        front_buf = self.buf[self.front]
        back_buf = self.buf[1 - self.front]
        self.front = 1 - self.front
        prog = self.cache.get('kernels/test.cl')
        cl.enqueue_acquire_gl_objects(self.queue, self.buf)
        global_size = (self.width, self.height)
        args = (self.cam_xform, np.int32(self.sample), self.env, back_buf, front_buf)
        prog.foo(self.queue, global_size, None, *args)
        cl.enqueue_release_gl_objects(self.queue, self.buf)
        self.queue.finish()
        return front_buf.gl_object

    def set_camera_xform(self, xform):
        self.sample = 0
        cl.enqueue_write_buffer(self.queue, self.cam_xform, np.array(xform, np.float32))
