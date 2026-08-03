;;;; CI: install deps via cl-repository-client (OCI), then test this checkout.

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&UNHANDLED: ~A~%" c)
        (uiop:quit 1)))

;; QL client bootstrap and OCI pins can both define babel constants / packages.
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
  (let ((root (uiop:getcwd)))
    (pushnew root asdf:*central-registry* :test #'equal)
    (asdf:load-asd (merge-pathnames "quri.asd" root))
    (asdf:load-asd (merge-pathnames "quri-test.asd" root))
    (asdf:clear-system "quri")
    (asdf:clear-system "quri-test")))

(defparameter *ci-ql-sources*
  '(("babel" :ql)
    ("trivial-features" :ql)
    ("cl-unicode" :ql))
  "QL pins: babel already bootstrapped; cl-unicode OCI v0.1.6 lacks idna-mapping.")

(cl-repo:add-registry "https://ghcr.io" :namespace "egao1980/cl-systems" :priority :prepend)

(call-with-ci-muffles
 (lambda ()
   ;; Omit :version -> cl-repo resolves newest published tag.
   (ci-load "alexandria")
   (ci-load "split-sequence")
   (ci-load "cl-utilities")
   (ci-load "cl-idna")
   (ci-ensure-ql "prove")
   (ci-use-local-checkout)
   (asdf:test-system "quri")))

(uiop:quit 0)
