import processing.sound.*;
import oscP5.*;
import netP5.*;

AudioIn mic;
FFT fft;
Amplitude amp;
OscP5 oscP5;
NetAddress wekinator;
NetAddress game;

int fftBands=64;
int outputBands=16;
float[] spectrum=new float[fftBands];
float[] accumulatedBands=new float[outputBands];

float currentAmplitude=0;
float noiseFloor=0.005;
float minThreshold=0.025;
float thresholdMultiplier=4.0;
float onsetThreshold;

boolean recordingEvent=false;
int eventStartTime=0;
int eventDuration=160;
int lastEventTime=0;
int eventCooldown=280;

float amplitudeSum=0;
float maximumAmplitude=0;
int capturedFrames=0;
int totalEvents=0;

String statusText="WAITING";

void setup(){
  size(800,450);
  frameRate(60);

  mic=new AudioIn(this,0);
  mic.start();

  fft=new FFT(this,fftBands);
  fft.input(mic);

  amp=new Amplitude(this);
  amp.input(mic);

  oscP5=new OscP5(this,12001);
  wekinator=new NetAddress("127.0.0.1",6448);
  game=new NetAddress("127.0.0.1",12000);
}

void draw(){
  background(20);

  fft.analyze(spectrum);
  currentAmplitude=amp.analyze();

  if(!recordingEvent&&currentAmplitude<noiseFloor*2.0){
    noiseFloor=noiseFloor*0.98+currentAmplitude*0.02;
  }

  onsetThreshold=max(minThreshold,noiseFloor*thresholdMultiplier);

  if(!recordingEvent&&currentAmplitude>onsetThreshold&&millis()-lastEventTime>eventCooldown){
    startEvent();
  }

  if(recordingEvent){
    collectFeatures();

    if(millis()-eventStartTime>=eventDuration){
      finishEvent();
    }
  }

  drawSpectrum();
  drawDebug();
}

void startEvent(){
  recordingEvent=true;
  eventStartTime=millis();
  statusText="RECORDING";

  for(int i=0;i<outputBands;i++){
    accumulatedBands[i]=0;
  }

  amplitudeSum=0;
  maximumAmplitude=0;
  capturedFrames=0;
}

void collectFeatures(){
  int binsPerGroup=fftBands/outputBands;

  for(int group=0;group<outputBands;group++){
    float energy=0;

    for(int j=0;j<binsPerGroup;j++){
      int index=group*binsPerGroup+j;
      energy+=spectrum[index];
    }

    accumulatedBands[group]+=energy/binsPerGroup;
  }

  amplitudeSum+=currentAmplitude;
  maximumAmplitude=max(maximumAmplitude,currentAmplitude);
  capturedFrames++;
}

void finishEvent(){
  recordingEvent=false;
  lastEventTime=millis();

  if(capturedFrames<=0){
    statusText="INVALID";
    return;
  }

  OscMessage input=new OscMessage("/wek/inputs");

  for(int i=0;i<outputBands;i++){
    input.add(accumulatedBands[i]/capturedFrames);
  }

  float averageAmplitude=amplitudeSum/capturedFrames;

  input.add(averageAmplitude);
  input.add(maximumAmplitude);

  oscP5.send(input,wekinator);

  totalEvents++;

  OscMessage event=new OscMessage("/pedalbeat/event");
  event.add(totalEvents);
  oscP5.send(event,game);

  statusText="EVENT SENT";
}

void drawSpectrum(){
  stroke(0,255,120);

  for(int i=0;i<fftBands;i++){
    float x=map(i,0,fftBands,0,width);
    float h=constrain(map(spectrum[i],0,0.1,0,180),0,180);
    line(x,height,x,height-h);
  }
}

void drawDebug(){
  fill(255);
  textSize(21);
  text("PEDALBEAT SENSING",25,35);

  textSize(17);
  text("Amplitude: "+nf(currentAmplitude,1,4),25,75);
  text("Noise floor: "+nf(noiseFloor,1,4),25,105);
  text("Threshold: "+nf(onsetThreshold,1,4),25,135);
  text("Status: "+statusText,25,175);
  text("Events: "+totalEvents,25,205);

  if(recordingEvent){
    fill(255,80,80);
    textSize(26);
    text("CAPTURING SOUND",25,250);
  }
}
