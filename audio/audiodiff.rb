#! /usr/bin/ruby
require 'Qt4'
############################################################

def cmdstr( cmd )
  io = IO.popen( cmd )
  r = io.readlines.reverse!
  io.close
  return r
end

def cmdout( cmd )
  IO.popen( cmd ) { |io|
    io.readlines.reverse.each { |f|
      r = f
      yield( f )
    }
  }
end

def escstr( f )
  f.gsub( "'", "'?'" )
end

############################################################

class MAction < Qt::Object
  def initialize( ldir, rdir, parent = nil )
    super( parent )
    @ldir = ldir
    if ( ! FileTest.exists?( @ldir ) )
      exit 1
    end
    @rdir = rdir
    if ( ! FileTest.exists?( @rdir ) )
      exit 1
    end
  end

  attr_reader :ldir, :rdir

  slots 'merge()'
  def merge()
    system( 'picard', "#{@ldir}",  "#{@rdir}" )
    $qApp.quit()
  end

  slots 'xchange(int,int)'
  def xchange( row, col )
    puts "(#{row},#{col})"
    $ll.selectRow( row )
    $lr.selectRow( row )
  end
end

############################################################

class AudioFile < Qt::TableWidgetItem

  def initialize( file, parent = nil )
    @file = file
    @name = File.basename( file )
    super( parent, @name )

    tag = @name[/^([0-9]+-)?[0-9]+/]
    if ( tag.nil? )
      @disk = @track = 0
    else
      @disk = tag[/^[0-9]+-/]
      if ( @disk.nil? )
	@disk = 1
      else
	@disk = @disk[/^[0-9]+/].to_i
      end
      @track = tag[/[0-9]+$/].to_i
    end

    tag = cmdstr( "audioinfo '#{escstr(file)}' | grep 'kbs,'" )[0]
    if ( not tag.nil? )
      tag = tag.strip().to_s.split( ', ' )
      @bitrate   = tag[0]
      @frequency = tag[1]
      @chanels   = tag[2]
      @duration  = tag[3]
    end
  end

  attr_reader :file, :name, :disk, :track, :bitrate, :frequency, :chanels, :duration

  def valid()
    return @bitrate.nil?
  end

  def to_s()
    return @name
  end

  def <=> ( rhs )
    return self.disk <=> rhs.disk	unless ( self.disk == rhs.disk )
    return self.track <=> rhs.track	unless ( self.track == rhs.track )
    self.name <=> rhs.name
  end

end

############################################################

class AudioTable < Qt::TableWidget

  def initialize( dir, parent = nil )
    super( parent )
    @maxCol = 6
    setColumnCount( @maxCol+1 )
    horizontalHeader().setStretchLastSection( true )
    setEditTriggers( Qt::AbstractItemView::NoEditTriggers )
    setSelectionMode( Qt::AbstractItemView::SingleSelection )
    setSelectionBehavior( Qt::AbstractItemView::SelectRows )
    connect( self, SIGNAL('cellDoubleClicked(int,int)'), self, SLOT('rowSel(int,int)') )
     @dir = dir
    loaddir( dir )
  end

  attr_reader :dir

  def audioFileAt( row )
    return item( row, @maxCol )
  end

  private
    def loaddir( dir )
      if ( FileTest.directory?( dir ) )
	af = []
	Dir["#{dir}/*.[MmOoWw][PpGgMm][3GgAa]"].each do |f|
	  af.push( AudioFile.new( f ) )
	end
	d = t = nil
	af.sort!.each do |f|
	  if ( not d.nil? and d != f.disk )
	    diskgap
	  elsif ( not t.nil? and t+1 < f.track )
	    trackgap
	  end
	  d = f.disk
	  t = f.track
	  loadfile( f )
	end
	setEnabled( true )
      else
	setEnabled( false )
      end
      resizeColumnsToContents()
    end

    def loadfile( af, gap = 0 )
      loadfilerow( af, rowCount + gap )
    end

    def diskgap()
      row = rowCount
      setRowCount( row+1 )
      setItem( row, 0, Qt::TableWidgetItem.new( "----" ) )
      setItem( row, 1, Qt::TableWidgetItem.new( "----" ) )
      setItem( row, 2, Qt::TableWidgetItem.new( "----" ) )
      setItem( row, 3, Qt::TableWidgetItem.new( "----" ) )
      setItem( row, 4, Qt::TableWidgetItem.new( "----" ) )
      setItem( row, 5, Qt::TableWidgetItem.new( "----" ) )
    end

    def trackgap()
      row = rowCount
      setRowCount( row+1 )
    end

    def loadfilerow( af, row )
      setRowCount( row+1 ) unless ( rowCount > row )
      setItem( row, 0, Qt::TableWidgetItem.new( af.bitrate ) )
      setItem( row, 1, Qt::TableWidgetItem.new( af.frequency ) )
      setItem( row, 2, Qt::TableWidgetItem.new( af.chanels ) )
      setItem( row, 3, Qt::TableWidgetItem.new( af.duration ) )
      setItem( row, 4, Qt::TableWidgetItem.new( af.disk.to_s ) )
      setItem( row, 5, Qt::TableWidgetItem.new( af.track.to_s ) )
      setItem( row, @maxCol, af )
    end

    slots 'rowSel(int,int)'
    def rowSel( row, col )
      puts "rowSel (#{row},#{col}) #{audioFileAt( row )} "
    end
