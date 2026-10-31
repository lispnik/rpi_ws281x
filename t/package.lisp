;;;; t/package.lisp

(defpackage #:rpi-ws281x/tests
  (:use #:cl #:fiveam #:rpi-ws281x)
  (:shadowing-import-from #:rpi-ws281x #:wait)
  (:local-nicknames (#:ffi #:rpi-ws281x.ffi))
  (:export #:rpi-ws281x #:run-tests))
