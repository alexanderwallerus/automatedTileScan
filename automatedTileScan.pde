//code by Alexander Wallerus
//MIT license

import java.awt.AWTException;
import java.awt.Robot;
import java.awt.event.InputEvent; 
import java.awt.Rectangle;

import java.awt.event.KeyEvent;  //robot pressing keys

import java.awt.MouseInfo;       //mouse position
import java.awt.Point;

import controlP5.*;

import boofcv.processing.*;
import boofcv.struct.image.*;
import georegression.struct.point.*;
import java.util.*;
import boofcv.struct.feature.*;
import boofcv.factory.feature.detect.template.TemplateScoreType;

Robot robot;
Point mouse;

Silencer sil;
ControlP5 cp5;
Textarea instructions;
String inst;

int startTime;
PImage setupImg;
boolean allCharsCorrect = true;

String scanOrder = "";
char[] chars = new char[]{};
boolean debug = false;
PImage theScreen;
PImage capture;

boolean allSet = false;
PImage check;
boolean running = false;

int numTiles;
int currentTile = 0;
int programState = 0;  //click start->observeTaskStatus->move

PImage exampleTemplate;
int[] examplePos = new int[2];
PImage exampleFound;

PImage startTemplate;
int[] startPos = new int[2];
PImage startFound;

int[] scanningPos = new int[2];
PImage stillScanningTemplate;
PImage scanCompleteTemplate;
PImage scanningFound;

int[] yesSafePos = new int[2];
PImage yesSafeTemplate;
PImage yesSafeFound;

int[] closeImgPos = new int[2];
PImage closeImgTemplate;
PImage closeImgFound;
boolean foundCloseImg = false;

int[] yesClosePos = new int[2];
PImage yesCloseTemplate;
PImage yesClosefound;

int[] liveImagePos = new int[2];
PImage liveImageTemplate;
PImage liveImageFound;

PImage videoModeTemplate;
int[] videoModePos = new int[2];
PImage videoModeFound;

boolean allScanned = false;

void setup(){
  size(200, 850);
  sil = new Silencer();
  startTime=millis();  //stop new button from triggering on loading
  sil.silence();
  cp5 = new ControlP5(this);
  sil.unsilence();
  cp5.addButton("allSetUp").setValue(0).setPosition(50, 370).
    setSize(100, 40).setLabel("All set up");
  check = loadImage("checkMark.png");
  cp5.addTextfield("tileOrder", 25, 510, 150, 20).setLabel("Tile Order");
  cp5.addTextfield("cutScreenCSVs", 25, 730, 150, 20).hide();
  cp5.addButton("StartTileScan").setLabel("Start Tile Scan").setValue(0).
    setPosition(50, 600).setSize(100, 40);
  String[] nlCrashes = loadStrings("ifNeurolucidaCrashes.txt");
  String ifNlCrashes = join(nlCrashes, "\n");
  inst ="This program will take control of the mouse and keyboard once running.\nTo abort the run please close this program.\n" +
        "\nSetup Instructions:\n" +
        "-The program windows are roughly set up as visible bellow so that the computer vision can observe and use the Neurolucida UI elements.\n- The Camera Configuration has been set up to suit the tissue (exposure, gain,...)\n- The Magnification is set to 100xOil in Neurolucida.\n- The Neurolucida batch scanning has been set up to scan from a focus just above the slice to one just beneath it throughout all stacks belonging to the scan (Stack height and z resolution)\n- A reference point has set been set up (for example at the top of the first stack) and this empty reconstruction (.dat file) has been saved (Ctrl+S) into an otherwise empty output folder. Neurolucida will save its stacks to this folder, so previous scans need to be moved from there before each new tile scan.\n- Neurolucida's bottom bar says: \"Begin tracing a branched...\" - If it is not there after joystick mode it will be visible again after quickly starting a branch reconstruction and ctrl-Z-ing it away again.\nAfter this continue with \"all set up\".\n\n" +
        "If Neurolucida crashes a restart of this computer can take a long time. Most crashes can be solved through a restart of Neurolucida and repeating the UI setup for the scan. For more stubborn crashes with found solutions this program contains a .txt file that can be extended with new solutions to crashes:\n" +
        ifNlCrashes +
        "\n\nThis program was written by Alexander Wallerus";
  instructions = cp5.addTextarea("textarea").setPosition(0, 0).setSize(width, 250)
                    .setLineHeight(10).setText(inst);
  setupImg = loadImage("setupImg.png");   
  yesSafeTemplate = loadImage("yesSafe.png");
  closeImgTemplate = loadImage("closeImage.png");

  try{
    robot = new Robot();
  } 
  catch(Exception e){
    println("Robot class not supported by your system!");
    e.printStackTrace();
  }
}

