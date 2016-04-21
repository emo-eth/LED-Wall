/*  OctoWS2811 movie2serial.pde - Transmit video data to 1 or more
      Teensy 3.0 boards running OctoWS2811 VideoDisplay.ino
    http://www.pjrc.com/teensy/td_libs_OctoWS2811.html
    Copyright (c) 2013 Paul Stoffregen, PJRC.COM, LLC
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

// To configure this program, edit the following sections:
//
//  1: change myMovie to open a video file of your choice    ;-)
//
//  2: edit the serialConfigure() lines in setup() for your
//     serial device names (Mac, Linux) or COM ports (Windows)
//
//  3: if your LED strips have unusual color configuration,
//     edit colorWiring().  Nearly all strips have GRB wiring,
//     so normally you can leave this as-is.
//
//  4: if playing 50 or 60 Hz progressive video (or faster),
//     edit framerate in movieEvent().

import processing.serial.*;
import java.awt.Rectangle;
import java.awt.Color;
import processing.sound.*;
import java.util.Arrays;

PGraphics pg;
int blue = 0;

float gamma = 1.7;

int numPorts=0;  // the number of serial ports in use
int maxPorts=24; // maximum number of serial ports

Serial[] ledSerial = new Serial[maxPorts];     // each port's actual Serial port
Rectangle[] ledArea = new Rectangle[maxPorts]; // the area of the movie each port gets, in % (0-100)
boolean[] ledLayout = new boolean[maxPorts];   // layout of rows, true = even is left->right
PImage[] ledImage = new PImage[maxPorts];      // image sent to each port
int[] gammatable = new int[256];
int errorCount=0;
float framerate=0;

int multiplier = 10;

// added by me (James Wenzel)

SoundFile sample;
FFT fft;
AudioDevice device;

int scale = 5;
int bands = 1024;
int x_length = 32;
int update_window = 1;
float centroid;
float r_width;
float[] sum = new float[x_length];
float[] fftHistory = new float[0];
float smooth_factor = 0.2;
int indexPosition;


void setup() {
  size(32,64);
  String[] list = Serial.list();
  delay(20);
  println("Serial Ports List:");
  println(list);
  serialConfigure("/dev/tty.usbmodem1072251");  // change these to your port names
//  serialConfigure("/dev/ttyACM1");
  if (errorCount > 0) exit();
  for (int i=0; i < 256; i++) {
    gammatable[i] = (int)(pow((float)i / 255.0, gamma) * 255.0 + 0.5);
  }
   pg = createGraphics(32, 64);
   
   // added by me (James Wenzel)
   
    device = new AudioDevice(this, 44100, bands);
    r_width = width/float(x_length);
    sample = new SoundFile(this, "luude.aif");
    sample.loop();
    //AudioIn in = new AudioIn(this, 0);
    //in.start();
    fft = new FFT(this, bands);
    fft.input(sample);
    indexPosition = 0;
}


void draw() {
  framerate = 30.0; // TODO, how to read the frame rate???
  for (int i=0; i < numPorts; i++) {   
    pg.beginDraw();
    pg.background(0,0,0);
    
    // added by me (James Wenzel)
    //analyze fft
    fft.analyze();
    //calculate spectral centroid (weighted as noted in function)
    centroid = spectral_centroid(fft.spectrum);
    //add to array to average centroids so colors change more smoothly
    if (fftHistory.length < update_window){
      fftHistory = append(fftHistory, centroid);
    }
    else {
      fftHistory[indexPosition] = centroid;
      indexPosition = (indexPosition + 1) % update_window;
    }
    //converts centroid to wavelength to hue to integer RGB
    int c = Color.HSBtoRGB(get_hue(get_wavelength(average_array(fftHistory)))/240.0,1,1);
    Color rgb = new Color(c);
    pg.fill(rgb.getRed(),rgb.getGreen(),rgb.getBlue());
    pg.noStroke();
    int array_index = 0;
    //assign a vertical bar to a logarithmic range of frequencies (x measures linear octaves)
    for (int j = 0; j < x_length; j++) {
        int number_of_bins = (int)Math.floor(pow(2,j)/4295000)+1;
        float[] range = Arrays.copyOfRange(fft.spectrum, array_index, array_index+number_of_bins+1);
        //bar height depends on either largest bin value or average bin value, whichever is higher 
        float range_max = getMax(range);
        float range_average = average_array(range);
        float range_weight = max(range_max, range_average);
        array_index += number_of_bins;
        sum[j] += (range_weight  - sum[j]) * smooth_factor;
        pg.rect(j*r_width, height/4, r_width, -sum[j]*(height/4)*scale);
    }
    
    
    // end insert
    
    pg.endDraw(); 
    
    //OctoWS2811 library-provided
    // copy a portion of the movie's image to the LED image
    int xoffset = percentage(pg.width, ledArea[i].x);
    int yoffset = percentage(pg.height, ledArea[i].y);
    int xwidth =  percentage(pg.width, ledArea[i].width);
    int yheight = percentage(pg.height, ledArea[i].height);
    ledImage[i].copy(pg, xoffset, yoffset, xwidth, yheight,
                     0, 0, ledImage[i].width, ledImage[i].height);
    // convert the LED image to raw data
    byte[] ledData =  new byte[(ledImage[i].width * ledImage[i].height * 3) + 3];
    image2data(ledImage[i], ledData, ledLayout[i]);
    if (i == 0) {
      ledData[0] = '*';  // first Teensy is the frame sync master
      int usec = (int)((1000000.0 / framerate) * 0.75);
      ledData[1] = (byte)(usec);   // request the frame sync pulse
      ledData[2] = (byte)(usec >> 8); // at 75% of the frame time
    } else {
      ledData[0] = '%';  // others sync to the master board
      ledData[1] = 0;
      ledData[2] = 0;
    }
    // send the raw data to the LEDs  :-)
    ledSerial[i].write(ledData);
   image(pg,0,0, 32, 64);
  }
}
 
// OctoWS2811 library-provided code

// image2data converts an image to OctoWS2811's raw data format.
// The number of vertical pixels in the image must be a multiple
// of 8.  The data array must be the proper size for the image.
void image2data(PImage image, byte[] data, boolean layout) {
  int offset = 3;
  int x, y, xbegin, xend, xinc, mask;
  int linesPerPin = image.height / 8;
  int pixel[] = new int[8];
  
  for (y = 0; y < linesPerPin; y++) {
    if ((y & 1) == (layout ? 0 : 1)) {
      // even numbered rows are left to right
      xbegin = 0;
      xend = image.width;
      xinc = 1;
    } else {
      // odd numbered rows are right to left
      xbegin = image.width - 1;
      xend = -1;
      xinc = -1;
    }
    for (x = xbegin; x != xend; x += xinc) {
      for (int i=0; i < 8; i++) {
        // fetch 8 pixels from the image, 1 for each pin
        pixel[i] = image.pixels[x + (y + linesPerPin * i) * image.width];
        pixel[i] = colorWiring(pixel[i]);
      }
      // convert 8 pixels to 24 bytes
      for (mask = 0x800000; mask != 0; mask >>= 1) {
        byte b = 0;
        for (int i=0; i < 8; i++) {
          if ((pixel[i] & mask) != 0)
            b |= (1 << i);
        }
        data[offset++] = b;
      }
    }
  } 
}

// translate the 24 bit color from RGB to the actual
// order used by the LED wiring.  GRB is the most common.
int colorWiring(int c) {
  int red = (c & 0xFF0000) >> 16;
  int green = (c & 0x00FF00) >> 8;
  int blue = (c & 0x0000FF);
  red = gammatable[red];
  green = gammatable[green];
  blue = gammatable[blue];
  return (green << 16) | (red << 8) | (blue); // GRB - most common wiring
}

// ask a Teensy board for its LED configuration, and set up the info for it.
void serialConfigure(String portName) {
  if (numPorts >= maxPorts) {
    println("too many serial ports, please increase maxPorts");
    errorCount++;
    return;
  }
  try {
    ledSerial[numPorts] = new Serial(this, portName);
    if (ledSerial[numPorts] == null) throw new NullPointerException();
    ledSerial[numPorts].write('?');
  } catch (Throwable e) {
    println("Serial port " + portName + " does not exist or is non-functional");
    errorCount++;
    return;
  }
  delay(50);
  String line = ledSerial[numPorts].readStringUntil(10);
  if (line == null) {
    println("Serial port " + portName + " is not responding.");
    println("Is it really a Teensy 3.0 running VideoDisplay?");
    errorCount++;
    return;
  }
  String param[] = line.split(",");
  if (param.length != 12) {
    println("Error: port " + portName + " did not respond to LED config query");
    errorCount++;
    return;
  }
  // only store the info and increase numPorts if Teensy responds properly
  ledImage[numPorts] = new PImage(Integer.parseInt(param[0]), Integer.parseInt(param[1]), RGB);
  ledArea[numPorts] = new Rectangle(Integer.parseInt(param[5]), Integer.parseInt(param[6]),
                     Integer.parseInt(param[7]), Integer.parseInt(param[8]));
  ledLayout[numPorts] = (Integer.parseInt(param[5]) == 0);
  numPorts++;
}


// scale a number by a percentage, from 0 to 100
int percentage(int num, int percent) {
  double mult = percentageFloat(percent);
  double output = num * mult;
  return (int)output;
}

// scale a number by the inverse of a percentage, from 0 to 100
int percentageInverse(int num, int percent) {
  double div = percentageFloat(percent);
  double output = num / div;
  return (int)output;
}

// convert an integer from 0 to 100 to a float percentage
// from 0.0 to 1.0.  Special cases for 1/3, 1/6, 1/7, etc
// are handled automatically to fix integer rounding.
double percentageFloat(int percent) {
  if (percent == 33) return 1.0 / 3.0;
  if (percent == 17) return 1.0 / 6.0;
  if (percent == 14) return 1.0 / 7.0;
  if (percent == 13) return 1.0 / 8.0;
  if (percent == 11) return 1.0 / 9.0;
  if (percent ==  9) return 1.0 / 11.0;
  if (percent ==  8) return 1.0 / 12.0;
  return (double)percent / 100.0;
}

// end OctoWS2811-provided code

//added by me (James Wenzel

//finds spectral centroid
float spectral_centroid(float[] fftArray){
  float topSum = 0;
  float bottomSum = 0;
  float max = max_value(fftArray);
  for (int i = 0; i < bands; i++) {
    float frequency = i * 22050 / (bands-1);
    float weight = fftArray[i];
    //only color extreme frequencies for a more interesting graph
    if (weight < max*.4)
      weight = 0;
    topSum += frequency*weight;
    bottomSum += weight;
  }
  println(topSum/bottomSum);
  return topSum/bottomSum;
}

//logarithmic mapping
int get_wavelength(float centroid) {
  float octave = log_2(centroid) - log_2(20.0);
  int wavelength = round(-.415181 * pow(octave,3) + 3.90566 * pow(octave,2) - 16.3385 * octave + 633);
  println(wavelength);
  return wavelength;
}

//linear mapping
int get_wavelength_lin(float centroid) {
  int wavelength = round(-337/6720000000000.0 * pow(centroid, 3) + 411/224000000.0 * pow(centroid, 2) - 21871/840000.0 * centroid + 633);
  return wavelength;
}

//hue-to-wavelength approximation as written by Walter Robinson
// taken from http://www.mathworks.com/matlabcentral/answers/17011-color-wave-length-and-hue
int get_hue(int wavelength) {
  // (red - wave)*max_hue/(red-violet)
  int red = 615; //real red is 655; this makes lower frequencies redder
  int violet = 445;
  int max_hue = 196; // out of (in this case) 240; as close to true violet as possible (max hue is magenta-red again)
  int hue = (red - wavelength)*max_hue/(red-violet);
  return hue;
}


// useful math things

//finds max value in an array
float max_value(float[] fftArray) {
  float max = fftArray[0];
  for (int ktr = 0; ktr < fftArray.length; ktr++) {
    if (fftArray[ktr] > max) {
      max = fftArray[ktr];
    }
  }
  return max;
}

//gets average centroid in an array
float average_array(float[] history) {
  float sum = 0;
  for (int i = 0; i < history.length; i++) {
    sum += history[i];
  }
  return sum/history.length;
}

//log base 2
float log_2(float num) {
  return log(num)/log(2);
}

//gets maximum of array
float getMax(float[] inputArray){ 
    float maxValue = inputArray[0]; 
    for(int i=1;i < inputArray.length;i++){ 
      if(inputArray[i] > maxValue){ 
         maxValue = inputArray[i]; 
      } 
    } 
    return maxValue; 
  }