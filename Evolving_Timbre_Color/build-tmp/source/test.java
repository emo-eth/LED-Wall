import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import processing.sound.*; 
import java.util.Arrays; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class test extends PApplet {




SoundFile sample;
FFT fft;
AudioDevice device;

int scale = 10;
int bands = 1024;
int x_length = 32;
int update_window = 28;
float centroid;
float r_width;
float[] sum = new float[bands];
float[] fftHistory = new float[0];
float smooth_factor = 0.2f;
int indexPosition;

public void setup() {
  
    
    background(255);
    device = new AudioDevice(this, 44100, bands);
    r_width = width/PApplet.parseFloat(bands);
    sample = new SoundFile(this, "luude.aif");
    sample.loop();
    AudioIn in = new AudioIn(this, 0);
    in.start();
    fft = new FFT(this, bands);
    fft.input(sample);
    colorMode(HSB,240,100,100);
    fill(0,100,100);
    indexPosition = 0;
    
}

public void draw() {
    background(0,0,000);
    fft.analyze();
    centroid = spectral_centroid(fft.spectrum);
    //array to average centroids so colors change smoothly
    if (fftHistory.length < update_window){
      fftHistory = append(fftHistory, centroid);
    }
    else {
      fftHistory[indexPosition] = centroid;
      indexPosition = (indexPosition + 1) % update_window;
    }
    fill(get_hue(get_wavelength(average_array(Arrays.copyOfRange(fftHistory, 0, update_window+1)))), 100, 100);
    noStroke();
    int array_index = 0;
    for (int i = 0; i < x_length; i++) {
        int number_of_bins = Math.floor(pow(2,i)/4295000.0f);
        float range_weight = average_array(Arrays.copyofRange(fft.spectrum, array_index, array_index+number_of_bins+1));
        sum[i] += (range_weight  - sum[i]) * smooth_factor;
        rect(i*r_width, height, r_width, -sum[i]*height*scale);
    }
}

//finds spectral centroid
public float spectral_centroid(float[] fftArray){
  float topSum = 0;
  float bottomSum = 0;
  float max = max_value(fftArray);
  for (int i = 0; i < bands; i++) {
    float frequency = i * 22050 / (bands-1);
    float weight = fftArray[i];
    //only color extreme frequencies for a more interesting graph
    if (weight < max*.25f)
      weight = 0;
    topSum += frequency*weight;
    bottomSum += weight;
  }
  return topSum/bottomSum;
}

//logarithmic mapping
public int get_wavelength(float centroid) {
  float octave = log_2(centroid) - log_2(20.0f);
  int wavelength = round(-.415181f * pow(octave,3) + 3.90566f * pow(octave,2) - 16.3385f * octave + 633);
  return wavelength;
}

//linear mapping
public int get_wavelength_lin(float centroid) {
  int wavelength = round(-337/6720000000000.0f * pow(centroid, 3) + 411/224000000.0f * pow(centroid, 2) - 21871/840000.0f * centroid + 633);
  return wavelength;
}

//hue-to-wavelength equation I found
public int get_hue(int wavelength) {
  // red - wave*max_hue/(red-violet)
  int hue = (600 - wavelength)*196/(600-445);
  return hue;
}


// useful math things

//finds max value in an array
public float max_value(float[] fftArray) {
  float max = fftArray[0];
  for (int ktr = 0; ktr < fftArray.length; ktr++) {
    if (fftArray[ktr] > max) {
      max = fftArray[ktr];
    }
  }
  return max;
}

//gets average centroid in an array
public float average_array(float[] history) {
  float sum = 0;
  for (int i = 0; i < history.length; i++) {
    sum += history[i];
  }
  return sum/history.length;
}

public float log_2(float num) {
  return log(num)/log(2);
}
  public void settings() {  size(32,16); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "test" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