void draw(){
  background(0);
  fill(255);    
  textAlign(CENTER);  
  imageMode(CENTER);
  image(setupImg, width/2, 310, width*3/4, 94);  //150/1.6 = 93.75 screen ratio
  imageMode(CORNER);
  if (allSet){
    image(check, 160, 360, 40, 40);
  }
  text("Please enter the tile scan order using the num pad and confirm with Enter.\n example: a snake of 'current right right down left left down right right' = 66244266", 
    0, 420, width, 100);

  String replacedOrder = scanOrder.replaceAll("4", "\u2190").replaceAll("8", "\u2191").
    replaceAll("6", "\u2192").replaceAll("2", "\u2193");
  String showedOrder = "Your input:" + replacedOrder;
  allCharsCorrect = true;
  chars = scanOrder.toCharArray();
  for (char movement : chars) {
    if (!(movement == '4' || movement == '8' || movement == '6' || movement == '2')) {
      allCharsCorrect = false;
      showedOrder += "\n" + movement + " is not a correct direction";
    }
  }  
  text(showedOrder, 0, 544, width, 100);

  if (running){ 
    if (currentTile == chars.length+1){
      allScanned = true;
      running = false;
    } else {
      int added = currentTile+1;
      fill(0, 255, 255);
      text("Scan Running\nCurrent Tile: " + added + " of " + numTiles + 
        "\nCurrent program state: " + programState, width/2, 660);
      fill(255);
      if (programState == 1){
        delay(10000);
      } else {
        delay(2000);
      }      
      if (programState == 0){                           
        println("clicking start scan");
        robot.mouseMove(startPos[0], startPos[1]);
        delay(100); //probably not needed but NL is already instable without fast 
        //mouse movements and clicking
        robot.mousePress(InputEvent.BUTTON1_DOWN_MASK);
        robot.mouseRelease(InputEvent.BUTTON1_DOWN_MASK);
        programState ++;
        //the first few seconds the text will be "image 1 of... instead of aquring...
        //=> delay until this is over.
        delay(10000);
      } else if (programState == 1){ 
        println("waiting for scan completion");
        println("Errors for the current view to scanned and to scanning templates:");
        screenShot();
        scanningFound = foundOnScreen(scanningPos, stillScanningTemplate.width, 
          stillScanningTemplate.height);
        float scoreToScanned = calculateScore(scanningFound, scanCompleteTemplate);
        float scoreToScanning = calculateScore(scanningFound, stillScanningTemplate);
        if (scoreToScanning > scoreToScanned) {
          println("scanning complete");
          programState++;
        } else {
          println("still scanning");
        }
      } else if (programState == 2){
        robot.keyPress(KeyEvent.VK_CONTROL);
        robot.keyPress(KeyEvent.VK_S);  // VK_CONTROL key still pressed
        robot.keyRelease(KeyEvent.VK_S);
        robot.keyRelease(KeyEvent.VK_CONTROL);
        delay(1000);
        robot.keyPress(10);  //enter
        programState ++;
      } else if (programState == 3){
        println("entering savename");
        robot.keyPress(KeyEvent.VK_S);
        robot.keyRelease(KeyEvent.VK_S);
        delay(500);
        robot.keyPress(KeyEvent.VK_C);
        robot.keyRelease(KeyEvent.VK_C);
        delay(500);
        robot.keyPress(KeyEvent.VK_A);
        robot.keyRelease(KeyEvent.VK_A);
        delay(500);
        robot.keyPress(KeyEvent.VK_N);
        robot.keyRelease(KeyEvent.VK_N);
        delay(500);
        char[] chars = nf(currentTile, 2).toCharArray();
        println("current tile number: " + chars[0] + chars[1]);
        for (int i=0; i<chars.length; i++) {  //0 = 48, 9 = 57
          robot.keyPress(int(chars[i]) + 48);
          println("pressing " + (int(chars[i]) + 48));
          delay(500);
        }
        delay(2000); 
        robot.keyPress(10);  //Enter
        //IF SAVING TAKES MORE TIME CHANGE THIS VALUE INTO MORE MS
        delay(50000);
        programState++;
      } else if (programState == 4){
        if (foundCloseImg == false){
          println("finding close image button");
          closeImgPos = templatePos(closeImgTemplate);
          closeImgFound = foundOnScreen(closeImgPos, closeImgTemplate.width, 
                                        closeImgTemplate.height);
          calculateScore(closeImgFound, closeImgTemplate);
          closeImgPos = centerOfFound(closeImgPos, closeImgTemplate);
          foundCloseImg = true;
        }
        println("clicking close image button at " + closeImgPos[0]+","+closeImgPos[1]);
        robot.mouseMove(closeImgPos[0], closeImgPos[1]);
        delay(100);
        robot.mousePress(InputEvent.BUTTON1_DOWN_MASK);
        robot.mouseRelease(InputEvent.BUTTON1_DOWN_MASK);
        delay(1000);
        robot.keyPress(10);
        programState++;
      } else if (programState == 5){
        println("turning on the camera again");
        robot.keyPress(KeyEvent.VK_CONTROL);
        robot.keyPress(KeyEvent.VK_L);             //VK_CONTROL key still pressed
        robot.keyRelease(KeyEvent.VK_L);
        robot.keyRelease(KeyEvent.VK_CONTROL);
        programState++;
      } else if (programState == 6){               //move the platform
        println("moving the platform");
        if (!(currentTile == chars.length)){       //not last run
          char movement = chars[currentTile];
          switch(movement){
          case '4':
            robot.keyPress(37);  
            break;   //left arrow
          case '8':
            robot.keyPress(38);  
            break;   //top arrow
          case '6':
            robot.keyPress(39);  
            break;   //right arrow
          case '2':
            robot.keyPress(40);  
            break;   //down arrow
          }
          delay(4000);            //time to let the platform move
        }                                 
        programState = 0;         //last run will still progress but not move stage
        currentTile++;
        if((currentTile%3==0)&&(currentTile!=0)){
          //every 3 tiles will move ~1um upwards with this microscope
          //this if-block corrects for this
          delay(2000);
          robot.mouseWheel(-1);  //move down 1 um (mousewheel down 1 click)
          delay(2000);
        }
      }
    }
  } 
  if (allScanned){
    fill(0, 255, 255);
    text("All blocks scanned", width/2, 660);
  }
  fill(255);

  pushMatrix();
  translate(0, 700);
  fill(255);    
  textAlign(CENTER, CENTER);
  text("Press D for Debug View", width/2, 20);
  if (debug){
    mouse = MouseInfo.getPointerInfo().getLocation();
    text("Cursor Position: " + mouse.x + "," + mouse.y, 0, 20, width, 100);
    cp5.getController("cutScreenCSVs").show();
    imageMode(CORNER);
    if (exampleFound != null) {
      image(exampleFound, 5, 85, 40, 40);
    }
    if (startFound != null) {
      image(startFound, 55, 85, 40, 40);
    }
    if (scanningFound != null) {
      image(scanningFound, 105, 85, 40, 40);
    }
    if (capture != null) {
      image(capture, 155, 85, 40, 40);
    }
    imageMode(CENTER);
  } else {
    cp5.getController("cutScreenCSVs").hide();
  }
  popMatrix();
}

