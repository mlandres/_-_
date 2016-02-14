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
  def initialize( path, parent = nil )
    @path = path
    @filename = File.basename( path )

    @ext  = @filename[-3,3]
    @tag  = @filename[/^([0-9]+-)?[0-9]+/]
    if ( @tag.nil? )
      @name = @filename[0...-4]
    else
      @name = @filename[@tag.length()...-4]
    end

    super( parent, @name )

    if ( @tag.nil? )
      @disk = @track = -1
    else
      @disk = @tag[/^[0-9]+-/]
      if ( @disk.nil? )
	@disk = 0
      else
	@disk = @disk[/^[0-9]+/].to_i
      end
      @track = @tag[/[0-9]+$/].to_i
    end

    puts "audioinfo '#{path}'"
    tag = cmdstr( "audioinfo '#{escstr(path)}' | grep 'kbs,'" )[0]

    if ( not tag.nil? )
      tag = tag.strip().to_s.split( ', ' )
      @bitrate   = tag[0]
      @frequency = tag[1]
      @chanels   = tag[2]
      @duration  = tag[3]
    end
  end

  attr_reader :path, :filename, :tag, :name, :ext, :disk, :track, :bitrate, :frequency, :chanels, :duration

  def valid()
    return @bitrate.nil?
  end

  def to_s()
    return @filename
  end

  def <=> ( rhs )
    return self.disk <=> rhs.disk	unless ( self.disk == rhs.disk )
    return self.track <=> rhs.track	unless ( self.track == rhs.track )
    self.filename <=> rhs.filename
  end

end


############################################################

class DiskGap < Qt::TableWidgetItem

  def initialize( disk, parent = nil )
    super( parent, "(#{disk})========================" )
    @disk = disk
    @track = -1
  end

  attr_reader :disk, :track

  def valid()
    return False
  end

  def to_s()
    return "DiskGap #{@disk}"
  end

end

############################################################

