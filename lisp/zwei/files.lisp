
;;; ** (c) Copyright 1980 Massachusetts Institute of Technology **
;;; This file contains utility functions for manipulating files, and various
;;; commands to do I/O to intervals.  It does not know about buffers and such,
;;; just intervals.

;;; Get a pathname from the user, return as a pathname actor.
(DEFVAR *READING-PATHNAME-DEFAULTS*)
(DEFVAR *READING-PATHNAME-SPECIAL-TYPE*)
(DEFVAR *READING-PATHNAME-SPECIAL-VERSION*)
(DEFVAR *READING-PATHNAME-DIRECTION*)

(DEFUN READ-DEFAULTED-PATHNAME (PROMPT *READING-PATHNAME-DEFAULTS*
				&OPTIONAL *READING-PATHNAME-SPECIAL-TYPE*
					  *READING-PATHNAME-SPECIAL-VERSION*
					  (*READING-PATHNAME-DIRECTION* ':READ)
					  (MERGE-IN-SPECIAL-VERSION T)
				&AUX (SPECIAL-VERSION *READING-PATHNAME-SPECIAL-VERSION*))
  (SETQ PROMPT (FORMAT NIL "~A (Default is ~A)" PROMPT
		       (FS:DEFAULT-PATHNAME *READING-PATHNAME-DEFAULTS* NIL
			 *READING-PATHNAME-SPECIAL-TYPE* *READING-PATHNAME-SPECIAL-VERSION*)))
  ;; MERGE-IN-SPECIAL-VERSION is for the case of wanting the default to have :OLDEST, but
  ;; not having pathnames typed in keeping to this.
  (AND (NOT MERGE-IN-SPECIAL-VERSION)
       (SETQ *READING-PATHNAME-SPECIAL-VERSION* NIL))	;Don't complete from this
  (TEMP-KILL-RING *LAST-FILE-NAME-TYPED*
    (WITH-MINI-BUFFER-COMPLETION (*MINI-BUFFER-WINDOW*)
      (MULTIPLE-VALUE-BIND (NIL NIL INTERVAL)
	  (EDIT-IN-MINI-BUFFER *PATHNAME-READING-COMTAB* NIL NIL (NCONS PROMPT))
	(MAKE-DEFAULTED-PATHNAME (STRING-INTERVAL INTERVAL) *READING-PATHNAME-DEFAULTS*
				 *READING-PATHNAME-SPECIAL-TYPE* SPECIAL-VERSION
				 MERGE-IN-SPECIAL-VERSION)))))

(DEFUN READ-DEFAULTED-AUX-PATHNAME (PROMPT &OPTIONAL SPECIAL-TYPE SPECIAL-VERSION
						     (DIRECTION ':READ))
  (READ-DEFAULTED-PATHNAME PROMPT *AUX-PATHNAME-DEFAULTS* SPECIAL-TYPE SPECIAL-VERSION
			   DIRECTION))

(DEFUN MAKE-DEFAULTED-PATHNAME (STRING DEFAULTS &OPTIONAL SPECIAL-TYPE SPECIAL-VERSION
							  (MERGE-IN-SPECIAL-VERSION T))
  ;; STRING is what the user typed.  Remember it for next time if non-null.
  (IF (ZEROP (STRING-LENGTH STRING))
      ;; He didn't type anything, use the default.
      (FS:DEFAULT-PATHNAME DEFAULTS NIL SPECIAL-TYPE SPECIAL-VERSION)
      (SETQ *LAST-FILE-NAME-TYPED* STRING)
      (AND (NOT MERGE-IN-SPECIAL-VERSION)	;Was only for nullstring case
	   (SETQ SPECIAL-VERSION NIL))
      (FS:MERGE-AND-SET-PATHNAME-DEFAULTS STRING DEFAULTS
					  (OR SPECIAL-TYPE ':UNSPECIFIC)
					  (OR SPECIAL-VERSION ':NEWEST))))

;;; Canonicalize pathname for use as buffer name, etc.
(DEFUN EDITOR-FILE-NAME (FILE-NAME)
  (AND (STRINGP FILE-NAME)
       (SETQ FILE-NAME (FS:MERGE-PATHNAME-DEFAULTS FILE-NAME *PATHNAME-DEFAULTS*)))
  (SETQ FILE-NAME (FUNCALL FILE-NAME ':TRANSLATED-PATHNAME))
  (VALUES FILE-NAME (FUNCALL FILE-NAME ':STRING-FOR-EDITOR)))

;;; Special commands in the pathname mini-buffer
(DEFCOM COM-PATHNAME-COMPLETE "Try to complete the string so far as a pathname" ()
  (LET ((TEM (PATHNAME-COMPLETE)))
    (AND (NULL TEM) (BEEP)))
  DIS-TEXT)

(DEFCOM COM-PATHNAME-COMPLETE-AND-EXIT-IF-UNIQUE
	"Try to complete the string so far as a pathname and return if unique" ()
  (LET ((TEM (PATHNAME-COMPLETE)))
    (COND ((NULL TEM)
	   (BEEP))
	  ((EQ TEM ':OLD)
	   (MUST-REDISPLAY *WINDOW* DIS-TEXT)
	   (REDISPLAY *WINDOW* ':NONE)
	   (*THROW 'RETURN-FROM-COMMAND-LOOP T))))
  DIS-TEXT)

(DEFUN PATHNAME-COMPLETE (&AUX STRING VALUE)
  (SETQ STRING (STRING-APPEND (BP-LINE (POINT))))
  (MULTIPLE-VALUE (STRING VALUE)
    (FS:COMPLETE-PATHNAME *READING-PATHNAME-DEFAULTS* STRING *READING-PATHNAME-SPECIAL-TYPE*
			  *READING-PATHNAME-SPECIAL-VERSION* *READING-PATHNAME-DIRECTION*))
  (DELETE-INTERVAL *INTERVAL*)
  (INSERT-MOVING (POINT) STRING)
  VALUE)

;COM-PATHNAME-LIST-COMPLETIONS someday

(DEFCOM COM-DOCUMENT-PATHNAME-READ "Help while getting a pathname" ()
  (FORMAT T "~&You are typing a pathname~%")
  (FORMAT T
"You are typing to a mini-buffer, with the following commands redefined:
Altmode causes the pathname to be completed and the completion inserted
into the mini-buffer.
End attempts completion and exits if that succeeds.  Return exits without completion.
")
  (AND *MINI-BUFFER-COMMAND-IN-PROGRESS*
       (COM-DOCUMENT-CONTAINING-COMMAND))
  DIS-NONE)

;;; Various file-related commands on INTERVALs.

(DEFCOM COM-INSERT-FILE "Insert the contents of the specified file at point.
Reads a file name from the mini-buffer, and inserts the contents of that
file at point. Leaves mark at the end of inserted text, and point at the 
beginning, unless given an argument.  Acts like Yank (Control-Y) with respect
to the region." ()
  (POINT-PDL-PUSH (POINT) *WINDOW* NIL NIL)
  (MOVE-BP (MARK) (POINT))
  (SETQ *CURRENT-COMMAND-TYPE* ':YANK)
  (LET ((PATHNAME (READ-DEFAULTED-AUX-PATHNAME "Insert file:")))
    (WITH-OPEN-FILE (STREAM PATHNAME '(IN))
      (MOVE-BP (POINT) (STREAM-INTO-BP STREAM (POINT))))
    (MAYBE-DISPLAY-DIRECTORY ':READ PATHNAME))
  (OR *NUMERIC-ARG-P* (SWAP-BPS (POINT) (MARK)))
  DIS-TEXT)

(DEFCOM COM-WRITE-REGION "Write out the region to the specified file." ()
  (REGION (BP1 BP2)
    (LET ((PATHNAME (READ-DEFAULTED-AUX-PATHNAME "Write region to:"
						 NIL NIL ':WRITE)))
      (WITH-OPEN-FILE (STREAM PATHNAME '(OUT))
	(STREAM-OUT-INTERVAL STREAM BP1 BP2 T))))
  DIS-NONE)

(DEFCOM COM-APPEND-TO-FILE "Append region to the end of the specified file." ()
  (REGION (BP1 BP2)
    (LET ((PATHNAME (READ-DEFAULTED-AUX-PATHNAME "Append region to end of file:"
						 NIL NIL ':NEW-OK)))
      (WITH-OPEN-FILE (OSTREAM PATHNAME '(:OUT))
	(WITH-OPEN-FILE (ISTREAM PATHNAME '(:IN :NOERROR))
	  (IF (STRINGP ISTREAM)
	      (MULTIPLE-VALUE-BIND (ERR NIL MSG)
		  (FS:FILE-PROCESS-ERROR ISTREAM PATHNAME NIL T)
		(IF (STRING-EQUAL ERR "FNF")
		    (TYPEIN-LINE "(New File)")
		    (BARF "Error: ~A" MSG)))
	      (STREAM-COPY-UNTIL-EOF ISTREAM OSTREAM)))
	(STREAM-OUT-INTERVAL OSTREAM BP1 BP2 T))
      (MAYBE-DISPLAY-DIRECTORY ':READ PATHNAME)))
  DIS-NONE)

(DEFCOM COM-PREPEND-TO-FILE "Append region to the beginning of the specified file." ()
  (REGION (BP1 BP2)
    (LET ((PATHNAME (READ-DEFAULTED-AUX-PATHNAME "Append region to start of file:")))
      (WITH-OPEN-FILE (ISTREAM PATHNAME '(:IN))
	(WITH-OPEN-FILE (OSTREAM PATHNAME '(:OUT))
	  (STREAM-OUT-INTERVAL OSTREAM BP1 BP2 T)
	  (STREAM-COPY-UNTIL-EOF ISTREAM OSTREAM)))
      (MAYBE-DISPLAY-DIRECTORY ':READ PATHNAME)))
  DIS-NONE)

(DEFCOM COM-VIEW-FILE "View contents of a file." ()
  (LET ((PATHNAME (READ-DEFAULTED-PATHNAME "View file:" (PATHNAME-DEFAULTS))))
    (VIEW-FILE PATHNAME))
  DIS-NONE)

;;; Show the file in the "display window".
;;; The caller should set up a reasonable prompt.
(COMMENT
(DEFUN VIEW-FILE (FILENAME &OPTIONAL (OUTPUT-STREAM STANDARD-OUTPUT))
  (FUNCALL OUTPUT-STREAM ':HOME-CURSOR)
  (FUNCALL OUTPUT-STREAM ':CLEAR-EOL)
  (WITH-OPEN-FILE (STREAM FILENAME '(:READ))
    (STREAM-COPY-UNTIL-EOF STREAM OUTPUT-STREAM))
  (FUNCALL OUTPUT-STREAM ':CLEAR-EOF))
);COMMENT

(DEFUN VIEW-FILE (PATHNAME)
  (WITH-OPEN-FILE (STREAM PATHNAME ':PRESERVE-DATES T)
    (PROMPT-LINE "Viewing ~A" (FUNCALL STREAM ':TRUENAME))
    (VIEW-STREAM STREAM)))

(DEFUN VIEW-STREAM (STREAM &OPTIONAL (WINDOW (CREATE-OVERLYING-WINDOW *WINDOW*))
			   &AUX (INTERVAL (CREATE-BUFFER NIL)))
  (SETF (BUFFER-NAME INTERVAL) "")
  (FUNCALL (WINDOW-SHEET WINDOW) ':SET-LABEL "")
  (SET-WINDOW-INTERVAL WINDOW INTERVAL)
  (TEMPORARY-WINDOW-SELECT (WINDOW)
    (VIEW-WINDOW WINDOW STREAM)))

(DEFCOM COM-DELETE-FILE "Delete a file." ()
  (LET ((PATHNAME (READ-DEFAULTED-PATHNAME "Delete file:" (PATHNAME-DEFAULTS))))
    (LET ((TRUENAME (PROBEF PATHNAME)))
      (OR TRUENAME (SETQ TRUENAME PATHNAME))
      (AND (FQUERY NIL "Delete ~A? " TRUENAME)
	   (LET ((ERROR (DELETEF TRUENAME NIL)))
	     (IF (STRINGP ERROR)
		 (TYPEIN-LINE "Cannot delete ~A: ~A" TRUENAME ERROR)
		 (TYPEIN-LINE "~A deleted" TRUENAME))))))
  DIS-NONE)

(DEFCOM COM-RENAME-FILE "Rename one file to another." ()
  (MULTIPLE-VALUE-BIND (FROM TO)
      (READ-TWO-DEFAULTED-PATHNAMES "Rename" (PATHNAME-DEFAULTS))
    (LET ((FROM-NAME (PROBEF FROM)))
      (OR FROM-NAME (SETQ FROM-NAME FROM))
      (LET ((ERROR (RENAMEF FROM TO NIL)))
	(IF (STRINGP ERROR)
	    (TYPEIN-LINE "Cannot rename ~A to ~A: ~A" FROM-NAME TO ERROR)
	    (TYPEIN-LINE "~A renamed to ~A" FROM-NAME (OR (PROBEF TO) TO))))))
  DIS-NONE)

(DEFCOM COM-COPY-TEXT-FILE "Copy one ascii file to another." ()
  (MULTIPLE-VALUE-BIND (FROM TO)
      (READ-TWO-DEFAULTED-PATHNAMES "Copy" (PATHNAME-DEFAULTS))
    (WITH-OPEN-FILE (FROM-STREAM FROM '(:IN))
      (WITH-OPEN-FILE (TO-STREAM TO '(:OUT))
        (STREAM-COPY-UNTIL-EOF FROM-STREAM TO-STREAM NIL)
	(CLOSE TO-STREAM)
	(TYPEIN-LINE "~A copied to ~A"
		     (FUNCALL FROM-STREAM ':TRUENAME) (FUNCALL TO-STREAM ':TRUENAME)))))
  DIS-NONE)

(DEFCOM COM-COPY-BINARY-FILE "Copy one binary file to another." ()
  (MULTIPLE-VALUE-BIND (FROM TO)
      (READ-TWO-DEFAULTED-PATHNAMES "Copy" (PATHNAME-DEFAULTS))
    (WITH-OPEN-FILE (FROM-STREAM FROM '(:IN :FIXNUM))
      (WITH-OPEN-FILE (TO-STREAM TO '(:OUT :FIXNUM))
        (STREAM-COPY-UNTIL-EOF FROM-STREAM TO-STREAM NIL)
	(CLOSE TO-STREAM)
	(TYPEIN-LINE "~A copied to ~A"
		     (FUNCALL FROM-STREAM ':TRUENAME) (FUNCALL TO-STREAM ':TRUENAME)))))
  DIS-NONE)

(DEFUN READ-TWO-DEFAULTED-PATHNAMES (PROMPT DEFAULTS &AUX FROM TO)
  (SETQ FROM (READ-DEFAULTED-PATHNAME (FORMAT NIL "~A file:" PROMPT) DEFAULTS)
	TO (READ-DEFAULTED-PATHNAME (FORMAT NIL "~A ~A to:" PROMPT FROM) FROM
				    NIL NIL ':WRITE))
  (VALUES FROM TO))

(DEFCOM COM-PRINT-FILE "Print a file on the local hardcopy device." ()
  (LET ((PATHNAME (READ-DEFAULTED-PATHNAME "Print file:" (PATHNAME-DEFAULTS))))
    (DIRED-PRINT-FILE-1 PATHNAME))
  DIS-NONE)

;;; Directory Listing stuff.

(DEFCOM COM-DISPLAY-DIRECTORY "Display current buffer's file's directory.
Use the directory listing function in the variable Directory Lister.
With an argument, accepts the name of a file to list." ()
  (FUNCALL *DIRECTORY-LISTER* (READ-DEFAULTED-WILD-PATHNAME "Display Directory:"
							    (DEFAULT-PATHNAME)
							    (NOT *NUMERIC-ARG-P*)))
  DIS-NONE)

(DEFUN READ-DEFAULTED-WILD-PATHNAME (PROMPT &OPTIONAL (DEFAULT (DEFAULT-PATHNAME))
						      DONT-READ-P)
    (SETQ DEFAULT (FUNCALL DEFAULT ':NEW-PATHNAME ':TYPE ':WILD ':VERSION ':WILD))
    (OR DONT-READ-P
	(SETQ DEFAULT (READ-DEFAULTED-PATHNAME PROMPT DEFAULT ':WILD ':WILD)))
    DEFAULT)

(DEFUN MAYBE-DISPLAY-DIRECTORY (TYPE &OPTIONAL (PATHNAME (DEFAULT-PATHNAME)))
  (COND ((OR (AND (EQ TYPE ':READ) (MEMQ *AUTO-DIRECTORY-DISPLAY* '(:READ T)))
	     (AND (EQ TYPE ':WRITE) (MEMQ *AUTO-DIRECTORY-DISPLAY* '(:WRITE T))))
	 (FUNCALL *DIRECTORY-LISTER* (FUNCALL PATHNAME ':NEW-PATHNAME ':TYPE ':WILD
								      ':VERSION ':WILD)))))

;;; This is the default directory listing routine
(DEFUN DEFAULT-DIRECTORY-LISTER (PATHNAME)
  (FORMAT T "~&~A~%" PATHNAME)
  (LET ((DIRECTORY (FS:DIRECTORY-LIST PATHNAME ':SORTED)))
    (DOLIST (FILE DIRECTORY)
      (FUNCALL *DIRECTORY-SINGLE-FILE-LISTER* FILE)))
  (FORMAT T "Done.~%"))

;Note that *DIRECTORY-SINGLE-FILE-LISTER* is expected to output lines.

;Stream operations to editor stream are grossly slow.
;Make this faster by building a string then doing :LINE-OUT.
;Also try not to do the slower and more cretinously-implemented operations of FORMAT.
(DEFVAR *DIR-LISTING-BUFFER* (MAKE-ARRAY 128. ':TYPE 'ART-STRING ':LEADER-LENGTH 1))

(DEFUN DEFAULT-LIST-ONE-FILE (FILE &OPTIONAL (STREAM STANDARD-OUTPUT) &AUX PATHNAME)
  (COND ((AND (TYPEP STREAM ':CLOSURE) (EQ (CLOSURE-FUNCTION STREAM) 'INTERVAL-IO))
	 (STORE-ARRAY-LEADER 0 *DIR-LISTING-BUFFER* 0)
	 (WITH-OUTPUT-TO-STRING (S *DIR-LISTING-BUFFER*)
	   (DEFAULT-LIST-ONE-FILE FILE S))
	 (DECF (ARRAY-LEADER *DIR-LISTING-BUFFER* 0))	;Flush the carriage return
	 (FUNCALL STREAM ':LINE-OUT *DIR-LISTING-BUFFER*))
	((NULL (SETQ PATHNAME (CAR FILE)))
	 (COND ((GET FILE ':DISK-SPACE-DESCRIPTION)
		(FUNCALL STREAM ':LINE-OUT (GET FILE ':DISK-SPACE-DESCRIPTION)))
	       ((GET FILE ':PHYSICAL-VOLUME-FREE-BLOCKS)
		(DO ((FREE (GET FILE ':PHYSICAL-VOLUME-FREE-BLOCKS) (CDR FREE))
		     (FLAG T NIL))
		    ((NULL FREE) (FUNCALL STREAM ':TYO #\CR))
		 (FORMAT STREAM "~A #~A=~D" (IF FLAG "Free:" ",") (CAAR FREE) (CDAR FREE))))
	       (T
		(FUNCALL STREAM ':TYO #\CR))))
	(T (FUNCALL STREAM ':TYO (IF (GET FILE ':DELETED) #/D #\SP))
	   (FORMAT STREAM " ~3A " (OR (GET FILE ':PHYSICAL-VOLUME) ""))
	   (IF (FUNCALL STREAM ':OPERATION-HANDLED-P ':ITEM)
	       (FUNCALL STREAM ':ITEM 'FILE PATHNAME "~A"
			(FUNCALL PATHNAME ':STRING-FOR-DIRED))
	       (FUNCALL STREAM ':STRING-OUT (FUNCALL PATHNAME ':STRING-FOR-DIRED)))
	   (FORMAT STREAM "~20T")
	   (LET ((LINK-TO (GET FILE ':LINK-TO)))
	     (IF LINK-TO
		 (FORMAT STREAM "=> ~A~41T" LINK-TO)
		 (LET ((LENGTH (GET FILE ':LENGTH-IN-BLOCKS)))
		   (IF LENGTH
		       (FORMAT STREAM "~4D " LENGTH)
		       (FORMAT STREAM "~5X")))
		 (LET ((LENGTH (GET FILE ':LENGTH-IN-BYTES)))
		   (AND LENGTH
			(FORMAT STREAM "~6D(~D)" LENGTH (GET FILE ':BYTE-SIZE))))
		 (FORMAT STREAM "~39T")
		 (FUNCALL STREAM ':TYO (IF (GET FILE ':NOT-BACKED-UP) #/! #\SP))
		 (FUNCALL STREAM ':TYO (IF (GET FILE ':DONT-REAP) #/$ #\SP))))
	   (LET ((CREATION-DATE (GET FILE ':CREATION-DATE)))
	     (IF CREATION-DATE
		 (MULTIPLE-VALUE-BIND (SECONDS MINUTES HOURS DAY MONTH YEAR)
		     (TIME:DECODE-UNIVERSAL-TIME CREATION-DATE)
		   (FORMAT STREAM "~2,'0D//~2,'0D//~4,'0D ~2,'0D:~2,'0D:~2,'0D"
			   MONTH DAY (+ YEAR 1900.) HOURS MINUTES SECONDS))
		 (FORMAT STREAM "~17X")))
	   (LET ((REFERENCE-DATE (GET FILE ':REFERENCE-DATE)))
	     (AND REFERENCE-DATE
		  (MULTIPLE-VALUE-BIND (NIL NIL NIL DAY MONTH YEAR)
		      (TIME:DECODE-UNIVERSAL-TIME REFERENCE-DATE)
		    (FORMAT STREAM " (~2,'0D//~2,'0D//~4,'0D)"
			    MONTH DAY (+ YEAR 1900.)))))
	   (LET ((AUTHOR (GET FILE ':AUTHOR)))
	     (AND AUTHOR (NOT (EQUAL AUTHOR (FUNCALL PATHNAME ':DIRECTORY)))
		  (FORMAT STREAM "~72T~A" AUTHOR)))
	   (LET ((READER (GET FILE ':READER)))
	     (AND READER (NOT (EQUAL READER (FUNCALL PATHNAME ':DIRECTORY)))
		  (FORMAT STREAM "~82T~A" READER)))
	   (FUNCALL STREAM ':TYO #\CR))))

(DEFUN READ-DIRECTORY-NAME (PROMPT PATHNAME &AUX TYPEIN)
  (SETQ PATHNAME (FUNCALL PATHNAME ':NEW-PATHNAME ':NAME ':WILD
						  ':TYPE ':WILD
						  ':VERSION ':WILD)
	PROMPT (FORMAT NIL "~A (Default is ~A)" PROMPT PATHNAME))
  (LET ((*READING-PATHNAME-DEFAULTS* PATHNAME)
	(*READING-PATHNAME-SPECIAL-TYPE* ':WILD)
	(*READING-PATHNAME-SPECIAL-VERSION* ':WILD)
	(*READING-PATHNAME-DIRECTION* ':READ))
    (TEMP-KILL-RING *LAST-FILE-NAME-TYPED*
      (MULTIPLE-VALUE-BIND (NIL NIL INTERVAL)
	  (EDIT-IN-MINI-BUFFER *PATHNAME-READING-COMTAB* NIL NIL (NCONS PROMPT))
	(SETQ TYPEIN (STRING-INTERVAL INTERVAL)))))
  (COND ((EQUAL TYPEIN "") PATHNAME)
;	((NOT (DO ((I 0 (1+ I))
;		   (LEN (STRING-LENGTH TYPEIN))
;		   (CH))
;		  (( I LEN) NIL)
;		(SETQ CH (AREF TYPEIN I))
;		(OR (AND ( CH #/A) ( CH #/Z))
;		    (AND ( CH #/a) ( CH #/z))
;		    (AND ( CH #/0) ( CH #/9))
;		    (= CH #/-)
;		    (RETURN T))))
;	 ;;No funny characters, must be just a directory name
;	 (FUNCALL PATHNAME ':NEW-DIRECTORY TYPEIN))
	(T
	 (SETQ *LAST-FILE-NAME-TYPED* TYPEIN)
	 (FS:MERGE-PATHNAME-DEFAULTS TYPEIN PATHNAME ':WILD ':WILD))))

(DEFCOM COM-LIST-FILES "Brief directory listing.
Lists several files per line" ()
  (LET* ((PATHNAME (READ-DIRECTORY-NAME "List Directory:" (DEFAULT-PATHNAME)))
	 (LIST (FS:DIRECTORY-LIST PATHNAME)))
    (FORMAT T "~&~A~%" PATHNAME)
    (SETQ LIST (DELQ (ASSQ NIL LIST) LIST))	;Don't care about system info
    (DO L LIST (CDR L) (NULL L)
      (SETF (CAR L) (CONS (FUNCALL (CAAR L) ':STRING-FOR-DIRED) (CAAR L))))
    (FUNCALL *TYPEOUT-WINDOW* ':ITEM-LIST 'FILE LIST))
  DIS-NONE)

(DEFUN VIEW-DIRECTORY (VIEWED-DIRECTORY)
  (SETQ VIEWED-DIRECTORY (FS:MERGE-PATHNAME-DEFAULTS VIEWED-DIRECTORY *PATHNAME-DEFAULTS*))
  (PROMPT-LINE "Viewing directory ~A" VIEWED-DIRECTORY)
  (VIEW-STREAM (DIRECTORY-INPUT-STREAM VIEWED-DIRECTORY))
  DIS-NONE)

;;; This gives an input stream that does output
(DEFUN DIRECTORY-INPUT-STREAM (DIRECTORY)
  (LET-CLOSED ((*DIRECTORY-LIST* DIRECTORY))
    'DIRECTORY-INPUT-STREAM-IO))

(DEFUN DIRECTORY-INPUT-STREAM-IO (OP &OPTIONAL ARG1 &REST REST)
  (DECLARE (SPECIAL *DIRECTORY-LIST*))
  REST
  (SELECTQ OP
    (:WHICH-OPERATIONS '(:LINE-IN))
    (:LINE-IN
     (IF (EQ *DIRECTORY-LIST* 'EOF) (VALUES NIL T)
	 (LET ((STRING (MAKE-ARRAY 80. ':TYPE 'ART-STRING
				       ':LEADER-LENGTH (IF (NUMBERP ARG1) ARG1 1)
				       ':LEADER-LIST '(0))))
	   (WITH-OUTPUT-TO-STRING (S STRING)
	     (COND ((TYPEP *DIRECTORY-LIST* 'FS:PATHNAME)
		    (FUNCALL S ':STRING-OUT (STRING *DIRECTORY-LIST*))
		    (SETQ *DIRECTORY-LIST*
			  (OR (FUNCALL *DIRECTORY-LIST*
				       ':SEND-IF-HANDLES
				       ':DIRECTORY-LIST-STREAM)
			      (FS:DIRECTORY-LIST *DIRECTORY-LIST*))))
		   ((LISTP *DIRECTORY-LIST*)
		    (FUNCALL *DIRECTORY-SINGLE-FILE-LISTER* (POP *DIRECTORY-LIST*) S))
		   ((CLOSUREP *DIRECTORY-LIST*)
		    (LET ((TEM (FUNCALL *DIRECTORY-LIST*)))
		      (IF TEM
			  (FUNCALL *DIRECTORY-SINGLE-FILE-LISTER* TEM S)
			(SETQ *DIRECTORY-LIST* 'EOF)
			(FUNCALL S ':STRING-OUT "Done."))))
		   (T (SETQ *DIRECTORY-LIST* 'EOF)
		      (FUNCALL S ':STRING-OUT "Done."))))
	   (IF (= (AREF STRING (1- (ARRAY-ACTIVE-LENGTH STRING))) #\CR)
	       (DECF (ARRAY-LEADER STRING 0)))	;Flush carriage return
	   STRING)))))

;;; Obsolete ITS only functions
(DEFCOM COM-OLD-LIST-FILES "Brief directory listing.
Lists directory N entries to a line, with the following
special characters to the left of the filenames:
	: this is a link
	! this file has not been backed up to tape yet
	* this file has really been deleted but not yet
	  closed, or is otherwise locked.
	(blank) this is a plain normal file
Also the top line contains in order, the device being
listed from, the directory, Free: followed by the number of
free blocks on the device (separated into primary, secondary, etc.
packs), Used: followed by the number of blocks this directory is taking up." ()
  (LET ((PATHNAME (READ-DIRECTORY-NAME "List Directory:" (DEFAULT-PATHNAME)))
	(LINE NIL) (X NIL) (Y NIL) (X1 NIL) (Y1 NIL) (TEM1 NIL)
	(FREE-ARRAY (MAKE-ARRAY NIL 'ART-Q 10)) (USED-ARRAY (MAKE-ARRAY NIL 'ART-Q 10)))
    (WITH-OPEN-FILE (STREAM (FUNCALL PATHNAME ':DEFAULT-NAMESTRING ".FILE. (DIR)") '(READ))
      (SETQ LINE (FUNCALL STREAM ':LINE-IN))
      (SETQ LINE (FUNCALL STREAM ':LINE-IN))
      (DIRECTORY-FREE-SPACE LINE FREE-ARRAY)
      (FORMAT T "~6A ~6A  " (FUNCALL PATHNAME ':DEVICE) (FUNCALL PATHNAME ':DIRECTORY))
      (FORMAT-DISK-BLOCKS-ARRAY STANDARD-OUTPUT "Free: " FREE-ARRAY)
      (FORMAT T ", Used: ")			;Filled in later
      (MULTIPLE-VALUE (X Y) (FUNCALL STANDARD-OUTPUT ':READ-CURSORPOS ':PIXEL))
      ;; Make any pack that exists show up in the "used" display even if used=0
      (DOTIMES (IDX 10)
	(AND (AREF FREE-ARRAY IDX)
	     (ASET 0 USED-ARRAY IDX)))
      (DO ((I 0 (\ (1+ I) 5)))
	  (NIL)
	(AND (ZEROP I) (TERPRI))
	(SETQ LINE (FUNCALL STREAM ':LINE-IN))
	(COND ((OR (NULL LINE)
		   (ZEROP (ARRAY-ACTIVE-LENGTH LINE))
		   (= (AREF LINE 0) #\FF))
	       (RETURN NIL)))
	(FUNCALL STANDARD-OUTPUT ':TYO
		 (COND ((= #/* (AREF LINE 0))
			#/*)
		       ((= #/L (AREF LINE 2))
			#/:)
		       (T (LET ((USED)
				(PACK (PARSE-NUMBER LINE 2)))
			    (MULTIPLE-VALUE (USED TEM1) (PARSE-NUMBER LINE 20.))
			    (LET ((IDX (IF (OR (< PACK 10.) (> PACK 16.)) 0
					   (- PACK 9.))))
			      (ASET (+ (OR (AREF USED-ARRAY IDX) 0) USED)
				    USED-ARRAY IDX)))
			  (COND ((= #/! (AREF LINE (1+ TEM1)))
				 #/!)
				(T #\SP)))))
	(FUNCALL STANDARD-OUTPUT ':STRING-OUT (NSUBSTRING LINE 6 19.))
	(FUNCALL STANDARD-OUTPUT ':STRING-OUT "  "))
      (FUNCALL STANDARD-OUTPUT ':FRESH-LINE)
      (MULTIPLE-VALUE (X1 Y1) (FUNCALL STANDARD-OUTPUT ':READ-CURSORPOS ':PIXEL))
      (FUNCALL STANDARD-OUTPUT ':SET-CURSORPOS X Y ':PIXEL)
      (FORMAT-DISK-BLOCKS-ARRAY STANDARD-OUTPUT "" USED-ARRAY)
      (FUNCALL STANDARD-OUTPUT ':SET-CURSORPOS X1 Y1 ':PIXEL)))
  DIS-NONE)

(DEFUN SUBSET-DIRECTORY-LISTING (PATHNAME)
  (LET ((FN1 (FUNCALL PATHNAME ':NAME))
	(FN2 (FUNCALL PATHNAME ':FN2)))
    (FORMAT T "~&~A~%" PATHNAME)
    (LET ((LINE NIL)
	  (FREE-ARRAY (MAKE-ARRAY NIL 'ART-Q 10))
	  (USED-ARRAY (MAKE-ARRAY NIL 'ART-Q 10)))
      (WITH-OPEN-FILE (STREAM (FUNCALL PATHNAME ':NEW-STRUCTURED-NAME '(".FILE." "(DIR)"))
			      '(READ))
	;; First find out how much space is free.
	(SETQ LINE (FUNCALL STREAM ':LINE-IN))
	(SETQ LINE (FUNCALL STREAM ':LINE-IN))
	(DIRECTORY-FREE-SPACE LINE FREE-ARRAY)
	;; Make any pack that exists show up in the "used" display even if used=0
	(DOTIMES (IDX 10)
	  (AND (AREF FREE-ARRAY IDX)
	       (ASET 0 USED-ARRAY IDX)))
	;; Next, go through lines of dir, counting USED and printing some lines.
	(DO ((KEY (STRING-APPEND " "
				 (IF (STRING-EQUAL FN1 "TS") FN2 FN1)
				 " "))
	     (LINE) (EOF))
	    (NIL)
	  (MULTIPLE-VALUE (LINE EOF)
	    (FUNCALL STREAM ':LINE-IN))
	  (AND (OR EOF (ZEROP (STRING-LENGTH LINE))) (RETURN NIL))
	  (AND (STRING-SEARCH KEY LINE)
	       (FUNCALL STANDARD-OUTPUT ':LINE-OUT LINE))
	  (OR (= (AREF LINE 2) #/L)
	      (LET ((USED (PARSE-NUMBER LINE 20.))
		    (PACK (PARSE-NUMBER LINE 2)))
		(LET ((IDX (IF (OR (< PACK 10.) (> PACK 16.)) 0
			       (- PACK 9.))))
		  (ASET (+ (OR (AREF USED-ARRAY IDX) 0) USED) USED-ARRAY IDX)))))
	(FORMAT-DISK-BLOCKS-ARRAY T "Free: " FREE-ARRAY)
	(FORMAT-DISK-BLOCKS-ARRAY T ", Used: " USED-ARRAY)))))

;Element 0 of FREE-ARRAY is for packs other than 10.-16.
(DEFUN DIRECTORY-FREE-SPACE (LINE FREE-ARRAY)
  (DO ((I (STRING-SEARCH-CHAR #/# LINE)
	  (STRING-SEARCH-CHAR #/# LINE I))
       (NUM) (IDX) (BLKS))
      ((NULL I))
    (MULTIPLE-VALUE (NUM I)
      (PARSE-NUMBER LINE (1+ I)))
    (MULTIPLE-VALUE (BLKS I)
      (PARSE-NUMBER LINE (1+ I)))
    (SETQ IDX (IF (OR (< NUM 10.) (> NUM 16.)) 0
		  (- NUM 9.)))
    (ASET (+ (OR (AREF FREE-ARRAY IDX) 0) BLKS) FREE-ARRAY IDX)))

(DEFUN FORMAT-DISK-BLOCKS-ARRAY (STREAM TITLE ARRAY)
  (FORMAT STREAM TITLE)
  (DO ((IDX 0 (1+ IDX))
       (LIM (ARRAY-LENGTH ARRAY))
       (FIRSTP T)
       (BLKS))
      ((= IDX LIM))
    (COND ((SETQ BLKS (AREF ARRAY IDX))
	   (FORMAT STREAM "~:[+~]~D" FIRSTP BLKS)
	   (SETQ FIRSTP NIL)))))

(DEFUN ROTATED-DIRECTORY-LISTING (PATHNAME)
  (*CATCH 'ABORT
     (LET ((DEV (FUNCALL PATHNAME ':DEVICE))
           (DIR (FUNCALL PATHNAME ':DIRECTORY))
           (FN1 (FUNCALL PATHNAME ':NAME))
           (FN NIL))
       (SETQ FN (FUNCALL PATHNAME ':NEW-STRUCTURED-NAME '(".FILE." "(DIR)")))
       (PROMPT-LINE "Directory Listing")
       (FORMAT T "~&~A  ~A    --   ~A~%" DEV DIR PATHNAME)
       (LET ((LINE NIL) (X 0) (Y 0))
	 (WITH-OPEN-FILE (STREAM FN '(IN))
	   (SETQ LINE (FUNCALL STREAM ':LINE-IN))
	   (FORMAT T "~A~%" (FUNCALL STREAM ':LINE-IN))
	   (DO ((LINE (SETQ LINE (FUNCALL STREAM ':LINE-IN))
		      (SETQ LINE (FUNCALL STREAM ':LINE-IN)))
		(LFN1 (STRING-LENGTH FN1))
		(LFN16 (+ (STRING-LENGTH FN1) 6))
		)
	       ((NULL LINE)
		(FORMAT T "There is no file named ~A in the directory.~%" FN1))
	     (COND ((STRING-EQUAL LINE FN1 6 0 LFN16 LFN1)
		    ;; Found one.
		    (LET ((FIRST LINE))
		      (SETQ LINE (DO ((LINE LINE (FUNCALL STREAM ':LINE-IN)))
				     ((OR (= (AREF LINE 0) #\FF)
					  (NOT (STRING-EQUAL LINE FN1 6 0 LFN16 LFN1)))
				      LINE)
				   (FORMAT T "~A~%" LINE)))
		      (FORMAT T "==MORE==")
		      (OR (= (FUNCALL STANDARD-INPUT ':TYI) #\SP)
			  (*THROW 'ABORT NIL))
		      (MULTIPLE-VALUE (X Y)
			(FUNCALL STANDARD-OUTPUT ':READ-CURSORPOS))
		      (FUNCALL STANDARD-OUTPUT ':SET-CURSORPOS 0 Y)
		      (FUNCALL STANDARD-OUTPUT ':CLEAR-EOL)
		      (DO ((LINE LINE (FUNCALL STREAM ':LINE-IN)))
			  ((EQUAL LINE FIRST))
			(COND ((ZEROP (STRING-LENGTH LINE))
			       (FORMAT T "------------------------------------------------~%")
			       (CLOSE STREAM)
			       (SETQ STREAM (OPEN FN '(IN)))
			       (FUNCALL STREAM ':LINE-IN)
			       (FUNCALL STREAM ':LINE-IN)
			       (SETQ LINE (FUNCALL STREAM ':LINE-IN))))
			(FORMAT T "~A~%" LINE)))
		    (RETURN NIL)))))))))

(TV:ADD-TYPEOUT-ITEM-TYPE *TYPEOUT-COMMAND-ALIST* DIRECTORY "Edit" DIRECTORY-EDIT-1
			  T "Run DIRED on this directory.")

(DEFUN DIRECTORY-EDIT-1 (DIRECTORY)
  (DIRECTORY-EDIT DIRECTORY)
  NIL)

(TV:ADD-TYPEOUT-ITEM-TYPE *TYPEOUT-COMMAND-ALIST* DIRECTORY "View" VIEW-DIRECTORY
			  NIL "View this directory")

(DEFCOM COM-LIST-ALL-DIRECTORY-NAMES "List names of all disk directories." ()
  (LET* ((DEFAULT (FUNCALL (DEFAULT-PATHNAME) ':NEW-PATHNAME
			   ':DIRECTORY ':WILD ':NAME ':UNSPECIFIC
			   ':TYPE ':UNSPECIFIC ':VERSION ':UNSPECIFIC))
	 (PATHNAME (IF (OR *NUMERIC-ARG-P*
			   (NULL (ZWEI:BUFFER-PATHNAME *INTERVAL*)))
		       (READ-DEFAULTED-PATHNAME "List directories:" DEFAULT
						':UNSPECIFIC ':UNSPECIFIC)
		       DEFAULT))
	 (DIRS (FS:ALL-DIRECTORIES PATHNAME ':NOERROR)))
    (IF (STRINGP DIRS)
	(BARF "Error: ~A" DIRS)
	(SETQ DIRS (SORTCAR DIRS #'FS:PATHNAME-LESSP))
	(FUNCALL STANDARD-OUTPUT ':ITEM-LIST 'DIRECTORY
		 (LOOP FOR (PATHNAME) IN DIRS
		       COLLECT `(,(FUNCALL PATHNAME ':STRING-FOR-DIRECTORY)
				 . ,(FUNCALL PATHNAME ':NEW-PATHNAME ':NAME ':WILD
					     ':TYPE ':WILD ':VERSION ':WILD))))))
  DIS-NONE)

(DEFCOM COM-EXPUNGE-DIRECTORY "Expunge deleted files from a directory" ()
  (LET* ((DIRECTORY (READ-DIRECTORY-NAME "Expunge directory" (DEFAULT-PATHNAME)))
	 (RESULT (FS:EXPUNGE-DIRECTORY DIRECTORY ':ERROR NIL)))
    (IF (STRINGP RESULT) (BARF "Cannot expunge ~A: ~A" DIRECTORY RESULT)
	(TYPEIN-LINE "~A: ~D block~:P freed" DIRECTORY RESULT)))
  DIS-NONE)