int[] templatePos(PImage template_){
  SimpleTemplateMatching matching = 
    Boof.templateMatching(TemplateScoreType.SUM_SQUARE_ERROR); 
    //TemplateScoreType.SUM_DIFF_SQ in older versions of boofcv
  screenShot();
  matching.setInput(theScreen);
  List<Match> found = matching.detect(template_, 1); //1 (best) result only
  //List<Point2D_I32> in older versions of boofcv
  int[] result = new int[2];
  for (Point2D_I32 p : found){
    result[0] = p.x;
    result[1] = p.y;
  }
  return(result);
}

PImage foundOnScreen(int[] xy, int w, int h){
  return theScreen.get(xy[0], xy[1], w, h);
}

int[] centerOfFound(int[]xy, PImage template_){
  int[] result = new int[2];
  result[0] = xy[0] + template_.width/2;
  result[1] = xy[1] + template_.height/2;
  return result;
}

void screenShot(){
  theScreen = new PImage(robot.createScreenCapture(
    new Rectangle(0, 0, displayWidth, displayHeight)));
}

float calculateScore(PImage img0, PImage img1){
  img0.loadPixels();
  img1.loadPixels();
  if (img0.pixels.length != img1.pixels.length){
    println("There is a mistake with the compared images!");
  }
  float mse = 0;
  for (int i=0; i<img0.pixels.length; i++){
    float rd = red(img0.pixels[i]);
    float rt = red(img1.pixels[i]);
    mse += sq(rd-rt);
    float gd = green(img0.pixels[i]);
    float gt = green(img1.pixels[i]);
    mse += sq(gd-gt);
    float bd = blue(img0.pixels[i]);
    float bt = blue(img1.pixels[i]);
    mse += sq(bd-bt);
  }
  mse /= img0.pixels.length;
  println("The error between the images is: " + mse);
  return mse;
}

