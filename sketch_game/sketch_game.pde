import oscP5.*;
import netP5.*;

OscP5 oscP5;

int currentPrediction=0;
String lastDecision="NONE";

boolean waitingForClassification=false;
int eventReceivedTime=0;
int classificationTimeout=500;

String feedbackText="";
int feedbackStartTime=0;
int feedbackDuration=650;

int lastSnapTime=0;
int lastClapTime=0;
int snapCooldown=180;
int clapCooldown=400;

float bikeX=140;
float bikeY;
float groundY;

float verticalSpeed=0;
float gravity=0.65;
float jumpStrength=-17;
boolean onGround=true;

float speed=0;
float maxSpeed=15;
float accelerationPerSnap=2.3;
float friction=0.020;

float distanceTravelled=0;
int score=0;
boolean gameOver=false;

ArrayList<Obstacle> obstacles;
int lastObstacleTime=0;
int obstacleInterval=3500;

float roadOffset=0;
float treeOffset=0;
float wheelAngle=0;

void setup(){
  size(1000,600);
  frameRate(60);

  groundY=height-120;
  bikeY=groundY;

  obstacles=new ArrayList<Obstacle>();

  oscP5=new OscP5(this,12000);
}

void draw(){
  background(158,213,240);

  checkClassificationTimeout();
  updateWorldMovement();
  updateBikeAnimation();

  drawBackground();
  drawGround();

  if(!gameOver){
    updateBike();
    updateSpeed();
    spawnObstacles();
    updateObstacles();
    checkCollisions();

    distanceTravelled+=speed*0.01;
  }

  drawBike();
  drawHUD();
  drawSoundFeedback();

  if(gameOver){
    drawGameOver();
  }
}

void oscEvent(OscMessage msg){
  if(msg.checkAddrPattern("/pedalbeat/event")){
    waitingForClassification=true;
    eventReceivedTime=millis();
    return;
  }

  if(msg.checkAddrPattern("/wek/outputs")){
    int prediction=round(msg.get(0).floatValue());
    currentPrediction=prediction;

    if(!waitingForClassification){
      return;
    }

    waitingForClassification=false;

    if(prediction==1){
      lastDecision="SNAP";
      handleSnap();
    }else if(prediction==2){
      lastDecision="CLAP";
      handleClap();
    }
  }
}

void checkClassificationTimeout(){
  if(waitingForClassification&&millis()-eventReceivedTime>classificationTimeout){
    waitingForClassification=false;
    lastDecision="NO RESPONSE";
  }
}

void handleSnap(){
  if(gameOver){
    return;
  }

  if(millis()-lastSnapTime>snapCooldown){
    speed+=accelerationPerSnap;
    speed=constrain(speed,0,maxSpeed);
    lastSnapTime=millis();
    showFeedback("SNAP! + SPEED");
  }
}

void handleClap(){
  if(gameOver){
    return;
  }

  if(onGround&&millis()-lastClapTime>clapCooldown){
    verticalSpeed=jumpStrength;
    onGround=false;
    lastClapTime=millis();
    showFeedback("CLAP! JUMP");
  }
}

void showFeedback(String message){
  feedbackText=message;
  feedbackStartTime=millis();
}

void updateBike(){
  verticalSpeed+=gravity;
  bikeY+=verticalSpeed;

  if(bikeY>=groundY){
    bikeY=groundY;
    verticalSpeed=0;
    onGround=true;
  }
}

void updateSpeed(){
  if(speed>0){
    speed-=friction;

    if(speed<0){
      speed=0;
    }
  }
}

void updateWorldMovement(){
  if(gameOver){
    return;
  }

  float worldSpeed=1.5+speed*0.3;

  roadOffset-=worldSpeed;
  treeOffset-=worldSpeed*0.35;

  if(roadOffset<-100){
    roadOffset+=100;
  }

  if(treeOffset<-300){
    treeOffset+=300;
  }
}

