#======================================================================
import sys
#======================================================================

def _cwrite( stream, color, *args ):
  stream.write( color )
  for arg in args: stream.write( arg )
  stream.write( DEF )

#======================================================================

DEF	= "\033[0m"
RED	= "\033[31m"
BLU	= "\033[34m"
GRE	= "\033[32m"
CYA	= "\033[36m"
MAG	= "\033[35m"
WHI	= "\033[37m"
BLA	= "\033[30m"

def wOUT( color, *args ): _cwrite( sys.stdout, color, *args )
def eOUT( color, *args ): _cwrite( sys.stderr, color, *args )

def wDEF( *args ): wOUT( DEF, *args )
def wRED( *args ): wOUT( RED, *args )
def wBLU( *args ): wOUT( BLU, *args )
def wGRE( *args ): wOUT( GRE, *args )
def wCYA( *args ): wOUT( CYA, *args )
def wMAG( *args ): wOUT( MAG, *args )
def wWHI( *args ): wOUT( WHI, *args )
def wBLA( *args ): wOUT( BLA, *args )

def eDEF( *args ): eOUT( DEF, *args )
def eRED( *args ): eOUT( RED, *args )
def eBLU( *args ): eOUT( BLU, *args )
def eGRE( *args ): eOUT( GRE, *args )
def eCYA( *args ): eOUT( CYA, *args )
def eMAG( *args ): eOUT( MAG, *args )
def eWHI( *args ): eOUT( WHI, *args )
def eBLA( *args ): eOUT( BLA, *args )

#======================================================================
