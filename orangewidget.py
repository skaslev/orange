import logging
from OpenGL.GL import *
from PyQt4 import QtCore, QtOpenGL
from orange import Orange
from camera import MayaCamera

log = logging.getLogger(__file__)

class OrangeWidget(QtOpenGL.QGLWidget):
    def __init__(self, parent=None):
        super(OrangeWidget, self).__init__(parent)
        self.camera = MayaCamera()
        self.timer = QtCore.QTime()
        self.reset_fps()

    @property
    def fps(self):
        return 1000.0 * self.frames / max(1, self.timer.elapsed())

    def reset_fps(self):
        self.frames = 0
        self.timer.start()

    def cleanup(self):
        self.orange = None

    def initializeGL(self):
        self.cleanup()
        self.orange = Orange()
        self.orange.set_camera_xform(self.camera.view_matrix_inv.data())
        log.info('OpenGL %s' % glGetString(GL_VERSION))

    def paintGL(self):
        fb = self.orange.render()
        self.drawTexture(QtCore.QRectF(-1,-1,2,2), fb)
        glFinish()
        self.update()
        self.frames += 1

    def resizeGL(self, width, height):
        glViewport(0, 0, width, height)
        self.camera.aspect = float(width) / height

    def mousePressEvent(self, event):
        self.last_pos = event.posF()

    def mouseMoveEvent(self, event):
        dxy = event.posF() - self.last_pos
        dx = dxy.x() / self.width()
        dy = dxy.y() / self.height()
        if event.buttons() & QtCore.Qt.LeftButton:
            self.camera.rotate(dx, dy)
        elif (event.buttons() & Qt.MidButton) or event.modifiers():
            self.camera.pan(dx, dy)
        elif event.buttons() & QtCore.Qt.RightButton:
            self.camera.zoom(dx, dy)
        self.orange.set_camera_xform(self.camera.view_matrix_inv.data())
        self.last_pos = event.posF()

    def wheelEvent(self, event):
        self.camera.zoom(event.delta() / 360.0, 0.0)
        self.orange.set_camera_xform(self.camera.view_matrix_inv.data())
