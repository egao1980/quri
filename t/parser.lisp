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

(finalize)
