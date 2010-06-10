#! /usr/bin/env python
import os, sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'web'))
import png
file_name = sys.argv[1]
sw, sh, spix, smeta = png.Reader(file=open(file_name, 'rb')).asRGBA8()
print '%dx%d' % (sw, sh)