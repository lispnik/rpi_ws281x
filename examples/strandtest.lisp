;;;; examples/strandtest.lisp -- a Lisp port of the upstream strandtest
;;;;
;;;; As root on a Raspberry Pi:
;;;;   (asdf:load-system "rpi-ws281x/examples")
;;;;   (rpi-ws281x-examples:strandtest :count 30)

(defpackage #:rpi-ws281x-examples
  (:use #:cl #:rpi-ws281x)
  (:export #:strandtest #:color-wipe #:theater-chase #:rainbow #:rainbow-cycle))

(in-package #:rpi-ws281x-examples)

(defun show (strip wait-ms)
  (render strip)
  (sleep (/ wait-ms 1000)))

(defun color-wipe (strip color &key (wait-ms 50))
  "Light the strip one LED at a time."
  (dotimes (i (led-count strip))
    (setf (led strip i) color)
    (show strip wait-ms)))

(defun theater-chase (strip color &key (wait-ms 50) (iterations 10))
  "Movie-theater style crawling lights."
  (dotimes (j iterations)
    (dotimes (q 3)
      (loop for i from q below (led-count strip) by 3
            do (setf (led strip i) color))
      (show strip wait-ms)
      (loop for i from q below (led-count strip) by 3
            do (setf (led strip i) 0)))))

(defun rainbow (strip &key (wait-ms 20) (iterations 1))
  "Every LED shows the same color, cycling through the wheel."
  (dotimes (j (* 256 iterations))
    (fill-leds strip (wheel j))
    (show strip wait-ms)))

(defun rainbow-cycle (strip &key (wait-ms 20) (iterations 5))
  "A rainbow spread evenly along the strip, rotating."
  (let ((n (led-count strip)))
    (dotimes (j (* 256 iterations))
      (dotimes (i n)
        (setf (led strip i) (wheel (+ (floor (* i 256) n) j))))
      (show strip wait-ms))))

(defun strandtest (&key (count 16) (gpio 18) (dma 10) (brightness 64)
                        (strip-type +ws2811-strip-grb+))
  (with-strip (strip :count count :gpio gpio :dma dma
                     :brightness brightness :strip-type strip-type)
    (color-wipe strip (rgb 255 0 0))
    (color-wipe strip (rgb 0 255 0))
    (color-wipe strip (rgb 0 0 255))
    (theater-chase strip (rgb 127 127 127))
    (theater-chase strip (rgb 127 0 0))
    (theater-chase strip (rgb 0 0 127))
    (rainbow strip)
    (rainbow-cycle strip)))
