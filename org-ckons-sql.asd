;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-
(declaim (optimize (speed 0) (safety 3) (debug 3)))

(in-package :cl)

(defpackage :org-ckons-sql-system (:use :cl :asdf))
(in-package :org-ckons-sql-system)

(defmacro do-defsystem (&key name version maintainer author description long-description depends-on components)
  `(defsystem ,name
       :name ,name
       :version ,version
       :maintainer ,maintainer
       :author ,author
       :description ,description
       :long-description ,long-description
       :depends-on ,(eval depends-on)
       :components ,components))

(defparameter *quicklisp-packages* '(postmodern cl-ppcre simple-date simple-date/postgres-glue local-time))
(defparameter *asdf-packages* '(org-ckons-core org-ckons-serializable))
(defparameter *all-packages* (append *quicklisp-packages* *asdf-packages*))

(loop for pkg in *quicklisp-packages* do
     (ql:quickload (symbol-name pkg)))

(do-defsystem :name "org-ckons-sql"
              :version "1"
              :maintainer "Carlos Konstanski <me@ckons.org>"
              :author "Carlos Konstanski <me@ckons.org>"
              :description "org-ckons-sql"
              :long-description "org-ckons-sql is a library which provides a PostgreSQL interface and entity framework. It uses the third-party postmodern library."
              :depends-on *all-packages*
              :components ((:module src
                            :components ((:file "generics")
                                         (:file "database" :depends-on ("generics"))
                                         (:file "record" :depends-on ("database"))
                                         (:file "postgres-record" :depends-on ("record"))
                                         (:file "record-pkg" :depends-on ("postgres-record"))))))