class AudioTable < Qt::TableWidget
  attr_reader :path, :filename, :tag, :name, :ext, :disk, :track, :bitrate, :frequency, :chanels, :duration

  Ibit = 0
  Ifre = 1
  Icha = 2
  Idur = 3
  Itag = 4
  Inam = 5
  Iext = 6
  Imax = 7

  def initialize( dir, parent = nil )
    super( parent )
    setColumnCount( Imax )
    horizontalHeader().setResizeMode( Inam, Qt::HeaderView::Stretch )
    setEditTriggers( Qt::AbstractItemView::NoEditTriggers )
    setSelectionMode( Qt::AbstractItemView::SingleSelection )
    setSelectionBehavior( Qt::AbstractItemView::SelectRows )
    #connect( self, SIGNAL('cellDoubleClicked(int,int)'), self, SLOT('rowSel(int,int)') )
    @dir = dir
    #loaddir( dir )
  end

  attr_reader :dir

  def audioFileAt( row )
    return item( row, Inam )
  end

  def lateinit()
    loaddir( @dir )
  end

  private
    def loaddir( dir )
      if ( not dir.nil? and FileTest.directory?( dir ) )
	af = []
	Dir["#{dir}/*.[MmOoWw][PpGgMm][3GgAa]"].each do |f|
	  af.push( AudioFile.new( f ) )
	end
	puts "ALL FILES"
	d = t = nil
	af.sort!.each do |f|
	  if ( not d.nil? and d != f.disk )
	    diskgap( f.disk )
	  elsif ( not t.nil? and t+1 < f.track )
	    trackgap
	  end
	  d = f.disk
	  t = f.track
	  loadfile( f )
	end
	puts "ALL FILES2"
	setEnabled( true )
      else
	setEnabled( false )
      end
      resizeColumnsToContents()
    end

    def loadfile( af, gap = 0 )
      setFilerow( af, rowCount + gap )
    end

    def diskgap( diskno )
      row = rowCount
      setRowCount( row+1 )
      setItem( row, Ibit, Qt::TableWidgetItem.new( "=======" ) )
      setItem( row, Ifre, Qt::TableWidgetItem.new( "========" ) )
      setItem( row, Icha, Qt::TableWidgetItem.new( "====" ) )
      setItem( row, Idur, Qt::TableWidgetItem.new( "==========" ) )
      setItem( row, Itag, Qt::TableWidgetItem.new( "====" ) )
      setItem( row, Inam, Qt::TableWidgetItem.new( DiskGap.new( diskno ) ) )
      setItem( row, Iext, Qt::TableWidgetItem.new( "===" ) )
    end

    def trackgap()
      row = rowCount
      setRowCount( row+1 )
    end

    def setFilerow( af, row )
      setRowCount( row+1 ) unless ( rowCount > row )
      setItem( row, Ibit, Qt::TableWidgetItem.new( af.bitrate ) )
      setItem( row, Ifre, Qt::TableWidgetItem.new( af.frequency ) )
      setItem( row, Icha, Qt::TableWidgetItem.new( af.chanels ) )
      setItem( row, Idur, Qt::TableWidgetItem.new( af.duration ) )
      setItem( row, Itag, Qt::TableWidgetItem.new( af.tag ) )
      setItem( row, Inam, af )
      setItem( row, Iext, Qt::TableWidgetItem.new( af.ext ) )
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

    connect( @ltab.verticalScrollBar(), SIGNAL('valueChanged(int)'), @rtab.verticalScrollBar(), SLOT('setValue(int)') )
    connect( @rtab.verticalScrollBar(), SIGNAL('valueChanged(int)'), @ltab.verticalScrollBar(), SLOT('setValue(int)') )

    @ldir = ldir
    @rdir = rdir

    @ltab.lateinit()
    @rtab.lateinit()

    diffdir
  end

  attr_reader :ldir, :rdir

  private

    def compItem( col, row, ltab, rtab, locolor, hicolor = locolor )
      il = ltab.item( row, col )
      ir = rtab.item( row, col )
      tl = il.text()
      tr = ir.text()
      if ( tl != tr )
	c = tl.length() <=> tr.length()
	c = tl <=> tr if ( c == 0 )
	if ( c < 0 )
	  il.setTextColor( locolor )
	  ir.setTextColor( hicolor )
	else
	  il.setTextColor( hicolor )
	  ir.setTextColor( locolor )
	end
      end
    end

    def diffRow( row, ltab, rtab = nil )
      if ( rtab )
	c = compItem( 0, row, ltab, rtab, $red, $gre )
	c = compItem( 1, row, ltab, rtab, $blu )
	c = compItem( 2, row, ltab, rtab, $blu )
	c = compItem( 3, row, ltab, rtab, $blu )
	c = compItem( 4, row, ltab, rtab, $blu )
	c = compItem( 5, row, ltab, rtab, $blu )
      else
	ltab.item( row, 0 ).setTextColor( $gre )
      end
    end

    def diffdir()
      lcnt = @ltab.rowCount
      rcnt = @rtab.rowCount
      c = 0
      while ( c < lcnt or c < rcnt )
	cincr = 1
	if ( c < lcnt and c < rcnt )
	  lf = @ltab.audioFileAt( c )
	  rf = @rtab.audioFileAt( c )
	  if ( lf and rf )

	    #puts "#{lf} <> #{rf}"
	    #diffRow( c, @ltab, @rtab )


	  elsif ( lf )
	    #puts "#{lf} <> -----"
	    @rtab.removeRow( c )
	    rcnt -= 1
	    cincr = 0
	  else
	    #puts "----- <> #{rf}"
	    @ltab.removeRow( c )
	    lcnt -= 1
	    cincr = 0
	  end

	elsif ( c == lcnt )
	  #puts "EOT <> #{rf}"
	  lcnt += 1
	  @ltab.setRowCount( lcnt )
	  diffRow( c, @rtab )

	elsif ( c == rcnt )
	  #puts "#{lf} <> EOT"
	  rcnt += 1
	  @rtab.setRowCount( rcnt )
	  diffRow( c, @ltab )
	end
	c += cincr
       end
    end

    def diffdir2()
      lcnt = @ltab.rowCount
      rcnt = @rtab.rowCount
      c = 0
      while ( c < lcnt or c < rcnt )
	cincr = 1
	if ( c < lcnt and c < rcnt )
	  lf = @ltab.audioFileAt( c )
	  rf = @rtab.audioFileAt( c )
	  if ( lf and rf )

	    #puts "#{lf} <> #{rf}"
	    if lf.disk < rf.disk or ( lf.disk == rf.disk and lf.track < rf.track )
	      @rtab.insertRow( c )
	      rcnt += 1
	      diffRow( c, @ltab )

	    elsif lf.disk > rf.disk or ( lf.disk == rf.disk and lf.track > rf.track )
	      @ltab.insertRow( c )
	      lcnt += 1
	      diffRow( c, @rtab )

	    else
	      diffRow( c, @ltab, @rtab )
	    end

	  elsif ( lf )
	    #puts "#{lf} <> -----"
	    @rtab.removeRow( c )
	    rcnt -= 1
	    cincr = 0
	  else
	    #puts "----- <> #{rf}"
	    @ltab.removeRow( c )
	    lcnt -= 1
	    cincr = 0
	  end

	elsif ( c == lcnt )
	  #puts "EOT <> #{rf}"
	  lcnt += 1
	  @ltab.setRowCount( lcnt )
	  diffRow( c, @rtab )

	elsif ( c == rcnt )
	  #puts "#{lf} <> EOT"
	  rcnt += 1
	  @rtab.setRowCount( rcnt )
	  diffRow( c, @ltab )
	end
	c += cincr
      end
    end

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
