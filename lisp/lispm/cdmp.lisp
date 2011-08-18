;; -*- Mode: LISP; Package: MICRO-ASSEMBLER -*-
;	** (c) Copyright 1980 Massachusetts Institute of Technology **
(DECLARE (COND ((STATUS FEATURE LISPM))   ;DO NOTHING ON LISP MACHINE.
	       ((NULL (MEMQ 'NEWIO (STATUS FEATURES)))
		(BREAK 'YOU-HAVE-TO-COMPILE-THIS-WITH-QCOMPL T))
	       ((NULL (GET 'IF-FOR-MACLISP 'MACRO))
		(LOAD '(MACROS > DSK LISPM))
		(LOAD '(DEFMAC FASL DSK LISPM2))
		(LOAD '(LMMAC > DSK LISPM2))
		(MACROS T))))	;SEND OVER THE REST OF THE MACROS IN THIS FILE

(DECLARE (SPECIAL SPECIAL-OUT-FILE))

(DECLARE (SPECIAL RACMO RADMO RAAMO 
	   AREA-LIST RM-AREA-SIZES PAGE-SIZE CONSLP-INPUT CONSLP-OUTPUT)
	 (FIXNUM (LOGLDB FIXNUM NOTYPE)))

(IF-FOR-MACLISP
 (DEFMACRO LDB (PTR VAL) `(LOGLDB ,PTR ,VAL)))
(IF-FOR-MACLISP
 (DEFMACRO DPB (NEWVAL PTR VAL) `(LOGDPB ,NEWVAL ,PTR ,VAL)))

(DEFUN DUMP-MEM-ARRAY (ARRAYP RA-ORG OUT-FILE)
  (PROG (IDX LIM TEM)
	(SETQ IDX 0)
	(SETQ LIM (CADR (ARRAYDIMS ARRAYP)))
  L	(COND ((NOT (< IDX LIM))
		(RETURN T))
	      ((SETQ TEM (ARRAYCALL T ARRAYP IDX))
		(PRIN1 (+ RA-ORG IDX) OUT-FILE)
		(PRINC '/  OUT-FILE)
		(PRIN-16 TEM OUT-FILE)
		(TERPRI OUT-FILE)))
	(SETQ IDX (1+ IDX))
	(GO L)))

(DEFUN CONS-DUMP-ARRAY (ARRAYP OUT-FILE)
  (PROG (IDX LIM)
	(SETQ IDX 0)
	(SETQ LIM (CADR (ARRAYDIMS ARRAYP)))
  L	(COND ((NOT (< IDX LIM))
		(TERPRI OUT-FILE)
		(RETURN T)))
	(PRINT (ARRAYCALL T ARRAYP IDX) OUT-FILE)
	(SETQ IDX (1+ IDX))
	(GO L)))

(DEFUN PRIN-16 (NUM OUT-FILE)
       (COND ((MINUSP NUM) (SETQ NUM (PLUS NUM 40000000000))))
		;TURN IT INTO A 32 BIT POS NUMBER
       (PRIN1 (LDB 4020 NUM) OUT-FILE)
       (PRINC '/  OUT-FILE)
       (PRIN1 (LDB 2020 NUM) OUT-FILE)
       (PRINC '/  OUT-FILE)
       (PRIN1 (LDB 0020 NUM) OUT-FILE)
       (PRINC '/  OUT-FILE))

(DEFUN CONS-DUMP-MEMORIES NIL
  (PROG (OUT-FILE)
	(LET (#Q (PACKAGE (PKG-FIND-PACKAGE "MICRO-ASSEMBLER"))) ;REDUCE INCIDENCE OF
	  ; :'S IN OUTPUT, CAUSE MAPATOMS TO WIN MORE.
	  (COND ((NULL (BOUNDP 'RACMO))
		 (READFILE "LMCONS;CADREG >" PACKAGE)))
	  (SETQ OUT-FILE (OPEN `((DSK LISPM1) ,CONSLP-OUTPUT ULOAD)
			       'OUT))
	  (DUMP-MEM-ARRAY #M (GET 'I-MEM 'ARRAY) #Q (FUNCTION I-MEM) RACMO OUT-FILE)
	  (DUMP-MEM-ARRAY #M (GET 'D-MEM 'ARRAY) #Q (FUNCTION D-MEM) RADMO OUT-FILE)
	  (DUMP-MEM-ARRAY #M (GET 'A-MEM 'ARRAY) #Q (FUNCTION A-MEM) RAAMO OUT-FILE)
	  (TERPRI OUT-FILE)
	  (COND ((NOT (NULL (MICRO-CODE-SYMBOL-IMAGE 0)))	;IF HAVE WIPED SYMBOL VECTOR
		 (PRINT -3 OUT-FILE)		;DUMP MICRO-CODE-SYMBOL AREA
		 (PRINT (CONS-DUMP-FIND-AREA-ORIGIN 'MICRO-CODE-SYMBOL-AREA) OUT-FILE)
		 (CONS-DUMP-ARRAY #M (GET 'MICRO-CODE-SYMBOL-IMAGE 'ARRAY)
				  #Q (FUNCTION MICRO-CODE-SYMBOL-IMAGE)
				  OUT-FILE)))
	  (PRINT -2 OUT-FILE)		;NOW DUMP SYMBOLS
	  (TERPRI OUT-FILE)
	  (CONS-DUMP-SYMBOLS OUT-FILE)
	  (PRINT -1 OUT-FILE)		;EOF
	  (CLOSE OUT-FILE)
	  (RETURN T))))

(DEFUN CONS-DUMP-FIND-AREA-ORIGIN (AREA)
  (PROG (ADR LST TEM)
	(SETQ ADR 0)
	(SETQ LST AREA-LIST)
   L	(COND ((NULL LST)(BREAK 'CANT-FIND-AREA-ORIGIN T))
	      ((EQ (CAR LST) AREA) (RETURN ADR))
	      (T (OR (SETQ TEM (LIST-ASSQ (CAR LST) RM-AREA-SIZES))
				      (SETQ TEM 1))))
	(SETQ ADR (+ ADR (* TEM PAGE-SIZE)))
	(SETQ LST (CDR LST))
	(GO L)))

(DEFUN CONS-DUMP-SYMBOLS (SPECIAL-OUT-FILE)
	(MAPATOMS (FUNCTION CONS-LAP-DUMP-SYMTAB-ELEMENT))
)

(DEFUN CONS-LAP-DUMP-SYMTAB-ELEMENT (SYM)
  (PROG (VAL DMP-TYPE TEM)
	(SETQ VAL (GET SYM 'CONS-LAP-USER-SYMBOL))
    L	(COND ((NULL VAL) (RETURN NIL))
	      ((NUMBERP VAL)
		(SETQ DMP-TYPE 'NUMBER))
	      ((ATOM VAL)
		(SETQ VAL (CONS-LAP-SYMEVAL VAL))
		(GO L))
             ((AND (SETQ TEM (ASSQ (CAR VAL) 
			'( (I-MEM JUMP-ADDRESS-MULTIPLIER)
                           (D-MEM DISPATCH-ADDRESS-MULTIPLIER)
                           (A-MEM A-SOURCE-MULTIPLIER)
                           (M-MEM M-SOURCE-MULTIPLIER))))
                   (EQ (CAADR VAL) 'FIELD)
                   (EQ (CADADR VAL) (CADR TEM)))
              (SETQ DMP-TYPE (CAR VAL) VAL (CADDR (CADR VAL))))
	     (T (RETURN NIL)))
	(PRIN1 SYM SPECIAL-OUT-FILE)
	(PRINC '/  SPECIAL-OUT-FILE)
        (PRIN1 DMP-TYPE SPECIAL-OUT-FILE)
        (PRINC '/  SPECIAL-OUT-FILE)
	(PRIN1 VAL SPECIAL-OUT-FILE)
	(PRINC '/  SPECIAL-OUT-FILE)
	(TERPRI SPECIAL-OUT-FILE)
	(RETURN T)))

