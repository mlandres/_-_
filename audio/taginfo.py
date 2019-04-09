#! /usr/bin/python3

import argparse
import sys, os
import taglib

class Opt:
    tags = True
    all  = False
    fs   = 24 if all else 15
    deft = [
        'ALBUMARTIST',
        'ALBUM',
        'DISCNUMBER',
        'TRACKNUMBER',
        'ARTIST',
        'TITLE',
        'LENGTH',
        'ORIGINALYEAR',
        ]
    ret = 0

def ptag( tag, val ):
    print( '%-*s:' % ( Opt.fs, tag ), val )

def ptagif( tag, val ):
    ptag( tag, '' if val is None else val )


def taginfo( file ):
    song = taglib.File( file )  # might throw

    ptag( 'file',  file )
    ptag( 'audio', '%3d kbs, %d Hz, %d ch, %2d:%02d min.' % ( song.bitrate, song.sampleRate, song.channels, song.length/60 , song.length%60 ) )

    if not Opt.tags:
        return

    print( '---------------------------------------------------------' )
    if Opt.all:
        for t in song.tags:
            ptag( t, song.tags[t] )
    else:
        for t in Opt.deft:
            v = song.tags[t][0] if t in song.tags else None
            ptagif( t, v )


def pfile( file ):
    if not os.path.isfile( file ):
        return
    print( '=============================================================================' )
    try:
        taginfo( file )
    except Exception as e:
        print( '*** ',  file )
        print( e )
        Opt.ret = 1


def main():
    parser = argparse.ArgumentParser( description='Print audio properties and textual tags of one or more audio files.' )
    parser.add_argument( '-n', '--notags',  help='print no tags',  action='store_true' )
    parser.add_argument( '-a', '--alltags', help='print all tags', action='store_true' )
    parser.add_argument('file', nargs='+', help='file(s) to print tags of' )
    args = parser.parse_args()

    Opt.tags = not args.notags
    Opt.all  = args.alltags

    for arg in args.file:
        if os.path.isdir( arg ):
            dirc = os.listdir( arg )
            dirc.sort()
            for f in dirc:
                pfile( os.path.join( arg, f ) )
        else:
            pfile( arg )

    return Opt.ret


if __name__ == '__main__':
    exit( main() )
