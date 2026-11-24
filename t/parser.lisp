(in-package :cl-user)
(defpackage quri-test.parser
  (:use :cl
        :quri.parser
        :prove))
(in-package :quri-test.parser)

(plan nil)

(subtest "parser string bounds"
  (is (nth-value 0 (parse-uri "foo://bar")) "foo")
  (is (nth-value 0 (parse-uri "foo://bar" :start 4)) nil)
  (is (nth-value 4 (parse-uri "foo://bar/xyz?a=b#c")) "/xyz")
  (is (nth-value 4 (parse-uri "foo://bar/xyz?a=b#c" :end 12)) "/xy")
  (is (nth-value 5 (parse-uri "foo://bar/xyz?a=b#c")) "a=b")
  (is (nth-value 5 (parse-uri "foo://bar/xyz?a=b#c" :end 13)) nil)
  (is (nth-value 6 (parse-uri "foo://bar/xyz?a=b#c")) "c")
  (is (nth-value 6 (parse-uri "foo://bar/xyz?a=b#c" :end 17)) nil))

(subtest "IDNA host via cl-idna"
  (is (nth-value 2 (parse-uri "http://中央大学.tw/"))
      "xn--fiq80yua78t.tw")
  (is (nth-value 2 (parse-uri "http://βόλος.com/"))
      "xn--nxasmm1c.com")
  (is (quri:uri-host (quri:uri "http://müller.example.com/"))
      "xn--mller-kva.example.com"))

(defparameter *userinfo-authority-test-cases*
  '(;; userinfo before an IPv6 literal
    ("redis://:pw@[::1]:6379/2" ":pw" "[::1]" 6379 "/2" nil nil)
    ("redis://:pw@[::1]/2" ":pw" "[::1]" nil "/2" nil nil)
    ("amqp://app:pw@[::1]:5672/%2F" "app:pw" "[::1]" 5672 "/%2F" nil nil)
    ("http://user@[2001:db8::7]:8080/x" "user" "[2001:db8::7]" 8080 "/x" nil nil)
    ("http://user@[2001:db8::7]/x" "user" "[2001:db8::7]" 80 "/x" nil nil)
    ("redis://@[::1]:6379" "" "[::1]" 6379 nil nil nil)
    ("redis://u@[::1]?db=2#f" "u" "[::1]" nil nil "db=2" "f")
    ;; userinfo before an IPv4 address
    ("redis://:pw@127.0.0.1:6379/2" ":pw" "127.0.0.1" 6379 "/2" nil nil)
    ("redis://user@127.0.0.1/2" "user" "127.0.0.1" nil "/2" nil nil)
    ;; userinfo before a reg-name
    ("redis://user:pw@localhost:6379/0" "user:pw" "localhost" 6379 "/0" nil nil)
    ("redis://user@cache.example.com/0" "user" "cache.example.com" nil "/0" nil nil)
    ;; a bare IPv6 literal
    ("redis://[::1]:6379/0" nil "[::1]" 6379 "/0" nil nil)
    ("redis://[::1]/0" nil "[::1]" nil "/0" nil nil))
  "RFC 3986 3.2: authority = [ userinfo \"@\" ] host [ \":\" port ], and host
may be an IP literal.  Each case is (uri userinfo host port path query
fragment), the PARSE-URI values after the scheme.  They agree with Python's
urllib.parse.urlsplit, except that quri keeps an IP literal's brackets
(fukamachi/quri#91) and gives http its default port.")

(defparameter *malformed-authority-test-cases*
  '("redis://:pw@[::1]@host/"
    "redis://:pw@host[::1]/"
    "redis://:pw@[::1]:63[79/"
    "redis://a@b@[::1]:6379/"
    "redis://:pw@@[::1]/"
    "redis://us[er@[::1]/"
    "redis://:p w@[::1]/")
  "Authorities that stay malformed: a second \"@\", \"[\" anywhere but the
start of the host, and characters outside userinfo's set (RFC 3986 3.2.1).
Python's urlsplit rejects the first three too; it does not check userinfo's
characters.")

(defun check-authority (test-uri expected)
  "PARSE-URI of TEST-URI, as a string and as octets, gives EXPECTED after the
scheme, and RENDER-URI gives TEST-URI back."
  (dolist (data (list test-uri (babel:string-to-octets test-uri)))
    (is (rest (multiple-value-list (parse-uri data))) expected
        (format nil "~A (~:[byte-vector~;string~])" test-uri (stringp data))
        :test #'equal))
  (is (quri:render-uri (quri:uri test-uri)) test-uri
      (format nil "~A (render-uri)" test-uri)))

(defun check-malformed-authority (test-uri)
  "PARSE-URI signals URI-MALFORMED-STRING for TEST-URI, as a string and as
octets."
  (is-error (parse-uri test-uri) 'quri:uri-malformed-string
            (format nil "~A (string)" test-uri))
  (is-error (parse-uri (babel:string-to-octets test-uri))
            'quri:uri-malformed-string
            (format nil "~A (byte-vector)" test-uri)))

(loop for (test-uri . expected) in *userinfo-authority-test-cases*
      do (subtest test-uri (check-authority test-uri expected)))

(loop for test-uri in *malformed-authority-test-cases*
      do (subtest test-uri (check-malformed-authority test-uri)))

(finalize)