void updateBikeAnimation(){
  if(!gameOver){
    wheelAngle+=speed*0.035;
  }
}

void spawnObstacles(){
  if(millis()-lastObstacleTime>obstacleInterval){
    obstacles.add(new Obstacle(width+40));
    lastObstacleTime=millis();
    obstacleInterval=int(random(3200,5000));
  }
}

void updateObstacles(){
  for(int i=obstacles.size()-1;i>=0;i--){
    Obstacle o=obstacles.get(i);

    o.update();
    o.display();

    if(o.x<-50){
      obstacles.remove(i);
      score++;
    }
  }
}

void checkCollisions(){
  for(Obstacle o:obstacles){
    float bikeLeft=bikeX-17;
    float bikeRight=bikeX+22;
    float bikeTop=bikeY-34;
    float bikeBottom=bikeY-8;

    float obsLeft=o.x+2;
    float obsRight=o.x+o.w-2;
    float obsTop=groundY-o.h+2;
    float obsBottom=groundY;

    boolean overlapX=bikeRight>obsLeft&&bikeLeft<obsRight;
    boolean overlapY=bikeBottom>obsTop&&bikeTop<obsBottom;

    if(overlapX&&overlapY){
      gameOver=true;
      speed=0;
    }
  }
}

void drawBackground(){
  noStroke();

  fill(255,221,90);
  ellipse(865,95,85,85);

  drawCloud(170,100);
  drawCloud(530,150);

  fill(117,187,132);
  triangle(0,groundY,230,270,470,groundY);
  triangle(300,groundY,610,235,900,groundY);
  triangle(700,groundY,900,290,width,groundY);

  for(int i=-1;i<5;i++){
    drawTree(i*300+treeOffset,groundY);
  }
}

void drawCloud(float x,float y){
  noStroke();
  fill(255,255,255,210);

  ellipse(x,y,75,35);
  ellipse(x-30,y+5,50,28);
  ellipse(x+32,y+6,55,30);
  ellipse(x+5,y-15,48,35);
}

void drawTree(float x,float y){
  noStroke();

  fill(110,75,45);
  rect(x,y-90,15,90,5);

  fill(65,150,80);
  ellipse(x+8,y-105,65,75);
}

void drawGround(){
  noStroke();

  fill(86,175,91);
  rect(0,groundY,width,height-groundY);

  fill(76,78,82);
  rect(0,groundY+40,width,80);

  fill(225);
  rect(0,groundY+42,width,3);

  stroke(235);
  strokeWeight(4);

  for(int x=-100;x<width+100;x+=100){
    float lineX=x+roadOffset;
    line(lineX,groundY+80,lineX+48,groundY+80);
  }
}

void drawBike(){
  pushMatrix();
  translate(bikeX,bikeY);

  drawWheel(-25,0,wheelAngle);
  drawWheel(35,0,wheelAngle);

  stroke(224,66,60);
  strokeWeight(5);
  noFill();

  line(-25,0,0,-35);
  line(0,-35,35,0);
  line(-25,0,35,0);
  line(0,-35,15,-5);
  line(15,-5,-25,0);

  stroke(50);
  strokeWeight(4);
  line(25,-35,32,-48);
  line(32,-48,42,-48);

  strokeWeight(5);
  line(-3,-38,7,-38);

  float pedalX=cos(wheelAngle)*9;
  float pedalY=sin(wheelAngle)*9;

  stroke(40);
  strokeWeight(3);

  line(8,-10,8+pedalX,-10+pedalY);
  line(8,-10,8-pedalX,-10-pedalY);

  fill(40);
  noStroke();
  ellipse(8,-10,7,7);

  fill(255,205,170);
  stroke(40);
  strokeWeight(3);
  ellipse(2,-78,25,25);

  strokeWeight(5);
  line(2,-65,-2,-40);

  strokeWeight(4);
  line(-1,-57,15,-48);
  line(15,-48,32,-45);

  float hipX=0;
  float hipY=-40;

  float rightFootX=8+pedalX;
  float rightFootY=-10+pedalY;
  float leftFootX=8-pedalX;
  float leftFootY=-10-pedalY;

  float rightKneeX=(hipX+rightFootX)/2+8;
  float rightKneeY=(hipY+rightFootY)/2;
  float leftKneeX=(hipX+leftFootX)/2-7;
  float leftKneeY=(hipY+leftFootY)/2;

  line(hipX,hipY,rightKneeX,rightKneeY);
  line(rightKneeX,rightKneeY,rightFootX,rightFootY);

  line(hipX,hipY,leftKneeX,leftKneeY);
  line(leftKneeX,leftKneeY,leftFootX,leftFootY);

  popMatrix();
}

