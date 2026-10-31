;;;; color.lisp -- 0xWWRRGGBB color helpers

(in-package #:rpi-ws281x)

(deftype octet () '(unsigned-byte 8))
(deftype color () '(unsigned-byte 32))

(declaim (inline rgb rgbw color-red color-green color-blue color-white))

(defun rgbw (red green blue white)
  "Pack RED, GREEN, BLUE and WHITE (each 0-255) into a 0xWWRRGGBB color."
  (check-type red octet)
  (check-type green octet)
  (check-type blue octet)
  (check-type white octet)
  (logior (ash white 24) (ash red 16) (ash green 8) blue))

(defun rgb (red green blue)
  "Pack RED, GREEN and BLUE (each 0-255) into a 0x00RRGGBB color."
  (rgbw red green blue 0))

(defun color-white (color) (ldb (byte 8 24) color))
(defun color-red (color) (ldb (byte 8 16) color))
(defun color-green (color) (ldb (byte 8 8) color))
(defun color-blue (color) (ldb (byte 8 0) color))

(defun clamp-octet (x)
  (max 0 (min 255 (round x))))

(defun hsv (hue saturation value)
  "Convert HUE (degrees, any real; taken modulo 360), SATURATION and VALUE
(both 0.0-1.0) to an RGB color."
  (check-type saturation (real 0 1))
  (check-type value (real 0 1))
  (let* ((h (/ (mod hue 360) 60))
         (c (* value saturation))
         (x (* c (- 1 (abs (- (mod h 2) 1)))))
         (m (- value c)))
    (multiple-value-bind (r g b)
        (case (floor h)
          (0 (values c x 0))
          (1 (values x c 0))
          (2 (values 0 c x))
          (3 (values 0 x c))
          (4 (values x 0 c))
          (t (values c 0 x)))
      (rgb (clamp-octet (* 255 (+ r m)))
           (clamp-octet (* 255 (+ g m)))
           (clamp-octet (* 255 (+ b m)))))))

(defun wheel (position)
  "The classic Adafruit color wheel: POSITION 0-255 cycles red -> green ->
blue -> red. Values outside that range are taken modulo 256."
  (let ((pos (mod position 256)))
    (cond ((< pos 85) (rgb (* pos 3) (- 255 (* pos 3)) 0))
          ((< pos 170) (let ((p (- pos 85)))
                         (rgb (- 255 (* p 3)) 0 (* p 3))))
          (t (let ((p (- pos 170)))
               (rgb 0 (* p 3) (- 255 (* p 3))))))))

(defun blend (color1 color2 amount)
  "Linearly interpolate each channel between COLOR1 (AMOUNT 0) and COLOR2
(AMOUNT 1)."
  (check-type amount (real 0 1))
  (flet ((mix (f) (clamp-octet (+ (* (- 1 amount) (funcall f color1))
                                  (* amount (funcall f color2))))))
    (rgbw (mix #'color-red) (mix #'color-green)
          (mix #'color-blue) (mix #'color-white))))

(defun scale-color (color factor)
  "Multiply every channel of COLOR by FACTOR (0.0-1.0)."
  (check-type factor (real 0 1))
  (flet ((s (f) (clamp-octet (* factor (funcall f color)))))
    (rgbw (s #'color-red) (s #'color-green) (s #'color-blue) (s #'color-white))))
