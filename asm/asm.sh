#!/bin/bash
#
# http://john.ccac.rwth-aachen.de:8000/as/
#
# untar, then:
# cd asl-current
# cp Makefile.def-samples/Makefile.def-unknown-linux Makefile.def
# make
# copy binaries somewhere in your $PATH

asl -l -cpu 8080 $1
p2hex -F Intel $(basename -s .ASM $1).p

