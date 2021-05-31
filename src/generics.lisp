;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-
(declaim (optimize (speed 0) (safety 3) (debug 3)))

(defpackage :org-ckons-sql
  (:use :cl)
  (:export :id
           :*project
           :*table
           :*where-expression
           :record
           :postgres-record
           :record-pkg
           :get-record
           :get-records
           :insert-record
           :update-record
           :delete-record
           :call-pg-function
           :intersect-slots
           :slot-is-field-p
           :simple-date-to-date
           :sanitize-json
           :with-database))

(in-package :org-ckons-sql)

(defgeneric to-date (record date-string)
  (:documentation "In PostgreSQL, a string in the format `YYYY-MM-DD
HH:MM:SS' can be used directly to populate a date field. Therefore,
this function does nothing except to put quotes arount the value."))

(defgeneric sanitize (record field)
  (:documentation "If `field' is a lisp `nil', returns `NULL'.  Also
converts datestrings to a PLSQL to_date() function call, converts
numbers to oracle-friendly representations, and puts single ticks
around string values.  All munging, workarounds, hacks, etc. to make
the interface between lisp and PostgreSQL work better should be done
here."))

(defgeneric call-pg-function* (record)
  (:documentation "Calls a Postgresql function that returns something
other than a result set that matches up with the passed-in `record'
which is always a postgresql-record, or returns nothing at all."))

(defgeneric field-names-string (record)
  (:documentation "Builds a string of SQL query field names."))

(defgeneric field-values-string (record)
  (:documentation "Builds a string of SQL query values to match the
field names returned by `field-names-string'."))

(defgeneric field-value-pairs (record)
  (:documentation "Builds a string of SQL query field/value pairs."))

(defgeneric field-value-pairs-no-nulls (record)
  (:documentation "Builds a string of SQL query field/value pairs, but
only those fields with a non-null value are included."))

(defgeneric field-value-list (record)
  (:documentation "Builds a list of SQL query field/value pairs, but
only those fields with a non-null value are included."))

(defgeneric field-value-list-no-nulls (record)
  (:documentation "Builds a list of SQL query field/value pairs, but
only those fields with a non-null value are included."))

(defgeneric field-plist-no-nulls (record)
  (:documentation "Returns the non-null field slots of `record' as a
plist. Used for record serialization."))

(defgeneric build-where-clause (record)
  (:documentation "Builds a WHERE clause from the non-nil slots in
`record'."))

(defgeneric intersect-slots (record slots)
  (:documentation "Since the built-in `intersect' function does not
take package name prefixes into account, and since `map-slot-names'
returns slot names prefixed with the package name, this method was
written to intersect lists ignoring package prefixes."))

(defgeneric expand-where-expression (record where-expression)
  (:documentation "All WHERE clauses must pass through this method.
If the WHERE clause contains all hard-coded values, then it will make
it through untouched.  If it contains ~a placeholders, it will be
parsed and expanded using the values contained in `record'.  Finally
the WHERE keyword is prepended."))

(defgeneric insert-query (record)
  (:documentation "Builds an INSERT query to save the state of
`record' in the database. Does not include `nil' slots."))

(defgeneric currval-query (record)
  (:documentation "Calls currval() to get the last inserted ID. This
must be called with the same database connection that performed the
prior INSERT, and `record' must have a `*table' that can be used as
the first arguemnt to pg_get_serial_sequence()."))

(defgeneric update-query (record)
  (:documentation "Builds an UPDATE query to save the state of
`record' in the database."))

(defgeneric select-query (record)
  (:documentation "Builds a SELECT query to retrieve the state of
`record' from the database."))

(defgeneric delete-query (record)
  (:documentation "Builds a DELETE query to to delete a `record' from
the database.  CAUTION: use this only on `record' objects whose
backend tables are real tables, not inlined table functions."))

(defgeneric insert-record* (record)
  (:documentation "Inserts the state of `record' into the database,
and fetches the newly-created ID into the `id' slot of `record'."))

(defgeneric update-record* (record)
  (:documentation "Saves the state of `record' to the database."))

(defgeneric select-records-impl* (record where-clause order-by-clause)
  (:documentation "Low-level function which is to be called via
`select-records'.  Executes a SELECT statement with the given WHERE
clause and ORDER BY clause. Do not include the WHERE and ORDER BY
keywords in your arguments, as they will be automatically
prepended."))

(defgeneric select-records* (record order-by-clause)
  (:documentation "High-level interface to `select-records-impl'.
Executes a SELECT statement with the given ORDER BY clause, with a
WHERE clause automatically built by AND-separating the name/values
stored in `record', and fetches the result set of the query into a
list of `record' objects.  Do not include the ORDER BY keyword in
`order-by-clause', as it will be automatically prepended."))

(defgeneric select-records-where* (record where-expression order-by-clause)
  (:documentation "High-level interface to `select-records-impl'.
Executes a SELECT statement with the given WHERE clause and ORDER BY
clause.  `where-expression' is a FORMAT-style string which uses ~a for
value placeholders.  The slots of `record' that correspond to the
field names in `where-expression' are used to fill in the
placeholders.  Fetches the result set of the query into a list of
`record' objects.  Do not include the WHERE and ORDER BY keywords in
`where-expression' and `order-by-clause', as they will be
automatically prepended."))

(defgeneric delete-records-impl* (record where-expression)
  (:documentation "Low-level function which is to be called via
`delete-records'.  Executes a DELETE statement with the given WHERE
clause.  Do not include the WHERE keyword in your argument, as this
method automatically prepends it."))

(defgeneric delete-record* (record)
  (:documentation "High-level interface to `delete-records-impl'.
Convenience function for deleting records by `id'. record' must
conform to a certain standard pattern. Executes a DELETE statement
with a WHERE clause built with `*where-expression' and `id'. Assumes
that `*where-expression' is the format string id = ~a."))

(defgeneric delete-records* (record)
  (:documentation "High-level interface to `delete-records-impl'.
Executes a DELETE statement with a WHERE clause automatically built by
AND-separating the name/values stored in `record'."))

(defgeneric delete-records-where* (record where-expression)
  (:documentation "High-level interface to `delete-records-impl'.
Executes a DELETE statement with the given WHERE clause.
`where-expression' is a FORMAT-style string which uses ~a for value
placeholders.  The slots of `record' that correspond to the field
names in `where-expression' are used to fill in the placeholders.Do
not include the WHERE keyword in `where-expression', as it will be
automatically prepended."))

(defgeneric load-record (record row)
  (:documentation "Populates the slots of the `record' subclass from
the fields in `row', which are usually obtained by running a SELECT
query."))

(defgeneric sanitize-json (record-or-service)
  (:documentation "Untaints the record or service object so that it's
safe to serialize into JSON."))

(defgeneric insert-record (record-pkg record)
  (:documentation "Inserts a new record into the table associated with
`record', using the data from `record'."))

(defgeneric update-record (record-pkg record)
  (:documentation "Updates an existing record in the table associated
with `record', using the data from `record'."))

(defgeneric delete-record (record-pkg record)
  (:documentation "Deletes an existing record in the table associated
with `record', using `id' and `*where-expression' from `record'."))

(defgeneric delete-records (record-pkg record)
  (:documentation "Deletes an existing record in the table associated
with `record', using the data from `record'."))

(defgeneric delete-records-where (record-pkg record where-expression)
  (:documentation "Updates an existing record in the table associated
with `record', using the passed-in `where-expression'."))

(defgeneric get-records (record-pkg record order-by-clause)
  (:documentation "All-purpose method for issuing a SELECT statement
to obtain a result set of `record' objects.  The instance of `record'
passed into this method is used to hold input parameters, including
the table name.  Any slots that are populated with a non-nil value
will be used in the AND-separated WHERE clause.  Fetches the result
set of the query into a list of `record' objects."))

(defgeneric get-records-where (record-pkg record where-expression order-by-clause)
  (:documentation "All-purpose method for issuing a SELECT statement
to obtain a result set of `record' objects.  The instance of `record'
passed into this method is used to hold input parameters, including
the table name.  `where-expression' is a FORMAT-style string which
uses ~a for value placeholders.  The slots of `record' that correspond
to the field names in `where-expression' are used to fill in the
placeholders.  Fetches the result set of the query into a list of
`record' objects."))

(defgeneric get-record (record-pkg record)
  (:documentation "Returns a single `record' object.  The instance of
`record' passed into this method is used to hold input parameters,
including the table name.  Any slots that are populated with a non-nil
value will be used in the AND-separated WHERE clause.  Meant for
queries that return only one unique row.  Returns `nil' if no rows
were found matching the query.  Warning: if more than one row is
returned by the query, this method will return the first one.  Note
that you cannot control which row will be first because of the lack of
an ORDER BY clause.  Use this only for queries that are supposed to
return no more than one row."))

(defgeneric get-record-where (record-pkg record where-expression)
  (:documentation "Returns a single `record' object.  The instance of
`record' passed into this method is used to hold input parameters,
including the table name.  `where-expression' is a FORMAT-style string
which uses ~a for value placeholders.  The slots of `record' that
correspond to the field names in `where-expression' are used to fill
in the placeholders.  Meant for queries that return only one unique
row.  Returns `nil' if no rows were found matching the query.
Warning: if more than one row is returned by the query, this method
will return the first one.  Note that you cannot control which row
will be first because of the lack of an ORDER BY clause.  Use this
only for queries that are supposed to return no more than one row."))

(defgeneric call-pg-function (record-pkg postgresql-record)
  (:documentation ""))
