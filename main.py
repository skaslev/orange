#!/usr/bin/env python
import sys
import logging
from PyQt4 import QtGui
from orangewidget import OrangeWidget

class MainWindow(QtGui.QMainWindow):
    def __init__(self, parent=None):
        super(MainWindow, self).__init__(parent)
        self._setup_ui()
        self.fps_timer = self.startTimer(1500)

    def _setup_ui(self):
        self.resize(641, 512)
        self.setWindowTitle('orange')

        central = QtGui.QWidget(self)
        self.setCentralWidget(central)

        self.orange = OrangeWidget(central)
        self.orange.setMinimumSize(512, 512)

        right = QtGui.QWidget(central)
        self.fps = QtGui.QLabel(right)
        vsync = QtGui.QPushButton(right, text='Toggle Vsync', clicked=self._toggle_vsync)
        about = QtGui.QPushButton(right, text='About Qt', clicked=self._about_qt)

        vbox = QtGui.QVBoxLayout(right)
        vbox.addWidget(self.fps, 0)
        vbox.addWidget(vsync, 0)
        vbox.addWidget(about, 0)
        vbox.addStretch(0)

        hbox = QtGui.QHBoxLayout(central)
        hbox.setContentsMargins(0, 0, 0, 0)
        hbox.addWidget(self.orange, 1)
        hbox.addWidget(right)

    def closeEvent(self, event):
        if event.isAccepted():
            self.orange.cleanup()

    def timerEvent(self, event):
        if self.fps_timer == event.timerId():
            self.fps.setText('%.0f fps' % (self.orange.fps + 0.5))
            self.orange.reset_fps()

    def _toggle_vsync(self):
        fmt = self.orange.format()
        fmt.setSwapInterval((fmt.swapInterval() + 1) % 2)
        self.orange.setFormat(fmt)

    def _about_qt(self):
        QtGui.QApplication.aboutQt()

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(levelname)-5s %(message)s')
    a = QtGui.QApplication(sys.argv)
    w = MainWindow()
    w.show()
    a.exec_()
