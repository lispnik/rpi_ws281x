;;;; t/tests.lisp
;;;;
;;;; Everything except the HARDWARE suite runs on any machine, with or
;;;; without libws2811. The LED buffer tests stand in for ws2811_init by
;;;; attaching a foreign buffer to the channel themselves.
;;;;
;;;; To run the hardware tests on a Pi (as root, LEDs on GPIO 18):
;;;;   RPI_WS281X_HARDWARE_TESTS=1 RPI_WS281X_TEST_LEDS=8 sbcl ...

(in-package #:rpi-ws281x/tests)

(def-suite rpi-ws281x :description "All rpi-ws281x tests.")

(defun run-tests ()
  (run! 'rpi-ws281x))

;;; Helpers

(defun channel-pointer (strip channel)
  (rpi-ws281x::%channel strip channel))

(defun channel-slot (strip channel slot)
  (cffi:foreign-slot-value (channel-pointer strip channel)
                           '(:struct ffi:ws2811-channel) slot))

(defmacro with-fake-strip ((var &rest args) &body body)
  "Make an uninitialized strip and attach malloc'd LED buffers to each
channel with a nonzero count, mimicking what ws2811_init does."
  `(let ((,var (make-strip ,@args)))
     (unwind-protect
          (progn
            (dotimes (c 2)
              (let ((n (led-count ,var c)))
                (when (plusp n)
                  (setf (cffi:foreign-slot-value (channel-pointer ,var c)
                                                 '(:struct ffi:ws2811-channel)
                                                 'ffi:leds)
                        (cffi:foreign-alloc :uint32 :count n :initial-element 0)))))
            ,@body)
       (when (strip-open-p ,var)
         (dotimes (c 2)
           (let ((p (channel-slot ,var c 'ffi:leds)))
             (unless (cffi:null-pointer-p p)
               (cffi:foreign-free p))))
         (free-strip ,var)))))

;;; FFI layer

(def-suite ffi :in rpi-ws281x)
(in-suite ffi)

(test constants
  (is (= 800000 ffi:+ws2811-target-freq+))
  (is (= 2 ffi:+rpi-pwm-channels+))
  (is (= #x00081000 ffi:+ws2811-strip-grb+))
  (is (= #x00100800 ffi:+ws2811-strip-rgb+))
  (is (= #x18081000 ffi:+sk6812-strip-grbw+))
  (is (= ffi:+ws2811-strip-grb+ ffi:+ws2812-strip+ ffi:+sk6812-strip+))
  (is (= ffi:+sk6812-strip-grbw+ ffi:+sk6812w-strip+))
  ;; Re-exported from the high-level package.
  (is (eq 'ffi:+ws2812-strip+ 'rpi-ws281x:+ws2812-strip+)))

(test return-code-table
  (is (= 15 (length ffi:*return-codes*)))
  (is (equal (loop for i from 0 downto -14 collect i)
             (mapcar #'first ffi:*return-codes*)))
  (is (eq :success (return-code-keyword 0)))
  (is (eq :error-mmap (return-code-keyword -5)))
  (is (eq :unknown (return-code-keyword -99)))
  (is (string= "Selected GPIO not possible" (return-code-message -11)))
  (is (search "-99" (return-code-message -99))))

;; Expected layouts were taken from the C compiler for each data model.
(test struct-layout
  (let ((ptr-size (cffi:foreign-type-size :pointer)))
    (flet ((offset (struct slot) (cffi:foreign-slot-offset struct slot)))
      (is (= 0 (offset '(:struct ffi:ws2811-channel) 'ffi:gpionum)))
      (is (= 12 (offset '(:struct ffi:ws2811-channel) 'ffi:strip-type)))
      (is (= 16 (offset '(:struct ffi:ws2811-channel) 'ffi:leds)))
      (is (= 0 (offset '(:struct ffi:ws2811) 'ffi:render-wait-time)))
      (is (= 8 (offset '(:struct ffi:ws2811) 'ffi:device)))
      (ecase ptr-size
        (8
         (is (= 24 (offset '(:struct ffi:ws2811-channel) 'ffi:brightness)))
         (is (= 28 (offset '(:struct ffi:ws2811-channel) 'ffi:bshift)))
         (is (= 32 (offset '(:struct ffi:ws2811-channel) 'ffi:gamma)))
         (is (= 40 (cffi:foreign-type-size '(:struct ffi:ws2811-channel))))
         (is (= 16 (offset '(:struct ffi:ws2811) 'ffi:rpi-hw)))
         (is (= 24 (offset '(:struct ffi:ws2811) 'ffi:freq)))
         (is (= 28 (offset '(:struct ffi:ws2811) 'ffi:dmanum)))
         (is (= 32 (offset '(:struct ffi:ws2811) 'ffi:channel)))
         (is (= 112 (cffi:foreign-type-size '(:struct ffi:ws2811)))))
        (4
         (is (= 20 (offset '(:struct ffi:ws2811-channel) 'ffi:brightness)))
         (is (= 24 (offset '(:struct ffi:ws2811-channel) 'ffi:bshift)))
         (is (= 28 (offset '(:struct ffi:ws2811-channel) 'ffi:gamma)))
         (is (= 32 (cffi:foreign-type-size '(:struct ffi:ws2811-channel))))
         (is (= 12 (offset '(:struct ffi:ws2811) 'ffi:rpi-hw)))
         (is (= 16 (offset '(:struct ffi:ws2811) 'ffi:freq)))
         (is (= 20 (offset '(:struct ffi:ws2811) 'ffi:dmanum)))
         (is (= 24 (offset '(:struct ffi:ws2811) 'ffi:channel)))
         (is (= 88 (cffi:foreign-type-size '(:struct ffi:ws2811)))))))))

;;; Colors

(def-suite color :in rpi-ws281x)
(in-suite color)

(test rgb-packing
  (is (= #x000000 (rgb 0 0 0)))
  (is (= #xFF0000 (rgb 255 0 0)))
  (is (= #x00FF00 (rgb 0 255 0)))
  (is (= #x0000FF (rgb 0 0 255)))
  (is (= #x123456 (rgb #x12 #x34 #x56)))
  (is (= #xAA123456 (rgbw #x12 #x34 #x56 #xAA))))

(test rgb-type-checks
  (locally (declare (notinline rgb rgbw))
    (signals type-error (rgb 256 0 0))
    (signals type-error (rgb 0 -1 0))
    (signals type-error (rgbw 0 0 0 1.5))))

(test color-components
  (let ((c (rgbw 1 2 3 4)))
    (is (= 1 (color-red c)))
    (is (= 2 (color-green c)))
    (is (= 3 (color-blue c)))
    (is (= 4 (color-white c)))))

(test hsv-conversion
  (is (= (rgb 255 0 0) (hsv 0 1 1)))
  (is (= (rgb 0 255 0) (hsv 120 1 1)))
  (is (= (rgb 0 0 255) (hsv 240 1 1)))
  (is (= (rgb 255 255 0) (hsv 60 1 1)))
  (is (= (rgb 255 0 0) (hsv 360 1 1)))
  (is (= (rgb 255 0 0) (hsv -360 1 1)))
  (is (= (rgb 255 255 255) (hsv 0 0 1)))
  (is (= 0 (hsv 200 1 0)))
  (signals type-error (hsv 0 2 1)))

(test wheel-colors
  (is (= (rgb 0 255 0) (wheel 0)))
  (is (= (rgb 255 0 0) (wheel 85)))
  (is (= (rgb 0 0 255) (wheel 170)))
  (is (= (wheel 10) (wheel 266)))
  (is (every (lambda (i) (typep (wheel i) '(unsigned-byte 24)))
             (loop for i below 256 collect i))))

(test blend-and-scale
  (is (= (rgb 0 0 0) (blend (rgb 0 0 0) (rgb 255 255 255) 0)))
  (is (= (rgb 255 255 255) (blend (rgb 0 0 0) (rgb 255 255 255) 1)))
  (is (= (rgb 128 64 0) (blend (rgb 0 0 0) (rgb 255 128 0) 1/2)))
  (is (= (rgbw 0 0 0 128) (blend 0 (rgbw 0 0 0 255) 1/2)))
  (is (= (rgb 50 100 0) (scale-color (rgb 100 200 0) 1/2)))
  (is (= 0 (scale-color (rgb 100 200 50) 0)))
  (signals type-error (blend 0 0 2)))

;;; Strip configuration (no hardware)

(def-suite strip :in rpi-ws281x)
(in-suite strip)

(test make-strip-defaults
  (let ((s (make-strip :count 30)))
    (unwind-protect
         (let ((ws (strip-pointer s)))
           (is (strip-open-p s))
           (is (not (strip-initialized-p s)))
           (is (= 800000 (cffi:foreign-slot-value ws '(:struct ffi:ws2811) 'ffi:freq)))
           (is (= 10 (cffi:foreign-slot-value ws '(:struct ffi:ws2811) 'ffi:dmanum)))
           (is (= 18 (channel-slot s 0 'ffi:gpionum)))
           (is (= 30 (led-count s)))
           (is (= 0 (channel-slot s 0 'ffi:invert)))
           (is (= +ws2811-strip-grb+ (channel-slot s 0 'ffi:strip-type)))
           (is (= 255 (brightness s)))
           (is (cffi:null-pointer-p (channel-slot s 0 'ffi:leds)))
           ;; Channel 1 is unused and must be all zero.
           (is (= 0 (channel-slot s 1 'ffi:gpionum)))
           (is (= 0 (led-count s 1))))
      (free-strip s))))

(test make-strip-options
  (let ((s (make-strip :count 8 :gpio 12 :dma 5 :freq 400000 :invert t
                       :brightness 64 :strip-type +sk6812-strip-rgbw+
                       :channel-1 '(:gpio 13 :count 4 :brightness 10))))
    (unwind-protect
         (progn
           (is (= 400000 (cffi:foreign-slot-value (strip-pointer s)
                                                  '(:struct ffi:ws2811) 'ffi:freq)))
           (is (= 5 (cffi:foreign-slot-value (strip-pointer s)
                                             '(:struct ffi:ws2811) 'ffi:dmanum)))
           (is (= 12 (channel-slot s 0 'ffi:gpionum)))
           (is (= 1 (channel-slot s 0 'ffi:invert)))
           (is (= +sk6812-strip-rgbw+ (channel-slot s 0 'ffi:strip-type)))
           (is (= 64 (brightness s 0)))
           (is (= 13 (channel-slot s 1 'ffi:gpionum)))
           (is (= 4 (led-count s 1)))
           (is (= 10 (brightness s 1))))
      (free-strip s))))

(test make-strip-validation
  (signals type-error (make-strip :count -1))
  (signals type-error (make-strip :dma 15))
  (signals type-error (make-strip :brightness 300))
  (signals type-error (make-strip :channel-1 '(:gpio 99))))

(test free-strip-is-idempotent
  (let ((s (make-strip :count 1)))
    (free-strip s)
    (is (not (strip-open-p s)))
    (is (null (free-strip s)))
    (signals ws281x-error (led-count s))
    (signals ws281x-error (render s))))

(test brightness-setf
  (let ((s (make-strip :count 1)))
    (unwind-protect
         (progn
           (setf (brightness s) 42)
           (is (= 42 (brightness s)))
           (setf (brightness s 1) 7)
           (is (= 7 (brightness s 1)))
           (signals type-error (setf (brightness s) 256)))
      (free-strip s))))

(test print-strip
  (let ((s (make-strip :count 3)))
    (is (search "3 LEDs" (princ-to-string s)))
    (free-strip s)
    (is (search "closed" (princ-to-string s)))))

(test uninitialized-buffer
  (let ((s (make-strip :count 3)))
    (unwind-protect
         (progn
           (signals ws281x-error (led s 0))
           (signals ws281x-error (set-gamma-factor s 2.8)))
      (free-strip s))))

;;; LED buffer operations against a fake buffer

(def-suite buffer :in rpi-ws281x)
(in-suite buffer)

(test led-get-set
  (with-fake-strip (s :count 5)
    (is (= 0 (led s 0)))
    (setf (led s 2) (rgb 1 2 3))
    (is (= (rgb 1 2 3) (led s 2)))
    (is (= 0 (led s 1)))
    (is (= 0 (led s 3)))))

(test led-bounds
  (with-fake-strip (s :count 5)
    (signals type-error (led s 5))
    (signals type-error (led s -1))
    (signals type-error (setf (led s 5) 0))
    (signals type-error (setf (led s 0) (expt 2 32)))
    (signals type-error (led s 0 2))))

(test fill-and-clear
  (with-fake-strip (s :count 6)
    (fill-leds s (rgb 9 9 9))
    (is (every (lambda (c) (= c (rgb 9 9 9))) (leds s)))
    (fill-leds s (rgb 1 0 0) :start 2 :end 4)
    (is (equalp (vector #x090909 #x090909 #x010000 #x010000 #x090909 #x090909)
                (leds s)))
    (signals error (fill-leds s 0 :start 4 :end 7))
    (clear s)
    (is (every #'zerop (leds s)))))

(test set-leds-sequence
  (with-fake-strip (s :count 4)
    (set-leds s (list 1 2 3))
    (is (equalp #(1 2 3 0) (leds s)))
    (set-leds s #(7 8 9) :start 2)       ; 9 falls off the end
    (is (equalp #(1 2 7 8) (leds s)))
    (signals type-error (set-leds s '(-1)))))

(test two-channels
  (with-fake-strip (s :count 3 :channel-1 '(:gpio 13 :count 2))
    (fill-leds s 5)
    (fill-leds s 6 :channel 1)
    (is (equalp #(5 5 5) (leds s 0)))
    (is (equalp #(6 6) (leds s 1)))
    (clear s 1)
    (is (equalp #(5 5 5) (leds s 0)))
    (is (equalp #(0 0) (leds s 1)))
    (clear s)
    (is (every #'zerop (leds s 0)))))

;;; Real hardware (opt-in)

(def-suite hardware :in rpi-ws281x)
(in-suite hardware)

(defun hardware-tests-enabled-p ()
  (and (uiop:getenv "RPI_WS281X_HARDWARE_TESTS")
       (ignore-errors (load-library))))

(test hardware-render
  (if (not (hardware-tests-enabled-p))
      (skip "Set RPI_WS281X_HARDWARE_TESTS=1 on a Raspberry Pi to run.")
      (let ((n (parse-integer (or (uiop:getenv "RPI_WS281X_TEST_LEDS") "8"))))
        (is (listp (hardware-info)))
        (with-strip (s :count n :brightness 32)
          (is (strip-initialized-p s))
          (is (getf (hardware-info s) :description))
          (set-gamma-factor s 2.8)
          (dotimes (i n)
            (setf (led s i) (wheel (floor (* i 256) n))))
          (is (eq s (render s)))
          (is (eq s (wait s)))
          (clear s)
          (render s)))))
