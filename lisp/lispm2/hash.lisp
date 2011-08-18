; -*- Mode:Lisp; Package:System-Internals; Base:8 -*-

;A hash-table is an array whose leader is described by the following defstruct.
;It is used to associate keys with values.
;The array portion of the array is divided into 16.-element blocks.  The first
;8 locations are 8 keys that hash to the same place and the second 8 locations
;are their corresponding values.
;A DTP-NULL is used in the table in the key position to mark an empty slot.
;Unlike the case in Interlisp and in the first version of this package,
;NIL is not treated any differently than any other object.
;DESCRIBE of a hash-table will tell you all about it.
;Some of the function names are the same as in Interlisp.

;Note that all hash-table operations, even GETHASH, can modify the hash-table
;because they may discover a need to rehash.  Therefore it is the user's
;responsibility to ensure that the same hash-table is not referenced
;simultaneously by more than one process.

;This is temporary until this really exists
(DEFSUBST %P-CONTENTS-EQ (P X) (AND (NEQ (%P-DATA-TYPE P) DTP-NULL)
				    (EQ (CAR P) X)))

(DEFSTRUCT (HASH-TABLE :NAMED :ARRAY-LEADER (:CONSTRUCTOR MAKE-HASH-TABLE-INTERNAL))
    (HASH-TABLE-REHASH-FUNCTION 'HASH-TABLE-REHASH)
	;A function when rehash is required.  First argument is the hash-table,
	;second is NIL to just rehash or the rehash-size to grow it first.
	;The function must return the hash-table (which may have been moved
	;by adjust-array-size)
    (HASH-TABLE-REHASH-SIZE 1.3)
	;How much to grow by when the time comes.  A flonum is the ratio to
	;increase by, a fixnum is the number of entries to add.
	;These will get rounded up to the next appropriate size.
		;flonum = ratio to rehash up by
    (HASH-TABLE-GC-GENERATION-NUMBER %GC-GENERATION-NUMBER)
	;Used to decide when rehash required because the GC may have moved
	;some objects, changing their %POINTER and hence their hash code.
    HASH-TABLE-MODULUS
	;The number of 16.-element blocks.  Used for remainder to get hash code.
    (HASH-TABLE-FULLNESS 0))
	;The number of valid entries currently in the array.

(DEFUN MAKE-HASH-TABLE (&REST OPTIONS &AUX (SIZE 100) AREA HT
					   (RHF 'HASH-TABLE-REHASH) (RHS 1.3))
  (DO L OPTIONS (CDDR L) (NULL L)
      (SELECTQ (CAR L)
	(:SIZE (SETQ SIZE (CADR L)))		;Number of associations room for
	(:AREA (SETQ AREA (CADR L)))
	(:REHASH-FUNCTION (SETQ RHF (CADR L)))
	(:REHASH-SIZE (SETQ RHS (CADR L)))
	(OTHERWISE (FERROR NIL "~S not a recognized option" (CAR L)))))
  (SETQ SIZE (HASH-TABLE-GOOD-SIZE (* SIZE 2)))
  (SETQ HT (MAKE-HASH-TABLE-INTERNAL :MAKE-ARRAY (:LENGTH SIZE :AREA AREA)
				     HASH-TABLE-MODULUS (// SIZE 16.)
				     HASH-TABLE-REHASH-FUNCTION RHF
				     HASH-TABLE-REHASH-SIZE RHS))
  (CLRHASH HT))

;Convert SIZE (a number of array elements) to a more-or-less prime multiple of 16.
(DEFUN HASH-TABLE-GOOD-SIZE (SIZE)
  (SETQ SIZE (// (+ SIZE 15.) 16.))		;Next higher multiple of 16.
  (OR (ODDP SIZE) (SETQ SIZE (1+ SIZE)))	;Find next higher more-or-less prime
  (DO () ((AND (NOT (ZEROP (\ SIZE 3)))
	       (NOT (ZEROP (\ SIZE 5)))
	       (NOT (ZEROP (\ SIZE 7)))))
    (SETQ SIZE (+ SIZE 2)))
  (* SIZE 16.))

;Given a supposed hash-table that was passed into the package as an argument,
;make sure that it really is one and return the real array (there might be
;structure-forwarding due to rehashing.)
(DEFUN GET-REAL-HASH-TABLE (HASH-TABLE &AUX HDR)
  (CHECK-ARG HASH-TABLE (AND (= (%DATA-TYPE HASH-TABLE) DTP-ARRAY-POINTER)
			     (= (LDB %%ARRAY-NAMED-STRUCTURE-FLAG
				     (SETQ HDR (%P-LDB-OFFSET %%Q-POINTER HASH-TABLE 0)))
				1)
			     (EQ (ARRAY-LEADER HASH-TABLE 1) 'HASH-TABLE)
			     (= (LDB %%ARRAY-NUMBER-DIMENSIONS HDR) 1))
	     "a hash table")
  (FOLLOW-STRUCTURE-FORWARDING HASH-TABLE))

(DEFUN CLRHASH (HASH-TABLE)
  (SETQ HASH-TABLE (GET-REAL-HASH-TABLE HASH-TABLE))
  (COPY-ARRAY-PORTION HASH-TABLE 0 0 HASH-TABLE 0 (ARRAY-LENGTH HASH-TABLE))  ;Fill with NIL
  (DO ((I 0 (1+ I))				;Fill key positions with dtp-nulls
       (N (ARRAY-LENGTH HASH-TABLE)))
      (( I N))
    (IF (EVENP (// I 8))
	(%P-STORE-TAG-AND-POINTER (ALOC HASH-TABLE I) DTP-NULL 0)
	(SETQ I (+ I 7))))
  (SETF (HASH-TABLE-FULLNESS HASH-TABLE) 0)
  (SETF (HASH-TABLE-GC-GENERATION-NUMBER HASH-TABLE) %GC-GENERATION-NUMBER)
  HASH-TABLE)

;Given a hash-table and a key, return a locative to the start
;of the block in the array which may contain an association from that key.
;Cannot use ALOC because it gets an error if there is a DTP-NULL in the array.
(DEFUN HASH-BLOCK-POINTER (HASH-TABLE KEY)
  (AND (MINUSP (SETQ KEY (%POINTER KEY)))
       (SETQ KEY (+ 1_24. KEY)))		;Make sure it's positive
  (%MAKE-POINTER-OFFSET DTP-LOCATIVE HASH-TABLE
			(+ (* (\ KEY (HASH-TABLE-MODULUS HASH-TABLE)) 16.)
			   (%P-LDB %%ARRAY-LONG-LENGTH-FLAG HASH-TABLE)
			   1)))

;Look up a key in a hash table, returning two values.  If key present,
;returns value and T.  If key absent, returns NIL and NIL.
(DEFUN GETHASH (KEY HASH-TABLE)
  (SETQ HASH-TABLE (GET-REAL-HASH-TABLE HASH-TABLE))
  (DO ((P (HASH-BLOCK-POINTER HASH-TABLE KEY) (%MAKE-POINTER-OFFSET DTP-LOCATIVE P 1))
       (N 8 (1- N)))
      ((ZEROP N)				;Not found
       (COND (( (HASH-TABLE-GC-GENERATION-NUMBER HASH-TABLE) %GC-GENERATION-NUMBER)
	      ;; Some %POINTER's may have changed, try rehashing
	      (FUNCALL (HASH-TABLE-REHASH-FUNCTION HASH-TABLE) HASH-TABLE NIL)
	      (GETHASH KEY HASH-TABLE))
	     (T (RETURN NIL NIL))))		;Not found
    (AND (%P-CONTENTS-EQ P KEY)
	 (RETURN (%P-CONTENTS-OFFSET P 8) T))))

(DEFUN PUTHASH (KEY VALUE HASH-TABLE)
  (SETQ HASH-TABLE (GET-REAL-HASH-TABLE HASH-TABLE))
  (DO ((P (HASH-BLOCK-POINTER HASH-TABLE KEY) (%MAKE-POINTER-OFFSET DTP-LOCATIVE P 1))
       (N 8 (1- N))
       (EMPTYP NIL))
      ((ZEROP N)				;Not found
       (COND (( (HASH-TABLE-GC-GENERATION-NUMBER HASH-TABLE) %GC-GENERATION-NUMBER)
	      ;; Some %POINTER's may have changed, try rehashing
	      (FUNCALL (HASH-TABLE-REHASH-FUNCTION HASH-TABLE) HASH-TABLE NIL)
	      (PUTHASH KEY VALUE HASH-TABLE))
	     (EMPTYP				;Add to table using empty slot found
	      (%P-STORE-CONTENTS EMPTYP KEY)
	      (%P-STORE-CONTENTS-OFFSET VALUE EMPTYP 8)
	      (SETF (HASH-TABLE-FULLNESS HASH-TABLE) (1+ (HASH-TABLE-FULLNESS HASH-TABLE)))
	      VALUE)
	     (T					;Need to make more room, then try again
	      (FUNCALL (HASH-TABLE-REHASH-FUNCTION HASH-TABLE)
		       HASH-TABLE (HASH-TABLE-REHASH-SIZE HASH-TABLE))
	      (PUTHASH KEY VALUE HASH-TABLE))))
    (COND ((%P-CONTENTS-EQ P KEY)		;Found existing entry
	   (%P-STORE-CONTENTS-OFFSET VALUE P 8)	;Update or flush associated value
	   (RETURN VALUE))
	  ((= (%P-DATA-TYPE P) DTP-NULL)	;Remember empty slot
	   (OR EMPTYP (SETQ EMPTYP P))))))

;Like PUTHASH, but returns old contents
(DEFUN SWAPHASH (KEY VALUE HASH-TABLE)
  (SETQ HASH-TABLE (GET-REAL-HASH-TABLE HASH-TABLE))
  (DO ((P (HASH-BLOCK-POINTER HASH-TABLE KEY) (%MAKE-POINTER-OFFSET DTP-LOCATIVE P 1))
       (N 8 (1- N))
       (EMPTYP NIL))
      ((ZEROP N)				;Not found
       (COND (( (HASH-TABLE-GC-GENERATION-NUMBER HASH-TABLE) %GC-GENERATION-NUMBER)
	      ;; Some %POINTER's may have changed, try rehashing
	      (FUNCALL (HASH-TABLE-REHASH-FUNCTION HASH-TABLE) HASH-TABLE NIL)
	      (PUTHASH KEY VALUE HASH-TABLE))
	     (EMPTYP				;Add to table using empty slot found
	      (%P-STORE-CONTENTS EMPTYP KEY)
	      (%P-STORE-CONTENTS-OFFSET VALUE EMPTYP 8)
	      (SETF (HASH-TABLE-FULLNESS HASH-TABLE) (1+ (HASH-TABLE-FULLNESS HASH-TABLE))))
	     (T					;Need to make more room, then try again
	      (FUNCALL (HASH-TABLE-REHASH-FUNCTION HASH-TABLE)
		       HASH-TABLE (HASH-TABLE-REHASH-SIZE HASH-TABLE))
	      (PUTHASH KEY VALUE HASH-TABLE)))
       (VALUES NIL NIL))
    (COND ((%P-CONTENTS-EQ P KEY)		;Found existing entry
	   (RETURN (PROG1 (%P-CONTENTS-OFFSET P 8)
			  (%P-STORE-CONTENTS-OFFSET VALUE P 8))
		   T))
	  ((= (%P-DATA-TYPE P) DTP-NULL)	;Remember empty slot
	   (OR EMPTYP (SETQ EMPTYP P))))))

;Returns T if was really in table, NIL if not found
(DEFUN REMHASH (KEY HASH-TABLE)
  (SETQ HASH-TABLE (GET-REAL-HASH-TABLE HASH-TABLE))
  (DO ((P (HASH-BLOCK-POINTER HASH-TABLE KEY) (%MAKE-POINTER-OFFSET DTP-LOCATIVE P 1))
       (N 8 (1- N)))
      ((ZEROP N)				;Not found
       (COND (( (HASH-TABLE-GC-GENERATION-NUMBER HASH-TABLE) %GC-GENERATION-NUMBER)
	      ;; Some %POINTER's may have changed, try rehashing
	      (FUNCALL (HASH-TABLE-REHASH-FUNCTION HASH-TABLE) HASH-TABLE NIL)
	      (REMHASH KEY HASH-TABLE))
	     (T NIL)))				;Really not found
    (COND ((%P-CONTENTS-EQ P KEY)		;Found existing entry
	   (%P-STORE-CONTENTS-OFFSET NIL P 8)	;Wipe out old value
	   (%P-STORE-TAG-AND-POINTER P DTP-NULL 0)	;Remove entry
	   (SETF (HASH-TABLE-FULLNESS HASH-TABLE) (1- (HASH-TABLE-FULLNESS HASH-TABLE)))
	   (RETURN T)))))

;These are not the same order of arguments as in Interlisp
;FUNCTION gets KEY VALUE for each pair in HASH-TABLE
;Note that if another process does either a GETHASH or a PUTHASH
; while you are MAPHASHing the whole thing can be bollixed, it is
; the responsibility of the user to synchronize this and all other
; uses of the same hash-table in multiple processes.
(DEFUN MAPHASH (FUNCTION HASH-TABLE)
  (SETQ HASH-TABLE (GET-REAL-HASH-TABLE HASH-TABLE))
  (DO ((P (%MAKE-POINTER-OFFSET DTP-LOCATIVE HASH-TABLE
				(1+ (%P-LDB %%ARRAY-LONG-LENGTH-FLAG HASH-TABLE)))
	  (%MAKE-POINTER-OFFSET DTP-LOCATIVE P 1))
       (I 0 (1+ I))
       (N (ARRAY-LENGTH HASH-TABLE)))
      (( I N))
    (COND ((ODDP (// I 8)) (SETQ I (+ I 7) P (%MAKE-POINTER-OFFSET DTP-LOCATIVE P 7)))
	  ((= (%P-DATA-TYPE P) DTP-NULL))
	  (T (FUNCALL FUNCTION (CAR P) (%P-CONTENTS-OFFSET P 8)))))
  HASH-TABLE)

;Standard rehash function
(DEFUN HASH-TABLE-REHASH (HASH-TABLE GROW)
  (LET* ((NEW-SIZE (IF GROW (HASH-TABLE-GOOD-SIZE
			      (IF (FLOATP GROW) (FIX (* (ARRAY-LENGTH HASH-TABLE) GROW))
				  (+ (ARRAY-LENGTH HASH-TABLE) GROW GROW)))
		       (ARRAY-LENGTH HASH-TABLE)))
	 (TEMP-ARRAY (MAKE-ARRAY NEW-SIZE))
	 (NEW-HASH-TABLE)
	 (J 0))
    ;; Copy it all out into TEMP-ARRAY
    (DO ((P (%MAKE-POINTER-OFFSET DTP-LOCATIVE HASH-TABLE
				  (1+ (%P-LDB %%ARRAY-LONG-LENGTH-FLAG HASH-TABLE)))
	    (%MAKE-POINTER-OFFSET DTP-LOCATIVE P 1))
	 (I 0 (1+ I))
	 (N (ARRAY-LENGTH HASH-TABLE)))
	(( I N))
      (COND ((ODDP (// I 8)) (SETQ I (+ I 7) P (%MAKE-POINTER-OFFSET DTP-LOCATIVE P 7)))
	    ((= (%P-DATA-TYPE P) DTP-NULL))
	    (T (ASET (CAR P) TEMP-ARRAY J)
	       (ASET (%P-CONTENTS-OFFSET P 8) TEMP-ARRAY (1+ J))
	       (SETQ J (+ J 2)))))
    ;; Make new array if necessary.  Note that ADJUST-ARRAY-SIZE will die on DTP-NULL's.
    (COND (GROW
	   (SETQ NEW-HASH-TABLE
		 (MAKE-HASH-TABLE-INTERNAL
			    :MAKE-ARRAY (:LENGTH NEW-SIZE :AREA (%AREA-NUMBER HASH-TABLE))
			    HASH-TABLE-MODULUS (// NEW-SIZE 16.)
			    HASH-TABLE-REHASH-FUNCTION (HASH-TABLE-REHASH-FUNCTION HASH-TABLE)
			    HASH-TABLE-REHASH-SIZE (HASH-TABLE-REHASH-SIZE HASH-TABLE)))
	   (STRUCTURE-FORWARD HASH-TABLE NEW-HASH-TABLE)
	   (SETQ HASH-TABLE NEW-HASH-TABLE)))
    (CLRHASH HASH-TABLE)
    (DO I 0 (+ I 2) (= I J)
      (PUTHASH (AREF TEMP-ARRAY I) (AREF TEMP-ARRAY (1+ I)) HASH-TABLE))
    (RETURN-ARRAY TEMP-ARRAY))
  HASH-TABLE)

;Named-structure handler
(DEFUN (HASH-TABLE NAMED-STRUCTURE-INVOKE) (MESSAGE SELF &REST IGNORE)
  (SELECTQ MESSAGE
    (:WHICH-OPERATIONS '(:DESCRIBE))
    (:DESCRIBE (FORMAT T "~&~S is a hash-table with ~D entries out of a possible ~D (~D%).~%"
		         SELF (HASH-TABLE-FULLNESS SELF) (* (HASH-TABLE-MODULUS SELF) 8)
			 (// (* (HASH-TABLE-FULLNESS SELF) 100.)
			     (* (HASH-TABLE-MODULUS SELF) 8)))
	       (OR (= (HASH-TABLE-GC-GENERATION-NUMBER SELF) %GC-GENERATION-NUMBER)
		   (FORMAT T " rehash is required due to GC.~%"))
	       (FORMAT T " The rehash function is ~S with increase parameter ~D.~%"
		         (HASH-TABLE-REHASH-FUNCTION SELF) (HASH-TABLE-REHASH-SIZE SELF))
	       (COND ((Y-OR-N-P "Do you want to see the block fullness distribution?")
		      (DO ((RES (MAKE-ARRAY 9 ':TYPE 'ART-32B))
			   (I (HASH-TABLE-MODULUS SELF))
			   (TOT (HASH-TABLE-MODULUS SELF))
			   (N 0 0))
			  ((ZEROP I)
			   (DOTIMES (N 9)
			     (FORMAT T "~&Blocks with ~D elements: ~4D ~3D%~%"
				       N (AREF RES N) (// (* (AREF RES N) 100.) TOT))))
			(SETQ I (1- I))
			(DO ((P (%MAKE-POINTER-OFFSET DTP-LOCATIVE SELF
				   (+ (* I 16.) (1+ (%P-LDB %%ARRAY-LONG-LENGTH-FLAG SELF))))
				(%MAKE-POINTER-OFFSET DTP-LOCATIVE P 1))
			     (K 8 (1- K)))
			    ((ZEROP K))
			  (OR (= (%P-DATA-TYPE P) DTP-NULL)
			      (SETQ N (1+ N))))
			(ASET (1+ (AREF RES N)) RES N))))
	       (AND (NOT (ZEROP (HASH-TABLE-FULLNESS SELF)))
		    (Y-OR-N-P "Do you want to see the contents of the hash table?")
		    (IF (NOT (Y-OR-N-P "Do you want it sorted?"))
			(MAPHASH #'(LAMBDA (KEY VALUE) (FORMAT T "~& ~S -> ~S~%" KEY VALUE))
				 SELF)
			(LOCAL-DECLARE ((SPECIAL *L*))
			  (LET ((*L* NIL))
			    (MAPHASH #'(LAMBDA (KEY VALUE) (PUSH (LIST KEY VALUE) *L*))
				     SELF)
			    (SETQ *L* (SORTCAR *L* #'ALPHALESSP))
			    (FORMAT T "~&~:{ ~S -> ~S~%~}" *L*))))))))

;;; EQUAL hash tables
;;; The functions here have similar names to the EQ hashing ones.

(DEFSTRUCT (EQUAL-HASH-TABLE :NAMED :ARRAY-LEADER
			     (:CONSTRUCTOR MAKE-EQUAL-HASH-TABLE-INTERNAL))
  EQUAL-HASH-TABLE-SIZE
  (EQUAL-HASH-TABLE-FULLNESS 0)
  EQUAL-HASH-TABLE-THRESHOLD
  EQUAL-HASH-TABLE-GROWTH-FACTOR)

;;; 3-D manual defstruct
(DEFMACRO EQUAL-HASH-TABLE-HASH (HASH-TABLE IDX)
  `(AREF ,HASH-TABLE ,IDX 0))

(DEFMACRO EQUAL-HASH-TABLE-KEY (HASH-TABLE IDX)
  `(AREF ,HASH-TABLE ,IDX 1))

(DEFMACRO EQUAL-HASH-TABLE-VALUE (HASH-TABLE IDX)
  `(AREF ,HASH-TABLE ,IDX 2))

(DEFUN MAKE-EQUAL-HASH-TABLE (&REST OPTIONS &AUX (SIZE 100) AREA (THRESH 0.8s0) (GROW 1.3s0))
  (TV:DOPLIST (OPTIONS VAL KEY)
    (SELECTQ KEY
      (:SIZE (SETQ SIZE VAL))
      (:AREA (SETQ AREA VAL))
      (:REHASH-THRESHOLD (SETQ THRESH VAL))
      (:GROWTH-FACTOR (SETQ GROW VAL))
      (OTHERWISE (FERROR NIL "~S not a recognized option" KEY))))
  (DOLIST (GOOD-SIZE PKG-GOOD-SIZES)
    (COND (( GOOD-SIZE SIZE)
	   (SETQ SIZE GOOD-SIZE)
	   (RETURN))))
  (MAKE-EQUAL-HASH-TABLE-INTERNAL :MAKE-ARRAY (:LENGTH (LIST SIZE 3) :AREA AREA)
				  EQUAL-HASH-TABLE-SIZE SIZE
				  EQUAL-HASH-TABLE-THRESHOLD THRESH
				  EQUAL-HASH-TABLE-GROWTH-FACTOR GROW))

(DEFUN CLRHASH-EQUAL (HASH-TABLE)
  (MATH:FILL-2D-ARRAY HASH-TABLE '((NIL)))
  (SETF (EQUAL-HASH-TABLE-FULLNESS HASH-TABLE) 0)
  HASH-TABLE)

(DEFUN GETHASH-EQUAL (KEY HASH-TABLE &AUX HASH SIZE)
  (SETQ HASH (ABS (SXHASH KEY))
	SIZE (EQUAL-HASH-TABLE-SIZE HASH-TABLE))
  (DO ((IDX (\ HASH SIZE) (\ (1+ IDX) SIZE))
       (TEM))
      (NIL)
    (OR (SETQ TEM (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX))
	(RETURN NIL NIL))			;Not found
    (AND (= TEM HASH) (EQUAL KEY (EQUAL-HASH-TABLE-KEY HASH-TABLE IDX))
	 (RETURN (EQUAL-HASH-TABLE-VALUE HASH-TABLE IDX) T))))

(DEFUN PUTHASH-EQUAL (KEY VALUE HASH-TABLE &AUX SIZE HASH)
  (SETQ SIZE (EQUAL-HASH-TABLE-SIZE HASH-TABLE))
  (SETQ HASH (ABS (SXHASH KEY)))
  (DO ((IDX (\ HASH SIZE) (\ (1+ IDX) SIZE))
       (TEM))
      (NIL)
    (COND ((OR (NULL (SETQ TEM (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX)))
	       (MINUSP TEM))
	   (SETF (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX) HASH)
	   (SETF (EQUAL-HASH-TABLE-KEY HASH-TABLE IDX) KEY)
	   (SETF (EQUAL-HASH-TABLE-VALUE HASH-TABLE IDX) VALUE)
	   (LET ((FULLNESS (1+ (EQUAL-HASH-TABLE-FULLNESS HASH-TABLE))))
	     (SETF (EQUAL-HASH-TABLE-FULLNESS HASH-TABLE) FULLNESS)
	     (AND (> FULLNESS (* SIZE (EQUAL-HASH-TABLE-THRESHOLD HASH-TABLE)))
		  (EQUAL-HASH-TABLE-REHASH
		    HASH-TABLE
		    (FIX (* SIZE (EQUAL-HASH-TABLE-GROWTH-FACTOR HASH-TABLE))))))
	   (RETURN))
	  ((AND (= TEM HASH) (EQUAL KEY (EQUAL-HASH-TABLE-KEY HASH-TABLE IDX)))
	   (SETF (EQUAL-HASH-TABLE-VALUE HASH-TABLE IDX) VALUE)
	   (RETURN))))
  VALUE)

(DEFUN SWAPHASH-EQUAL (KEY VALUE HASH-TABLE &AUX SIZE HASH)
  (SETQ SIZE (EQUAL-HASH-TABLE-SIZE HASH-TABLE))
  (SETQ HASH (ABS (SXHASH KEY)))
  (DO ((IDX (\ HASH SIZE) (\ (1+ IDX) SIZE))
       (TEM))
      (NIL)
    (COND ((OR (NULL (SETQ TEM (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX)))
	       (MINUSP TEM))
	   (SETF (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX) HASH)
	   (SETF (EQUAL-HASH-TABLE-KEY HASH-TABLE IDX) KEY)
	   (SETF (EQUAL-HASH-TABLE-VALUE HASH-TABLE IDX) VALUE)
	   (LET ((FULLNESS (1+ (EQUAL-HASH-TABLE-FULLNESS HASH-TABLE))))
	     (SETF (EQUAL-HASH-TABLE-FULLNESS HASH-TABLE) FULLNESS)
	     (AND (> FULLNESS (* SIZE (EQUAL-HASH-TABLE-THRESHOLD HASH-TABLE)))
		  (EQUAL-HASH-TABLE-REHASH
		    HASH-TABLE
		    (FIX (* SIZE (EQUAL-HASH-TABLE-GROWTH-FACTOR HASH-TABLE))))))
	   (RETURN NIL NIL))
	  ((AND (= TEM HASH) (EQUAL KEY (EQUAL-HASH-TABLE-KEY HASH-TABLE IDX)))
	   (RETURN (PROG1 (EQUAL-HASH-TABLE-VALUE HASH-TABLE IDX)
			  (SETF (EQUAL-HASH-TABLE-VALUE HASH-TABLE IDX) VALUE))
		   T)))))

;Note that this rehashes using the hash codes saved in the table.  It does not page
;in any of the keys and values.
(DEFUN EQUAL-HASH-TABLE-REHASH (HASH-TABLE NEW-SIZE &AUX HASH)
  (LET ((NEW-HASH-TABLE (MAKE-EQUAL-HASH-TABLE
			    ':AREA (%AREA-NUMBER HASH-TABLE)
			    ':SIZE NEW-SIZE
			    ':REHASH-THRESHOLD (EQUAL-HASH-TABLE-THRESHOLD HASH-TABLE)
			    ':GROWTH-FACTOR (EQUAL-HASH-TABLE-GROWTH-FACTOR HASH-TABLE))))
    (SETQ NEW-SIZE (EQUAL-HASH-TABLE-SIZE NEW-HASH-TABLE))
    (DOTIMES (I (EQUAL-HASH-TABLE-SIZE HASH-TABLE))
      (COND ((AND (SETQ HASH (EQUAL-HASH-TABLE-HASH HASH-TABLE I))
		  ( HASH 0))
	     (DO ((J (\ HASH NEW-SIZE) (\ (1+ J) NEW-SIZE))) (NIL)
	       (COND ((NULL (EQUAL-HASH-TABLE-HASH NEW-HASH-TABLE J))
		      (SETF (EQUAL-HASH-TABLE-HASH NEW-HASH-TABLE J) HASH)
		      (SETF (EQUAL-HASH-TABLE-KEY NEW-HASH-TABLE J)
			    (EQUAL-HASH-TABLE-KEY HASH-TABLE I))
		      (SETF (EQUAL-HASH-TABLE-VALUE NEW-HASH-TABLE J) 
			    (EQUAL-HASH-TABLE-VALUE HASH-TABLE I))
		      (RETURN)))))))
    (SETF (EQUAL-HASH-TABLE-FULLNESS NEW-HASH-TABLE)
	  (EQUAL-HASH-TABLE-FULLNESS HASH-TABLE))
    (STRUCTURE-FORWARD HASH-TABLE NEW-HASH-TABLE)))

(DEFUN REMHASH-EQUAL (KEY HASH-TABLE &AUX HASH SIZE)
  (SETQ HASH (ABS (SXHASH KEY))
	SIZE (EQUAL-HASH-TABLE-SIZE HASH-TABLE))
  (DO ((IDX (\ HASH SIZE) (\ (1+ IDX) SIZE))
       (TEM))
      (NIL)
    (OR (SETQ TEM (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX))
	(RETURN NIL))				;Not found
    (COND ((AND (= TEM HASH) (EQUAL KEY (EQUAL-HASH-TABLE-KEY HASH-TABLE IDX)))
	   (SETF (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX) -1)
	   (SETF (EQUAL-HASH-TABLE-KEY HASH-TABLE IDX) NIL)
	   (SETF (EQUAL-HASH-TABLE-VALUE HASH-TABLE IDX) NIL)
	   (SETF (EQUAL-HASH-TABLE-FULLNESS HASH-TABLE)
		 (1- (EQUAL-HASH-TABLE-FULLNESS HASH-TABLE)))
	   (RETURN T)))))

(DEFUN MAPHASH-EQUAL (FUNCTION HASH-TABLE)
  (DO ((IDX 0 (1+ IDX))
       (SIZE (EQUAL-HASH-TABLE-SIZE HASH-TABLE))
       (HASH))
      (( IDX SIZE))
    (AND (SETQ HASH (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX))
	 ( HASH 0)
	 (FUNCALL FUNCTION (EQUAL-HASH-TABLE-KEY HASH-TABLE IDX)
			   (EQUAL-HASH-TABLE-VALUE HASH-TABLE IDX)))))

(DEFSELECT ((EQUAL-HASH-TABLE NAMED-STRUCTURE-INVOKE))
  (:DESCRIBE (HASH-TABLE &AUX SIZE FULLNESS)
    (SETQ SIZE (EQUAL-HASH-TABLE-SIZE HASH-TABLE)
	  FULLNESS (EQUAL-HASH-TABLE-FULLNESS SELF))
    (FORMAT T "~&~S is a hash-table with ~D entries out of a possible ~D (~D%).~%"
	    HASH-TABLE FULLNESS SIZE (// (* FULLNESS 100.) SIZE))
    (FORMAT T "~&Rehash threshold = ~2F, Growth factor = ~2F"
	    (EQUAL-HASH-TABLE-THRESHOLD HASH-TABLE)
	    (EQUAL-HASH-TABLE-GROWTH-FACTOR HASH-TABLE))
    (AND (NOT (ZEROP FULLNESS))
	 (Y-OR-N-P "Do you want to see distribution information?")
	 (DO ((DIFFS (MAKE-ARRAY FULLNESS ':TYPE 'ART-16B))
	      (IDX 0 (1+ IDX))
	      (HASH) (DIFF))
	     (( IDX SIZE)
	      (DO ((J 0 (1+ J))
		   (N))
		  (( J FULLNESS))
		(AND (NOT (ZEROP (SETQ N (AREF DIFFS J))))
		     (FORMAT T "~&~D entr~:@P off by ~D~%" N J))))
	   (COND ((AND (SETQ HASH (EQUAL-HASH-TABLE-HASH HASH-TABLE IDX))
		       ( HASH 0))
		  (SETQ DIFF (- IDX (\ HASH SIZE)))
		  (AND (MINUSP DIFF) (SETQ DIFF (+ DIFF SIZE)))
		  (ASET (1+ (AREF DIFFS DIFF)) DIFFS DIFF)))))
    (AND (NOT (ZEROP FULLNESS))
	 (Y-OR-N-P "Do you want to see the contents of the hash table?")
	 (IF (NOT (Y-OR-N-P "Do you want it sorted?"))
	     (MAPHASH-EQUAL #'(LAMBDA (KEY VALUE) (FORMAT T "~& ~S -> ~S~%" KEY VALUE))
			    HASH-TABLE)
	     (LOCAL-DECLARE ((SPECIAL *L*))
	       (LET ((*L* NIL))
		 (MAPHASH-EQUAL #'(LAMBDA (KEY VALUE) (PUSH (LIST KEY VALUE) *L*))
				HASH-TABLE)
		 (SETQ *L* (SORTCAR *L* #'ALPHALESSP))
		 (FORMAT T "~&~:{ ~S -> ~S~%~}" *L*)))))))