//controlP5 elements:
public void StartTileScan(){
  if (millis()-startTime<1000){
    //println("too early");
    return;
  }
  if (allCharsCorrect && (chars.length != 0) && allSet){
    running = true;
    allScanned = false;
    numTiles = chars.length+1;
    currentTile = 0;
  } else {
    println("not starting");
  }
}

public void tileOrder(String theValue){
  scanOrder = theValue;
}

public void cutScreenCSVs(String theValue){
  String[] values = split(theValue, ",");
  int[] coordinates = int(values);
  println(coordinates);
  screenShot();
  capture = theScreen.get(coordinates[0], coordinates[1], //x1,y1,x2,y2
    coordinates[2], coordinates[3]);
  String absPath = sketchPath() + "\\data\\";
  println(absPath);
  capture.save(absPath + "capture.png");
}

public void allSetUp(){
  if (millis()-startTime<1000){
    return;
  }
  println("Running all set up.");
  allSet = true;

  println("Finding start Button");
  startTemplate = loadImage("aquireStack.png");
  startPos = templatePos(startTemplate);
  println(startPos[0], startPos[1]);
  startFound = foundOnScreen(startPos, startTemplate.width, startTemplate.height);
  calculateScore(startFound, startTemplate);
  startPos = centerOfFound(startPos, startTemplate);  //center of the button

  println("Finding scan state text");
  stillScanningTemplate = loadImage("scanning.png");
  scanCompleteTemplate = loadImage("scanned.png");
  scanningPos = templatePos(scanCompleteTemplate);
  println(scanningPos[0], scanningPos[1]);
  scanningFound = foundOnScreen(scanningPos, scanCompleteTemplate.width, 
    scanCompleteTemplate.height);
  calculateScore(scanningFound, scanCompleteTemplate);
}

void keyPressed(){
  if (key == 'd'){
    debug = ! debug;
  }
}

void addMouseWheelListener(){
  frame.addMouseWheelListener(new java.awt.event.MouseWheelListener(){
    public void mouseWheelMoved(java.awt.event.MouseWheelEvent e){
      cp5.setMouseWheelRotation(e.getWheelRotation());
    }
  }
  );
}

import java.io.PrintStream;

class Silencer{   //silences spammy libraries from the console
  PrintStream originalStream = System.out;
  PrintStream dummyStream = new PrintStream(new OutputStream(){
    public void write(int b){
      // NO-OP
    }
  }
  );   

  Silencer(){
  }

  void silence(){
    System.setOut(dummyStream);
  }
  void unsilence(){
    System.setOut(originalStream);
  }
}
