;;;; CI: install project deps via cl-repository-client (OCI), then test this checkout.
;;;;
;;;; cl-repository-client itself is bootstrapped in the workflow (QL deps for the
;;;; client only — same list as every other egao1980 CI). This file must not
;;;; ql:quickload project systems; those come from cl-repo below.
;;;;
;;;; Special case: this checkout is also named "quri", and the client's QL
;;;; bootstrap already loaded upstream quri. Hide ./quri.asd until cl-idna is
;;;; installed via cl-repo, then register this checkout for the test run.

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&UNHANDLED: ~A~%" c)
        (uiop:quit 1)))

(setf asdf:*compile-file-failure-behaviour* :warn)

(defun call-with-ci-muffles (fn)
  #+sbcl
  (handler-bind ((sb-ext:defconstant-uneql
                  (lambda (c)
                    (declare (ignore c))
                    (let ((r (find-restart 'continue)))
                      (when r (invoke-restart r))))))
    (funcall fn))
  #-sbcl
  (funcall fn))

(defun ci-root ()
  (uiop:getcwd))

;;; Hide ./quri.asd while loading the client (needs upstream quri from the
;;; workflow bootstrap, not this fork's cl-idna-dependent .asd).
(let ((repo (merge-pathnames ".cl-repository/" (ci-root))))
  (asdf:initialize-source-registry
   `(:source-registry
     (:tree ,repo)
     :ignore-inherited-configuration)))

(call-with-ci-muffles
 (lambda ()
   (asdf:load-system "cl-repository-client")))

(defun ci-load (name &key version)
  (format t "~&; ci: cl-repo load ~a~@[:~a~]~%" name version)
  (call-with-ci-muffles
   (lambda ()
     (if version
         (cl-repo:load-system name :version version :sources *ci-ql-sources*)
         (cl-repo:load-system name :sources *ci-ql-sources*))))
  (unless (asdf:component-loaded-p name)
    (error "ci-load: ~a did not load" name)))

(defun ci-ensure-ql (&rest names)
  "QL only for systems not yet published to egao1980/cl-systems."
  (dolist (name names)
    (unless (asdf:find-system name nil)
      (format t "~&; ci: ql fallback (unpublished) ~a~%" name)
      (ql:quickload name :silent t))))

(defun ci-use-local-checkout ()
  "Register this checkout after OCI deps are installed (esp. cl-idna)."
  (let ((root (ci-root)))
    (pushnew root asdf:*central-registry* :test #'equal)
    (asdf:initialize-source-registry
     `(:source-registry
       (:directory ,root)
       (:tree ,(merge-pathnames ".cl-repository/" root))
       (:tree ,(merge-pathnames ".local/share/cl-repository/systems/"
                                (user-homedir-pathname)))
       :inherit-configuration))
    (asdf:load-asd (merge-pathnames "quri.asd" root))
    (asdf:load-asd (merge-pathnames "quri-test.asd" root))
    (asdf:clear-system "quri")
    (asdf:clear-system "quri-test")))

(defparameter *ci-ql-sources*
  '(("babel" :ql)
    ("trivial-features" :ql)
    ("cl-unicode" :ql))
  "cl-repo :sources pins — babel already in client image; cl-unicode OCI lacks idna-mapping.")

(cl-repo:add-registry "https://ghcr.io" :namespace "egao1980/cl-systems" :priority :prepend)

(call-with-ci-muffles
 (lambda ()
   ;; Project deps: cl-repo only (newest tag). Not ql:quickload.
   (ci-load "alexandria")
   (ci-load "split-sequence")
   (ci-load "cl-utilities")
   (ci-load "cl-idna")
   (ci-ensure-ql "prove") ; not published to cl-systems yet
   (ci-use-local-checkout)
   (asdf:test-system "quri")))

(uiop:quit 0)
