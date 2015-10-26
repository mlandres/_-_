#======================================================================
import cout
import select
import subprocess
#======================================================================

def _readByLine( stream ):
  while True:
    line = stream.readline()
    if line: yield line
    else: break

#======================================================================

def run( *args ):
  p = subprocess.Popen( args, stdout=subprocess.PIPE, stderr=subprocess.PIPE )
  reads = [p.stdout.fileno(), p.stderr.fileno()]

  while reads:
    if p.poll() is None:
      ret = select.select( reads, [], [] )
    else:
      ret = [ reads ]
      reads = None

    for fd in ret[0]:
      if fd == p.stdout.fileno():
	for line in _readByLine( p.stdout ):
	  yield line[:-1]	# wo. NL
      if fd == p.stderr.fileno():
	for line in _readByLine( p.stderr ):
	  cout.eRED( '*** ', line )

#======================================================================
