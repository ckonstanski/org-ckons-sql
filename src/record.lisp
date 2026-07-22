 ;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-
(declaim (optimize (speed 0) (safety 3) (debug 3)))

(in-package :org-ckons-sql)

(defclass record (org-ckons-serializable::serializable)
  ((*project :initarg :*project
             :initform nil
             :accessor *project)
   (*table :initarg :*table
           :initform (error "Subclasses of RECORD must supply an initform for the *TABLE slot.")
           :accessor *table)
   (*where-expression :initarg :*where-expression
                      :initform (error "Subclasses of RECORD must supply an initform for the *WHERE-EXPRESSION slot.")
                      :accessor *where-expression
                      :documentation "A string that specifies a WHERE
clause that is the proper format to feed through
`expand-where-expression'. `nil' if the `record' subclass is
read-only, as would be the case if the backing table is a view, or a
table that you do not ever want to write to."))
  (:documentation "Superclass for all sql record objects. Since some
`record' subclasses are also `session' subclasses, `record' is
sometimes involved in multiple inheritance.

`record' is not 100% ready to be used directly as a superclass of a
concrete entity object. We need a few more methods than what `record'
alone supplies:

`sysdate'
`to-date'
`sanitize'

See `postgres-record' as an example of their implementations. All
`record' subclasses are really direct subclasses of one of these
database-specific variants."))

(defmacro with-record-slots-to-string (record &rest body)
  "Iterates over all the slots of `record', and builds a string based
on those slots. The action taken on each slot is completely
customizable; this macro only provides the loop. It is assumed that
the fencepost problem will creep into your string, so this macro trims
the last character."
  `(let ((record-slot-string (make-array '(0) :element-type 'character :fill-pointer 0 :adjustable t)))
     (with-output-to-string (stream record-slot-string)
       (loop for slot in (org-ckons-core::map-slot-names ,record) do
            (when (slot-is-field-p slot) ,@body)))
     (org-ckons-core::trim-last-char record-slot-string)))

(defmacro with-record-slots-to-list (record &rest body)
  "Iterates over all the slots of `record', and builds an alist based
on those slots."
  `(remove-if 'null (mapcar (lambda (slot)
                              (when (slot-is-field-p slot)
                                ,@body))
                            (org-ckons-core::map-slot-names ,record))))

;; (defmethod id ((record record))
;;   (car (remove-if 'null (mapcar (lambda (slot)
;;                                   (when (string= (org-ckons-core::parse-slot slot) "ID")
;;                                     (slot-value record slot)))
;;                                 (org-ckons-core::map-slot-names record)))))

;; (defmethod (setf id) (value (record record))
;;   (loop for slot in (org-ckons-core::map-slot-names record) do
;;        (when (string= (org-ckons-core::parse-slot slot) "ID")
;;          (setf (slot-value record slot) value))))

(defmethod field-names-string ((record record))
  (with-record-slots-to-string record (format stream "~a," slot)))

(defmethod field-values-string ((record record))
  (with-record-slots-to-string record (format stream "~a," (sanitize record (slot-value record slot)))))

(defmethod field-value-pairs ((record record))
  (with-record-slots-to-string record (format stream "~a = ~a," slot (sanitize record (slot-value record slot)))))

(defmethod field-value-pairs-no-nulls ((record record))
  (with-record-slots-to-string record (when (slot-value record slot)
                                        (format stream "~a = ~a," slot (sanitize record (slot-value record slot))))))

(defmethod field-value-list ((record record))
  (with-record-slots-to-list record `(,slot . ,(slot-value record slot))))

(defmethod field-value-list-no-nulls ((record record))
  (with-record-slots-to-list record (when (slot-value record slot)
                                      `(,slot . ,(slot-value record slot)))))

(defmethod field-plist-no-nulls ((record record))
  (let ((field-plist ()))
    (loop for field in (field-value-list-no-nulls record) do
         (setf field-plist (append field-plist `(,(intern (format nil "~a" (car field)) "KEYWORD") ,(cdr field)))))
    field-plist))

(defmethod build-where-clause ((record record))
  (if (field-value-list-no-nulls record)
      (reduce (lambda (x y)
                  (format nil "~a AND ~a" x y))
              (mapcar (lambda (slot-cons)
                          (format nil "~a = ~a" (car slot-cons) (sanitize record (cdr slot-cons))))
                      (field-value-list-no-nulls record)))
      nil))

(defmethod intersect-slots ((record record) slots)
  (let ((intersect-slots ()))
    (loop for class-slot in (org-ckons-core::map-slot-names record) do
         (let ((class-slot-string (org-ckons-core::parse-slot class-slot)))
           (loop for arg-slot in slots do
                (let ((arg-slot-string (org-ckons-core::parse-slot arg-slot)))
                  (when (string= class-slot-string arg-slot-string)
                    (push class-slot intersect-slots))))))
    (nreverse intersect-slots)))

