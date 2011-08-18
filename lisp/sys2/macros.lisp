;; -*-LISP-*-

;	** (c) Copyright 1980 Massachusetts Institute of Technology **

;; This file is not readable with lmlisp.
;; This is only read by MACLISP programs.  The macros that are
;; part of the LM system have been moved to the file 
;; LISPM2;LMMAC >.
;; If you try to either read this file into the lisp machine,
;; or to compile it, you will lose so badly you will not believe it.

;TEMPORARY FOR WHILE COMPILER IS RUNNING IN MACLISP
(SETSYNTAX '/" 'MACRO '(LAMBDA ()
    (PROG (STR CH)
	A (COND ((= 42 (SETQ CH (TYI)))
		 (RETURN (LIST '**STRING** (IMPLODE (NREVERSE STR)))))
		((= 57 CH)
		 (SETQ CH (TYI)))
		((= CH 12) (GO A)))	;FLUSH LINEFEED
	  (SETQ STR (CONS CH STR))
	  (GO A))))

(DEFUN **STRING** MACRO (X) (LIST 'QUOTE X))   ;MAKE STRINGS SELF-EVALUATE IN MACLISP

;#Q <SEXP> or #q <SEXP> MAKES SEXP EXIST FOR LISPM VERSION
;#M <SEXP> or #m <SEXP> MAKES SEXP EXIST FOR MACLISP VERSION

;#+<FEATURE> <SEXP> makes <SEXP> exist if (STATUS FEATURE <FEATURE>) is T
;#+(NOT <FEATURE>) <SEXP> makes <SEXP> exist if (STATUS FEATURE <FEATURE>) is NIL
;#+(OR F1 F2 ...) <SEXP> makes <SEXP> exist of any one of F1,F2,... are in
;			 the (STATUS FEATURES) list.
;#+(AND F1 F2 ...) works similarly except all must be present in the list.
;#-<FEATURE> <SEXP> is the same as #+(NOT <FEATURE>)
;AND, OR, and NOT can be used recursively following #+ or #-.

;## CH IS OLD WAY OF GETTING NUMERICAL CHARACTER CODES -- SPACE AFTER "##"
;   IS NEEDED
;#/CH IS NEW WAY OF GETTING NUMERICAL CHARACTER CODES
;#\SYMBOL GETS NUMERICAL CHARACTER CODES FOR NON-PRINTING CHARACTERS
;#' IS TO FUNCTION AS ' IS TO QUOTE
;#, IS HAIRY EVALED CONSTANT FEATURE

(SETSYNTAX '/# 'SPLICING '(LAMBDA ()
  (PROG (TO-MODE IN-MODE CH FROB SHARP-ARG)
	(SETQ SHARP-ARG 0)
     MORE
	(SETQ CH (TYI))
	(COND ((MEMBER CH '(60 61 62 63 64 65 66 67 70 71))
	       (SETQ SHARP-ARG (+ (* SHARP-ARG 10.) (- CH 60)))
	       (GO MORE))
	      ((MEMBER CH '(2 3 6))
	       (SETQ SHARP-ARG (COND ((= CH 2) 1) ((= CH 3) 2) (T 6)))
	       (GO MORE))
	      ((OR (= CH 121)			;Q
		   (= CH 161))			;q
	       (SETQ TO-MODE 'LISPM))
	      ((OR (= CH 115)		        ;M
		   (= CH 155))			;m
		(SETQ TO-MODE 'MACLISP))

	      ((= CH 53)			;+
	       (SETQ FROB (READ))
	       (COND ((NOT (FEATURE-PRESENT FROB)) (READ)))
	       (RETURN NIL))

	      ((= CH 55)			;-
	       (SETQ FROB (READ))
	       (COND ((FEATURE-PRESENT FROB) (READ)))
	       (RETURN NIL))

	      ((= CH 43)			;#
		(TYI)				;FLUSH FOLLOWING SPACE
		(RETURN (LIST (TYI))))		;RETURN NUMERIC VALUE OF CHAR
						;LIST BECAUSE SPLICING
	      ((= CH 57)			;/
	       (RETURN (LIST (+ (LSH SHARP-ARG 8) (TYI))))) ;RETURN NUMERIC VALUE OF CHAR
						;LIST BECAUSE SPLICING
	      ((= CH 47)			;'
	       (RETURN (LIST (LIST 'FUNCTION (READ)))))
	      ((= CH 54)			;,
	       (RETURN (LIST (COND ((AND (BOUNDP 'QC-FILE-READ-IN-PROGRESS)
					 QC-FILE-READ-IN-PROGRESS)
				    (CONS '**EXECUTION-CONTEXT-EVAL** (READ)))
				   (T (EVAL (READ)))))))
	      ((= CH 134)			;\
	       (SETQ FROB (READ))		;Get symbolic name of character
	       (SETQ CH
		     (CDR (ASSQ FROB
				(COND ((AND (BOUNDP 'COMPILING-FOR-LISPM)
					    COMPILING-FOR-LISPM)
				       LISPM-SYMBOLIC-CHARACTER-NAMES)
				      (T MACLISP-SYMBOLIC-CHARACTER-NAMES)))))
	       (OR CH (ERROR '|Illegal character name in #\| FROB))
	       (RETURN (LIST (+ (LSH SHARP-ARG 8) CH))))

	      (T (ERROR '|bad character after #| (ASCII CH))))

	(SETQ IN-MODE 
	      (COND ((AND (BOUNDP 'COMPILING-FOR-LISPM) COMPILING-FOR-LISPM)
		     'LISPM)
		    (T 'MACLISP)))
	(OR (EQ TO-MODE IN-MODE)
	    (READ))
	(RETURN NIL))))

(EVAL-WHEN (EVAL LOAD COMPILE)

(SETQ MACLISP-SYMBOLIC-CHARACTER-NAMES
      '((BS . 10) (BACKSPACE . 10)
        (TAB . 11) (LF . 12) (LINEFEED . 12)
	(FF . 14) (FORM . 14) (RETURN . 15) (CR . 15)
	(ALT . 33) (ESC . 33)
	(SP . 40) (SPACE . 40)
	(RUBOUT . 177) (HELP . 4110)))

(SETQ LISPM-SYMBOLIC-CHARACTER-NAMES
      '( (BRK . 201) (BREAK . 201)
	 (CLR . 202) (CLEAR . 202)
	 (CALL . 203) (ESC . 204) (ESCAPE . 204)
	 (BACK-NEXT . 205) (HELP . 206)
	 (RUBOUT . 207) (BS . 210) (TAB . 211)
	 (LF . 212) (LINE . 212) (LINEFEED . 212)
	 (VT . 213) (FF . 214) (FORM . 214)
	 (CR . 215) (RETURN . 215)
	 (SP . 40) (SPACE . 40) (ALT . 33)
	 (LAMBDA . 10) (GAMMA . 11) (DELTA . 12)
	 (UPARROW . 13) (PLUS-MINUS . 14)
	 (CIRCLE-PLUS . 15) (INTEGRAL . 177)
	 (NULL . 200) (BACKSPACE . 210)
	 (MOUSE-1-1 . 2000) (MOUSE-1-2 . 2010)
	 (MOUSE-2-1 . 2001) (MOUSE-2-2 . 2011)
	 (MOUSE-3-1 . 2002) (MOUSE-3-2 . 2012)))

(DEFUN FEATURE-PRESENT (FEATURE)
       (COND ((ATOM FEATURE)
	      (COND ((NULL FEATURE) NIL)
		    ((EQ FEATURE T) T)
		    ((MEMQ FEATURE (STATUS FEATURES)) T)
		    (T NIL)))
	     ((EQ (CAR FEATURE) 'NOT)
	      (NOT (FEATURE-PRESENT (CADR FEATURE))))
	     ((EQ (CAR FEATURE) 'AND)
	      (DO ((LIST (CDR FEATURE) (CDR LIST)))
		  ((NULL LIST) T)
		  (COND ((NOT (FEATURE-PRESENT (CAR LIST)))
			 (RETURN NIL)))))
	     ((EQ (CAR FEATURE) 'OR)
	      (DO ((LIST (CDR FEATURE) (CDR LIST)))
		  ((NULL LIST) NIL)
		  (COND ((FEATURE-PRESENT (CAR LIST))
			 (RETURN T)))))
	     (T (ERROR '|unknown form after #+ or #-| FEATURE 'FAIL-ACT))))

) ;;End of EVAL-WHEN

; SOME RANDOM MACROS

;  NOTES-
;  MACRO, DEFINED IN HERE, IS A FUNCTION TO CREATE A MACRO WHICH GETS
;  KNOWN TO BOTH MACLISP AND LISP MACHINE.  DEFMACRO, DEFINED IN LISPM2;DEFMAC >, 
;  IS A MACRO WHICH IS USEFUL WITH THE ` READER MACRO.  Note that the MacLisp
;  version of MACRO cannot handle &MUMBLE keywords in the bound variable list.

(SETQ MACROS-TO-BE-SENT-OVER NIL)
(SETQ SAVE-MACROS-FOR-SENDING-OVER-SWITCH T)

;  THIS FUNCTION RUNS ONLY IN MACLISP.  THE CORRESPONDING ONE FOR THE LISP
;  MACHINE IS DEFINED IN QFCTNS.  THIS VERSION IS FOR QMOD WHEN RUNNING IN
;  MACLISP, EITHER FOR QC-FILE OR FOR QC OR FOR MAKE-COLD.  IT CANNOT EXPAND
;  INTO A DEFUN, SINCE THE COMPILE-DRIVER MIGHT EXPAND THAT INTO MACRO, CAUSING
;  AN INFINITE LOOP.

(COND ((GET 'MACRO 'MACRO))
      ((NOT (MEMQ COMPILER-STATE '(MAKLAP DECLARE COMPILE)))
(DEFUN MACRO FEXPR (X)	;(MACRO FOO (X) ... )  ;THIS ONLY WORKS IN LISP 1633 & >
  (PUTPROP (CAR X) (CONS 'LAMBDA (CDR X)) 'MACRO)
  (COND (SAVE-MACROS-FOR-SENDING-OVER-SWITCH 
	 (COND ((AND (BOUNDP 'QC-FILE-IN-PROGRESS)  ;DOING A QC-FILE, PUT IT THERE.
		      QC-FILE-IN-PROGRESS)
		 (SETQ QC-FILE-MACRO-LIST (CONS (CONS 'MACRO X) QC-FILE-MACRO-LIST)))
		(T (SETQ MACROS-TO-BE-SENT-OVER (CONS (CONS (CAR X)
							    (CONS 'LAMBDA (CDR X)))
						      MACROS-TO-BE-SENT-OVER)))) ))
  (CAR X))
)
     (T

;  THIS VERSION IS FOR QCOMPLR.  WHEN CHOMPHOOK EXISTS, MAYBE IT SHOULD BE
;  CHANGED TO USE THAT INSTEAD?  THIS VERSION EXPANDS INTO DEFUN, WHICH IS THE
;  ONLY WAY TO GET CMP1 TO RECOGNIZE AND DO THE RIGHT THING.  FOR THE SAME
;  REASON, THIS VERSION MUST BE A MACRO.

(DEFUN MACRO MACRO (X)
       `(DEFUN ,(CADR X) MACRO . ,(CDDR X)))

)) ;END OF STRANGE COND

;  THIS FUNCTION RUNS ONLY IN MACLISP.  THE CORRESPONDING ONE FOR THE LISP
;  MACHINE IS DEFINED IN QFCTNS.

(DEFUN SEND-OVER-MACRO FEXPR (X)               ;SAME AS MACRO, EXCEPT DOESNT DEFINE IT IN 
  (COND (SAVE-MACROS-FOR-SENDING-OVER-SWITCH   ; MACLISP.  USEFUL IF NECC TO HAVE SEPARATE
	  (SETQ MACROS-TO-BE-SENT-OVER (CONS (CONS (CAR X)  ;VERSION OF MACRO FOR MACLISP
					   (CONS 'LAMBDA (CDR X)))  ;AND LISPM
				     MACROS-TO-BE-SENT-OVER)) ))
  (CAR X))

;  THIS FUNCTION RUNS ONLY IN MACLISP.  THE CORRESPONDING ONE FOR THE LISP
;  MACHINE IS DEFINED IN QFCTNS.

(DEFUN MACLISP-MACRO FEXPR (X)   	      ;SAME AS MACRO, BUT ONLY DEFINES IT IN MACLISP
    (PUTPROP (CAR X) (CONS 'LAMBDA (CDR X)) 'MACRO)
    (CAR X))

;THIS IS FOR SETF.
;MACROEXPAND X ONCE, IF POSSIBLE.  IF IT ISN'T A MACRO INVOCATION, RETURN IT UNCHANGED.
(AND (NOT (GET 'MACROEXAPND-1 'SUBR))
     (NOT (GET 'MACROEXAPND-1 'AUTOLOAD))
     (DEFUN MACROEXPAND-1 (X)
	    (PROG (TM)
		  (AND (NOT (ATOM X))
		       (ATOM (CAR X))
		       (SETQ TM (GET (CAR X) 'MACRO))
		       (RETURN (FUNCALL TM X)))
		  (RETURN X))))

;  These aren't in MacLisp.

(DEFUN PROG1 MACRO (FORM)
       `(PROG2 NIL . ,(CDR FORM)))

(DEFUN LOGAND MACRO (FORM)
       `(BOOLE 1 . ,(CDR FORM)))

(DEFUN LOGIOR MACRO (FORM)
       `(BOOLE 7 . ,(CDR FORM)))

(DEFUN LOGXOR MACRO (FORM)
       `(BOOLE 6 . ,(CDR FORM)))

(DEFUN SETQ-IF-UNBOUND FEXPR (*X*)	;FOR DEFVAR
  (OR (BOUNDP (CAR *X*))
      (SET (CAR *X*) (EVAL (CADR *X*)))))

(DEFUN RECORD-SOURCE-FILE-NAME (IGNORE)
       NIL)