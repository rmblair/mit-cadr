;-*- Mode:LISP; Package:Compiler; Base:8 -*-

;	** (c) Copyright 1980 Massachusetts Institute of Technology **

(DECLARE (SETQ OPEN-CODE-MAP-SWITCH T))

(DECLARE (SPECIAL ARRAY-ELEMENTS-PER-Q ARRAY-DIM-MULT ARRAY-TYPES 
	ARRAY-TYPE-SHIFT ARRAY-DISPLACED-BIT ARRAY-LEADER-BIT ARRAY-LONG-LENGTH-FLAG 
	%ARRAY-MAX-SHORT-INDEX-LENGTH))

(DECLARE (SPECIAL FASD-TABLE SI:FASL-TABLE FASD-GROUP-LENGTH MACROLIST FASD-TABLE-IGNORE
		  FASL-TABLE-AREA FASD-TEMPORARY-AREA FASD-WHACK-THRESHOLD
		  FASD-STREAM FASD-SYMBOL-LIST
		  FASD-ALREADY-DUMPED-SYMBOL-LIST FASD-NEW-SYMBOL-FUNCTION
		  FASD-SYMBOL))

(OR (BOUNDP 'FASD-TEMPORARY-AREA)
    (SETQ FASD-TEMPORARY-AREA
	  (MAKE-AREA ':NAME 'FASD-TEMPORARY-AREA
		     ':REGION-SIZE 200000
		     ':GC ':STATIC
		     ':REPRESENTATION ':LIST)))

(DEFVAR FASD-PACKAGE)	;The package in which the fasl file will presumably be loaded

;If this is the car of a list, the cdr is a form to be evaluated at load time
;The "#," reader macro uses this
(DEFVAR EVAL-AT-LOAD-TIME-MARKER (COPYSYMBOL 'EVAL-AT-LOAD-TIME-MARKER NIL))

(PUTPROP EVAL-AT-LOAD-TIME-MARKER '(EXECUTION-CONTEXT-EVAL-WARNING) 'OPTIMIZERS)
(DEFUN EXECUTION-CONTEXT-EVAL-WARNING (FORM)
  (BARF (CDR FORM) "Load-time eval (#,) not inside quoted structure" 'WARN)
  (EVAL (CDR FORM)))

;If this uninterned symbol is seen as the car of a list, and the cadr of the
;list is a named-lambda, it will be compiled.
(DEFVAR FUNCTIONAL-CONSTANT-MARKER (COPYSYMBOL 'FUNCTIONAL-CONSTANT-MARKER NIL))

;Make it the same as FUNCTION for when the interpreter or compiler sees it.
;Do NOT make it a displacing macro!
(FSET FUNCTIONAL-CONSTANT-MARKER
      '(MACRO LAMBDA (X) (CONS 'FUNCTION (CDR X))))

;This is an a-list of special markers that may exist in the car of a cons
;and the function to fasdump such conses.  A typical thing for such a
;a function to do is to call FASD-EVAL1 on some suitable form.
(DEFVAR FASD-MARKERS-ALIST
	(LIST (CONS EVAL-AT-LOAD-TIME-MARKER 'FASD-EVAL-AT-LOAD-TIME)
	      (CONS FUNCTIONAL-CONSTANT-MARKER 'FASD-FUNCTIONAL-CONSTANT)))

;This is an a-list of area numbers and functions to fasdump conses in that
;area.  The function is treated just as for fasd-markers.
(DEFVAR FASD-MAGIC-AREAS-ALIST NIL)

(DECLARE (SPECIAL %FASL-GROUP-CHECK 
   %FASL-GROUP-FLAG %FASL-GROUP-LENGTH 
   FASL-GROUP-LENGTH-SHIFT %FASL-GROUP-TYPE 
   FASL-OP-ERR FASL-OP-INDEX FASL-OP-SYMBOL FASL-OP-LIST 
   FASL-OP-TEMP-LIST FASL-OP-FIXED FASL-OP-FLOAT 
   FASL-OP-ARRAY FASL-OP-EVAL FASL-OP-MOVE 
   FASL-OP-FRAME FASL-OP-ARRAY-PUSH FASL-OP-STOREIN-SYMBOL-VALUE 
   FASL-OP-STOREIN-FUNCTION-CELL FASL-OP-STOREIN-PROPERTY-CELL 
   FASL-OP-STOREIN-ARRAY-LEADER
   FASL-OP-FETCH-SYMBOL-VALUE FASL-OP-FETCH-FUNCTION-CELL 
   FASL-OP-FETCH-PROPERTY-CELL FASL-OP-APPLY FASL-OP-END-OF-WHACK 
   FASL-OP-END-OF-FILE FASL-OP-SOAK FASL-OP-FUNCTION-HEADER FASL-OP-FUNCTION-END 
   FASL-OP-QUOTE-POINTER FASL-OP-S-V-CELL 
   FASL-OP-FUNCELL FASL-OP-CONST-PAGE FASL-OP-SET-PARAMETER 
   FASL-OP-INITIALIZE-ARRAY 
   FASL-OP-STRING FASL-OP-EVAL1 FASL-OP-FILE-PROPERTY-LIST
   FASL-OP-RATIONAL
   FASL-NIL FASL-EVALED-VALUE FASL-TEM1 FASL-TEM2 FASL-TEM3 
   FASL-SYMBOL-HEAD-AREA 
   FASL-SYMBOL-STRING-AREA FASL-OBARRAY-POINTER FASL-ARRAY-AREA 
   FASL-FRAME-AREA FASL-LIST-AREA FASL-TEMP-LIST-AREA 
   FASL-TABLE-WORKING-OFFSET ))

(DEFUN FASD-NIBBLE (NUMBER)
    (FUNCALL FASD-STREAM 'TYO NUMBER))

(COMMENT OUTPUT THE THINGS THAT DIVIDE A FASL FILE INTO ITS MAJOR SUBPARTS)

;OUTPUT SIXBIT /QFASL/ TO START A FASL FILE.
;ALSO CLEARS OUT THE TEMP AREA
(DEFUN FASD-START-FILE NIL
    (FASD-NIBBLE 143150)
    (FASD-NIBBLE 71660))

(DEFUN FASD-START-GROUP (FLAG LENGTH TYPE)
  (PROG (OUT-LEN)
	(SETQ FASD-GROUP-LENGTH LENGTH)
        (SETQ OUT-LEN (LSH (COND ((>= LENGTH 377) 377)
                                 (T LENGTH))
                           (MINUS FASL-GROUP-LENGTH-SHIFT)))                           
	(FASD-NIBBLE (+ %FASL-GROUP-CHECK 
			(+ (COND (FLAG %FASL-GROUP-FLAG) (T 0))
			   (+ OUT-LEN
			      TYPE))))
	(AND (>= LENGTH 377)
	     (FASD-NIBBLE LENGTH))
	(RETURN NIL)))

(DEFUN FASD-FUNCTION-HEADER (FCTN-NAME)
  (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 0 FASL-OP-FUNCTION-HEADER)
	(FASD-CONSTANT FCTN-NAME)
	(FASD-CONSTANT '0)))

(DEFUN FASD-FUNCTION-END NIL 
  (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 0 FASL-OP-FUNCTION-END)))

(DEFUN FASD-END-WHACK NIL 
	;STARTING NEW WHACK SO LET FASD-GROUP-LENGTH GET
	;SET TO 0
  (FASD-START-GROUP NIL 0 FASL-OP-END-OF-WHACK)
  (FASD-TABLE-CLEAN)
  (FILLARRAY FASD-TABLE '(NIL))
  (STORE-ARRAY-LEADER FASL-TABLE-WORKING-OFFSET FASD-TABLE 0)
  (LET ((SI:FASL-TABLE FASD-TABLE))
    (SI:INITIALIZE-FASL-TABLE))) ;RESET FASL/FASD TABLE, BUT NOT TEMPORARY AREAS

(DEFUN FASD-END-FILE NIL
  (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 0 FASL-OP-END-OF-FILE)
	(FASD-TABLE-CLEAN)
	(SETQ FASD-TABLE NIL)
	(RESET-TEMPORARY-AREA FASD-TEMPORARY-AREA)	;DISPOSE OF STORAGE
	(RESET-TEMPORARY-AREA FASL-TABLE-AREA)))

(COMMENT GIVEN A SEXP DUMP A GROUP TO CONS UP THAT SEXP AND RETURN IT)

;;  This is the main function of FASD.  It takes a Lisp object and
;;     dumps it.  The second (optional) arg is a FASL-OP to use
;;     on any lists in the structure.  It returns the IDX of the object.

(DEFUN FASD-CONSTANT (S-EXP &OPTIONAL (LIST-OP FASL-OP-LIST))
 (PROG (TEM)
    (AND FASD-NEW-SYMBOL-FUNCTION			;For FASD-SYMBOLS-PROPERTIES,
	 (SYMBOLP S-EXP)				;make sure we examine all symbols in
	 (FUNCALL FASD-NEW-SYMBOL-FUNCTION S-EXP))	;the data that we dump.
    (COND ((SETQ TEM (FASD-TABLE-LOOKUP S-EXP))		;If this object already dumped,
	   (FASD-START-GROUP NIL 1 FASL-OP-INDEX)	;Just reference it in
	   (FASD-NIBBLE TEM)				;the FASL TABLE.
	   (RETURN TEM))
	  ((FIXP S-EXP)
	   (FASD-FIXED S-EXP))
	  ((SMALL-FLOATP S-EXP)
	   (FASD-SMALL-FLOAT S-EXP))
	  ((FLOATP S-EXP)
	   (FASD-FLOAT S-EXP))
	  ((SYMBOLP S-EXP)
	   (FASD-SYMBOL S-EXP))
	  ((STRINGP S-EXP)
	   (FASD-STRING S-EXP))
	  ((ARRAYP S-EXP)
	   (RETURN (FASD-ARRAY S-EXP)))
	  ((= (SETQ TEM (%DATA-TYPE S-EXP)) DTP-FEF-POINTER)
	   (FASD-FEF S-EXP))
	  ((LISTP S-EXP)
	   (RETURN (FASD-LIST S-EXP LIST-OP)))
	  ((= TEM DTP-INSTANCE)
	   (RETURN (FASD-EVAL1 (FUNCALL S-EXP ':FASD-FORM))))
	  ((SI:RATIONALP S-EXP)
	   (RETURN (FASD-RATIONAL S-EXP)))
	  (T (FERROR NIL "~S is a ~S, which is not a valid data-type for FASD-CONSTANT"
		     S-EXP (TYPEP S-EXP))))
    (RETURN (FASD-TABLE-ADD S-EXP))))

(DEFUN FASD-LIST (S-EXP LIST-OP)
  ;Determine the size of the list, and check for special markers
  (DO ((L S-EXP (CDR L))
       (N-CONSES 0 (1+ N-CONSES))
       (MARK) (DOTTED))
      ((OR (ATOM L)
	   (SETQ MARK (ASSQ (CAR L) FASD-MARKERS-ALIST))
	   (AND FASD-MAGIC-AREAS-ALIST
		(SETQ MARK (ASSQ (%AREA-NUMBER L) FASD-MAGIC-AREAS-ALIST))))
       ;Now dump that many conses and the tail if non-null
       (COND ((ZEROP N-CONSES) (FUNCALL (CDR MARK) S-EXP))
	     (T (SETQ DOTTED (NOT (NULL L)))
		(FASD-START-GROUP DOTTED 1 LIST-OP)
		(FASD-NIBBLE (IF DOTTED (1+ N-CONSES) N-CONSES))
		(DO ((L1 S-EXP (CDR L1)))
		    ((EQ L1 L))
		  (FASD-CONSTANT (CAR L1) LIST-OP))
		(COND ((NOT DOTTED))
		      ((NOT MARK) (FASD-CONSTANT L))
		      (T (FUNCALL (CDR MARK) L)))
		;FASL-OP-LIST-COMPONENT speeds things up by not bloating the fasl
		;table with conses out of the middle of lists.
		(IF (= LIST-OP FASL-OP-LIST-COMPONENT)
		    FASL-EVALED-VALUE
		    (FASD-TABLE-ADD S-EXP)))))))

(DEFUN FASD-EVAL-AT-LOAD-TIME (CONS)
  (FASD-EVAL1 (CDR CONS)))

(DEFUN FASD-FUNCTIONAL-CONSTANT (CONS)
  (COND ((AND (LISTP (CADR CONS))
	      (EQ (CAADR CONS) 'NAMED-LAMBDA))
	 (IF (BOUNDP 'QC-FUNCTIONS-TO-BE-TRANSLATED)
	     (FERROR NIL "Compiler is not recursive--you will lose somehow"))
	 (QC-TRANSLATE-FUNCTION (IF (ATOM (CADADR CONS)) (CADADR CONS)
				    (CAR (CADADR CONS)))
				(CADR CONS)
				'MACRO-COMPILE
				'QFASL-NO-FDEFINE))
	(T (FASD-CONSTANT (CONS 'FUNCTION (CDR CONS))))))

(DEFUN FASD-SYMBOL (SYM &AUX (FASD-SYMBOL NIL)) ;Flag for below
  (SI:PKG-PREFIX SYM #'(LAMBDA (REFNAME CNT)
                           (COND ((NULL FASD-SYMBOL) ;first time
                                  (SETQ FASD-SYMBOL T)
                                  (FASD-START-GROUP NIL 1 FASL-OP-PACKAGE-SYMBOL)
                                  (FASD-NIBBLE (+ 2 CNT))))
                           (FASD-CONSTANT REFNAME))
		 FASD-PACKAGE)
  (IF FASD-SYMBOL (FASD-CONSTANT (STRING SYM)) ;If there was a prefix
      (FASD-WRITE-STRING SYM FASL-OP-SYMBOL))) ;If uninterned or no prefix needed

(DEFUN FASD-STRING (STRING) (FASD-WRITE-STRING STRING FASL-OP-STRING))

(DEFUN FASD-WRITE-STRING (OBJECT GROUP-TYPE &AUX (STRING (STRING OBJECT)))
  (PROG (FASD-GROUP-LENGTH LENGTH (I 0) C0 C1)
	(SETQ LENGTH (STRING-LENGTH STRING))
	(FASD-START-GROUP NIL (// (1+ LENGTH) 2) GROUP-TYPE)
	L
	(AND (>= I LENGTH) (RETURN NIL))
	(SETQ C0 (AR-1 STRING I)
	      C1 (COND ((= (1+ I) LENGTH) 200)
		       (T (AR-1 STRING (1+ I)))))
	(FASD-NIBBLE (+ (LSH C1 8) C0))
	(SETQ I (+ I 2))
	(GO L)))

(DEFUN FASD-FIXED (N)
 (PROG (FASD-GROUP-LENGTH NMAG NLENGTH)
	(SETQ NMAG (ABS N)
	      NLENGTH (// (+ (HAULONG NMAG) 15.) 16.))
	(FASD-START-GROUP (< N 0) NLENGTH FASL-OP-FIXED)
	(DO ((POS (* 20 (1- NLENGTH)) (- POS 20))
	     (C NLENGTH (1- C)))
	    ((ZEROP C))
	    (FASD-NIBBLE (LDB (+ (LSH POS 6) 20) NMAG)))))

;(DEFUN FASD-FIXED (N)
; (PROG (FASD-GROUP-LENGTH)
;	(AND (BIGP N) (FERROR NIL "FASL-OP-FIXED doesn't win for bignums yet"))
;	(FASD-START-GROUP (< N 0) 2 FASL-OP-FIXED)
;	(AND (< N 0) (SETQ N (%24-BIT-DIFFERENCE 0 N))) ;Don't use ABS, see FASL-OP-FIXED
;	(FASD-NIBBLE (LOGAND (LSH N -20) 177777))
;	(FASD-NIBBLE (LOGAND N 177777))))

(DEFUN FASD-FLOAT (N)
 (PROG (FASD-GROUP-LENGTH)
        (FASD-START-GROUP NIL 3 FASL-OP-FLOAT)
	(FASD-NIBBLE (%P-LDB-OFFSET 1013 N 0))
	(FASD-NIBBLE (DPB (%P-LDB-OFFSET 0010 N 0) 1010 (%P-LDB-OFFSET 2010 N 1)))
	(FASD-NIBBLE (%P-LDB-OFFSET 0020 N 1))))

(DEFUN FASD-SMALL-FLOAT (N)
 (PROG (FASD-GROUP-LENGTH)
    (SETQ N (%MAKE-POINTER DTP-FIX N))  ;So that LDB's will work.
    (FASD-START-GROUP T 2 FASL-OP-FLOAT)
    (FASD-NIBBLE (LDB 2010 N))
    (FASD-NIBBLE (LDB 0020 N))))

(DEFUN FASD-RATIONAL (RAT)
  (LET ((FASD-GROUP-LENGTH))
    (FASD-START-GROUP NIL 0 FASL-OP-RATIONAL)
    (FASD-CONSTANT (SI:NUMERATOR RAT))
    (FASD-CONSTANT (SI:DENOMINATOR RAT))
    (FASD-TABLE-ADD RAT)))

(DEFUN FASD-FEF (FEF &AUX Q-COUNT NON-Q-COUNT)
    (SETQ Q-COUNT (LSH (%P-LDB %%FEFH-PC FEF) -1)
	  NON-Q-COUNT (- (%P-CONTENTS-OFFSET FEF %FEFHI-STORAGE-LENGTH) Q-COUNT))
    (FASD-START-GROUP NIL 3 FASL-OP-FRAME)
    (FASD-NIBBLE Q-COUNT)
    (FASD-NIBBLE NON-Q-COUNT)
    (FASD-NIBBLE (+ Q-COUNT (LSH NON-Q-COUNT 1)))
    (DO ((I 0 (1+ I)))
	((= I Q-COUNT))
	(FASD-FEF-Q FEF I))
    (DO ((I Q-COUNT (1+ I)))
	((= I (+ Q-COUNT NON-Q-COUNT)))
      (FASD-NIBBLE (%P-LDB-OFFSET %%Q-LOW-HALF FEF I))
      (FASD-NIBBLE (%P-LDB-OFFSET %%Q-HIGH-HALF FEF I)))
    NIL)

(DEFUN FASD-FEF-Q (FEF I &AUX DATTP PTR PTR1 OFFSET (TYPE 0))
    (SETQ DATTP (%P-LDB-OFFSET %%Q-DATA-TYPE FEF I))
    (SETQ TYPE (LSH (%P-LDB-OFFSET %%Q-CDR-CODE FEF I) 6))
    (COND ((OR (= DATTP DTP-EXTERNAL-VALUE-CELL-POINTER)
	       (= DATTP DTP-LOCATIVE))
	   (SETQ PTR1 (%P-CONTENTS-AS-LOCATIVE-OFFSET FEF I))
	   (SETQ PTR (%FIND-STRUCTURE-HEADER PTR1))
	   (SETQ OFFSET (%POINTER-DIFFERENCE PTR1 PTR))
	   (AND (> OFFSET 17)
		(FERROR NIL "~O is too great an offset into atom while fasdumping FEF ~S"
		       OFFSET (%P-CONTENTS-OFFSET FEF %FEFHI-FCTN-NAME)))
	   (FASD-CONSTANT PTR)
	   (AND (= DATTP DTP-EXTERNAL-VALUE-CELL-POINTER)
		(SETQ TYPE (+ TYPE 20)))
	   (AND (= DATTP DTP-LOCATIVE)
		(SETQ TYPE (+ TYPE 400)))
	   ;; LOW 4 BITS OF TYPE ARE OFFSET TO ADD TO POINTER TO MAKE IT POINT AT VALUE CELL, ETC.
	   (SETQ TYPE (+ TYPE OFFSET)))
          ((= DATTP DTP-HEADER)
           (FASD-CONSTANT (%P-LDB-OFFSET %%Q-POINTER FEF I)))
          (T (FASD-CONSTANT (%P-CONTENTS-OFFSET FEF I))))
    (FASD-NIBBLE TYPE))

(DEFUN FASD-INTERNALP (INTERNAL MAIN &AUX TEM)
  MAIN
  (AND (SYMBOLP INTERNAL)
       (> (SETQ TEM (STRING-LENGTH INTERNAL)) 18.)
       (SETQ TEM (STRING-REVERSE-SEARCH-CHAR #/- INTERNAL TEM))
       (STRING-EQUAL INTERNAL "-INTERNAL-LAMBDA" (- TEM 16.) 0 TEM)))

;DOES ITS OWN FASD-TABLE ADDING SINCE IT HAS TO BE DONE IN THE MIDDLE
;OF THIS FUNCTION, AFTER THE FASL-OP-ARRAY BUT BEFORE THE INITIALIZATION DATA.
(DEFUN FASD-ARRAY (ARRAY &AUX DIMLIST SIZE OBJECTIVE-P FAKE-ARRAY RETVAL NSP)
    (SETQ DIMLIST (ARRAYDIMS ARRAY)
	  NSP (NAMED-STRUCTURE-P ARRAY))
    (SETQ SIZE (APPLY (FUNCTION TIMES) (CDR DIMLIST))
	  OBJECTIVE-P (NULL (CDR (ASSQ (CAR DIMLIST) ARRAY-BITS-PER-ELEMENT))))
    (COND ((NOT OBJECTIVE-P)
	   (LET ((EPQ (CDR (ASSQ (CAR DIMLIST) ARRAY-ELEMENTS-PER-Q))))
	     ;; In this case, number of halfwords
	     (SETQ SIZE (IF (PLUSP EPQ) (// (* SIZE 2) EPQ) (* SIZE 2 (MINUS EPQ)))))))
    (FASD-START-GROUP NIL 0 (COND (OBJECTIVE-P FASL-OP-INITIALIZE-ARRAY)
				  (T FASL-OP-INITIALIZE-NUMERIC-ARRAY)))
    (FASD-START-GROUP NSP 0 FASL-OP-ARRAY)
    (FASD-CONSTANT (NTH (%AREA-NUMBER ARRAY) AREA-LIST))	;AREA
    (FASD-CONSTANT (CAR DIMLIST))				;TYPE-SYMBOL
    (FASD-CONSTANT (CDR DIMLIST) FASL-OP-TEMP-LIST)		;DIMENSIONS
    (FASD-CONSTANT NIL)					        ;DISPLACED-P. FOR NOW
    (FASD-CONSTANT						;LEADER
     (COND ((ARRAY-HAS-LEADER-P ARRAY)
	    (DO ((I 0 (1+ I))
		 (LIST NIL)
		 (LIM (ARRAY-DIMENSION-N 0 ARRAY)))
		((>= I LIM) LIST)
	      (PUSH (ARRAY-LEADER ARRAY I) LIST)))
	   (T NIL))
     FASL-OP-TEMP-LIST)
    (FASD-CONSTANT NIL)					        ;INDEX-OFFSET FOR NOW
    (AND NSP
	 (FASD-CONSTANT T))					;NAMED-STRUCTURE-P
    ;; Now that six values have been given, the group is over.
    (SETQ RETVAL (FASD-TABLE-ADD ARRAY))
    ;; Next, continue to initialize the array.
    (FASD-CONSTANT SIZE)
    (SETQ FAKE-ARRAY
	  (MAKE-ARRAY NIL
		      (COND (OBJECTIVE-P ART-Q) (T ART-16B))
		      SIZE
		      ARRAY))
    (COND (OBJECTIVE-P
	   (DO I 0 (1+ I) (>= I SIZE)
	       (FASD-CONSTANT (AR-1 FAKE-ARRAY I))))
	  (T
	   (DO I 0 (1+ I) (>= I SIZE)
	     (FASD-NIBBLE (AR-1 FAKE-ARRAY I)))))
    (RETURN-ARRAY (PROG1 FAKE-ARRAY (SETQ FAKE-ARRAY NIL)))
    RETVAL)

(COMMENT LOW LEVEL ROUTINES TO DUMP GROUPS TO DEPOSIT THINGS IN VARIOUS PLACES)

(DEFUN FASD-SET-PARAMETER (PARAM VAL)
  (PROG (FASD-GROUP-LENGTH C-VAL)
	(COND ((NULL (SETQ C-VAL (ASSQ PARAM FASD-TABLE)))
		(FERROR NIL "~S is an unknown FASL parameter" PARAM)))
	(COND ((EQUAL VAL (CDR C-VAL))(RETURN NIL)))
	(FASD-START-GROUP NIL 0 FASL-OP-SET-PARAMETER)
	(FASD-CONSTANT PARAM)
	(FASD-CONSTANT VAL)
))

(DEFUN FASD-STORE-ARRAY-LEADER (VALUE ARRAY SUBSCR)
   (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 3 FASL-OP-STOREIN-ARRAY-LEADER)
	(FASD-NIBBLE ARRAY)
	(FASD-NIBBLE SUBSCR)
	(FASD-NIBBLE VALUE)	;NOTE nibbles not in same order as STORE-ARRAY-LEADER!
	(RETURN 0)))

(BEGF FASD-STORE-FUNCTION-CELL)

(DEFUN FASD-STORE-FUNCTION-CELL (SYM IDX)	;IDX AN FASD-TABLE INDEX THAT HAS
   (PROG (FASD-GROUP-LENGTH)			;STUFF DESIRED TO STORE.
	(FASD-START-GROUP NIL 1 FASL-OP-STOREIN-FUNCTION-CELL)
	(FASD-NIBBLE IDX)
	(FASD-CONSTANT SYM)
	(RETURN 0)))

(FSET 'FASD-STOREIN-FUNCTION-CELL (FUNCTION FASD-STORE-FUNCTION-CELL))

(ENDF FASD-STORE-FUNCTION-CELL)

(DEFUN FASD-STORE-VALUE-CELL (SYM IDX)
   (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 1 FASL-OP-STOREIN-SYMBOL-VALUE)
	(FASD-NIBBLE IDX)
	(FASD-CONSTANT SYM)
	(RETURN 0)))

(DEFUN FASD-STORE-PROPERTY-CELL (SYM IDX)
   (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 1 FASL-OP-STOREIN-PROPERTY-CELL)
	(FASD-NIBBLE IDX)
	(FASD-CONSTANT SYM)
	(RETURN 0)))

(DEFUN FASD-FILE-PROPERTY-LIST (PLIST)
  (LET ((P (GET (LOCF PLIST) ':PACKAGE)))
    (AND P (SETQ FASD-PACKAGE (PKG-FIND-PACKAGE P))))
  (FASD-START-GROUP NIL 0 FASL-OP-FILE-PROPERTY-LIST)
  ;Put package prefixes on everything in the plist since it will be loaded in
  ;the wrong package.  This way the symbols in the plist will always be loaded
  ;into exactly the same package they were dumped from, while the rest of the
  ;symbols in the file will be free to follow the usual rules for intern.
  (LET ((FASD-PACKAGE NIL))
    (FASD-CONSTANT PLIST)))

(DEFUN FASD-EVAL (IDX) 
  (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 1 FASL-OP-EVAL)
	(FASD-NIBBLE IDX)
	(RETURN FASL-EVALED-VALUE)))

;THE OLD WAY OF DOING EVAL (FASD-EVAL) UNFORTUNATELY DOES NOT NEST PROPERLY.  IE
; CAN NOT BE USED TO LOAD INTO A FEF, BECAUSE THE LOADER IS EXPECTING TO SEE
; A SINGLE NEXT-VALUE.  SO THIS IS THE WAY IT PROBABLY SHOULD HAVE BEEN DONE IN
; THE FIRST PLACE..
(DEFUN FASD-EVAL1 (SEXP)
  (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 0 FASL-OP-EVAL1)
	(FASD-CONSTANT SEXP)
	(RETURN (FASD-TABLE-ADD FASD-TABLE-IGNORE))))

;IS THIS USED FOR ANYTHING?
(DEFUN FASD-MAKE-ARRAY (AREA TYPE DIMLIST DISPLACED-P LEADER &OPTIONAL INDEX-OFFSET
			      &AUX FASD-GROUP-LENGTH)
	(FASD-SET-PARAMETER 'FASL-ARRAY-AREA AREA)
	(FASD-START-GROUP NIL 0 FASL-OP-ARRAY)
	(FASD-CONSTANT TYPE)
	(FASD-CONSTANT DIMLIST)
	(FASD-CONSTANT DISPLACED-P)
	(FASD-CONSTANT LEADER)
	(FASD-CONSTANT INDEX-OFFSET)
	(FASD-TABLE-ADD FASD-TABLE-IGNORE))

;IS THIS USED FOR ANYTHING?
(DEFUN FASD-INITIALIZE-ARRAY (IDX INIT)
   (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 2 FASL-OP-INITIALIZE-ARRAY)
	(FASD-NIBBLE IDX)
	(FASD-NIBBLE (LENGTH INIT))
   L	(COND ((NULL INIT) (RETURN 0)))
	(FASD-CONSTANT (CAR INIT))
	(SETQ INIT (CDR INIT))
	(GO L)))

(COMMENT ROUTINES TO MANIPULATE THE FASD TABLE)

;FASD keeps a table that looks just like the one FASLOAD will keep.
;FASD uses it to refer back to atoms which have been seen before,
;so that no atom need be interned twice.
;In addition to the table, each atom that is put in it gets a
;FASD-TABLE-INDEX property which is the index in the table where it appears.
;This makes it unnecessary to spend time searching the FASD table for atoms.

(DEFUN FASD-TABLE-ADD (DATA &AUX)
    (PROG (TEM) 
	(COND ((NULL (SETQ TEM (ARRAY-PUSH FASD-TABLE DATA)))
	       (FERROR NIL "FASD TABLE OVERFLOW")))
	(COND ((SYMBOLP DATA)
	       (PUTPROP DATA TEM 'FASD-TABLE-INDEX)))
	(RETURN TEM)))

(DEFUN FASD-TABLE-LOOKUP (DATA &AUX TEM)
       (COND ((SYMBOLP DATA)
	      (AND (SETQ TEM (GET DATA 'FASD-TABLE-INDEX))
		   (< TEM (ARRAY-ACTIVE-LENGTH FASD-TABLE))
		   (EQ DATA (AR-1 FASD-TABLE TEM))
		   TEM))
       ;; THIS WANTS TO CHECK FOR SINGLE-WORD FIXNUMS ONLY, NOT BIGNUMS, MAYBE.
	     ((NUMBERP DATA) NIL)
	     ((SETQ TEM
		   ;THIS COULD BE FIND-POSITION-IN-LIST-EQUAL, WHICH WOULD MAKE
		   ;EQUAL LISTS BECOME EQ, WHICH MIGHT BE A SCREW.  ALSO IT WOULD BE SLOWER.
		   (FIND-POSITION-IN-LIST DATA 
					  (%MAKE-POINTER DTP-LIST
							 (AP-1 FASD-TABLE
							       FASL-TABLE-WORKING-OFFSET))))
	      (+ TEM FASL-TABLE-WORKING-OFFSET))	;DON'T SEARCH FRONT PART OF TABLE
	     ))

;Set one of the parameters at the front of the FASD-TABLE, as in
;(FASD-TABLE-SET FASL-SYMBOL-STRING-AREA PN-STRING)
(DEFUN FASD-TABLE-SET (PARAM DATA)
    (AS-1 DATA FASD-TABLE PARAM))

(DEFUN FASD-TABLE-LENGTH ()
    (ARRAY-ACTIVE-LENGTH FASD-TABLE))

;Remove all the FASD-TABLE-INDEX properties we have made for this whack.
(DEFUN FASD-TABLE-CLEAN (&AUX (LEN (FASD-TABLE-LENGTH)))
    (DO I FASL-TABLE-WORKING-OFFSET (1+ I) (= I LEN)
       (AND (SYMBOLP (AR-1 FASD-TABLE I))
	    (REMPROP (AR-1 FASD-TABLE I) 'FASD-TABLE-INDEX))))

(DEFUN FASD-INITIALIZE (&AUX SI:FASL-TABLE)
    (RESET-TEMPORARY-AREA FASD-TEMPORARY-AREA)
    (RESET-TEMPORARY-AREA FASL-TABLE-AREA)
    (SETQ FASD-NEW-SYMBOL-FUNCTION NIL)
    (SETQ FASD-PACKAGE PACKAGE)
    (SETQ FASD-TABLE-IGNORE (NCONS-IN-AREA NIL FASD-TEMPORARY-AREA))
    (SETQ FASD-TABLE (MAKE-ARRAY FASL-TABLE-AREA 
				 'ART-Q-LIST 
				 LENGTH-OF-FASL-TABLE 
				 NIL 
				 (LIST FASL-TABLE-WORKING-OFFSET)))
							;LEADER FOR FILLING
    (SETQ SI:FASL-TABLE FASD-TABLE)
    (SI:INITIALIZE-FASL-TABLE))

(COMMENT DUMP FORMS TO BE EVALUATED WITH HAIR FOR DEFUN AND SETQ)

;DUMP A GROUP TO EVALUATE A GIVEN FORM AND RETURN ITS VALUE.
;IF OPTIMIZE IS SET, SETQ AND DEFUN ARE HANDLED SPECIALLY,
;IN A WAY APPROPRIATE FOR THE TOP LEVEL OF FASDUMP OR QC-FILE.
(DEFUN FASD-FORM (FORM &OPTIONAL OPTIMIZE)
   (COND ((OR (MEMQ FORM '(T NIL))
	      (STRINGP FORM)
	      (NUMBERP FORM))
	  (FASD-CONSTANT FORM))
	 ((SYMBOLP FORM) (FASD-SYMEVAL FORM))
	 ((ATOM FORM) (FASD-RANDOM-FORM FORM))
	 ((EQ (CAR FORM) 'QUOTE)
	  (FASD-CONSTANT (CADR FORM)))
	 ((NOT OPTIMIZE)
	  (FASD-RANDOM-FORM FORM))
	 ((EQ (CAR FORM) 'SETQ)
	  (FASD-SETQ FORM))
	 ((EQ (CAR FORM) 'DEFF)
	  (FASD-STORE-FUNCTION-CELL (CADR FORM) (FASD-FORM (CADDR FORM))))
         ((AND (EQ (CAR FORM) 'FSET-CAREFULLY)
               (LISTP (CADR FORM))
               (EQ (CAADR FORM) 'QUOTE))
          (FASD-STORE-FUNCTION-CELL (CADADR FORM) (FASD-FORM (CADDR FORM))))
	 ((EQ (CAR FORM) 'DEFUN)
	  (FASD-FUNCTION (CADR FORM) (FDEFINITION (CADR FORM))))
         ((EQ (CAR FORM) 'DECLARE)
          (MAPC (FUNCTION FASD-DECLARATION) (CDR FORM)))
	 (T (FASD-RANDOM-FORM FORM))))

(DEFUN FASD-DECLARATION (DCL)
    (AND (MEMQ (CAR DCL) '(SPECIAL UNSPECIAL))
         (FASD-FORM DCL)))

;DUMP SOMETHING TO EVAL SOME RANDOM FORM (WHICH IS THE ARGUMENT).
(DEFUN FASD-RANDOM-FORM (FRM)
    (FASD-EVAL1 FRM))
	
;GIVEN THE BODY OF A DEFUN, DUMP STUFF TO PERFORM IT.
(DEFUN FASD-FUNCTION (FUNCTION DEFINITION)
  (FASD-STORE-FUNCTION-CELL FUNCTION (FASD-CONSTANT DEFINITION)))

;GIVEN THE BODY OF A SETQ, DUMP STUFF TO PERFORM IT.
(DEFUN FASD-SETQ (SETQ-FORM)
  (DO ((PAIRS (CDR SETQ-FORM) (CDDR PAIRS)))
      ((NULL PAIRS))
    (CHECK-ARG PAIRS (ATOM (CAR PAIRS)) "a SETQ form")
    (FASD-STORE-VALUE-CELL (CAR PAIRS) (FASD-FORM (CADR PAIRS)))))

(DEFUN FASD-SYMEVAL (SEXP)
  (PROG (FASD-GROUP-LENGTH)
	(FASD-START-GROUP NIL 0 FASL-OP-FETCH-SYMBOL-VALUE)
	(FASD-CONSTANT SEXP)
	(RETURN (FASD-TABLE-ADD FASD-TABLE-IGNORE))))

;;; TESTING

(DEFUN FASD-TEST (FILENAME FORMS)
  (WITH-OPEN-FILE (FASD-STREAM (FS:MERGE-PATHNAME-DEFAULTS FILENAME FS:LOAD-PATHNAME-DEFAULTS
							   "QFASL")
			       '(:WRITE :FIXNUM))
    (FASD-INITIALIZE)
    (FASD-START-FILE)
    (MAPC (FUNCTION (LAMBDA (FORM) (FASD-FORM FORM T)))
	  FORMS)
    (FASD-END-WHACK)
    (FASD-END-FILE)))

(DEFUN FASD-SYMBOL-VALUE (FILENAME SYMBOL)
  (WITH-OPEN-FILE (FASD-STREAM (FS:MERGE-PATHNAME-DEFAULTS FILENAME FS:LOAD-PATHNAME-DEFAULTS
							   "QFASL")
			       '(:WRITE :FIXNUM))
    (FASD-INITIALIZE)
    (FASD-START-FILE)
    (FASD-STORE-VALUE-CELL SYMBOL
			   (FASD-CONSTANT (SYMEVAL SYMBOL)))
    (FASD-END-WHACK)
    (FASD-END-FILE)))

(DEFUN FASD-FONT (FONT)
  (FASD-SYMBOL-VALUE (FS:MAKE-PATHNAME ':HOST "SYS"
				       ':DIRECTORY "FONTS"
				       ':NAME (STRING FONT))
		     FONT))

;Output in an already started FASD the specified properties of the specified symbols.
;DUMP-VALUES says dump the value cells as well.  DUMP-FUNCTIONS says dump the
;function cells as well.  FASD-NEW-SYMBOL-FUNCTION will be called whenever a new
;symbol is seen in the structure being dumped.  It can do nothing.
;(LAMBDA (SYMBOL) (OR (MEMQ SYMBOL FASD-ALREADY-DUMPED-SYMBOL-LIST)
;		      (MEMQ SYMBOL FASD-SYMBOL-LIST)
;		      (PUSH SYMBOL FASD-SYMBOL-LIST)))
;is a good way to cause all symbols found in the substructure
;to be dumped as well.

(DEFUN FASD-FILE-SYMBOLS-PROPERTIES (FILENAME SYMBOLS PROPERTIES
                                              DUMP-VALUES-P DUMP-FUNCTIONS-P
                                              NEW-SYMBOL-FUNCTION)
  (WITH-OPEN-FILE (FASD-STREAM (FS:MERGE-PATHNAME-DEFAULTS FILENAME FS:LOAD-PATHNAME-DEFAULTS
							   "QFASL")
			       '(:WRITE :FIXNUM))
    (FASD-INITIALIZE)
    (FASD-START-FILE)
    (FASD-SYMBOLS-PROPERTIES SYMBOLS PROPERTIES DUMP-VALUES-P
			     DUMP-FUNCTIONS-P NEW-SYMBOL-FUNCTION)
    (FASD-END-WHACK)
    (FASD-END-FILE)))

;Take each symbol in SYMBOLS and do a FASD-SYMBOL-PROPERTIES on it.
;The symbols already thus dumped are put on FASD-ALREADY-DUMPED-SYMBOL-LIST.
;The NEW-SYMBOL-FUNCTION can add more symbols to FASD-SYMBOL-LIST
;to cause them to be dumped as well.
(DEFUN FASD-SYMBOLS-PROPERTIES (SYMBOLS PROPERTIES DUMP-VALUES
					DUMP-FUNCTIONS NEW-SYMBOL-FUNCTION)
    (DO ((FASD-SYMBOL-LIST SYMBOLS)
	 (FASD-ALREADY-DUMPED-SYMBOL-LIST)
	 (SYMBOL))
	((NULL FASD-SYMBOL-LIST))
	(SETQ SYMBOL (CAR FASD-SYMBOL-LIST))
	(POP FASD-SYMBOL-LIST)
	(PUSH SYMBOL FASD-ALREADY-DUMPED-SYMBOL-LIST)
	(FASD-SYMBOL-PROPERTIES SYMBOL PROPERTIES
				DUMP-VALUES DUMP-FUNCTIONS NEW-SYMBOL-FUNCTION)))

;Dump into the FASD file the properties of SYMBOL in PROPERTIES,
;and the value if DUMP-VALUES, and the function cell if DUMP-FUNCTIONS.
;NEW-SYMBOL-FUNCTION will be called on appropriate symbols in the
;structures which are dumped.
(DEFUN FASD-SYMBOL-PROPERTIES (SYMBOL PROPERTIES DUMP-VALUES
                                      DUMP-FUNCTIONS NEW-SYMBOL-FUNCTION &AUX TEM)
	(AND DUMP-VALUES
             (BOUNDP SYMBOL)
	     (FASD-STORE-VALUE-CELL SYMBOL
				    (FASD-CONSTANT-TRACING-SYMBOLS (SYMEVAL SYMBOL)
								   NEW-SYMBOL-FUNCTION)))
	(AND DUMP-FUNCTIONS
             (FBOUNDP SYMBOL)
	     (FASD-STORE-VALUE-CELL SYMBOL
				    (FASD-CONSTANT-TRACING-SYMBOLS (FSYMEVAL SYMBOL)
								   NEW-SYMBOL-FUNCTION)))
	(MAPC (FUNCTION (LAMBDA (PROP)
		  (AND (SETQ TEM (GET SYMBOL PROP))	;IF THIS ATOM HAS THIS PROPERTY,
		       (PROGN				;DUMP A DEFPROP TO BE EVALLED.
			(FASD-START-GROUP NIL 1 FASL-OP-TEMP-LIST)
			(FASD-NIBBLE 4)			;4 IS LENGTH OF THE DEFPROP FORM.
			(FASD-CONSTANT 'DEFPROP)	;DON'T USE FASD-FORM, SINCE WE
			(FASD-CONSTANT SYMBOL)		;WANT TO DETECT NEW SYMBOLS IN THE
			(FASD-CONSTANT-TRACING-SYMBOLS TEM NEW-SYMBOL-FUNCTION)
			(FASD-CONSTANT PROP)		;VALUE OF THE PROPERTY.
			(FASD-EVAL (FASD-TABLE-ADD `(DEFPROP ,SYMBOL ,TEM ,PROP)))))))
	      PROPERTIES))

(DEFUN FASD-CONSTANT-TRACING-SYMBOLS (OBJECT FASD-NEW-SYMBOL-FUNCTION)
    (FASD-CONSTANT OBJECT))

;Use this as the NEW-SYMBOL-FUNCTION, for nice results:
;All the substructures of the structures being dumped are also dumped.
(DEFUN FASD-SYMBOL-PUSH (SYMBOL)
    (OR (MEMQ SYMBOL FASD-SYMBOL-LIST)
        (MEMQ SYMBOL FASD-ALREADY-DUMPED-SYMBOL-LIST)
        (PUSH SYMBOL FASD-SYMBOL-LIST)))