(defmethod expand-where-expression ((record record) where-expression)
  (if (org-ckons-core::null-or-empty-p where-expression)
      ""
      (let ((field-names (nreverse (remove-if (lambda (x)
                                                (or (org-ckons-core::null-or-empty-p x)
                                                    (equal x "LIKE")
                                                    (equal x "NOT")))
                                              (ppcre:split "[ ()!=<>,]" where-expression))))
            (slots ())
            (slot-values ()))
        (let ((field-name-impending-p nil))
          (loop for field-name in field-names do
               (cond (field-name-impending-p
                      (push (intern (string-upcase field-name)) slots)
                      (setf field-name-impending-p nil))
                     (t
                      (when (ppcre:all-matches-as-strings "~a" field-name)
                        (setf field-name-impending-p t))))))
        (loop for slot in (intersect-slots record slots) do
             (when (slot-is-field-p slot)
               (push (sanitize record (slot-value record slot)) slot-values)))
        (org-ckons-core::format-list (concatenate 'string " WHERE " where-expression) (reverse slot-values)))))

(defmethod insert-query ((record record))
  (let* ((field-value-alist (field-value-list-no-nulls record)))
    (format nil
            "INSERT INTO ~a (~a) VALUES (~a) RETURNING id"
            (org-ckons-core::format-list (if (slot-exists-p record '*write-table)
                                             (slot-value record '*write-table)
                                             (slot-value record '*table))
              `(,(*project record)))
            (org-ckons-core::reduce-to-comma-separated-string (mapcar (lambda (pair)
                                                                        (car pair))
                                                                      field-value-alist))
            (org-ckons-core::reduce-to-comma-separated-string (mapcar (lambda (pair)
                                                                        (sanitize record (cdr pair)))
                                                                      field-value-alist)))))

(defmethod currval-query ((record record))
  (format nil "SELECT * FROM currval(pg_get_serial_sequence('~a', 'id'))" (*table record)))

(defmethod update-query ((record record))
  (if (null (*where-expression record))
      (error 'org-ckons-condition::handled-error (format nil "Attempting to update a record of type ~a, but it has no *WHERE-EXPRESSION" (type-of record)))
      (format nil
              "UPDATE ~a SET ~a~a"
              (org-ckons-core::format-list (if (slot-exists-p record '*write-table) (slot-value record '*write-table) (slot-value record '*table)) `(,(*project record)))
              (field-value-pairs record)
              (expand-where-expression record (*where-expression record)))))

(defmethod select-query ((record record))
  (format nil
          "SELECT ~a FROM ~a"
          (field-names-string record)
          (org-ckons-core::format-list (*table record) `(,(*project record)))))

(defmethod delete-query ((record record))
  (format nil
          "DELETE FROM ~a"
          (org-ckons-core::format-list (if (slot-exists-p record '*write-table)
                                           (slot-value record '*write-table)
                                           (slot-value record '*table))
                                       `(,(*project record)))))

(defmethod insert-record* ((record record))
  (setf (id record) (execute-command (insert-query record))))
  
(defmethod update-record* ((record record))
  (execute-command (update-query record)))

(defmethod select-records-impl* ((record record) where-expression order-by-clause)
  (let* ((where-string (expand-where-expression record where-expression))
         (order-by-string (if (org-ckons-core::null-or-empty-p order-by-clause)
                              ""
                              (format nil " ORDER BY ~a" order-by-clause)))
         (sql-query (format nil
                            "~a~a~a"
                            (select-query record)
                            where-string
                            order-by-string)))
    (execute-query sql-query)))

(defmethod select-records* ((record record) order-by-clause)
  (select-records-where* record (build-where-clause record) order-by-clause))

(defmethod select-records-where* ((record record) where-expression order-by-clause)
  (let* ((result-set (select-records-impl* record where-expression order-by-clause))
         (records ()))
    (loop for row in result-set do
         (let ((my-record (make-instance (type-of record))))
           (load-record my-record row)
           (push my-record records)))
    (nreverse records)))

(defmethod delete-records-impl* ((record record) where-expression)
  (let* ((where-string (expand-where-expression record where-expression))
         (sql-query (format nil "~a~a"  (delete-query record) where-string)))
    (execute-command sql-query)))

(defmethod delete-record* ((record record))
  (delete-records-where* record (format nil (*where-expression record) (id record))))

(defmethod delete-records* ((record record))
  (delete-records-where* record (build-where-clause record)))

(defmethod delete-records-where* ((record record) where-expression)
  (delete-records-impl* record where-expression))

(defmethod load-record ((record record) row)
  (loop for slot in (org-ckons-core::map-slot-names record) do
       (when (slot-is-field-p slot)
         (eval `(setf (,slot ,record) ,(pop row))))))

(defmethod sanitize-json ((record record))
  (setf (*project record) nil)
  (setf (*table record) nil)
  (setf (*where-expression record) nil))

(defun slot-is-field-p (slot)
  (equal (symbol-name slot) (ppcre:regex-replace "^\\*" (symbol-name slot) "")))

(defun execute-command (sql-query)
  "Given a SQL query in a string, runs the query. No result set is
returned. Use this for INSERT, UPDATE, DELETE, etc."
  ;;(print sql-query)
  (postmodern:execute sql-query))

(defun execute-query (sql-query)
  "Given a SQL query in a string, runs the query and returns the
result set. Use this for SELECT."
  ;;(print sql-query)
  (postmodern:query sql-query))

(defun timestamp-to-date (timestamp)
  (let ((dateparts (ppcre:split "-" (local-time:to-rfc3339-timestring timestamp))))
    (ppcre:regex-replace-all "T" (format nil "~a-~a-~a" (pop dateparts) (pop dateparts) (pop dateparts)) " ")))

(defun universal-to-date (universal)
  (timestamp-to-date (local-time:universal-to-timestamp universal)))

(defun simple-date-to-date (simple-date)
  (universal-to-date (simple-date:timestamp-to-universal-time simple-date)))

(defun get-date (full-sql-date)
  (car (ppcre:split "\\." full-sql-date)))

(defun notime (full-sql-date)
  (car (ppcre:split " " full-sql-date)))

(defun quote-string (field)
  "Puts single ticks around `field'."
  (format nil "'~a'" (ppcre:regex-replace-all "'" field "''")))

(defun get-slot-names-list (record-type)
  "Returns a list of field slots in `record-type'. `record-type' is a
symbol, not a `record' instance."
  (remove-if-not (lambda (x)
                     (slot-is-field-p x))
                 (org-ckons-core::map-slot-names (make-instance (find-class record-type)))))
