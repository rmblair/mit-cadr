#!/bin/sh

#PREFIX=/work6/oldtapes/mit/extract/cadr
PREFIX=cad-orig
OUTPUT=netlist-new.txt

(
echo "#"
echo "# generated by script, using soap"
echo "# `date`"
echo "#"
echo
) >$OUTPUT

(
    while read f; do
	file=$PREFIX/$f.drw;
	echo $file;
	./soap -n $file >>$OUTPUT;
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
clock1
clock2
debug
icaps
ictl
iwrpar
mbcpin
mcpins
olord1
olord2
opcs
pctl
prom0
prom1
iram00
iram01
iram02
iram03
iram10
iram11
iram12
iram13
iram20
iram21
iram22
iram23
iram30
iram31
iram32
iram33
spy0
spy4
stat
EOF