# Digital Caliper USB interface & LED Display

This project interfaces with the serial data output port found on cheap digital calipers.  It does several things:

* Provides power to the calipers
* Provides a second readout which isn't physically constrained by the measurement location/orientation
* Emulates a USB HID keyboard and "types" the current measurement at the press of a button
* Emulates a USB CDC-ACM serial port for logging/debug

There are many different variations on the serial format output by different calipers.  Some use 24-bit integers, some use BCD.  Some always output in inches, some always in mm, and some in whatever format the internal display is currently using.  Some include error detection data, others don't.  Currently there is only one protocol supported:

* Data signal is stable whenever Clock signal is high
* 24-bit packet, transferred over 8.1ms (+/- 0.1ms)
* First bit is always 1
* Next 20 bits are the unsigned magnitude (little-endian)
* Next bit is 1 if negative
* Last two bits are unused
* There is no indication whether it is in mm or inches mode.  In mm mode, 1 ULP is 0.01mm, and in inches mode, 1 ULP is 0.0005".
* The bus is idle for at least 5ms between packets

![PXL_20241017_001500729](https://github.com/user-attachments/assets/ef0a3db9-4297-4528-91de-4439dca1619d)
