#!/bin/sh

PREFIX=/work6/oldtapes/mit/extract/cadr

(
echo "#"
echo "# generated by script"
echo "#"
echo
) >netlist.txt

(
    while read f; do
	file=$PREFIX/$f.drw;
	echo $file;
	./soap -n $file >>netlist.txt;
done
) <<EOF
actl
alatch
alu0
alu1
aluc4
amem0
amem1
apar
bcpins
bcterm
caps
clockd
contrl
cpins
dram0
dram1
dram2
dspctl
flag
ior
ipar
ireg
iwr
l
lc
lcc
lpc
mctl
md
mds
mf
mlatch
mmem
mo0
mo1
mskg4
npc
opcd
pdl0
pdl1
pdlctl
pdlptr
platch
q
qctl
shift0
shift1
smctl
source
spc
spclch
spcpar
spcw
spy1
spy2
trap
vctl1
vctl2
vma
vmas
vmem0
vmem1
vmem2
vmemdr
EOF
