#! /usr/bin/python3

import sys, os
import taglib

class Opt:
    all = False
    fs  = 24 if all else 13
    deft = [
        'TITLE',
        'ARTIST',
        'LENGTH',
        'ALBUM',
        'ALBUMARTIST',
        'DISCNUMBER',
        'TRACKNUMBER',
        'DATE',
        'ORIGINALYEAR',
        'GENRE'
        ]

def ptag( tag, val ):
    print( "%-*s:" % ( Opt.fs, tag ), val )

def ptagif( tag, val ):
    ptag( tag, '' if val is None else val )


def taginfo( file ):
    song = taglib.File( file )  # might throw
    ptag( "FILE",  file )

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
    print( "=========================================================" )
    try:
        taginfo( file )
    except Exception as e:
        print( "*** ",  file )
        print( e )


def main():
    for arg in sys.argv[1:]:
        if os.path.isdir( arg ):
            dirc = os.listdir( arg )
            dirc.sort()
            for f in dirc:
                pfile( os.path.join( arg, f ) )
        else:
            pfile( arg )

    return 0


if __name__ == '__main__':
    main()
