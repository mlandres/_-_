#======================================================================
import cout
import cmd
import re
#======================================================================

class Osc():

  def ls( self, rx = None ):
    for line in self._cmd( 'ls' ):
      if rx and not re.match( rx, line ): continue
      yield Prj( self, line )

  @classmethod
  def _cmd( cls, *args ):
    for line in cmd.run( cls._cmdstr(), *args ):
      yield line

  @classmethod
  def _cmdstr( cls ):
    return 'unknown'

  @classmethod
  def __str__( cls ):
    return cls._cmdstr()

#======================================================================

class Obs( Osc ):

  @classmethod
  def _cmdstr( cls ):
    return 'osc'

  @classmethod
  def __str__( cls ):
    return 'obs:/'

#======================================================================

class Ibs( Osc ):

  @classmethod
  def _cmdstr( cls ):
    return 'isc'

  @classmethod
  def __str__( cls ):
    return 'ibs:/'

#======================================================================

class Prj():

  def __init__( self, osc, name ):
    self.osc = osc
    self.name = name

  def ls( self, rx = None ):
    for line in self.osc._cmd( 'ls', self.name ):
      if rx and not re.match( rx, line ): continue
      yield Pkg( self, line )

  def __str__( self ):
    return self.name

#======================================================================

class Pkg():

  def __init__( self, prj, name  ):
    self.prj = prj
    self.name = name
    self.__content = None
    self.__version = None
    self.__version = None

  def ls( self, rx = None ):
    for line in self._content():
      if rx and not re.match( rx, line ): continue
      yield line

  def version( self ):
    if self.__version is None:
      for line in self._content():
	if ( line[0] == '#'):
	  self.__version = line
	  break
	m = re.search( "-([^-]*)\\.tar", line )
	if ( m ):
	  self.__version = m.group( 1 )
	  break

    return self.__version

  def _content( self ):
    if self.__content is None:
      self.__content = list()
      for line in self.prj.osc._cmd( 'ls', self.prj.name, self.name ):
	if ( line[0] == '#'): self.__content = list()	# reset on # -> zypp:SLE-11-SP3-Branch libzypp (latest)
	self.__content.append( line )

    return self.__content

  def __str__( self ):
    return self.name


#======================================================================