end

############################################################

class AudioDiff < Qt::Widget

  def initialize( ldir, rdir, parent = nil )
    super( parent )

    hl = Qt::HBoxLayout.new
    setLayout( hl )

    vl = Qt::VBoxLayout.new
    vl.addWidget( Qt::Label.new( ldir ) )
    @ltab = at = AudioTable.new( ldir )
    connect( at, SIGNAL('cellDoubleClicked(int,int)'), self, SLOT('lRowSel(int,int)') )
    vl.addWidget( at )
    hl.addLayout( vl )

    vl = Qt::VBoxLayout.new
    vl.addWidget( Qt::Label.new( rdir ) )
    @rtab = at = AudioTable.new( rdir )
    connect( at, SIGNAL('cellDoubleClicked(int,int)'), self, SLOT('rRowSel(int,int)') )
    vl.addWidget( at )
    hl.addLayout( vl )

    @ldir = ldir
    @rdir = rdir
  end

  attr_reader :ldir, :rdir

  private
    slots 'lRowSel(int,int)'
    def lRowSel( row, col )
      puts "lRowSel (#{row},#{col}) #{@ltab.audioFileAt( row )} "
    end
    slots 'rRowSel(int,int)'
    def rRowSel( row, col )
      puts "rRowSel (#{row},#{col}) #{@rtab.audioFileAt( row )} "
    end
end

############################################################
$red = Qt::Color.new( 200, 0, 0 )
$gre = Qt::Color.new( 0, 200, 0 )
$blu = Qt::Color.new( 0, 0, 200 )

$a = Qt::Application.new(ARGV)
$main = Qt::Dialog.new
$main.setWindowTitle( "audiodiff.rb" );
$main.setWindowIconText( "audiodiff.rb" );
$main.setGeometry( 60, 60, 1200, 700 );
$f = Qt::VBoxLayout.new
$main.setLayout( $f );
# --------------------------------------


# $fh = Qt::HBoxLayout.new
# $f.addLayout( $fh )
#
# $fl = Qt::VBoxLayout.new
# $fr = Qt::VBoxLayout.new
# $fh.addLayout( $fl )
# $fh.addLayout( $fr )

ARGV[1] = ARGV[0] if ( not ARGV[1] )
#$ma = MAction.new( ARGV[0], ARGV[1] )

$audiodiff = AudioDiff.new( ARGV[0], ARGV[1] )
$f.addWidget( $audiodiff )

# $ll = Mp3Table.new( $ma.ldir )
# Qt::Object.connect( $ll, SIGNAL('cellDoubleClicked(int,int)'), $ma, SLOT('xchange(int,int)') )
# $fl.addWidget( Qt::Label.new( ARGV[0] ) )
# $fl.addWidget( $ll )

# $lr = Mp3Table.new( $ma.rdir )
# Qt::Object.connect( $lr, SIGNAL('cellDoubleClicked(int,int)'), $ma, SLOT('xchange(int,int)') )
# $fr.addWidget( Qt::Label.new( ARGV[1] ) )
# $fr.addWidget( $lr )

#ainfo( $ll, $ma.ldir )
#ainfo( $lr, $ma.rdir )

# maxr = [$ll.rowCount, $lr.rowCount].max
# $ll.setRowCount( maxr )
# $lr.setRowCount( maxr )

# --------------------------------------
# minrow = $ll.rowCount() < $lr.rowCount() ? $ll.rowCount() : $lr.rowCount()
# (0...0).each do |r|
#   col = 0
#   next if ( $ll.item( r, col ).nil? && $lr.item( r, col ).nil? )
#   if ( $ll.item( r, col ).nil? || $lr.item( r, col ).nil? )
#       side =  $ll.item( r, col ).nil? ? $lr : $ll
#       side.item( r, 0 ).setTextColor( $gre )
#       side.item( r, 3 ).setTextColor( $blu )
#       side.item( r, 4 ).setTextColor( $blu )
#       next
#   end
#   if ( $ll.item( r, col ).text() != $lr.item( r, col ).text() )
#     if ( $ll.item( r, col ).text() < $lr.item( r, col ).text() )
#       $ll.item( r, col ).setTextColor( $red )
#       $lr.item( r, col ).setTextColor( $gre )
#     else
#       $ll.item( r, col ).setTextColor( $gre )
#       $lr.item( r, col ).setTextColor( $red )
#     end
#   end
#   col = 3
#   if ( $ll.item( r, col ).text() != $lr.item( r, col ).text() )
#     $ll.item( r, col ).setTextColor( $blu )
#     $lr.item( r, col ).setTextColor( $blu )
#   end
#   col = 4
#   if ( $ll.item( r, col ).text()[/ .*\./] != $lr.item( r, col ).text()[/ .*\./] )
#     $ll.item( r, col ).setTextColor( $blu )
#     $lr.item( r, col ).setTextColor( $blu )
#   end
# end
# --------------------------------------
$q = Qt::PushButton.new( "Picard" )
Qt::Object.connect( $q, SIGNAL('clicked()'), $ma, SLOT('merge()') )
$f.addWidget( $q )


# --------------------------------------
$main.show
$a.exec
exit
