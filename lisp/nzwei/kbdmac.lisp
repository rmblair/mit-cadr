;;; ZWEI keyboard macros -*-MODE:LISP;PACKAGE:ZWEI-*-
;;; ** (c) Copyright 1980 Massachusetts Institute of Technology **

(DEFVAR MACRO-ESCAPE-CHAR #\BACK-NEXT)
(DEFVAR MACRO-STREAM)
(DEFVAR MACRO-LEVEL)
(DEFVAR MACRO-UNTYI)
(DEFVAR MACRO-LEVEL-ARRAY)
(DEFVAR MACRO-CURRENT-ARRAY)
(DEFVAR MACRO-PREVIOUS-ARRAY)
(DEFVAR MACRO-READING NIL)
(DEFVAR MACRO-REDIS-LEVEL -1)
(DEFVAR MACRO-OPERATIONS)

(DEFSTRUCT (MACRO-ARRAY ARRAY-LEADER (MAKE-ARRAY (NIL 'ART-Q 100)))
	   (MACRO-POSITION 0)		;Current position reading or writing
	   (MACRO-LENGTH 0)		;Length of macro
	   MACRO-COUNT			;Current repeat count for macro
	   MACRO-DEFAULT-COUNT		;Initial value of MACRO-COUNT, or NIL if writing
           MACRO-NAME)                  ;Name of macro as a string, or NIL if temporary.

;;; The following structure is used for the Backnext-A command.
;;; It is important that it be a LIST since that is how it is
;;; identified.
(DEFSTRUCT (MACRO-A LIST)
	   (MACRO-A-NAME '*A*)		;Symbol by which this is recognized.
	   MACRO-A-VALUE		;Current value of the character.
	   MACRO-A-STEP			;Number to increase VALUE by on each step.
	   MACRO-A-INITIAL-VALUE)	;Initial current-value given by user.

(DEFUN MAKE-MACRO-STREAM (STREAM)
  (LET-CLOSED ((MACRO-STREAM STREAM)
	       (MACRO-LEVEL -1)
	       (MACRO-UNTYI NIL)
	       (MACRO-LEVEL-ARRAY (MAKE-ARRAY NIL 'ART-Q 20))
	       (MACRO-CURRENT-ARRAY NIL)
	       (MACRO-PREVIOUS-ARRAY NIL)
	       (MACRO-OPERATIONS
		 (LET ((OPS (APPEND (FUNCALL STREAM ':WHICH-OPERATIONS) NIL)))
		   (MAPC #'(LAMBDA (X) (SETQ OPS (DELQ X OPS)))
			 '(:TYI :UNTYI :LISTEN :CLEAR-INPUT :MACRO-LEVEL :MACRO-ERROR
			   :MACRO-EXECUTE :LINE-IN :RUBOUT-HANDLER))
		   `(:TYI :UNTYI :LISTEN :CLEAR-INPUT :MACRO-LEVEL :MACRO-ERROR
		     :MACRO-EXECUTE :MACRO-PUSH :MACRO-POP :MACRO-QUERY :MACRO-PREVIOUS-ARRAY
		     . ,OPS))))
    #'MACRO-STREAM-IO))

(DEFSELECT (MACRO-STREAM-IO MACRO-STREAM-DEFAULT-HANDLER T)
  (:WHICH-OPERATIONS ()
   MACRO-OPERATIONS)
  (:UNTYI (CH)
   (SETQ MACRO-UNTYI CH))
  ((:TYI :ANY-TYI :MOUSE-OR-KBD-TYI
    :TYI-NO-HANG :ANY-TYI-NO-HANG :MOUSE-OR-KBD-TYI-NO-HANG) ()
   (COND (MACRO-UNTYI (PROG1 MACRO-UNTYI (SETQ MACRO-UNTYI NIL)))
	 (MACRO-READING
	  (MACRO-UPDATE-LEVEL)
	  (FUNCALL MACRO-STREAM SI:**DEFSELECT-OP**))
	 (T (MACRO-TYI SI:**DEFSELECT-OP**))))
  (:LISTEN ()
   (COND (MACRO-UNTYI T)
	 ((OR MACRO-READING
	      (NULL MACRO-CURRENT-ARRAY)
	      (NULL (MACRO-DEFAULT-COUNT MACRO-CURRENT-ARRAY))
	      (MEMQ (AREF MACRO-CURRENT-ARRAY (MACRO-POSITION MACRO-CURRENT-ARRAY))
		    '(*SPACE* *MOUSE* *MICE* NIL)))
	  (FUNCALL MACRO-STREAM ':LISTEN))
	 (T T)))
  (:MACRO-LEVEL ()
   (1+ MACRO-LEVEL))
  (:MACRO-ERROR ()			;Return T if we were playing back.
   (PROG1 (AND MACRO-CURRENT-ARRAY (MACRO-DEFAULT-COUNT MACRO-CURRENT-ARRAY))
	  (MACRO-STOP NIL)))
  (:CLEAR-INPUT ()
   (MACRO-STOP NIL)
   (FUNCALL MACRO-STREAM ':CLEAR-INPUT))
  (:MACRO-EXECUTE (&OPTIONAL ARRAY TIMES)
   (OR ARRAY (SETQ ARRAY MACRO-PREVIOUS-ARRAY))
   (MACRO-PUSH-LEVEL (MACRO-STORE ARRAY))
   (AND TIMES
	(SETF (MACRO-COUNT ARRAY) TIMES)))
  (:MACRO-PUSH (&OPTIONAL N)
   (AND MACRO-CURRENT-ARRAY		;Erase the command that caused this to happen
	N
	(SETF (MACRO-POSITION MACRO-CURRENT-ARRAY)
	      (- (MACRO-POSITION MACRO-CURRENT-ARRAY) N)))
   (MACRO-PUSH-LEVEL (MACRO-STORE)))
  (:MACRO-POP (&OPTIONAL N TIMES)
   (AND MACRO-CURRENT-ARRAY
	N
	(SETF (MACRO-POSITION MACRO-CURRENT-ARRAY)
	      (- (MACRO-POSITION MACRO-CURRENT-ARRAY) N)))
   (MACRO-REPEAT TIMES))
  (:MACRO-QUERY ()
   (MACRO-STORE '*SPACE*))
  (:MACRO-PREVIOUS-ARRAY ()
   MACRO-PREVIOUS-ARRAY))

(DEFUN MACRO-STREAM-DEFAULT-HANDLER (OP &REST REST)
  (IF (MEMQ OP MACRO-OPERATIONS)
      (LEXPR-FUNCALL MACRO-STREAM OP REST)
      (STREAM-DEFAULT-HANDLER 'MACRO-STREAM-IO OP (CAR REST) (CDR REST))))

(DEFUN MACRO-TYI (&OPTIONAL (OP ':TYI))
  (DO ((CH) (TEM) (NUMARG) (FLAG) (TEM2) (SUPPRESS))
      (())
   (*CATCH 'MACRO-LOOP
    (COND ((AND MACRO-CURRENT-ARRAY (SETQ TEM2 (MACRO-DEFAULT-COUNT MACRO-CURRENT-ARRAY)))
	   (SETQ TEM (MACRO-POSITION MACRO-CURRENT-ARRAY)
		 CH (AREF MACRO-CURRENT-ARRAY TEM))
	   (COND ((EQ CH '*SPACE*)
                  (SELECTQ (FUNCALL MACRO-STREAM ':TYI)
                   (#\SP
                    (SETQ CH '*IGNORE*))
                   ((#/? #\HELP)
                    (FORMAT T "~&You are in an interactive macro.
Space continues on, Rubout skips this one, Form refreshes the screen,
Control-R enters a typein macro level (Backnext R exits), anything else exits.")
                    (*THROW 'MACRO-LOOP NIL))
                   (#\RUBOUT
                    (SETQ TEM (MACRO-LENGTH MACRO-CURRENT-ARRAY)
                          CH '*IGNORE*))
                   ((#/R #/r)
                    (SETQ CH NIL))
                   (#\FF
                    (RETURN #\FF))
                   (#/. 
                    (SETF (MACRO-DEFAULT-COUNT MACRO-CURRENT-ARRAY) 0)
                    (SETF (MACRO-COUNT MACRO-CURRENT-ARRAY) 0)
                    (SETQ CH '*IGNORE*))
                   (#/!
                    (ASET '*RUN* MACRO-CURRENT-ARRAY TEM)
                    (SETQ CH '*IGNORE*))
                   (OTHERWISE
                    (MACRO-STOP 1)
                    (*THROW 'MACRO-LOOP NIL))))
		 ((MEMQ CH '(*MOUSE* *MICE*))
		  (AND (EQ CH '*MOUSE*) (FORMAT T "~&Use the mouse.~%"))
		  (SETQ CH (FUNCALL MACRO-STREAM ':MOUSE-OR-KBD-TYI))
		  (COND ((LDB-TEST %%KBD-MOUSE CH)
			 (ASET '*MICE* MACRO-CURRENT-ARRAY TEM)
			 (RETURN CH))
			(T
			 (ASET '*MOUSE* MACRO-CURRENT-ARRAY TEM)
			 (SETQ CH '*IGNORE*)))))
           (COND ((AND (ZEROP TEM)
		       (EQ TEM2 '*REPEAT*)
		       (MEMQ ':MACRO-TERMINATE MACRO-OPERATIONS)
		       (FUNCALL MACRO-STREAM ':MACRO-TERMINATE))
		  (COND (( (SETQ MACRO-LEVEL (1- MACRO-LEVEL)) 0)
			 (SETQ MACRO-CURRENT-ARRAY
			       (AREF MACRO-LEVEL-ARRAY MACRO-LEVEL)))
			(T
			 (SETQ MACRO-CURRENT-ARRAY NIL))))
		 ((< TEM (MACRO-LENGTH MACRO-CURRENT-ARRAY))
		  (SETF (MACRO-POSITION MACRO-CURRENT-ARRAY) (1+ TEM)))
		 ((EQ TEM2 '*REPEAT*)
		  (SETF (MACRO-POSITION MACRO-CURRENT-ARRAY) 0))
		 ((> (SETQ TEM (1- (MACRO-COUNT MACRO-CURRENT-ARRAY))) 0)
		  (SETF (MACRO-COUNT MACRO-CURRENT-ARRAY) TEM)
                  (SETF (MACRO-POSITION MACRO-CURRENT-ARRAY) 0))
		 (( (SETQ MACRO-LEVEL (1- MACRO-LEVEL)) 0)
		  (SETQ MACRO-CURRENT-ARRAY (AREF MACRO-LEVEL-ARRAY MACRO-LEVEL)))
		 (T
		  (SETQ MACRO-CURRENT-ARRAY NIL)))
	   (COND ((NUMBERP CH) (OR SUPPRESS (RETURN CH)))
                 ((MEMQ CH '(*RUN* *IGNORE*)))
		 ((AND (LISTP CH) (EQ (CAR CH) '*A*))
		  (LET ((X (MACRO-A-VALUE CH)))
		    (SETF (MACRO-A-VALUE CH) (+ X (MACRO-A-STEP CH)))
		    (OR SUPPRESS (RETURN X))))
		 (T (MACRO-PUSH-LEVEL CH))))
	  (T
	   (MACRO-UPDATE-LEVEL)
	   (MULTIPLE-VALUE (CH TEM) (FUNCALL MACRO-STREAM OP))
	   (COND (FLAG
		  (SETQ CH (CHAR-UPCASE CH))
		  (COND ((AND ( CH #/0) ( CH #/9))
			 (SETQ NUMARG (+ (- CH #/0) (* (OR NUMARG 0) 10.))))
			(T
			 (SETQ FLAG NIL)
			 (SELECTQ CH
			   (#/C
			    (SETQ TEM (MACRO-DO-READ "Macro to call: "))
			    (OR (SETQ TEM (GET TEM 'MACRO-STREAM-MACRO)) (MACRO-BARF))
			    (MACRO-STORE TEM)
			    (OR SUPPRESS (MACRO-PUSH-LEVEL TEM)))
			   (#/D
			    (SETQ SUPPRESS MACRO-LEVEL)
			    (MACRO-PUSH-LEVEL (MACRO-MAKE-NAMED-MACRO)))
			   (#/M
			    (MACRO-PUSH-LEVEL (MACRO-STORE (MACRO-MAKE-NAMED-MACRO))))
			   (#/P
			    (MACRO-PUSH-LEVEL (MACRO-STORE)))
			   (#/R
			    (MACRO-REPEAT NUMARG)
			    (AND (EQ SUPPRESS MACRO-LEVEL) (SETQ SUPPRESS NIL)))
			   (#/S
                            (MACRO-STOP NUMARG))
			   (#/T
			    (MACRO-PUSH-LEVEL (MACRO-STORE NIL)))
			   (#/U
			    (MACRO-PUSH-LEVEL NIL))
                           (#\SP
                            (MACRO-STORE '*SPACE*))
			   (#/A
			    (LET ((STR (MACRO-READ-STRING
				         "Initial character (type a one-character string):")))
			      (OR (= (STRING-LENGTH STR) 1) (MACRO-BARF))
			      (LET ((VAL (AREF STR 0))
				    (NUM (MACRO-READ-NUMBER
                                  "Amount by which to increase it (type a decimal number):")))
				(MACRO-STORE (MAKE-MACRO-A MACRO-A-VALUE (+ VAL NUM)
							   MACRO-A-STEP NUM
							   MACRO-A-INITIAL-VALUE VAL))
				(OR SUPPRESS (RETURN VAL)))))
                           (#\HELP
			    (FORMAT T "~&Macro commands are:
P push a level of macro, R end and repeat arg times, C call a macro by name,
S stop macro definition, U allow typein now only, T allow typein in expansion too.
M define a named macro, D define a named macro but don't execute as building.
Space enter macro query, A store an increasing character string.")
			    (SETQ FLAG T))
			   (OTHERWISE
			    (MACRO-BARF))))))
		 ((EQ CH MACRO-ESCAPE-CHAR)
		  (SETQ FLAG T NUMARG NIL))
		 (T
		  (AND (NUMBERP CH) (MACRO-STORE (IF (LDB-TEST %%KBD-MOUSE CH) '*MOUSE* CH)))
		  (OR SUPPRESS (RETURN CH TEM)))))))))

(DEFUN MACRO-PUSH-LEVEL (MAC)
  (COND (MAC
	  (AND (SYMBOLP MAC) (SETQ MAC (GET MAC 'MACRO-STREAM-MACRO)))
	  (OR (ARRAYP MAC) (MACRO-BARF))))
  (SETQ MACRO-LEVEL (1+ MACRO-LEVEL)
	MACRO-CURRENT-ARRAY MAC)
  (ASET MAC MACRO-LEVEL-ARRAY MACRO-LEVEL)
  (COND (MAC
	  (SETF (MACRO-POSITION MAC) 0)
	  (SETF (MACRO-COUNT MAC) (MACRO-DEFAULT-COUNT MAC))
	  (DO ((I 0 (1+ I))
	       (X)
	       (LIM (MACRO-LENGTH MAC)))
	      ((> I LIM))
	    (SETQ X (AREF MAC I))
	    (COND ((EQ '*RUN* X)
		   (ASET '*SPACE* MAC I))
		  ((EQ '*MICE* X)
		   (ASET '*MOUSE* MAC I))
		  ((AND (LISTP X) (EQ (CAR X) '*A*))
		   (SETF (MACRO-A-VALUE X) (MACRO-A-INITIAL-VALUE X)))
		  )))))

(DEFUN MACRO-STORE (&OPTIONAL (THING T))
  (AND (EQ THING T) (SETQ THING (MAKE-MACRO-ARRAY)))
  (AND MACRO-CURRENT-ARRAY (ARRAY-PUSH-EXTEND MACRO-CURRENT-ARRAY THING))
  THING)

(DEFUN MACRO-BARF ()
  (BEEP)
  (*THROW 'MACRO-LOOP NIL))

(DEFUN MACRO-REPEAT (ARG &AUX (TEM -1))
  (AND (< MACRO-LEVEL 0) (MACRO-BARF))
  (COND (MACRO-CURRENT-ARRAY
	  (OR ARG (SETQ ARG '*REPEAT*))
	  (SETF (MACRO-DEFAULT-COUNT MACRO-CURRENT-ARRAY) ARG)
	  (SETQ TEM (1- (MACRO-POSITION MACRO-CURRENT-ARRAY)))
	  (SETF (MACRO-LENGTH MACRO-CURRENT-ARRAY) TEM)
	  (SETQ MACRO-PREVIOUS-ARRAY MACRO-CURRENT-ARRAY)))
  (COND ((AND ( TEM 0) (NUMBERP ARG) (> ARG 1))
	 (SETF (MACRO-POSITION MACRO-CURRENT-ARRAY) 0)
	 (SETF (MACRO-COUNT MACRO-CURRENT-ARRAY) (1- ARG)))
	((EQ ARG '*REPEAT*)
	 (SETF (MACRO-POSITION MACRO-CURRENT-ARRAY) 0))
	(( (SETQ MACRO-LEVEL (1- MACRO-LEVEL)) 0)
	 (SETQ MACRO-CURRENT-ARRAY
	       (AREF MACRO-LEVEL-ARRAY MACRO-LEVEL)))
	(T (SETQ MACRO-CURRENT-ARRAY NIL))))

(DEFUN MACRO-MAKE-NAMED-MACRO (&AUX TEM MAC)
  (SETQ TEM (MACRO-DO-READ "Name of macro to define: "))
  (OR (SYMBOLP TEM) (MACRO-BARF))
  (SETQ MAC (MAKE-MACRO-ARRAY))
  (PUTPROP TEM MAC 'MACRO-STREAM-MACRO)
  (SETF (MACRO-NAME MAC) (STRING TEM))
  MAC)

(DEFUN MACRO-READ-STRING (STR &AUX (MACRO-READING T) (MACRO-REDIS-LEVEL -1))
  (IF (MEMQ ':READ-MACRO-LINE MACRO-OPERATIONS)
      (FUNCALL MACRO-STREAM ':READ-MACRO-LINE STR)
      (PRINC STR MACRO-STREAM)
      (READLINE MACRO-STREAM)))

(DEFUN MACRO-DO-READ (STR)
  (INTERN (STRING-UPCASE (STRING-TRIM '(#\SP #\TAB) (MACRO-READ-STRING STR)))
	  ""))

(DEFUN MACRO-READ-NUMBER (STR)
  (LET ((NUM (READ-FROM-STRING (MACRO-READ-STRING STR))))
    (OR (NUMBERP NUM) (MACRO-BARF))
    NUM))

(DEFUN MACRO-STOP (NUM)
  (SETQ MACRO-LEVEL (MAX -1 (- MACRO-LEVEL (OR NUM 20)))
	MACRO-CURRENT-ARRAY (AND ( MACRO-LEVEL 0)
				 (AREF MACRO-LEVEL-ARRAY MACRO-LEVEL))))

(DEFUN MACRO-UPDATE-LEVEL ()
  (COND ((AND ( MACRO-LEVEL MACRO-REDIS-LEVEL) (MEMQ ':SET-MACRO-LEVEL MACRO-OPERATIONS))
	 (SETQ MACRO-REDIS-LEVEL MACRO-LEVEL)
	 (FUNCALL MACRO-STREAM ':SET-MACRO-LEVEL
		  (AND (NOT (MINUSP MACRO-LEVEL))
		       (FORMAT NIL "~D" (1+ MACRO-LEVEL)))))))

;;; Handy things for saving out macros on disk and editing them
(DEFMACRO DEFINE-KEYBOARD-MACRO (NAME (COUNT) . EXPANSION)
  `(DEFINE-KEYBOARD-MACRO-1 ',NAME ,(OR COUNT 1) ',(COPYLIST EXPANSION)))

(DEFUN DEFINE-KEYBOARD-MACRO-1 (NAME COUNT EXPANSION &AUX MACRO-ARRAY (LEN 0) STRING)
  (SETQ STRING (STRING NAME)
	NAME (INTERN STRING ""))
  (DOLIST (THING EXPANSION)
    (IF (STRINGP THING)
	(SETQ LEN (+ LEN (STRING-LENGTH THING)))
	(SETQ LEN (1+ LEN))))
  (SETQ MACRO-ARRAY (MAKE-MACRO-ARRAY MAKE-ARRAY (NIL 'ART-Q LEN)
				      MACRO-LENGTH (1- LEN)
				      MACRO-DEFAULT-COUNT COUNT
				      MACRO-NAME STRING))
  (DOLIST (THING EXPANSION)
    (IF (STRINGP THING)
	(APPEND-TO-ARRAY MACRO-ARRAY THING)
	(COND ((NUMBERP THING))
	      ((STRING-EQUAL THING '*INPUT*)
	       (SETQ THING NIL))
	      ((STRING-EQUAL THING '*SPACE*)
	       (SETQ THING '*SPACE*))
	      ((STRING-EQUAL THING '*MOUSE*)
	       (SETQ THING '*MOUSE*))
	      ((STRING-EQUAL THING '*MICE*)
	       (SETQ THING '*MICE*))
	      (T
	       (FERROR NIL "~S is not a known macro expansion element." THING)))
	(ARRAY-PUSH MACRO-ARRAY THING)))
  (PUTPROP NAME MACRO-ARRAY 'MACRO-STREAM-MACRO)
  NAME)

(DEFUN PRINT-KEYBOARD-MACRO-DEFINITION (STREAM NAME &OPTIONAL MACRO-ARRAY)
  (LET ((PACKAGE (PKG-FIND-PACKAGE "ZWEI"))
	(BASE 'CHARACTER))
    (SI:GRIND-TOP-LEVEL (GET-KEYBOARD-MACRO-DEFINITION NAME MACRO-ARRAY) 95. STREAM)))

(DEFUN GET-KEYBOARD-MACRO-DEFINITION (NAME MACRO-ARRAY)
  (OR MACRO-ARRAY (SETQ MACRO-ARRAY (GET NAME 'MACRO-STREAM-MACRO)))
  (SETQ NAME (INTERN NAME "ZWEI"))
  (DO ((I 0 (1+ I))
       (LEN (1+ (MACRO-LENGTH MACRO-ARRAY)))
       (THING)
       (STATE NIL)
       (LIST NIL)
       (STRING (MAKE-ARRAY NIL 'ART-STRING 10. NIL 1)))
      (( I LEN)
       `(DEFINE-KEYBOARD-MACRO ,NAME () . ,(NREVERSE LIST)))
    (SETQ THING (AREF MACRO-ARRAY I))
    (COND ((OR (SYMBOLP THING) (LDB-TEST %%KBD-CONTROL-META THING))
	   (COND (STATE
		  (PUSH (STRING-APPEND STRING) LIST)
		  (SETQ STATE NIL)))
	   (COND ((NUMBERP THING))
		 ((NULL THING)
		  (SETQ THING '*INPUT*)))
	   (PUSH THING LIST))
	  (T
	   (COND ((NOT STATE)
		  (STORE-ARRAY-LEADER 0 STRING 0)
		  (SETQ STATE T)))
	   (ARRAY-PUSH-EXTEND STRING THING)))))

(DEFUN (CHARACTER SI:PRINC-FUNCTION) (-N STREAM)
  (FORMAT STREAM "~@C" (- -N)))