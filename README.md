# rpi-ws281x

Common Lisp bindings for [jgarff/rpi_ws281x](https://github.com/jgarff/rpi_ws281x),
the C library that drives WS2811/WS2812/SK6812 ("NeoPixel") LED strips from a
Raspberry Pi using PWM, PCM or SPI with DMA.

Two layers are provided:

- **`rpi-ws281x.ffi`**: a direct CFFI translation of `ws2811.h`: structs,
  constants and all six functions, plus `rpi_hw_detect`.
- **`rpi-ws281x`** (nickname `ws281x`): a Lisp-friendly API with
  `with-strip`, `setf`-able LED access, conditions for error codes, and
  color helpers.

Developed with SBCL and [ocicl](https://github.com/ocicl/ocicl); tested
with [FiveAM](https://github.com/lispci/fiveam). It only depends on CFFI.

## Building the C library

The upstream build produces a static library by default. Build it as a
shared library so Lisp can load it:

```sh
sudo apt install cmake build-essential
git clone https://github.com/jgarff/rpi_ws281x.git
cd rpi_ws281x && mkdir build && cd build
cmake -D BUILD_SHARED=ON -D BUILD_TEST=OFF ..
make && sudo make install && sudo ldconfig
```

The binding looks for `libws2811.so` on the normal library path. To use a
different file, set `RPI_WS281X_LIBRARY=/path/to/libws2811.so`, or call
`(rpi-ws281x:load-library "/path/to/libws2811.so")`.

The library is loaded lazily, so the system compiles and its tests run on
machines without it (a laptop, for example).

## Installing

```sh
cd ~/src && git clone https://github.com/lispnik/rpi_ws281x.git
cd rpi_ws281x
ocicl install          # fetches cffi and fiveam listed in ocicl.csv
```

```lisp
(asdf:load-system "rpi-ws281x")
```

## Usage

Driving the hardware needs root, because the library maps `/dev/mem`.
SPI on GPIO 10 is the exception: it can run as a normal user in the
`gpio` group (see the upstream README).

```lisp
(use-package :rpi-ws281x)

;; 30 WS2812B LEDs on GPIO 18 (PWM0), DMA channel 10.
(with-strip (s :count 30 :gpio 18 :dma 10 :brightness 64
               :strip-type +ws2811-strip-grb+)
  (set-gamma-factor s 2.8)
  (dotimes (j 256)
    (dotimes (i (led-count s))
      (setf (led s i) (wheel (+ (* i 8) j))))
    (render s)
    (sleep 0.02)))
;; On exit the strip is cleared and released.
```

Without the macro:

```lisp
(defvar *strip* (open-strip :count 60))
(fill-leds *strip* (rgb 255 80 0))
(setf (brightness *strip*) 128)
(render *strip*)
(close-strip *strip*)          ; turns the LEDs off, then ws2811_fini
```

Two channels (PWM0 + PWM1):

```lisp
(with-strip (s :count 30 :gpio 18
               :channel-1 (list :gpio 13 :count 20
                               :strip-type +ws2811-strip-rgb+))
  (fill-leds s (rgb 255 0 0) :channel 0)
  (fill-leds s (rgb 0 0 255) :channel 1)
  (render s))
```

A port of the upstream `strandtest` lives in `examples/`:

```lisp
(asdf:load-system "rpi-ws281x/examples")
(rpi-ws281x-examples:strandtest :count 30)
```

### API summary

| Function | Purpose |
|---|---|
| `open-strip &key count gpio dma freq strip-type brightness invert channel-1` | Allocate and `ws2811_init`. |
| `close-strip strip &key (clear t)` | Blank the LEDs, `ws2811_fini`, free memory. |
| `with-strip (var &rest args) &body` | `open-strip` / `close-strip` with `unwind-protect`. |
| `make-strip`, `strip-init`, `free-strip` | The separate steps, if you need them. |
| `render strip`, `wait strip` | `ws2811_render` / `ws2811_wait`. |
| `led strip i &optional ch`, `(setf led)` | Read or write one LED. |
| `fill-leds strip color &key channel start end` | Fill a range. |
| `set-leds strip colors &key channel start` | Copy a sequence of colors in. |
| `leds strip &optional ch` | Copy the buffer out as a vector. |
| `clear strip &optional ch` | Set the LEDs to black (no render). |
| `brightness strip &optional ch`, `(setf brightness)` | Per-channel global brightness. |
| `set-gamma-factor strip factor` | `ws2811_set_custom_gamma_factor`. |
| `led-count`, `render-wait-time`, `hardware-info` | Introspection. |
| `rgb`, `rgbw`, `hsv`, `wheel`, `blend`, `scale-color` | Build `0xWWRRGGBB` colors. |
| `color-red`, `color-green`, `color-blue`, `color-white` | Take colors apart. |

Strip types: `+ws2811-strip-{rgb,rbg,grb,gbr,brg,bgr}+`,
`+sk6812-strip-{rgbw,rbgw,grbw,gbrw,brgw,bgrw}+`, `+ws2812-strip+`,
`+sk6812-strip+` and `+sk6812w-strip+`.

Errors: a failed library call signals `ws2811-return-error`, a subclass of
`ws281x-error`. Use `ws2811-return-error-code` to get the integer and
`return-code-keyword` to turn it into a keyword (e.g. `:error-mmap`).
Bad arguments signal `type-error`.

## Tests

```lisp
(asdf:test-system "rpi-ws281x")
```

The suite checks constants, the struct layout on 32-bit and 64-bit ARM,
color math, strip configuration, and the LED buffer operations (against
a fake buffer). None of that needs a Pi. To also run the hardware test
on a Pi, as root, with LEDs on GPIO 18:

```sh
sudo RPI_WS281X_HARDWARE_TESTS=1 RPI_WS281X_TEST_LEDS=8 \
  sbcl --non-interactive --eval '(asdf:test-system "rpi-ws281x")'
```

## License

MIT. rpi_ws281x itself is BSD-2-Clause.
