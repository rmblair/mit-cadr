;;;-*-LISP-*-
;	** (c) Copyright 1980 Massachusetts Institute of Technology **
(DEFUN QUOTED-ARGS FEXPR (L) (MAPCAR (FUNCTION (LAMBDA (X) 
				(PUTPROP X '((1005 (FEF-ARG-OPT FEF-QT-QT))) 'ARGDESC))) L))

(DEFUN CLOSED FEXPR (IGNORE) NIL)
(DEFUN NOTYPE FEXPR (IGNORE) NIL)
(DEFUN FIXNUM FEXPR (IGNORE) NIL)
(DEFUN ARRAY* FEXPR (IGNORE) NIL)

(DEFUN GENPREFIX FEXPR (IGNORE) NIL)
(DEFUN EXPR-HASH FEXPR (IGNORE) NIL)

(IF-IN-MACLISP
(ADD-OPTIMIZER CATCH CATCH-MACRO)
(DEFUN CATCH-MACRO (X)
  ((LAMBDA (EXP TAG)
    `(*CATCH ',TAG ,EXP))
   (CADR X)
   (CADDR X)))

(ADD-OPTIMIZER THROW THROW-MACRO)
(DEFUN THROW-MACRO (X)
	((LAMBDA (EXP TAG)
	  `(*THROW ',TAG ,EXP))
	(CADR X)
	(CADDR X))))

(DEFUN LIST-ASSQ (ITEM IN-LIST)
  (PROG NIL 
    L	(COND ((NULL IN-LIST) (RETURN NIL))
	      ((EQ ITEM (CAR IN-LIST))
		(RETURN (CADR IN-LIST))))
	(SETQ IN-LIST (CDDR IN-LIST))
	(GO L)))

(DECLARE (SPECIAL **INDICATOR**))
(DEFUN ALLREMPROP (**INDICATOR**)
 (MAPATOMS (FUNCTION (LAMBDA (X) (REMPROP X **INDICATOR**)))))

(DEFUN INCLUDE (&QUOTE &REST IGNORE))

;(DEFMACRO ARRAYCALL (ARRAY-TYPE ARRAY &REST ARGS)
;  `(FUNCALL ,ARRAY . ,ARGS))

(DEFUN SLEEP (X)
  (PROCESS-SLEEP (FIX (* X 60.))))
