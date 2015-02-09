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
    w = QPushButton( 'Auto' )
    w.clicked.connect( self.gsAuto )
    l.addWidget( w )
    w = QPushButton( 'Reset' )
    w.clicked.connect( self.gsReset )
    l.addWidget( w )

    self.grid.addLayout( l, self.maxRow, 0, 1, -1 )
    self.setLayout( self.grid );

    self.target  = self.maxRow * self.maxCol
    self.current = 0

    self.lockrow = None
    self.lockcol = None

    self.autosolving = False

  def widgetAt( self, row, col ):
    return self.grid.itemAtPosition( row, col ).widget()

  def widgetNum( self, num ):
    if 0 < num and num <= self.current:
      for row in range( 0, self.maxRow ):
	for col in range( 0, self.maxCol ):
	  gs = self.widgetAt( row, col )
	  if gs.value == num:
	    return gs
    return None

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
    # -> number of next highlights
    ret = 0
    w.value = self.current
    if self.current < self.target:
      w.highlight = True
      row = w.row
      col = w.col
      if self._highlightIf( row-3, col ):	ret += 1
      if self._highlightIf( row-2, col+2 ):	ret += 1
      if self._highlightIf( row, col+3 ):	ret += 1
      if self._highlightIf( row+2, col+2 ):	ret += 1
      if self._highlightIf( row+3, col ):	ret += 1
      if self._highlightIf( row+2, col-2 ):	ret += 1
      if self._highlightIf( row, col-3 ):	ret += 1
      if self._highlightIf( row-2, col-2 ):	ret += 1
    else:
      w.highlight = False
      self.solved()
    return ret

  def _highlightIf( self, row, col ):
    # -> True if highlighted
    if row < 0 or row >= self.maxRow:
      return False
    if col < 0 or col >= self.maxCol:
      return False
    w = self.widgetAt( row, col )
    if self.lockrow is None:
      if w.value:
	return False
      w.highlight = True
      return True
    elif self.lockrow == row and self.lockcol == col:
      self.lockrow = None
      self.lockcol = None
    return False

  def gsSelect( self, gs ):
    # -> number of next highlights
    self.lowlight()
    self.current += 1
    ret = self.highlight( gs )
    #print "s %3d -> %d" % ( self.current, ret )
    return ret

  def gsUndo( self, gs = None ):
    """ None => undo last; Return number of fwds  """
    if gs:
      self.current = gs.value
    elif self.current > 1:
      self.current = self.current - 1
    elif self.current == 1:
      self.gsReset()
      return self.target
    else:
      return self.target
    gs = self.lowlight( self.current )
    ret = self.highlight( gs )
    #print "u %3d -> %d" % ( self.current, ret )
    return ret

  def gsReset( self ):
    self.current = 0
    self.lowlight( self.current )
    self.lockrow = None
    self.lockcol = None

  def gsAuto( self, looped = False ):
    if self.autosolving:
      self.autosolving = False
    elif self.current == 0:
      pass
    elif self.current == self.target:
      self._autoBwd()
    else:
      self.autosolving = True
      steps = 0
      while self.autosolving and self.current != 0 and self.current != self.target:
	if self._autoFwd():
	  while self.current != 0 and self._autoFwd():
	    app.processEvents();
	    pass
	else:
	  while self.current != 0 and not self._autoBwd():
	    app.processEvents();
	    pass
	#break
	steps += 1
	if not steps % 100:
	  print "%d ===>" % steps
	  app.processEvents();
      self.autosolving = False

  def _autoFwd( self ):
    # Return True if we moved forward
    w = self.widgetNum( self.current )
    if w is None:
      return False
    row = w.row
    col = w.col
    if self._auto( row-3, col ):	return True
    if self._auto( row-2, col+2 ):	return True
    if self._auto( row, col+3 ):	return True
    if self._auto( row+2, col+2 ):	return True
    if self._auto( row+3, col ):	return True
    if self._auto( row+2, col-2 ):	return True
    if self._auto( row, col-3 ):	return True
    if self._auto( row-2, col-2 ):	return True
    return False

  def _autoBwd( self ):
    # Return True if we can move forward again
    w = self.widgetNum( self.current )
    if w is None:
      return 0
    self.lockrow = w.row
    self.lockcol = w.col
    return self.gsUndo()

  def _auto( self, row, col ):
    # Return True if we moved forward
    if row < 0 or row >= self.maxRow:
      return False
    if col < 0 or col >= self.maxCol:
      return False
    if self.lockrow is None:
      w = self.widgetAt( row, col )
      if not w.value and w.highlight:
	self.gsSelect( self.widgetAt( row, col ) )
	return True
    elif self.lockrow == row and self.lockcol == col:
      self.lockrow = None
      self.lockcol = None
    return False

  def solved( self ):
    path = '%s/.config/100' % os.environ['HOME']
    f = open( path, 'a' )
    f.write( '%d:' % time.time() )
    for row in range( 0, self.maxRow ):
      f.write( ' {' )
      for col in range( 0, self.maxCol ):
	f.write( ' %d' % self.widgetAt( row, col ).value )
      f.write( ' }' )
    f.write( '\n' )
    f.close()

#======================================================================

class MainWindow( QMainWindow ):

  def __init__( self, argv ):
    QMainWindow.__init__( self )

    self.setFocus()
    #self.message = self.statusBar()
    self.setCentralWidget( GameGrid() )

#======================================================================
app = None

def main():
  global app
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
