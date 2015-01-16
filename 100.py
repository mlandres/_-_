#! /usr/bin/python
import sys, os, time, random
from PyQt4 import QtCore
from PyQt4.QtCore import *
from PyQt4 import QtGui
from PyQt4.QtGui import *
#======================================================================

def getColor( str ):
  return QPalette( QColor( int( str[0:2], 16 ), int( str[2:4], 16 ), int( str[4:6], 16 ) ) )

#======================================================================
class GameSquare( QLabel ):
  """
   state  value  highlight
  ------------------------
   PVoid      0      False
  *PNext      0       True
   PCurr     >0       True
   PUsed     >0      False
  """

  nextSelected = pyqtSignal( object )
  usedSelected = pyqtSignal( object )

  _color = {
    'void':	getColor( 'D0D0D0' ),
    'lo':	getColor( 'FCEAE6' ),
    'hi':	getColor( 'E62E00' ),
    'curr':	getColor( 'B82500' ),
    'next':	getColor( '8AB800' ),
    }
  @staticmethod
  def color( arg ):
    if type(arg) is int:
      if arg <= 0:
	return GameSquare._color['lo']
      elif arg >= 100:
	return GameSquare._color['hi']
      else:
	if not arg in GameSquare._color:
	  if not 'l' in GameSquare._color:
	    GameSquare._color['l'] = GameSquare._color['lo'].color( QPalette.Background )
	    GameSquare._color['h'] = GameSquare._color['hi'].color( QPalette.Background )
	  l = GameSquare._color['l']
	  h = GameSquare._color['h']
	  r = l.red()   + ( h.red()   - l.red()   ) * arg / 100
	  g = l.green() + ( h.green() - l.green() ) * arg / 100
	  b = l.blue()  + ( h.blue()  - l.blue()  ) * arg / 100
	  GameSquare._color[arg] = QPalette( QColor( r, g, b ) )

    return GameSquare._color[arg]

  def __init__( self, row, col ):
    QLabel.__init__( self )
    sze = 40
    self.setMinimumSize( sze, sze )
    self.setMaximumSize( sze, sze )
    self.setAutoFillBackground( True )
    self.setFrameStyle( QFrame.Box )
    self.setAlignment( Qt.AlignCenter )

    self.row		= row
    self.col		= col
    self.value		= 0
    self.highlight	= True

  @property
  def value( self ):
    return self._value

  @value.setter
  def value( self, num ):
    if num:
      self.setText( str(num) )
    else:
      self.setText( '' )
    self._value = num

  @property
  def highlight( self ):
    return self._highlight

  @highlight.setter
  def highlight( self, on ):
    if self.value:
      if on:
	self.setPalette( GameSquare.color('curr') )
      else:
	self.setPalette( GameSquare.color(self.value) )
    else:
      if on:
	self.setPalette( GameSquare.color('next') )
      else:
	self.setPalette( GameSquare.color('void') )
    self._highlight = on

  def mousePressEvent( self, event ):
    if event.button() == Qt.LeftButton:
      if not self.value and self.highlight:	# in PNext
	self.nextSelected.emit( self )
    elif event.button() == Qt.RightButton:
      if self.value and not self.highlight:	# in PUsed
	self.usedSelected.emit( self )

#======================================================================

class GameGrid( QWidget ):
  maxRow = 10
  maxCol = 10

  def __init__( self ):
    QWidget.__init__( self )

    self.setPalette( getColor( 'DCDCDC' ) )
    self.setAutoFillBackground( True )

    self.grid = QGridLayout()
    self.grid.setSpacing( 3 )

    for row in range( 0, self.maxRow ):
      for col in range( 0, self.maxCol ):
	gs = GameSquare( row, col )
	gs.nextSelected.connect( self.gsSelect )
	gs.usedSelected.connect( self.gsUndo )
	self.grid.addWidget( gs, row, col )

    l = QHBoxLayout()

    w = QPushButton( 'Undo' )
    w.clicked.connect( self.gsUndo )
    l.addWidget( w )

    w = QPushButton( 'Reset' )
    w.clicked.connect( self.gsReset )
    l.addWidget( w )

    self.grid.addLayout( l, self.maxRow, 0, 1, -1 )
    self.setLayout( self.grid );

    self.target  = self.maxRow * self.maxCol
    self.current = 0

  def widgetAt( self, row, col ):
    return self.grid.itemAtPosition( row, col ).widget()

  def lowlight( self, reset = None ):
    r = None
    for row in range( 0, self.maxRow ):
      for col in range( 0, self.maxCol ):
	gs = self.widgetAt( row, col )
	if reset is None:
	  gs.highlight = False
	else:
	  if gs.value > reset:
	    gs.value = 0
	  if reset:
	    gs.highlight = False
	    if gs.value == reset:
	      r = gs
	  else:
	    gs.highlight = True
    return r

  def highlight( self, w ):
    w.value = self.current
    if self.current < self.target:
      w.highlight = True
      row = w.row
      col = w.col
      self._highlightIf( row-3, col )
      self._highlightIf( row, col+3 )
      self._highlightIf( row+3, col )
      self._highlightIf( row, col-3 )
      self._highlightIf( row-2, col+2 )
      self._highlightIf( row+2, col+2 )
      self._highlightIf( row+2, col-2 )
      self._highlightIf( row-2, col-2 )
    else:
      w.highlight = False

  def _highlightIf( self, row, col ):
    if row < 0 or row >= self.maxRow:
      return
    if col < 0 or col >= self.maxCol:
      return
    w = self.widgetAt( row, col )
    if not w.value:
      w.highlight = True

  def gsSelect( self, gs ):
    print "!: %d %d" % ( gs.row, gs.col )
    self.lowlight()
    self.current += 1
    self.highlight( gs )

  def gsUndo( self, gs = None ):
    """ None => undo last """
    if gs:
      self.current = gs.value
    elif self.current > 1:
      self.current = self.current - 1
    elif self.current == 1:
      self.gsReset()
      return
    else:
      return

    gs = self.lowlight( self.current )
    self.highlight( gs )

  def gsReset( self ):
    self.current = 0
    self.lowlight( self.current )

#======================================================================

class MainWindow( QMainWindow ):

  def __init__( self, argv ):
    QMainWindow.__init__( self )

    self.setFocus()
    #self.message = self.statusBar()
    self.setCentralWidget( GameGrid() )

#======================================================================
def main():
  app = QApplication( sys.argv )

  main = MainWindow( sys.argv[1:] )
  main.setWindowFlags( Qt.Window | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint )
  main.setWindowTitle( '100' )
  main.setWindowIconText( '100' )
  #main.setGeometry( 100, 100, 400, 400 )

  main.show()
  app.lastWindowClosed.connect( app.quit )
  sys.exit( app.exec_() )

if __name__ == '__main__':
  main()
