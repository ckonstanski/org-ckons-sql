*;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-
(declaim (optimize (speed 0) (safety 3) (debug 3)))

(in-package :org-ckons-sql)

(defclass record-pkg ()
  ()
  (:documentation "The superclass for all `pkg' classes."))

(defmethod insert-record ((record-pkg record-pkg) (record record))
  (insert-record* record))

(defmethod update-record ((record-pkg record-pkg) (record record))
  (update-record* record))

(defmethod delete-record ((record-pkg record-pkg) (record record))
  (delete-record* record))

(defmethod delete-records ((record-pkg record-pkg) (record record))
  (delete-records* record))

(defmethod delete-records-where ((record-pkg record-pkg) (record record) where-expression)
  (delete-records-where* record where-expression))

(defmethod get-records ((record-pkg record-pkg) (record record) order-by-clause)
  (select-records* record order-by-clause))

(defmethod get-records-where ((record-pkg record-pkg) (record record) where-expression order-by-clause)
  (select-records-where* record where-expression order-by-clause))

(defmethod get-record ((record-pkg record-pkg) (record record))
  (let ((record-list (get-records record-pkg record nil)))
    (when (not (org-ckons-core::null-or-empty-p record-list))
      (car record-list))))

(defmethod get-record-where ((record-pkg record-pkg) (record record) where-expression)
  (let ((record-list (get-records-where record-pkg record where-expression nil)))
    (when (org-ckons-core::null-or-empty-p record-list)
      (car record-list))))

(defmethod get-records-where ((record-pkg record-pkg) (record record) where-expression order-by-clause)
  (select-records-where* record where-expression order-by-clause))

(defmethod call-pg-function ((record-pkg record-pkg) (postgres-record postgres-record))
  (call-pg-function* postgres-record))
