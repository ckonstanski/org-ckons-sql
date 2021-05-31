;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-
(declaim (optimize (speed 0) (safety 3) (debug 3)))

(in-package :org-ckons-sql)

(defmacro with-database (db &body body)
  `(postmodern:with-connection ,db
     ,@body))
