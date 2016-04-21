import processing.sound.*;
import java.util.Arrays;

SoundFile sample;
FFT fft;
AudioDevice device;

int scale = 5;
int bands = 1024;
int x_length = 32;
int update_window = 10;
float centroid;
float r_width;
float[] sum = new float[x_length];
float[] fftHistory = new float[0];
float smooth_factor = 0.2;
int indexPosition;

void setup() {
  
    size(640,360);
    background(255);
    device = new AudioDevice(this, 44100, bands);
    r_width = width/float(x_length);
    //uncomment one or the other
    //sample = new SoundFile(this, "trombone.wav");
    sample = new SoundFile(this, "noise.wav");
    sample.play();
    //AudioIn in = new AudioIn(this, 0);
    //in.start();
    fft = new FFT(this, bands);
    fft.input(sample);
    colorMode(HSB,240,100,100);
    fill(0,100,100);
    indexPosition = 0;
    
}

void draw() {
    background(0,0,0);
    fft.analyze();
    float sum = sum(fft.spectrum);
    //array to average centroids so colors change smoothly
    if (fftHistory.length < update_window){
      fftHistory = append(fftHistory, sum);
    }
    else {
      fftHistory[indexPosition] = sum;
      indexPosition = (indexPosition + 1) % update_window;
    }
    float avg_weight = average_array(fftHistory);
    println(avg_weight);
    float weight_coefficient = avg_weight/9;
    background(get_hue(555), 100, 100*weight_coefficient);
}

//finds spectral centroid
float spectral_centroid(float[] fftArray){
  float topSum = 0;
  float bottomSum = 0;
  float max = max_value(fftArray);
  for (int i = 0; i < bands; i++) {
    float frequency = i * 22050 / (bands-1);
    float weight = fftArray[i];
    //only color extreme frequencies for a more interesting graph
    if (weight < max)
      weight = 0;
    topSum += frequency*weight;
    bottomSum += weight;
  }
  return topSum/bottomSum;
}

//logarithmic mapping
int get_wavelength(float centroid) {
  float octave = log_2(centroid) - log_2(20.0);
  int wavelength = round(-.415181 * pow(octave,3) + 3.90566 * pow(octave,2) - 16.3385 * octave + 633);
  return wavelength;
}

//linear mapping
int get_wavelength_lin(float centroid) {
  int wavelength = round(-337/6720000000000.0 * pow(centroid, 3) + 411/224000000.0 * pow(centroid, 2) - 21871/840000.0 * centroid + 633);
  return wavelength;
}

//hue-to-wavelengthe approximation as written by Walter Robinson
// taken from http://www.mathworks.com/matlabcentral/answers/17011-color-wave-length-and-hue
int get_hue(int wavelength) {
  // (red - wave)*max_hue/(red-violet)
  int red = 615; //real red is 655; this makes lower frequencies redder (fun for bass-heavy tracks)
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

float log_2(float num) {
  return log(num)/log(2);
}

float getMax(float[] inputArray){ 
    float maxValue = inputArray[0]; 
    for(int i=1;i < inputArray.length;i++){ 
      if(inputArray[i] > maxValue){ 
         maxValue = inputArray[i]; 
      } 
    } 
    return maxValue; 
  }
  
float sum(float[] array){
  float sum = 0;
  for (int i = 0; i < array.length; i++){
    sum += array[i];
  }
  return sum;
}