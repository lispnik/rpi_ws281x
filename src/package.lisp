;;;; package.lisp

(defpackage #:rpi-ws281x.ffi
  (:use #:cl)
  (:documentation "Low-level CFFI bindings that mirror ws2811.h one-to-one.")
  (:export
   ;; Library loading
   #:libws2811
   #:load-library
   #:library-loaded-p
   ;; Constants
   #:+ws2811-target-freq+
   #:+rpi-pwm-channels+
   #:+sk6812-strip-rgbw+ #:+sk6812-strip-rbgw+ #:+sk6812-strip-grbw+
   #:+sk6812-strip-gbrw+ #:+sk6812-strip-brgw+ #:+sk6812-strip-bgrw+
   #:+sk6812-shift-wmask+
   #:+ws2811-strip-rgb+ #:+ws2811-strip-rbg+ #:+ws2811-strip-grb+
   #:+ws2811-strip-gbr+ #:+ws2811-strip-brg+ #:+ws2811-strip-bgr+
   #:+ws2812-strip+ #:+sk6812-strip+ #:+sk6812w-strip+
   #:+rpi-hwver-type-unknown+ #:+rpi-hwver-type-pi1+
   #:+rpi-hwver-type-pi2+ #:+rpi-hwver-type-pi4+
   #:+ws2811-success+
   #:*return-codes*
   ;; Structs and slots
   #:rpi-hw #:type #:hwver #:periph-base #:videocore-base #:desc
   #:ws2811-channel #:gpionum #:invert #:count #:strip-type #:leds
   #:brightness #:wshift #:rshift #:gshift #:bshift #:gamma
   #:ws2811 #:render-wait-time #:device #:freq #:dmanum #:channel
   ;; Functions
   #:ws2811-init
   #:ws2811-fini
   #:ws2811-render
   #:ws2811-wait
   #:ws2811-get-return-t-str
   #:ws2811-set-custom-gamma-factor
   #:rpi-hw-detect))

(defpackage #:rpi-ws281x
  (:use #:cl)
  (:nicknames #:ws281x)
  (:import-from #:rpi-ws281x.ffi
                #:load-library #:library-loaded-p
                #:+ws2811-target-freq+
                #:+sk6812-strip-rgbw+ #:+sk6812-strip-rbgw+ #:+sk6812-strip-grbw+
                #:+sk6812-strip-gbrw+ #:+sk6812-strip-brgw+ #:+sk6812-strip-bgrw+
                #:+ws2811-strip-rgb+ #:+ws2811-strip-rbg+ #:+ws2811-strip-grb+
                #:+ws2811-strip-gbr+ #:+ws2811-strip-brg+ #:+ws2811-strip-bgr+
                #:+ws2812-strip+ #:+sk6812-strip+ #:+sk6812w-strip+)
  (:documentation "High-level interface for driving WS281x/SK6812 LED strips.")
  (:export
   ;; Library
   #:load-library
   #:library-loaded-p
   ;; Constants
   #:+ws2811-target-freq+
   #:+sk6812-strip-rgbw+ #:+sk6812-strip-rbgw+ #:+sk6812-strip-grbw+
   #:+sk6812-strip-gbrw+ #:+sk6812-strip-brgw+ #:+sk6812-strip-bgrw+
   #:+ws2811-strip-rgb+ #:+ws2811-strip-rbg+ #:+ws2811-strip-grb+
   #:+ws2811-strip-gbr+ #:+ws2811-strip-brg+ #:+ws2811-strip-bgr+
   #:+ws2812-strip+ #:+sk6812-strip+ #:+sk6812w-strip+
   ;; Conditions
   #:ws281x-error
   #:ws2811-return-error
   #:ws2811-return-error-code
   #:ws2811-return-error-operation
   #:return-code-keyword
   #:return-code-message
   ;; Colors
   #:rgb #:rgbw
   #:color-red #:color-green #:color-blue #:color-white
   #:hsv #:wheel #:blend #:scale-color
   ;; Strips
   #:strip #:strip-p
   #:make-strip #:strip-init #:free-strip
   #:open-strip #:close-strip #:with-strip
   #:strip-pointer #:strip-initialized-p #:strip-open-p
   #:render #:wait
   #:led-count #:led #:fill-leds #:set-leds #:leds #:clear
   #:brightness #:set-gamma-factor
   #:render-wait-time #:hardware-info))
