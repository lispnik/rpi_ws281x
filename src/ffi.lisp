;;;; ffi.lisp -- direct CFFI translation of ws2811.h, rpihw.h and pwm.h

(in-package #:rpi-ws281x.ffi)

;;; Library loading

(cffi:define-foreign-library libws2811
  (:unix (:or "libws2811.so" "libws2811.so.1"
              "/usr/local/lib/libws2811.so" "/usr/lib/libws2811.so"))
  (t (:default "libws2811")))

(defvar *library-loaded* nil)

(defun library-loaded-p ()
  "True when libws2811 has been loaded into the image."
  *library-loaded*)

(defun load-library (&optional (path (uiop:getenv "RPI_WS281X_LIBRARY")))
  "Load libws2811. PATH defaults to the RPI_WS281X_LIBRARY environment
variable; when that is unset the standard library search path is used.
Returns T. Signals an error if the library cannot be found."
  (unless *library-loaded*
    (if (and path (plusp (length path)))
        (cffi:load-foreign-library path)
        (cffi:load-foreign-library 'libws2811))
    (setf *library-loaded* t))
  t)

;;; Constants

(defconstant +ws2811-target-freq+ 800000
  "Default output frequency in Hz. Can go as low as 400000.")

(defconstant +rpi-pwm-channels+ 2)

;; 4 color R, G, B and W ordering
(defconstant +sk6812-strip-rgbw+ #x18100800)
(defconstant +sk6812-strip-rbgw+ #x18100008)
(defconstant +sk6812-strip-grbw+ #x18081000)
(defconstant +sk6812-strip-gbrw+ #x18080010)
(defconstant +sk6812-strip-brgw+ #x18001008)
(defconstant +sk6812-strip-bgrw+ #x18000810)
(defconstant +sk6812-shift-wmask+ #xf0000000)

;; 3 color R, G and B ordering
(defconstant +ws2811-strip-rgb+ #x00100800)
(defconstant +ws2811-strip-rbg+ #x00100008)
(defconstant +ws2811-strip-grb+ #x00081000)
(defconstant +ws2811-strip-gbr+ #x00080010)
(defconstant +ws2811-strip-brg+ #x00001008)
(defconstant +ws2811-strip-bgr+ #x00000810)

;; Predefined fixed LED types
(defconstant +ws2812-strip+ +ws2811-strip-grb+)
(defconstant +sk6812-strip+ +ws2811-strip-grb+)
(defconstant +sk6812w-strip+ +sk6812-strip-grbw+)

;; rpi_hw_t types
(defconstant +rpi-hwver-type-unknown+ 0)
(defconstant +rpi-hwver-type-pi1+ 1)
(defconstant +rpi-hwver-type-pi2+ 2)
(defconstant +rpi-hwver-type-pi4+ 3)

(defconstant +ws2811-success+ 0)

(defparameter *return-codes*
  '((0 :success "Success")
    (-1 :error-generic "Generic failure")
    (-2 :error-out-of-memory "Out of memory")
    (-3 :error-hw-not-supported "Hardware revision is not supported")
    (-4 :error-mem-lock "Memory lock failed")
    (-5 :error-mmap "mmap() failed")
    (-6 :error-map-registers "Unable to map registers into userspace")
    (-7 :error-gpio-init "Unable to initialize GPIO")
    (-8 :error-pwm-setup "Unable to initialize PWM")
    (-9 :error-mailbox-device "Failed to create mailbox device")
    (-10 :error-dma "DMA error")
    (-11 :error-illegal-gpio "Selected GPIO not possible")
    (-12 :error-pcm-setup "Unable to initialize PCM")
    (-13 :error-spi-setup "Unable to initialize SPI")
    (-14 :error-spi-transfer "SPI transfer error"))
  "The ws2811_return_t values as (CODE KEYWORD MESSAGE) lists.")

;;; Structures

(cffi:defcstruct rpi-hw
  (type :uint32)
  (hwver :uint32)
  (periph-base :uint32)
  (videocore-base :uint32)
  (desc :string))

(cffi:defcstruct ws2811-channel
  (gpionum :int)                        ; GPIO pin with PWM alternate function, 0 if unused
  (invert :int)                         ; Invert output signal
  (count :int)                          ; Number of LEDs, 0 if channel is unused
  (strip-type :int)                     ; One of the strip type constants
  (leds :pointer)                       ; uint32_t[count] 0xWWRRGGBB, allocated by driver
  (brightness :uint8)                   ; 0..255
  (wshift :uint8)
  (rshift :uint8)
  (gshift :uint8)
  (bshift :uint8)
  (gamma :pointer))                     ; uint8_t[256] gamma correction table

(cffi:defcstruct ws2811
  (render-wait-time :uint64)            ; µs before the next render can run
  (device :pointer)                     ; private driver data
  (rpi-hw :pointer)                     ; const rpi_hw_t *
  (freq :uint32)                        ; output frequency
  (dmanum :int)                         ; DMA channel not already in use
  (channel (:struct ws2811-channel) :count 2))

;;; Functions

(cffi:defcfun ("ws2811_init" ws2811-init) :int
  "Initialize buffers and hardware. Returns a ws2811_return_t code."
  (ws2811 :pointer))

(cffi:defcfun ("ws2811_fini" ws2811-fini) :void
  "Tear down hardware and free driver buffers."
  (ws2811 :pointer))

(cffi:defcfun ("ws2811_render" ws2811-render) :int
  "Send the LED buffers to the hardware. Returns a ws2811_return_t code."
  (ws2811 :pointer))

(cffi:defcfun ("ws2811_wait" ws2811-wait) :int
  "Wait for DMA completion. Returns a ws2811_return_t code."
  (ws2811 :pointer))

(cffi:defcfun ("ws2811_get_return_t_str" ws2811-get-return-t-str) :string
  "Return the description string for a ws2811_return_t code."
  (state :int))

(cffi:defcfun ("ws2811_set_custom_gamma_factor" ws2811-set-custom-gamma-factor) :void
  "Build a gamma correction table from GAMMA-FACTOR (0 disables correction)."
  (ws2811 :pointer)
  (gamma-factor :double))

(cffi:defcfun ("rpi_hw_detect" rpi-hw-detect) :pointer
  "Detect the Raspberry Pi model. Returns a const rpi_hw_t * or NULL.")

;;; Try to load the library now. Failure is fine: on a development
;;; machine without libws2811 everything except the hardware calls still
;;; works, and LOAD-LIBRARY can be called later with an explicit path.
(ignore-errors (load-library))