void drawWheel(float x,float y,float angle){
  pushMatrix();
  translate(x,y);

  noFill();
  stroke(30);
  strokeWeight(5);
  ellipse(0,0,50,50);

  pushMatrix();
  rotate(angle);

  stroke(100);
  strokeWeight(2);

  line(-22,0,22,0);
  line(0,-22,0,22);
  line(-16,-16,16,16);
  line(-16,16,16,-16);

  popMatrix();

  fill(40);
  noStroke();
  ellipse(0,0,7,7);

  popMatrix();
}

void drawHUD(){
  noStroke();
  fill(255,255,255,210);
  rect(20,20,275,155,18);

  fill(35);
  textSize(22);
  text("PEDALBEAT",38,50);

  textSize(17);
  text("Speed   "+nf(speed*3,0,1)+" km/h",38,82);
  text("Distance   "+nf(distanceTravelled,0,1)+" m",38,108);
  text("Obstacles passed   "+score,38,134);

 

  if(waitingForClassification){
    fill(255,255,255,220);
    rect(width-225,25,195,45,14);

    fill(50);
    textSize(15);
    text("Listening...",width-205,54);
  }
}

void drawSoundFeedback(){
  if(feedbackText.equals("")){
    return;
  }

  int elapsed=millis()-feedbackStartTime;

  if(elapsed>feedbackDuration){
    feedbackText="";
    return;
  }

  float alpha=map(elapsed,0,feedbackDuration,255,0);

  noStroke();
  fill(255,255,255,alpha);
  rect(width/2-120,45,240,55,16);

  fill(40,alpha);
  textAlign(CENTER);
  textSize(22);
  text(feedbackText,width/2,80);
  textAlign(LEFT);
}

void drawGameOver(){
  noStroke();
  fill(0,170);
  rect(0,0,width,height);

  fill(255);
  textAlign(CENTER);

  textSize(58);
  text("CRASH!",width/2,height/2-65);

  textSize(26);
  text("Obstacles passed: "+score,width/2,height/2);

  textSize(20);
  text("Press ENTER to restart",width/2,height/2+55);

  textAlign(LEFT);
}

void keyPressed(){
  if(gameOver&&keyCode==ENTER){
    restartGame();
  }
}

void restartGame(){
  gameOver=false;
  speed=0;
  distanceTravelled=0;
  score=0;
  bikeY=groundY;
  verticalSpeed=0;
  onGround=true;

  obstacles.clear();

  lastObstacleTime=millis();
  waitingForClassification=false;
  currentPrediction=0;
  lastDecision="NONE";
  feedbackText="";
  wheelAngle=0;
}

class Obstacle{
  float x;
  float w;
  float h;

  Obstacle(float startX){
    x=startX;
    w=random(25,32);
    h=random(22,30);
  }

  void update(){
    float movementSpeed=2.0+speed*0.30;
    x-=movementSpeed;
  }

  void display(){
    noStroke();

    fill(0,0,0,35);
    ellipse(x+w/2,groundY+3,w+10,8);

    fill(154,94,54);
    rect(x,groundY-h,w,h,10);

    fill(185,120,72);
    rect(x+5,groundY-h+5,w-10,5,4);
  }
}
