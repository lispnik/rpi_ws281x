;;;; strip.lisp -- high-level strip interface

(in-package #:rpi-ws281x)

;;; Conditions

(define-condition ws281x-error (error) ()
  (:documentation "Superclass of all errors signalled by rpi-ws281x."))

(define-condition strip-closed-error (ws281x-error) ()
  (:report "The strip has been closed."))

(define-condition led-buffer-missing (ws281x-error) ()
  (:report "The LED buffer has not been allocated; call STRIP-INIT first."))

(defun return-code-entry (code)
  (assoc code rpi-ws281x.ffi:*return-codes*))

(defun return-code-keyword (code)
  "Map a ws2811_return_t integer to a keyword such as :ERROR-MMAP."
  (or (second (return-code-entry code)) :unknown))

(defun return-code-message (code)
  "Human-readable description of a ws2811_return_t integer."
  (or (third (return-code-entry code))
      (format nil "Unknown return code ~D" code)))

(define-condition ws2811-return-error (ws281x-error)
  ((code :initarg :code :reader ws2811-return-error-code)
   (operation :initarg :operation :initform nil
              :reader ws2811-return-error-operation))
  (:report (lambda (c s)
             (let ((code (ws2811-return-error-code c)))
               (format s "~@[~A: ~]~A (~D, ~S)"
                       (ws2811-return-error-operation c)
                       (return-code-message code)
                       code
                       (return-code-keyword code)))))
  (:documentation "Signalled when a libws2811 call returns a failure code."))

(defun check-return (code operation)
  (unless (= code rpi-ws281x.ffi:+ws2811-success+)
    (error 'ws2811-return-error :code code :operation operation))
  code)

;;; Foreign slot helpers

(defmacro channel-slot (pointer slot)
  `(cffi:foreign-slot-value ,pointer '(:struct rpi-ws281x.ffi:ws2811-channel)
                            ',slot))

(defmacro ws-slot (pointer slot)
  `(cffi:foreign-slot-value ,pointer '(:struct rpi-ws281x.ffi:ws2811) ',slot))

;;; The strip object

(defstruct (strip (:constructor %make-strip (pointer)))
  "Wraps a foreign ws2811_t. Create with MAKE-STRIP or OPEN-STRIP."
  (pointer (cffi:null-pointer) :type cffi:foreign-pointer)
  (initialized-p nil))

(defun strip-open-p (strip)
  "True until FREE-STRIP or CLOSE-STRIP has released STRIP's memory."
  (not (cffi:null-pointer-p (strip-pointer strip))))

(defun %ws (strip)
  (unless (strip-open-p strip)
    (error 'strip-closed-error))
  (strip-pointer strip))

(defun %channel (strip channel)
  "Pointer to the ws2811_channel_t for CHANNEL (0 or 1)."
  (check-type channel (integer 0 1))
  (cffi:mem-aptr (cffi:foreign-slot-pointer (%ws strip) '(:struct rpi-ws281x.ffi:ws2811)
                                            'rpi-ws281x.ffi:channel)
                 '(:struct rpi-ws281x.ffi:ws2811-channel)
                 channel))

(defmethod print-object ((strip strip) stream)
  (print-unreadable-object (strip stream :type t :identity t)
    (if (strip-open-p strip)
        (format stream "~D LED~:P~:[~; initialized~]"
                (+ (led-count strip 0) (led-count strip 1))
                (strip-initialized-p strip))
        (format stream "closed"))))

(defun configure-channel (pointer &key (gpio 0) (count 0) (invert nil)
                                       (strip-type +ws2811-strip-grb+)
                                       (brightness 255))
  (check-type gpio (integer 0 53))
  (check-type count (integer 0 #.(1- (expt 2 31))))
  (check-type strip-type (unsigned-byte 31))
  (check-type brightness octet)
  (setf (channel-slot pointer rpi-ws281x.ffi:gpionum) gpio
        (channel-slot pointer rpi-ws281x.ffi:count) count
        (channel-slot pointer rpi-ws281x.ffi:invert) (if invert 1 0)
        (channel-slot pointer rpi-ws281x.ffi:strip-type) strip-type
        (channel-slot pointer rpi-ws281x.ffi:brightness) brightness))

(defun make-strip (&key (count 0) (gpio 18) (dma 10) (freq +ws2811-target-freq+)
                        (strip-type +ws2811-strip-grb+) (brightness 255) (invert nil)
                        channel-1)
  "Allocate and configure a ws2811_t without touching the hardware.

COUNT, GPIO, STRIP-TYPE, BRIGHTNESS and INVERT describe channel 0.
CHANNEL-1 is an optional plist (:GPIO :COUNT :STRIP-TYPE :BRIGHTNESS
:INVERT) for the second channel. Call STRIP-INIT before rendering and
FREE-STRIP when done. Most code should use OPEN-STRIP or WITH-STRIP."
  (check-type dma (integer 0 14))
  (check-type freq (integer 1 #.(1- (expt 2 32))))
  (let* ((size (cffi:foreign-type-size '(:struct rpi-ws281x.ffi:ws2811)))
         (pointer (cffi:foreign-alloc :uint8 :count size :initial-element 0))
         (strip (%make-strip pointer)))
    (handler-bind ((error (lambda (e) (declare (ignore e)) (free-strip strip))))
      (setf (ws-slot pointer rpi-ws281x.ffi:freq) freq
            (ws-slot pointer rpi-ws281x.ffi:dmanum) dma)
      (configure-channel (%channel strip 0) :gpio gpio :count count :invert invert
                                            :strip-type strip-type :brightness brightness)
      (when channel-1
        (apply #'configure-channel (%channel strip 1) channel-1)))
    strip))

(defun strip-init (strip)
  "Call ws2811_init on STRIP, allocating the LED buffers and setting up
the hardware. Usually needs root."
  (unless (strip-initialized-p strip)
    (load-library)
    (check-return (rpi-ws281x.ffi:ws2811-init (%ws strip)) "ws2811_init")
    (setf (strip-initialized-p strip) t))
  strip)

(defun free-strip (strip)
  "Run ws2811_fini if STRIP was initialized, then free its memory.
Safe to call more than once."
  (when (strip-open-p strip)
    (when (strip-initialized-p strip)
      (rpi-ws281x.ffi:ws2811-fini (strip-pointer strip))
      (setf (strip-initialized-p strip) nil))
    (cffi:foreign-free (strip-pointer strip))
    (setf (strip-pointer strip) (cffi:null-pointer)))
  nil)

(defun open-strip (&rest args &key &allow-other-keys)
  "MAKE-STRIP with ARGS, then STRIP-INIT. Returns the strip."
  (let ((strip (apply #'make-strip args)))
    (handler-bind ((error (lambda (e) (declare (ignore e)) (free-strip strip))))
      (strip-init strip))))

(defun close-strip (strip &key (clear t))
  "Turn the LEDs off (unless CLEAR is NIL), then release STRIP."
  (when (and clear (strip-open-p strip) (strip-initialized-p strip))
    (ignore-errors (clear strip) (render strip) (wait strip)))
  (free-strip strip))

(defmacro with-strip ((var &rest args) &body body)
  "Bind VAR to (OPEN-STRIP ,@ARGS) around BODY; the strip is cleared and
closed on exit."
  `(let ((,var (open-strip ,@args)))
     (unwind-protect (progn ,@body)
       (close-strip ,var))))

;;; Rendering

(defun render (strip)
  "Push the LED buffers out to the strip."
  (check-return (rpi-ws281x.ffi:ws2811-render (%ws strip)) "ws2811_render")
  strip)

(defun wait (strip)
  "Block until the previous render's DMA transfer has finished."
  (check-return (rpi-ws281x.ffi:ws2811-wait (%ws strip)) "ws2811_wait")
  strip)

;;; LED buffer access

(defun led-count (strip &optional (channel 0))
  "Number of LEDs configured on CHANNEL."
  (channel-slot (%channel strip channel) rpi-ws281x.ffi:count))

(defun leds-pointer (strip channel)
  (let ((leds (channel-slot (%channel strip channel) rpi-ws281x.ffi:leds)))
    (when (cffi:null-pointer-p leds)
      (error 'led-buffer-missing))
    leds))

(defun check-index (strip index channel)
  (let ((n (led-count strip channel)))
    (unless (and (integerp index) (< -1 index n))
      (error 'type-error :datum index :expected-type `(integer 0 (,n))))))

(defun led (strip index &optional (channel 0))
  "The 0xWWRRGGBB color of LED INDEX on CHANNEL. SETF-able."
  (check-index strip index channel)
  (cffi:mem-aref (leds-pointer strip channel) :uint32 index))

(defun (setf led) (color strip index &optional (channel 0))
  (check-type color color)
  (check-index strip index channel)
  (setf (cffi:mem-aref (leds-pointer strip channel) :uint32 index) color))

(defun fill-leds (strip color &key (channel 0) (start 0) end)
  "Set LEDs from START (inclusive) to END (exclusive, default the end of
the strip) to COLOR. Does not render."
  (check-type color color)
  (let* ((n (led-count strip channel))
         (end (or end n))
         (leds (leds-pointer strip channel)))
    (unless (<= 0 start end n)
      (error "LED range [~D, ~D) is outside [0, ~D)." start end n))
    (loop for i from start below end
          do (setf (cffi:mem-aref leds :uint32 i) color))
    strip))

(defun set-leds (strip colors &key (channel 0) (start 0))
  "Copy the sequence COLORS into the LED buffer beginning at START.
Colors past the end of the strip are ignored. Does not render."
  (let* ((n (led-count strip channel))
         (leds (leds-pointer strip channel))
         (i start))
    (check-type start (integer 0))
    (map nil (lambda (c)
               (when (< i n)
                 (check-type c color)
                 (setf (cffi:mem-aref leds :uint32 i) c)
                 (incf i)))
         colors)
    strip))

(defun leds (strip &optional (channel 0))
  "A fresh vector of the current colors on CHANNEL."
  (let* ((n (led-count strip channel))
         (leds (leds-pointer strip channel))
         (v (make-array n :element-type 'color)))
    (dotimes (i n v)
      (setf (aref v i) (cffi:mem-aref leds :uint32 i)))))

(defun clear (strip &optional channel)
  "Set every LED on CHANNEL (or on all used channels when CHANNEL is NIL)
to black. Does not render."
  (dolist (c (if channel (list channel) '(0 1)) strip)
    (when (plusp (led-count strip c))
      (fill-leds strip 0 :channel c))))

(defun brightness (strip &optional (channel 0))
  "Global brightness (0-255) of CHANNEL, applied at render time. SETF-able."
  (channel-slot (%channel strip channel) rpi-ws281x.ffi:brightness))

(defun (setf brightness) (value strip &optional (channel 0))
  (check-type value octet)
  (setf (channel-slot (%channel strip channel) rpi-ws281x.ffi:brightness) value))

(defun set-gamma-factor (strip factor)
  "Install a gamma correction table built from FACTOR (e.g. 2.8); 0 gives
a linear table. The strip must be initialized."
  (unless (strip-initialized-p strip)
    (error 'led-buffer-missing))
  (rpi-ws281x.ffi:ws2811-set-custom-gamma-factor (%ws strip)
                                                 (coerce factor 'double-float))
  strip)

(defun render-wait-time (strip)
  "Microseconds the driver waits before the next render may start."
  (ws-slot (%ws strip) rpi-ws281x.ffi:render-wait-time))

(defun hardware-info (&optional strip)
  "A plist describing the Raspberry Pi model, read from an initialized
STRIP or, without one, from rpi_hw_detect. NIL if the model is unknown."
  (let ((hw (if strip
                (ws-slot (%ws strip) rpi-ws281x.ffi:rpi-hw)
                (progn (load-library) (rpi-ws281x.ffi:rpi-hw-detect)))))
    (unless (cffi:null-pointer-p hw)
      (flet ((slot (name)
               (cffi:foreign-slot-value hw '(:struct rpi-ws281x.ffi:rpi-hw) name)))
        (list :type (case (slot 'rpi-ws281x.ffi:type)
                      (1 :pi1) (2 :pi2) (3 :pi4) (t :unknown))
              :hwver (slot 'rpi-ws281x.ffi:hwver)
              :periph-base (slot 'rpi-ws281x.ffi:periph-base)
              :videocore-base (slot 'rpi-ws281x.ffi:videocore-base)
              :description (slot 'rpi-ws281x.ffi:desc))))))
