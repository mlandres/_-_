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
    @disk = @name[/^[0-9]*-/]
    if ( @disk.nil? )
      @disk = 1
    else
      @disk = @disk[/^[0-9]*/].to_i
    end
    @track = @name[/^[-0-9]*/][/[0-9]*$/].to_i

    i = cmdstr( "audioinfo '#{escstr(file)}' | grep 'kbs,'" )[0]
    if ( not i.nil? )
      i = i.strip().to_s.split( ', ' )
      @bitrate   = i[0]
      @frequency = i[1]
      @chanels   = i[2]
      @duration  = i[3]
    end
  end

  attr_reader :file, :name, :disk, :track, :bitrate, :frequency, :chanels, :duration

  def valid()
    return @bitrate.nil?
  end
end

############################################################

class AudioTable < Qt::TableWidget

  def initialize( dir, parent = nil )
    super( parent )
    setColumnCount( 5 )
    horizontalHeader().setStretchLastSection( true )
    setEditTriggers( Qt::AbstractItemView::NoEditTriggers )
    setSelectionMode( Qt::AbstractItemView::SingleSelection )
    setSelectionBehavior( Qt::AbstractItemView::SelectRows )
    #connect( self, SIGNAL('cellDoubleClicked(int,int)'), self, SLOT('xchange(int,int)') )
    connect( self, SIGNAL('itemDoubleClicked(QTableWidgetItem*)'), self, SLOT('ychange(QTableWidgetItem*)') )
     @dir = dir
    loaddir( dir )
    emit testsig(11)
  end

  attr_reader :dir

  signals 'fileDoubleClicked(QTableWidgetItem)'
  signals 'testsig(int)'
    def wrzl( arg )
      puts arg
      emit fileDoubleClicked( arg )
      emit testsig(13)
    end

  private
    def loaddir( dir )
      if ( FileTest.directory?( dir ) )
	af = []
	Dir["#{dir}/*.[MmOoWw][PpGgMm][3GgAa]"].sort.each do |f|
	  loadfile( AudioFile.new( f ) )
	end
	setEnabled( true )
      else
	setEnabled( false )
      end
      resizeColumnsToContents()
    end

    def loadfile( af )
      tr = rowCount
      setRowCount( tr+1 )
      setItem( tr, 0, Qt::TableWidgetItem.new( af.bitrate ) )
      setItem( tr, 1, Qt::TableWidgetItem.new( af.frequency ) )
      setItem( tr, 2, Qt::TableWidgetItem.new( af.chanels ) )
      setItem( tr, 3, Qt::TableWidgetItem.new( af.duration ) )
      #setItem( tr, 4, Qt::TableWidgetItem.new( "[#{tr}](#{af.disk})(#{af.track})#{af.name()}" ) )
      setItem( tr, 4, af )
    end

    slots 'xchange(int,int)'
    def xchange( row, col )
      puts "(#{row},#{col})"
    end


    slots 'ychange(QTableWidgetItem*)'
    def ychange( ti )
      puts "ychange (#{ti})"
      emit wrzl( ti )
      emit fileDoubleClicked( ti )
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
    at = AudioTable.new( ldir )
    #connect( at, SIGNAL('cellDoubleClicked(int,int)'), self, SLOT('xchange(int,int)') )
    connect( at, SIGNAL('fileDoubleClicked(QTableWidgetItem)'), self, SLOT('ychange(QTableWidgetItem)') )
    connect( at, SIGNAL('testsig(int)'), self, SLOT('gtestsig(int)') )
     vl.addWidget( at )
    hl.addLayout( vl )

    vl = Qt::VBoxLayout.new
    vl.addWidget( Qt::Label.new( rdir ) )
    vl.addWidget( AudioTable.new( rdir ) )
    hl.addLayout( vl )

    @ldir = ldir
    @rdir = rdir
  end

  attr_reader :ldir, :rdir

  private
    slots 'xchange(int,int)'
    def xchange( row, col )
      puts "Diffsel (#{row},#{col})"
    end

    slots 'gtestsig(int)'
    def gtestsig(i)
      puts "GTETSIG #{i}"
    end

    slots 'ychange(QTableWidgetItem)'
    def ychange( ti )
      puts "Diffsel2 (#{ti})"
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
