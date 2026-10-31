;;;; rpi-ws281x.asd

(defsystem "rpi-ws281x"
  :description "Common Lisp bindings for the rpi_ws281x C library (WS281x/SK6812 LEDs on the Raspberry Pi)."
  :author "Matthew Kennedy <burnsidemk@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/lispnik/rpi_ws281x"
  :source-control (:git "https://github.com/lispnik/rpi_ws281x.git")
  :depends-on ("cffi")
  :pathname "src/"
  :serial t
  :components ((:file "package")
               (:file "ffi")
               (:file "color")
               (:file "strip"))
  :in-order-to ((test-op (test-op "rpi-ws281x/tests"))))

(defsystem "rpi-ws281x/tests"
  :description "FiveAM tests for rpi-ws281x."
  :depends-on ("rpi-ws281x" "fiveam")
  :pathname "t/"
  :serial t
  :components ((:file "package")
               (:file "tests"))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :fiveam '#:run!
                                       (uiop:find-symbol* '#:rpi-ws281x :rpi-ws281x/tests))
               (error "rpi-ws281x tests failed."))))

(defsystem "rpi-ws281x/examples"
  :description "Example animations for rpi-ws281x."
  :depends-on ("rpi-ws281x")
  :pathname "examples/"
  :components ((:file "strandtest")))
