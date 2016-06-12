;; These symbols are put onto the SYSTEM package, which is a subpackage
;; of GLOBAL and has SYSTEM-INTERNALS and COMPILER as subpackages.
;; All of the symbols from SYSTEM-CONSTANT-LISTS and SYSTEM-VARIABLE-LISTS
;; are on it as well.
;; Also, any symbol in MICRO-CODE-SYMBOL-NAME-AREA that doesn't go on
;; GLOBAL gets put on SYSTEM.

;	** (c) Copyright 1980 Massachusetts Institute of Technology **

;; Be SURE to leave a SPACE before all symbols, because the Maclisp reader b.d.g.
 GET-MACRO-ARG-DESC-POINTER  ;These used by compiler.
 HEADER-TYPE-FEF 
 CONSTANTS-PAGE
 *LOGIOR
 *LOGXOR
 *LOGAND
 *BOOLE
 *MAX
 *MIN
 M-EQ
 RESET-TEMPORARY-AREA		;Used by COMPILER, SI, but shouldn't be GLOBAL really
 DECLARED-DEFINITION		;More COMPILER vs SI problems
 UNDO-DECLARATIONS-FLAG		;Used by MACRO to communicate with QC-FILE.
 FILE-LOCAL-DECLARATIONS	;Used by COMPILER and SI
 FDEFINE-FILE-PATHNAME
 TYPEP-ALIST			;Used by TYPEP and by its optimizers.
 ACTIVE-PROCESSES
 ALL-PROCESSES
 CLOCK-FUNCTION-LIST
 LISP-ERROR-HANDLER
 COMMAND-LEVEL			;for ABORT key
 *BREAK-BINDINGS*
 DEFUN-COMPATIBILITY		;If you expect DEFUN to work
 DECODE-KEYWORD-ARGLIST
 STORE-KEYWORD-ARG-VALUES
 READ-AREA
 FUNCTION-SPEC-HANDLER
 VALIDATE-FUNCTION-SPEC
 STANDARDIZE-FUNCTION-SPEC
 FDEFINITION-LOCATION		;not in GLOBAL, I guess you're supposed to use LOCF
 FUNCTION-PARENT
 *DEBUG-INFO-LOCAL-DECLARATION-TYPES*
 LAMBDA-MACRO-CALL-P
 LAMBDA-MACRO-EXPAND


;; Shared between LFL which is in COMPILER and stuff in SI
 GET-FILE-LOADED-ID
 SET-FILE-LOADED-ID
 
;; "Entries" to DISK
 GET-DISK-RQB
 RETURN-DISK-RQB
 FIND-DISK-PARTITION
 FIND-DISK-PARTITION-FOR-READ
 FIND-DISK-PARTITION-FOR-WRITE
 PARTITION-COMMENT
 UPDATE-PARTITION-COMMENT
 MEASURED-SIZE-OF-PARTITION
 GET-DISK-STRING
 PUT-DISK-STRING
 GET-DISK-FIXNUM
 PUT-DISK-FIXNUM
 DISK-READ
 DISK-WRITE
 DISK-READ-COMPARE
 POWER-UP-DISK
 CLEAR-DISK-FAULT
 RQB-8-BIT-BUFFER
 RQB-BUFFER
 RQB-NPAGES
 PAGE-IN-STRUCTURE
 PAGE-IN-WORDS
 PAGE-IN-REGION
 PAGE-IN-AREA
 PAGE-IN-ARRAY
 PAGE-OUT-STRUCTURE
 PAGE-OUT-WORDS
 PAGE-OUT-REGION
 PAGE-OUT-AREA
 PAGE-OUT-ARRAY

;Symbols defined by LISPM2;SGDEFS.  These should be in SYSTEM just like those
;symbols defined by QCOM.
 SG-NAME SG-REGULAR-PDL SG-REGULAR-PDL-LIMIT SG-SPECIAL-PDL SG-SPECIAL-PDL-LIMIT
 SG-INITIAL-FUNCTION-INDEX
 SG-UCODE SG-TRAP-TAG SG-RECOVERY-HISTORY SG-FOOTHOLD-DATA
 SG-STATE SG-CURRENT-STATE SG-FOOTHOLD-EXECUTING-FLAG SG-PROCESSING-ERROR-FLAG
 SG-PROCESSING-INTERRUPT-FLAG SG-SAFE SG-INST-DISP SG-IN-SWAPPED-STATE
 SG-SWAP-SV-ON-CALL-OUT SG-SWAP-SV-OF-SG-THAT-CALLS-ME
 SG-PREVIOUS-STACK-GROUP SG-CALLING-ARGS-POINTER SG-CALLING-ARGS-NUMBER
 SG-TRAP-AP-LEVEL SG-REGULAR-PDL-POINTER SG-SPECIAL-PDL-POINTER SG-AP SG-IPMARK
 SG-TRAP-MICRO-PC
;SG-ERROR-HANDLING-SG
;SG-INTERRUPT-HANDLING-SG
 SG-SAVED-QLARYH SG-SAVED-QLARYL SG-SAVED-M-FLAGS SG-FLAGS-QBBFL
 SG-FLAGS-CAR-SYM-MODE SG-FLAGS-CAR-NUM-MODE SG-FLAGS-CDR-SYM-MODE SG-FLAGS-CDR-NUM-MODE
 SG-FLAGS-DONT-SWAP-IN SG-FLAGS-TRAP-ENABLE SG-FLAGS-MAR-MODE SG-FLAGS-PGF-WRITE
 SG-FLAGS-METER-ENABLE SG-FLAGS-TRAP-ON-CALL
 SG-AC-K SG-AC-S SG-AC-J SG-AC-I SG-AC-Q SG-AC-R SG-AC-T SG-AC-E SG-AC-D
 SG-AC-C SG-AC-B SG-AC-A SG-AC-ZR SG-AC-2 SG-AC-1 SG-VMA-M1-M2-TAGS SG-SAVED-VMA SG-PDL-PHASE
 REGULAR-PDL-SG SPECIAL-PDL-SG
 RP-CALL-WORD RP-EXIT-WORD RP-ENTRY-WORD RP-FUNCTION-WORD
 RP-DOWNWARD-CLOSURE-PUSHED RP-ADI-PRESENT RP-DESTINATION RP-DELTA-TO-OPEN-BLOCK
 RP-DELTA-TO-ACTIVE-BLOCK RP-MICRO-STACK-SAVED RP-PC-STATUS RP-BINDING-BLOCK-PUSHED RP-EXIT-PC
 RP-NUMBER-ARGS-SUPPLIED RP-LOCAL-BLOCK-ORIGIN RP-TRAP-ON-EXIT
 FEF-INITIAL-PC FEF-NO-ADL-P FEF-FAST-ARGUMENT-OPTION-P FEF-SPECIALS-BOUND-P
 FEF-LENGTH FEF-FAST-ARGUMENT-OPTION-WORD FEF-BIT-MAP-P FEF-BIT-MAP
 FEF-NUMBER-OF-LOCALS FEF-ADL-ORIGIN FEF-ADL-LENGTH FEF-NAME
