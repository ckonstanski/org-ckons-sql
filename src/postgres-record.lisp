;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-
(declaim (optimize (speed 0) (safety 3) (debug 3)))

(in-package :org-ckons-sql)

(defclass postgres-record (record) ())

(defun sysdate ()
  (simple-date-to-date (caar (execute-query (format nil "select now()")))))

(defun date-or-nothing (value)
  (handler-case
      (simple-date-to-date value)
    (error (e)
      (declare (ignore e))
      nil)))

(defmethod to-date ((postgres-record postgres-record) date-string)
  (quote-string date-string))

(defmethod sanitize ((postgres-record postgres-record) field)
  (cond ((numberp field)
         (if (integerp field)
             (format nil "~a" (parse-integer (format nil "~a" field) :junk-allowed t))
             (org-ckons-core::real-to-string field :places 4)))
        ((org-ckons-core::null-or-empty-p field)
         "NULL")
        ((stringp field)
         (cond ((org-ckons-core::match-it "^\\d\\d\\d\\d-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d" field)
                (to-date postgres-record field))
               (t
                (quote-string field))))
        (t
         field)))

(defmethod call-pg-function* ((postgres-record postgres-record))
  (execute-query (format nil "select * from ~a" (*table postgres-record))))
