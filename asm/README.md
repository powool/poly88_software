# Various assemblers and assembly programs

monitor\_4.0 is the Polymorphics ROM monitor.
I've verified it fairly carefully - it generates
the same output binary that my emulator is using.
This is not a perfect check, but it is pretty good.

ASM_G02.CAS is my beloved assembler/editor that I spent
years using.

NOTE: My initial commit is a clean commit take directly
from the Polymorhphics 88 G02 Assembler/Editor tape.

I patched machine location 3464H from F2 (JP) to
D2 (JNC) because the original conditional check
fails on larger RAM machines.

As patched, it will load large editor programs.


ASM_G02.ASM is a disassmbled version of ASM_G02.CAS.
It still has hundreds of errors and is included only
for reference or possibly aiding fixing future bugs.

ASM_4.4.CAS is my conversion of an older poly88
assembler. This one has a line number editor.

asm.sh - my lazy bash script to assemble files

LIFE.ASM, LIFE.CAS and LIFE.hex are from a copy of
the larger Polymorhphic version originally published
in the VTI manual. Transcribed by voidstart78.
