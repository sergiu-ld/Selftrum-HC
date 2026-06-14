/**
 * SELFTRUM HC
 * TRIBUTE TO ZX Spectrum & HC-85
 *
 * Flow (listen / think / speak, keyboard-driven):
 *   Welcome -> Camera (LISTEN) -> Confirm -> Choose Style -> Choose BG
 *   -> convertAll (THINK) -> Loading: beep/silence choreography (SPEAK) -> Complete
 * Medallion = circular center-crop of selfie; backgrounds stay clean; branding burned in.
 * 5 backgrounds: Rainbow, Starfield, Tron Grid, Checkerboard, Matrix
 *
 * CONCEPT: Sergiu Ardelean / coding with Claude.ai
 * Requires: Processing Video library
 */

import processing.video.*;

int ZX_W = 256;
int ZX_H = 192;
int ATTR_COLS = 32;
int ATTR_ROWS = 24;
int PS = 4;
int SW, SH;

color CLR_BLACK   = #000000;
color CLR_BLUE    = #0022FF;
color CLR_RED     = #FF2222;
color CLR_MAGENTA = #FF22FF;
color CLR_GREEN   = #22FF22;
color CLR_CYAN    = #22FFFF;
color CLR_YELLOW  = #FFFF22;
color CLR_WHITE   = #FFFFFF;

color[] ZX = {
  #000000, #0000D7, #D70000, #D700D7,
  #00D700, #00D7D7, #D7D700, #D7D7D7,
  #000000, #0000FF, #FF0000, #FF00FF,
  #00FF00, #00FFFF, #FFFF00, #FFFFFF
};

color[] RAIN7 = { CLR_BLUE, CLR_RED, CLR_MAGENTA, CLR_GREEN, CLR_CYAN, CLR_YELLOW, CLR_WHITE };

// FLOW (MARK 2 — listen/think/speak, keyboard-driven):
//   0=welcome (SPACE) -> 2=camera (LISTEN) -> 7=confirm (SPACE/ENTER)
//   -> 1=choose style -> 4=choose BG -> [convertAll = THINK] -> 5=loading (SPEAK) -> 6=complete
// (3=processing is legacy/unused now; detectFace runs inside convertAll)
int appState = 0;
int caricMode = 3; // 0=B&W, 1=pop art, 2=random bit, 3=normal
int bgChoice = 0;  // 0=rainbow, 1=starfield, 2=tron, 3=checker, 4=matrix

Capture cam;
boolean camReady = false;
PImage selfie, zxImage;


color[][] zxPix;
byte[] screenBytes;
ZXAudio zxAudio;
ConfigEmail cfgEmail;
ConfigNetwork cfgNetwork;
ConfigAPI cfgAPI;

int fbTimer = 0;
String fbMsg = "";
int countdown = -1;
int countdownStart = 0;
int flashTimer = 0;
int loadingStartTime = 0;
int completeStartTime = 0;
int faceX, faceY, faceW, faceH;
boolean faceFound = false;

// ═══════════════════════════════════════
//  8x8 BITMAP FONT
// ═══════════════════════════════════════
int[] FONT;

void initFont() {
  FONT = new int[128 * 8];
  setG(' ', new int[]{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00});
  setG('!', new int[]{0x18,0x18,0x18,0x18,0x18,0x00,0x18,0x00});
  setG('"', new int[]{0x6C,0x6C,0x6C,0x00,0x00,0x00,0x00,0x00});
  setG('#', new int[]{0x6C,0x6C,0xFE,0x6C,0xFE,0x6C,0x6C,0x00});
  setG('$', new int[]{0x18,0x3E,0x60,0x3C,0x06,0x7C,0x18,0x00});
  setG('%', new int[]{0x00,0x66,0xAC,0xD8,0x36,0x6A,0xCC,0x00});
  setG('&', new int[]{0x38,0x6C,0x68,0x36,0x6C,0x6C,0x36,0x00});
  setG('\'',new int[]{0x18,0x18,0x30,0x00,0x00,0x00,0x00,0x00});
  setG('(', new int[]{0x0C,0x18,0x30,0x30,0x30,0x18,0x0C,0x00});
  setG(')', new int[]{0x30,0x18,0x0C,0x0C,0x0C,0x18,0x30,0x00});
  setG('*', new int[]{0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00});
  setG('+', new int[]{0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00});
  setG(',', new int[]{0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x30});
  setG('-', new int[]{0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00});
  setG('.', new int[]{0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00});
  setG('/', new int[]{0x02,0x06,0x0C,0x18,0x30,0x60,0x40,0x00});
  setG('0', new int[]{0x3C,0x66,0x6E,0x7E,0x76,0x66,0x3C,0x00});
  setG('1', new int[]{0x18,0x38,0x18,0x18,0x18,0x18,0x7E,0x00});
  setG('2', new int[]{0x3C,0x66,0x06,0x0C,0x18,0x30,0x7E,0x00});
  setG('3', new int[]{0x3C,0x66,0x06,0x1C,0x06,0x66,0x3C,0x00});
  setG('4', new int[]{0x0C,0x1C,0x3C,0x6C,0x7E,0x0C,0x0C,0x00});
  setG('5', new int[]{0x7E,0x60,0x7C,0x06,0x06,0x66,0x3C,0x00});
  setG('6', new int[]{0x1C,0x30,0x60,0x7C,0x66,0x66,0x3C,0x00});
  setG('7', new int[]{0x7E,0x06,0x0C,0x18,0x30,0x30,0x30,0x00});
  setG('8', new int[]{0x3C,0x66,0x66,0x3C,0x66,0x66,0x3C,0x00});
  setG('9', new int[]{0x3C,0x66,0x66,0x3E,0x06,0x0C,0x38,0x00});
  setG(':', new int[]{0x00,0x18,0x18,0x00,0x18,0x18,0x00,0x00});
  setG('A', new int[]{0x18,0x3C,0x66,0x66,0x7E,0x66,0x66,0x00});
  setG('B', new int[]{0x7C,0x66,0x66,0x7C,0x66,0x66,0x7C,0x00});
  setG('C', new int[]{0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00});
  setG('D', new int[]{0x78,0x6C,0x66,0x66,0x66,0x6C,0x78,0x00});
  setG('E', new int[]{0x7E,0x60,0x60,0x7C,0x60,0x60,0x7E,0x00});
  setG('F', new int[]{0x7E,0x60,0x60,0x7C,0x60,0x60,0x60,0x00});
  setG('G', new int[]{0x3C,0x66,0x60,0x6E,0x66,0x66,0x3E,0x00});
  setG('H', new int[]{0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00});
  setG('I', new int[]{0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00});
  setG('J', new int[]{0x0E,0x06,0x06,0x06,0x06,0x66,0x3C,0x00});
  setG('K', new int[]{0x66,0x6C,0x78,0x70,0x78,0x6C,0x66,0x00});
  setG('L', new int[]{0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00});
  setG('M', new int[]{0x63,0x77,0x7F,0x6B,0x63,0x63,0x63,0x00});
  setG('N', new int[]{0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x00});
  setG('O', new int[]{0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00});
  setG('P', new int[]{0x7C,0x66,0x66,0x7C,0x60,0x60,0x60,0x00});
  setG('Q', new int[]{0x3C,0x66,0x66,0x66,0x6A,0x6C,0x36,0x00});
  setG('R', new int[]{0x7C,0x66,0x66,0x7C,0x6C,0x66,0x66,0x00});
  setG('S', new int[]{0x3C,0x66,0x60,0x3C,0x06,0x66,0x3C,0x00});
  setG('T', new int[]{0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00});
  setG('U', new int[]{0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00});
  setG('V', new int[]{0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00});
  setG('W', new int[]{0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00});
  setG('X', new int[]{0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00});
  setG('Y', new int[]{0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x00});
  setG('Z', new int[]{0x7E,0x06,0x0C,0x18,0x30,0x60,0x7E,0x00});
  for (int i = 'a'; i <= 'z'; i++) {
    for (int r = 0; r < 8; r++) {
      FONT[i * 8 + r] = FONT[(i - 32) * 8 + r];
    }
  }
}

void setG(char c, int[] rows) {
  for (int r = 0; r < 8; r++) FONT[c * 8 + r] = rows[r];
}

void bText(String txt, int cx, int cy, int sc, color col) {
  int tw = txt.length() * 8 * sc;
  int sx = cx - tw / 2;
  int sy = cy - 4 * sc;
  noStroke();
  for (int i = 0; i < txt.length(); i++) {
    char ch = txt.charAt(i);
    if (ch >= 0 && ch < 128) {
      for (int row = 0; row < 8; row++) {
        int bits = FONT[ch * 8 + row];
        for (int bit = 0; bit < 8; bit++) {
          if ((bits & (1 << (7 - bit))) != 0) {
            fill(col);
            rect(sx + i * 8 * sc + bit * sc, sy + row * sc, sc, sc);
          }
        }
      }
    }
  }
}

void bGlow(String txt, int cx, int cy, int sc, color col, color gCol) {
  bText(txt, cx - 1, cy - 1, sc, gCol);
  bText(txt, cx + 1, cy - 1, sc, gCol);
  bText(txt, cx - 1, cy + 1, sc, gCol);
  bText(txt, cx + 1, cy + 1, sc, gCol);
  bText(txt, cx, cy, sc, col);
}

// ═══════════════════════════════════════
//  SETUP / DRAW
// ═══════════════════════════════════════

void setup() {
  pixelDensity(1);
  fullScreen();
  initFont();

  // Dynamic pixel scale — fit ZX screen with margin
  int maxPW = (int)(displayWidth * 0.9) / ZX_W;
  int maxPH = (int)(displayHeight * 0.8) / ZX_H;
  PS = min(maxPW, maxPH);
  PS = max(PS, 2); // minimum 2
  SW = ZX_W * PS;
  SH = ZX_H * PS;
  println("[Init] Screen: " + displayWidth + "x" + displayHeight + " PS=" + PS);

  zxPix = new color[ZX_H][ZX_W];
  screenBytes = new byte[6912];
  zxAudio = new ZXAudio();
  String dp = dataPath("");
  cfgEmail = new ConfigEmail(dp);
  cfgNetwork = new ConfigNetwork(dp);
  cfgAPI = new ConfigAPI(dp);
}

void draw() {
  switch (appState) {
    case 0: drawWelcome(); break;
    case 1: drawAlterEgo(); break;
    case 2: drawCamera(); break;
    case 4: drawChooseBG(); break;
    case 5: drawLoading(); break;
    case 6: drawComplete(); break;
    case 7: drawConfirm(); break;
  }

  if (fbTimer > 0) {
    fbTimer--;
    fill(0, 220);
    noStroke();
    rect(width / 2 - 300, height / 2 - 30, 600, 60);
    bText(fbMsg, width / 2, height / 2, 2, CLR_GREEN);
  }
}

void captureEvent(Capture c) { c.read(); camReady = true; }

void initCamera() {
  if (cam != null) return;
  try {
    String[] cameras = Capture.list();
    if (cameras.length > 0) {
      cam = new Capture(this, 640, 480);
    }
  } catch (Exception e) {
    println("Camera error: " + e.getMessage());
  }
}

// ═══════════════════════════════════════
//  SCREEN 0: WELCOME
// ═══════════════════════════════════════

void drawWelcome() {
  background(0);

  // Center everything vertically
  int centerY = height / 2 - 60;

  bText("SELFTRUM HC", width / 2, centerY - 160, 6, CLR_WHITE);

  // Black band with thin lines
  fill(0); noStroke();
  rect(0, centerY - 100, width, 30);
  stroke(CLR_WHITE); strokeWeight(1);
  for (int i = 0; i < 3; i++) line(200, centerY - 93 + i * 4, width - 200, centerY - 93 + i * 4);

  // Rainbow diagonal stripes — centered
  int stripeW = 70;
  int stripeH = 250;
  int skew = stripeH / 3;
  int totalVisualW = 7 * stripeW + skew;
  int startX = (width - totalVisualW) / 2 + skew;
  int startY = centerY - 40;
  for (int i = 0; i < 7; i++) {
    fill(RAIN7[i]);
    noStroke();
    int x = startX + i * stripeW;
    beginShape();
    vertex(x, startY);
    vertex(x + stripeW, startY);
    vertex(x + stripeW - skew, startY + stripeH);
    vertex(x - skew, startY + stripeH);
    endShape(CLOSE);
  }

  // "PRESS SPACE TO START" below stripes — unified interactive prompt
  int pressY = startY + stripeH + 50;
  pressPrompt("PRESS SPACE TO START", width / 2, pressY);
}

// ═══════════════════════════════════════
//  SCREEN 1: ALTER-EGO
// ═══════════════════════════════════════

void drawAlterEgo() {
  background(0);
  bText("CHOOSE YOUR STYLE", width / 2, 120, 4, CLR_WHITE);
  stroke(CLR_WHITE); strokeWeight(1);
  line(120, 165, width - 120, 165);

  int cR = 115;
  int cx = width / 2;
  int cy = height / 2 - 20;
  int spacing = min(330, (width - 300) / 2);

  drawCircleBtn(cx - spacing, cy, cR, #11AAAA, #22DDDD, "NORMAL", "", CLR_WHITE, CLR_YELLOW);
  drawCircleBtn(cx,           cy, cR, #EE3333, #FF5555, "BLACK", "& WHITE", CLR_WHITE, CLR_YELLOW);
  drawCircleBtn(cx + spacing, cy, cR, #EE22CC, #FF55FF, "8 BIT", "", CLR_YELLOW, CLR_WHITE);

  // Key labels under each circle, colored like their option
  int ly = cR + 30;
  bText("PRESS 1", cx - spacing, cy + ly, 2, CLR_CYAN);
  bText("PRESS 2", cx,           cy + ly, 2, CLR_RED);
  bText("PRESS 3", cx + spacing, cy + ly, 2, CLR_MAGENTA);

  // Shuffle prompt — lower, framed near the bottom
  pressPrompt("PRESS SPACE TO SHUFFLE", cx, height - 130);
}

// ═══════════════════════════════════════
//  SCREEN 2: CAMERA
// ═══════════════════════════════════════

void drawCamera() {
  background(0);

  // Flash effect
  if (flashTimer > 0) {
    int alpha;
    if (flashTimer > 15) { alpha = 255; }
    else { alpha = (int) map(flashTimer, 0, 15, 0, 255); }
    fill(255, alpha);
    noStroke();
    rect(0, 0, width, height);
    flashTimer--;
    if (flashTimer == 0) { takeSelfie(); }
    return;
  }

  // Circle medallion for camera — like the final output
  int medalCx = width / 2;
  int medalCy = height / 2 - 60;
  int medalR = (int)(height * 0.33);

  if (cam != null && camReady) {
    PImage frame = cam.get();
    PImage mir = mirrorImg(frame);

    // Zoom camera to fill the medallion (crops the sides)
    drawCircleImageCover(mir, medalCx, medalCy, medalR);

    // (8-bit frame drawn below for both states)
  } else {
    // Placeholder
    fill(0); noStroke(); ellipse(medalCx, medalCy, medalR * 2, medalR * 2);
    bText("CAMERA LOADING", medalCx, medalCy, 3, CLR_WHITE);
    if (cam != null) { try { cam.start(); } catch (Exception e) {} }
  }

  // 8-bit colored frame around the camera circle
  drawZXRing(medalCx, medalCy, medalR + 18, 18);

  // Countdown — the digit flies toward the screen (small -> large), no backdrop
  if (countdown > 0) {
    long elapsedMs = millis() - countdownStart;
    int rem = countdown - (int)(elapsedMs / 1000);
    if (rem > 0) {
      float p = (elapsedMs % 1000) / 1000.0;                       // 0..1 within this second
      float f = lerp(0.2, 4.6, p);                                 // grows: far -> near
      int a = (p < 0.78) ? 255 : (int)map(p, 0.78, 1.0, 255, 0);   // fade out before next digit
      pushMatrix();
      translate(medalCx, medalCy);
      scale(f);
      bText(str(rem), 0, 0, 6, color(255, 255, 255, a));
      popMatrix();
    } else {
      flashTimer = 25;
      countdown = -1;
    }
  }

  // Prompt below the camera circle (SPACE starts a 3-second timer)
  pressPrompt("PRESS SPACE TO TAKE SELFIE", medalCx, medalCy + medalR + 90);
}

PImage mirrorImg(PImage src) {
  PImage m = createImage(src.width, src.height, RGB);
  src.loadPixels(); m.loadPixels();
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      m.pixels[y * src.width + x] = src.pixels[y * src.width + (src.width - 1 - x)];
    }
  }
  m.updatePixels();
  return m;
}

void maskOvalBlack(int cx, int cy, int ow, int oh) {
  fill(0); noStroke();
  rect(0, 0, width, cy - oh / 2);
  rect(0, cy + oh / 2, width, height - cy - oh / 2);
  rect(0, cy - oh / 2, cx - ow / 2, oh);
  rect(cx + ow / 2, cy - oh / 2, width - cx - ow / 2, oh);
  for (int py = cy - oh / 2; py <= cy + oh / 2; py++) {
    float ry = (py - cy) / (oh / 2.0);
    float rx = sqrt(max(0, 1.0 - ry * ry));
    int le = (int) (cx - rx * ow / 2);
    int re = (int) (cx + rx * ow / 2);
    if (le > cx - ow / 2) rect(cx - ow / 2, py, le - (cx - ow / 2), 1);
    if (re < cx + ow / 2) rect(re, py, (cx + ow / 2) - re, 1);
  }
}

// Fill a circle with an image (cover/zoom — crops sides), masked LOCALLY only
// (does not paint the rest of the screen black, unlike maskOvalBlack).
void drawCircleImageCover(PImage src, int cx, int cy, int r) {
  int d = r * 2;
  float scale = max(d / (float)src.width, d / (float)src.height) * 1.04;
  int sw = (int)(src.width * scale);
  int sh = (int)(src.height * scale);
  clip(cx - r, cy - r, d, d);
  image(src, cx - sw / 2, cy - sh / 2, sw, sh);
  noClip();
  // Local circular mask — black only the square corners, within [cx-r..cx+r]
  fill(0); noStroke();
  for (int py = cy - r; py <= cy + r; py++) {
    float ry = (py - cy) / (float)r;
    float rx = sqrt(max(0, 1 - ry * ry));
    int le = (int)(cx - rx * r);
    int re = (int)(cx + rx * r);
    rect(cx - r, py, le - (cx - r), 1);
    rect(re, py, (cx + r) - re, 1);
  }
}

void takeSelfie() {
  if (cam != null && camReady) {
    selfie = cam.get();
    cam.stop();
    appState = 7; // -> confirm screen (continue / retake)
  }
}

void triggerFlash() {
  flashTimer = 25; // 10 frames pure white + 15 fade
}

void triggerInstant() {
  flashTimer = 20; // slightly shorter for instant
}

// ═══════════════════════════════════════
//  SCREEN 7: CONFIRM (continue / retake)
// ═══════════════════════════════════════

void drawConfirm() {
  background(0);

  int medalCx = width / 2;
  int medalCy = height / 2 - 60;
  int medalR = (int)(height * 0.30);

  if (selfie != null) {
    PImage mir = mirrorImg(selfie);
    drawCircleImageCover(mir, medalCx, medalCy, medalR);
    drawZXRing(medalCx, medalCy, medalR + 16, 16);
  }

  pressPrompt("PRESS SPACE TO CONTINUE", width / 2, medalCy + medalR + 75);
  pressPrompt("PRESS ENTER TO TAKE ANOTHER PHOTO", width / 2, medalCy + medalR + 130);
}

// ═══════════════════════════════════════
//  SCREEN 4: CHOOSE BACKGROUND
// ═══════════════════════════════════════

void drawChooseBG() {
  background(0);
  bText("CHOOSE BACKGROUND", width / 2, 120, 4, CLR_WHITE);
  stroke(CLR_WHITE); strokeWeight(1);
  line(120, 165, width - 120, 165);

  // 5 backgrounds in one row
  int bw = 180; int bh = 135; int gap = 15;
  int totalW = 5 * bw + 4 * gap;
  int startX = (width - totalW) / 2;
  int by = 230;

  String[] names = { "RAINBOW", "STARFIELD", "TRON GRID", "CHECKER", "MATRIX" };
  color[] nameCols = { CLR_YELLOW, CLR_CYAN, CLR_GREEN, CLR_MAGENTA, CLR_GREEN };

  for (int i = 0; i < 5; i++) {
    int bx = startX + i * (bw + gap);
    boolean hov = mouseX >= bx && mouseX <= bx + bw && mouseY >= by && mouseY <= by + bh + 40;

    drawBGPreview(i, bx, by, bw, bh);

    if (hov) {
      noFill();
      stroke(nameCols[i], 120); strokeWeight(6);
      rect(bx - 4, by - 4, bw + 8, bh + 8);
    }
    noFill();
    stroke(hov ? CLR_WHITE : #555555); strokeWeight(2);
    rect(bx, by, bw, bh);

    if (hov) {
      bGlow(names[i], bx + bw / 2, by + bh + 22, 2, CLR_WHITE, nameCols[i]);
    } else {
      bText(names[i], bx + bw / 2, by + bh + 22, 2, nameCols[i]);
    }
    bText("PRESS " + (i + 1), bx + bw / 2, by + bh + 50, 2, nameCols[i]);
  }

  // Shuffle prompt — centered equally between the labels and the medallion
  pressPrompt("PRESS SPACE TO SHUFFLE", width / 2, (by + bh + 50 + height - 300) / 2);

  // Round medallion preview of the selfie
  if (selfie != null) {
    int mcx = width / 2;
    int mcy = height - 200;
    int mr = 100;
    drawCircleImageCover(mirrorImg(selfie), mcx, mcy, mr);
    drawZXRing(mcx, mcy, mr + 14, 14);
    bText("YOUR SELFIE", mcx, mcy + mr + 40, 2, CLR_WHITE);
  }
}

void drawBGPreview(int bgType, int px, int py, int pw, int ph) {
  // Mini version of each background
  noStroke();
  if (bgType == 0) {
    // Rainbow gradient
    for (int y = 0; y < ph; y++) {
      int ci = (int) map(y, 0, ph, 0, 7) % 7;
      fill(RAIN7[ci]);
      rect(px, py + y, pw, 1);
    }
  } else if (bgType == 1) {
    // Starfield
    fill(#000011); rect(px, py, pw, ph);
    randomSeed(42);
    fill(CLR_WHITE);
    for (int i = 0; i < 40; i++) {
      int sx = px + (int) random(pw);
      int sy = py + (int) random(ph);
      int ss = (int) random(1, 4);
      rect(sx, sy, ss, ss);
    }
  } else if (bgType == 2) {
    // Tron grid
    fill(#000022); rect(px, py, pw, ph);
    stroke(CLR_CYAN, 100); strokeWeight(1);
    for (int gy = 0; gy < ph; gy += 15) line(px, py + gy, px + pw, py + gy);
    for (int gx = 0; gx < pw; gx += 15) line(px + gx, py, px + gx, py + ph);
  } else if (bgType == 3) {
    // Checkerboard
    int cs = 10;
    for (int cy = 0; cy < ph / cs; cy++) {
      for (int cx = 0; cx < pw / cs; cx++) {
        fill(((cx + cy) % 2 == 0) ? CLR_WHITE : CLR_BLUE);
        rect(px + cx * cs, py + cy * cs, cs, cs);
      }
    }
  } else {
    // Matrix
    fill(#000800); rect(px, py, pw, ph);
    fill(CLR_GREEN, 180);
    randomSeed(99);
    for (int col = 0; col < pw / 8; col++) {
      int len = (int) random(3, ph / 8);
      int startRow = (int) random(0, ph / 8 - len);
      for (int row = startRow; row < startRow + len; row++) {
        if (random(1) > 0.3) {
          rect(px + col * 8 + 2, py + row * 8 + 2, 4, 6);
        }
      }
    }
  }
}

// ═══════════════════════════════════════
//  GENERATE FULL-SIZE BACKGROUNDS (256x192)
// ═══════════════════════════════════════

PImage generateBackground(int bgType) {
  PImage bg = createImage(ZX_W, ZX_H, RGB);
  bg.loadPixels();

  if (bgType == 0) {
    // Rainbow vertical gradient
    for (int y = 0; y < ZX_H; y++) {
      float t = (float) y / ZX_H;
      int ci = (int) (t * 6.99);
      color c = RAIN7[ci % 7];
      for (int x = 0; x < ZX_W; x++) {
        bg.pixels[y * ZX_W + x] = c;
      }
    }
  }
  else if (bgType == 1) {
    // Starfield
    for (int i = 0; i < bg.pixels.length; i++) bg.pixels[i] = color(0, 0, 8);
    randomSeed(frameCount / 10 + 42);
    for (int i = 0; i < 200; i++) {
      int sx = (int) random(ZX_W);
      int sy = (int) random(ZX_H);
      int br = (int) random(150, 255);
      color starC = color(br, br, (int) random(200, 255));
      if (sy >= 0 && sy < ZX_H && sx >= 0 && sx < ZX_W) {
        bg.pixels[sy * ZX_W + sx] = starC;
        // Some bigger stars
        if (random(1) > 0.7 && sx + 1 < ZX_W) bg.pixels[sy * ZX_W + sx + 1] = starC;
      }
    }
  }
  else if (bgType == 2) {
    // Tron grid with perspective
    for (int i = 0; i < bg.pixels.length; i++) bg.pixels[i] = color(0, 0, 20);
    for (int y = 0; y < ZX_H; y++) {
      for (int x = 0; x < ZX_W; x++) {
        boolean gridH = (y % 16 == 0);
        boolean gridV = (x % 16 == 0);
        if (gridH || gridV) {
          bg.pixels[y * ZX_W + x] = color(0, 200, 200);
        }
      }
    }
  }
  else if (bgType == 3) {
    // Checkerboard ZX-style
    int cs = 8; // 8-pixel checks match ZX attribute cells
    for (int y = 0; y < ZX_H; y++) {
      for (int x = 0; x < ZX_W; x++) {
        int cy = y / cs;
        int cx = x / cs;
        boolean white = ((cx + cy) % 2 == 0);
        bg.pixels[y * ZX_W + x] = white ? ZX[15] : ZX[1]; // white/blue
      }
    }
  }
  else {
    // Matrix falling characters
    for (int i = 0; i < bg.pixels.length; i++) bg.pixels[i] = color(0, 8, 0);
    randomSeed(77);
    for (int col = 0; col < ZX_W / 4; col++) {
      int len = (int) random(6, ZX_H / 4);
      int startRow = (int) random(0, ZX_H / 4);
      for (int row = startRow; row < min(startRow + len, ZX_H / 4); row++) {
        int px = col * 4;
        int py = row * 4;
        int br = (int) map(row - startRow, 0, len, 255, 60);
        color mc = color(0, br, 0);
        for (int dy = 0; dy < 3; dy++) {
          for (int dx = 0; dx < 3; dx++) {
            if (random(1) > 0.3) {
              int idx = (py + dy) * ZX_W + (px + dx);
              if (idx >= 0 && idx < bg.pixels.length) {
                bg.pixels[idx] = mc;
              }
            }
          }
        }
      }
    }
  }
  bg.updatePixels();
  return bg;
}

// ═══════════════════════════════════════
//  COMPOSITE: face on background
// ═══════════════════════════════════════

// ═══════════════════════════════════════
//  CONVERT ALL — new approach:
//  1. Style-process the selfie ONLY
//  2. Convert styled selfie to ZX palette (medallion pixels)
//  3. Convert background to ZX palette separately (clean)
//  4. Composite: medallion from styled + BG clean
//  5. Add branding (timestamp + logo) AFTER processing
// ═══════════════════════════════════════

void convertAll() {
  if (selfie == null) return;

  // Face bounds needed for the medallion crop (was the old PROCESSING step)
  detectFace();

  // ─── STEP 1: Prepare selfie for medallion ───
  PImage mir = mirrorImg(selfie);
  mir.resize(ZX_W, ZX_H);

  // Try API first
  PImage styledSelfie = mir.copy();
  if (cfgAPI.isReady()) {
    println("[API] Attempting style processing mode=" + caricMode);
    try {
      mir.save(dataPath("_temp_api_input.png"));
      byte[] inputBytes = java.nio.file.Files.readAllBytes(
        new java.io.File(dataPath("_temp_api_input.png")).toPath()
      );
      byte[] resultBytes = cfgAPI.processForMode(inputBytes, caricMode);
      if (resultBytes != null && resultBytes.length > 100) {
        java.io.File tmpOut = new java.io.File(dataPath("_temp_api_output.png"));
        java.io.FileOutputStream fos = new java.io.FileOutputStream(tmpOut);
        fos.write(resultBytes);
        fos.close();
        PImage apiResult = loadImage(dataPath("_temp_api_output.png"));
        if (apiResult != null && apiResult.width > 0) {
          apiResult.resize(ZX_W, ZX_H);
          styledSelfie = apiResult;
          println("[API] Using API result");
        }
      }
      new java.io.File(dataPath("_temp_api_input.png")).delete();
      new java.io.File(dataPath("_temp_api_output.png")).delete();
    } catch (Exception e) {
      println("[API] Error: " + e.getMessage());
    }
  }

  // ─── STEP 2: Convert styled selfie to ZX palette ───
  // Contrast boost
  styledSelfie.loadPixels();
  for (int i = 0; i < styledSelfie.pixels.length; i++) {
    float r = constrain((red(styledSelfie.pixels[i]) - 128) * 1.5 + 128, 0, 255);
    float g = constrain((green(styledSelfie.pixels[i]) - 128) * 1.5 + 128, 0, 255);
    float b = constrain((blue(styledSelfie.pixels[i]) - 128) * 1.5 + 128, 0, 255);
    styledSelfie.pixels[i] = color(r, g, b);
  }
  styledSelfie.updatePixels();

  // Edge detection on selfie
  PImage edges = createImage(ZX_W, ZX_H, RGB);
  styledSelfie.loadPixels(); edges.loadPixels();
  for (int y = 1; y < ZX_H - 1; y++) {
    for (int x = 1; x < ZX_W - 1; x++) {
      float gx = -brightness(styledSelfie.pixels[(y-1)*ZX_W+(x-1)])
                 + brightness(styledSelfie.pixels[(y-1)*ZX_W+(x+1)])
                 - 2*brightness(styledSelfie.pixels[y*ZX_W+(x-1)])
                 + 2*brightness(styledSelfie.pixels[y*ZX_W+(x+1)])
                 - brightness(styledSelfie.pixels[(y+1)*ZX_W+(x-1)])
                 + brightness(styledSelfie.pixels[(y+1)*ZX_W+(x+1)]);
      float gy = -brightness(styledSelfie.pixels[(y-1)*ZX_W+(x-1)])
                 - 2*brightness(styledSelfie.pixels[(y-1)*ZX_W+x])
                 - brightness(styledSelfie.pixels[(y-1)*ZX_W+(x+1)])
                 + brightness(styledSelfie.pixels[(y+1)*ZX_W+(x-1)])
                 + 2*brightness(styledSelfie.pixels[(y+1)*ZX_W+x])
                 + brightness(styledSelfie.pixels[(y+1)*ZX_W+(x+1)]);
      edges.pixels[y*ZX_W+x] = color(constrain(sqrt(gx*gx+gy*gy), 0, 255));
    }
  }
  edges.updatePixels();

  // Convert selfie pixels to ZX palette based on style mode
  color[][] selfiePix = new color[ZX_H][ZX_W];
  styledSelfie.loadPixels(); edges.loadPixels();

  // MODE 3: NORMAL — faithful/minimal: keep the tones, soften the colour
  if (caricMode == 3) {
    for (int y = 0; y < ZX_H; y++) {
      for (int x = 0; x < ZX_W; x++) {
        color orig = styledSelfie.pixels[y*ZX_W+x];
        float r = red(orig), g = green(orig), b = blue(orig);
        float gray = 0.299*r + 0.587*g + 0.114*b;
        float keep = 0.5; // blend halfway to grey -> much gentler than 8 BIT
        r = lerp(gray, r, keep);
        g = lerp(gray, g, keep);
        b = lerp(gray, b, keep);
        float dither = ((x%2)*2+(y%2))*10-15;
        r=constrain(r+dither,0,255); g=constrain(g+dither,0,255); b=constrain(b+dither,0,255);
        selfiePix[y][x] = nearestZX(r, g, b, false);
      }
    }
  }
  // MODE 0: B&W
  else if (caricMode == 0) {
    for (int y = 0; y < ZX_H; y++) {
      for (int x = 0; x < ZX_W; x++) {
        float br = brightness(styledSelfie.pixels[y*ZX_W+x]);
        float ev = brightness(edges.pixels[y*ZX_W+x]);
        if (ev > 50) br *= map(ev, 50, 255, 0.6, 0.0);
        float thr = 128 + ((x%2)*2+(y%2))*20-30;
        selfiePix[y][x] = (br > thr) ? ZX[15] : ZX[0];
      }
    }
  }
  // MODE 2: RANDOM BIT (Kandinsky-inspired)
  else if (caricMode == 2) {
    for (int y = 0; y < ZX_H; y++) {
      for (int x = 0; x < ZX_W; x++) {
        selfiePix[y][x] = ZX[8];
      }
    }
    for (int y = 1; y < ZX_H - 1; y++) {
      for (int x = 1; x < ZX_W - 1; x++) {
        float ev = brightness(edges.pixels[y*ZX_W+x]);
        if (ev > 35) {
          float edgegx = brightness(edges.pixels[y*ZX_W+min(ZX_W-1,x+1)])
                       - brightness(edges.pixels[y*ZX_W+max(0,x-1)]);
          float edgegy = brightness(edges.pixels[min(ZX_H-1,y+1)*ZX_W+x])
                       - brightness(edges.pixels[max(0,y-1)*ZX_W+x]);
          float angle = atan2(edgegy, edgegx);
          int ci;
          if (angle < -2.0) ci = 10;
          else if (angle < -1.0) ci = 14;
          else if (angle < 0) ci = 9;
          else if (angle < 1.0) ci = 13;
          else if (angle < 2.0) ci = 12;
          else ci = 11;
          selfiePix[y][x] = ZX[ci];
          if (ev > 80 && x+1 < ZX_W) selfiePix[y][x+1] = ZX[ci];
          if (ev > 120 && y+1 < ZX_H) selfiePix[y+1][x] = ZX[ci];
        }
      }
    }
    // Circles at density peaks
    for (int gy = 0; gy < ZX_H; gy += 16) {
      for (int gx = 0; gx < ZX_W; gx += 16) {
        float density = 0;
        for (int dy = 0; dy < 16 && (gy+dy)<ZX_H; dy++) {
          for (int dx = 0; dx < 16 && (gx+dx)<ZX_W; dx++) {
            density += brightness(edges.pixels[(gy+dy)*ZX_W+(gx+dx)]);
          }
        }
        density /= 256.0;
        if (density > 30) {
          int radius = min((int)map(density,30,120,2,7), 7);
          color srcC = styledSelfie.pixels[min(gy+8,ZX_H-1)*ZX_W+min(gx+8,ZX_W-1)];
          int best = 15; float minD = 999999;
          for (int ci = 9; ci < 16; ci++) {
            float dr=red(srcC)-red(ZX[ci]); float dg=green(srcC)-green(ZX[ci]); float db=blue(srcC)-blue(ZX[ci]);
            float dd=dr*dr+dg*dg+db*db;
            if (dd<minD) { minD=dd; best=ci; }
          }
          int ccx=gx+8; int ccy=gy+8;
          for (int dy=-radius; dy<=radius; dy++) {
            for (int dx=-radius; dx<=radius; dx++) {
              float dist=sqrt(dx*dx+dy*dy);
              if (dist>=radius-1.2 && dist<=radius+0.5) {
                int px=ccx+dx; int py=ccy+dy;
                if (px>=0&&px<ZX_W&&py>=0&&py<ZX_H) selfiePix[py][px]=ZX[best];
              }
            }
          }
        }
      }
    }
  }
  // MODE 1: 8 BIT — full vivid ZX colour (super colourful, true 8-bit)
  else {
    for (int y = 0; y < ZX_H; y++) {
      for (int x = 0; x < ZX_W; x++) {
        color orig = styledSelfie.pixels[y*ZX_W+x];
        float r = red(orig), g = green(orig), b = blue(orig);
        // saturation lift so colours really pop (no black outlines)
        float avg = (r+g+b)/3.0;
        r = constrain(r+(r-avg)*0.35,0,255);
        g = constrain(g+(g-avg)*0.35,0,255);
        b = constrain(b+(b-avg)*0.35,0,255);
        float dither = ((x%2)*2+(y%2))*12-18;
        r=constrain(r+dither,0,255); g=constrain(g+dither,0,255); b=constrain(b+dither,0,255);
        selfiePix[y][x] = nearestZX(r, g, b, true); // preferBright -> punchy palette
      }
    }
  }

  // Apply attribute clash to selfie (skip B&W)
  if (caricMode != 0) {
    applyClashToArray(selfiePix);
  }

  // ─── STEP 3: Convert background to ZX palette (clean, no style) ───
  PImage bg = generateBackground(constrain(bgChoice, 0, 4));
  bg.loadPixels();
  color[][] bgPix = new color[ZX_H][ZX_W];
  for (int y = 0; y < ZX_H; y++) {
    for (int x = 0; x < ZX_W; x++) {
      color c = bg.pixels[y*ZX_W+x];
      bgPix[y][x] = nearestZX(red(c), green(c), blue(c), false);
    }
  }
  applyClashToArray(bgPix);

  // ─── STEP 4: Composite — medallion from styled selfie, BG clean ───
  int medalCx = ZX_W / 2;
  int medalCy = ZX_H / 2;
  int medalR = (int)(ZX_H * 0.46);
  int frameW = 3;

  for (int y = 0; y < ZX_H; y++) {
    for (int x = 0; x < ZX_W; x++) {
      float dx = x - medalCx;
      float dy = y - medalCy;
      float dist = sqrt(dx*dx + dy*dy);

      if (dist < medalR - frameW) {
        // Inside medallion — FACE AUTOZOOM
        // u,v = normalized position within medallion circle (0..1)
        float u = (dx / (float)(medalR - frameW) + 1.0) * 0.5;
        float v = (dy / (float)(medalR - frameW) + 1.0) * 0.5;

        // Face crop rectangle in ORIGINAL selfie pixels
        // Expand face bounds to include some margin (hair, chin)
        int cropX = max(0, faceX - faceW / 3);
        int cropY = max(0, faceY - faceH / 2); // more room above for hair
        int cropW = min(selfie.width - cropX, faceW + faceW * 2 / 3);
        int cropH = min(selfie.height - cropY, faceH + faceH * 2 / 3);
        // Make square crop (circle needs square source)
        int cropSize = max(cropW, cropH);
        int cropCx = cropX + cropW / 2;
        int cropCy = cropY + cropH / 2;
        cropX = max(0, cropCx - cropSize / 2);
        cropY = max(0, cropCy - cropSize / 2);
        cropSize = min(cropSize, min(selfie.width - cropX, selfie.height - cropY));

        // Map u,v to crop area, then to ZX coords (mirrored)
        int origX = cropX + (int)(u * cropSize);
        int origY = cropY + (int)(v * cropSize);
        origX = constrain(origX, 0, selfie.width - 1);
        origY = constrain(origY, 0, selfie.height - 1);

        // Convert to ZX coords (mirrored)
        int zxX = (int)map(selfie.width - 1 - origX, 0, selfie.width, 0, ZX_W);
        int zxY = (int)map(origY, 0, selfie.height, 0, ZX_H);
        zxX = constrain(zxX, 0, ZX_W - 1);
        zxY = constrain(zxY, 0, ZX_H - 1);

        zxPix[y][x] = selfiePix[zxY][zxX];
      }
      else if (dist < medalR) {
        // Rainbow checkerboard frame
        int segment = ((int)(atan2(dy, dx) * 7 / PI) + 7) % 7;
        color frameCol = RAIN7[segment];
        boolean checker = ((x/2 + y/2) % 2 == 0);
        zxPix[y][x] = checker ? nearestZX(red(frameCol), green(frameCol), blue(frameCol), false) : ZX[0];
      }
      else if (dist < medalR + 2) {
        zxPix[y][x] = ZX[0]; // thin black border
      }
      else {
        // Background — clean, unprocessed by style
        zxPix[y][x] = bgPix[y][x];
      }
    }
  }

  // ─── STEP 5: Add branding AFTER all processing (clear footer bar) ───
  // Solid black footer across the bottom 8px (one ZX cell-row -> no attribute clash)
  for (int y = ZX_H - 8; y < ZX_H; y++)
    for (int x = 0; x < ZX_W; x++)
      zxPix[y][x] = ZX[0];

  // Timestamp (date only) — 6px, bright white, bottom-left
  String ts = nf(day(),2) + "." + nf(month(),2) + "." + year();
  burnTextH(ts, 4, ZX_H - 7, ZX[15], 6);

  // "SELFTRUM HC" logo — 6px, bright cyan, bottom-right
  String logo = "SELFTRUM HC";
  int logoW = logo.length() * 6;
  burnTextH(logo, ZX_W - logoW - 4, ZX_H - 7, ZX[13], 6);

  // ─── Build screen bytes ───
  buildScreenBytes();

  zxImage = createImage(ZX_W, ZX_H, RGB);
  zxImage.loadPixels();
  for (int y = 0; y < ZX_H; y++) {
    for (int x = 0; x < ZX_W; x++) {
      zxImage.pixels[y*ZX_W+x] = zxPix[y][x];
    }
  }
  zxImage.updatePixels();
}

// Burn text into zxPix at 1:1 (8px) or half (4px) scale
void burnText(String txt, int x0, int y0, color col) {
  burnTextScale(txt, x0, y0, col, 1);
}
void burnTextHalf(String txt, int x0, int y0, color col) {
  burnTextScale(txt, x0, y0, col, 0);
}
void burnTextScale(String txt, int x0, int y0, color col, int fullScale) {
  for (int i = 0; i < txt.length(); i++) {
    char ch = txt.charAt(i);
    if (ch < 0 || ch >= 128) continue;

    if (fullScale == 1) {
      // Full 8x8
      for (int row = 0; row < 8; row++) {
        int bits = FONT[ch * 8 + row];
        for (int bit = 0; bit < 8; bit++) {
          if ((bits & (1 << (7 - bit))) != 0) {
            int px = x0 + i * 8 + bit;
            int py = y0 + row;
            if (px >= 0 && px < ZX_W && py >= 0 && py < ZX_H) zxPix[py][px] = col;
          }
        }
      }
    } else {
      // Half 4x4 — OR-combine each 2x2 source block so glyphs stay solid
      for (int hr = 0; hr < 4; hr++) {
        for (int hb = 0; hb < 4; hb++) {
          boolean on = false;
          for (int dr = 0; dr < 2; dr++) {
            int bits = FONT[ch * 8 + hr * 2 + dr];
            for (int db = 0; db < 2; db++) {
              if ((bits & (1 << (7 - (hb * 2 + db)))) != 0) on = true;
            }
          }
          if (on) {
            int px = x0 + i * 4 + hb;
            int py = y0 + hr;
            if (px >= 0 && px < ZX_W && py >= 0 && py < ZX_H) zxPix[py][px] = col;
          }
        }
      }
    }
  }
}

// Burn text at an arbitrary pixel height (nearest-neighbour from the 8x8 font)
void burnTextH(String txt, int x0, int y0, color col, int h) {
  float sc = h / 8.0;
  for (int i = 0; i < txt.length(); i++) {
    char ch = txt.charAt(i);
    if (ch < 0 || ch >= 128) continue;
    for (int ty = 0; ty < h; ty++) {
      int srow = constrain((int)(ty / sc), 0, 7);
      int bits = FONT[ch * 8 + srow];
      for (int tx = 0; tx < h; tx++) {
        int sbit = constrain((int)(tx / sc), 0, 7);
        if ((bits & (1 << (7 - sbit))) != 0) {
          int px = x0 + i * h + tx;
          int py = y0 + ty;
          if (px >= 0 && px < ZX_W && py >= 0 && py < ZX_H) zxPix[py][px] = col;
        }
      }
    }
  }
}

// Find nearest ZX color
color nearestZX(float r, float g, float b, boolean preferBright) {
  float minD = 999999; int best = 0;
  for (int ci = 0; ci < 16; ci++) {
    float dr = r - red(ZX[ci]);
    float dg = g - green(ZX[ci]);
    float db = b - blue(ZX[ci]);
    float dd = dr*dr + dg*dg + db*db;
    if (preferBright && ci >= 8) dd *= 0.7;
    if (dd < minD) { minD = dd; best = ci; }
  }
  return ZX[best];
}

// Apply attribute clash to a color array
void applyClashToArray(color[][] pix) {
  for (int row = 0; row < ATTR_ROWS; row++) {
    for (int col = 0; col < ATTR_COLS; col++) {
      int[] cc = new int[16];
      for (int py = 0; py < 8; py++) {
        for (int px = 0; px < 8; px++) {
          color c = pix[row*8+py][col*8+px];
          for (int ci = 0; ci < 16; ci++) { if (c == ZX[ci]) { cc[ci]++; break; } }
        }
      }
      int ink=0, paper=0, m1=0, m2=0;
      for (int ci = 0; ci < 16; ci++) {
        if (cc[ci]>m1) { m2=m1; paper=ink; m1=cc[ci]; ink=ci; }
        else if (cc[ci]>m2) { m2=cc[ci]; paper=ci; }
      }
      for (int py = 0; py < 8; py++) {
        for (int px = 0; px < 8; px++) {
          int y = row*8+py; int x = col*8+px;
          color c = pix[y][x];
          float di = cdist(c, ZX[ink]); float dp = cdist(c, ZX[paper]);
          pix[y][x] = (di<=dp) ? ZX[ink] : ZX[paper];
        }
      }
    }
  }
}

float cdist(color a, color b) {
  float dr=red(a)-red(b); float dg=green(a)-green(b); float db=blue(a)-blue(b);
  return dr*dr+dg*dg+db*db;
}

void buildScreenBytes() {
  screenBytes = new byte[6912];
  for (int addr = 0; addr < 6144; addr++) {
    int third=(addr>>11)&0x03; int scanLine=(addr>>8)&0x07;
    int charRow=(addr>>5)&0x07; int col=addr&0x1F;
    int y=third*64+charRow*8+scanLine; int xBase=col*8;
    int attrRow=y/8; int attrCol=xBase/8;
    int[] cnt=new int[16];
    for (int py2=0;py2<8;py2++) { for (int px2=0;px2<8;px2++) {
      color c=zxPix[attrRow*8+py2][attrCol*8+px2];
      for (int ci=0;ci<16;ci++) { if (c==ZX[ci]) { cnt[ci]++; break; } }
    } }
    int paperC=0; int m1=0;
    for (int ci=0;ci<16;ci++) { if (cnt[ci]>m1) { m1=cnt[ci]; paperC=ci; } }
    byte b=0;
    for (int bit=0;bit<8;bit++) { int x=xBase+bit;
      if (x<ZX_W && y<ZX_H) { if (zxPix[y][x]!=ZX[paperC]) b|=(1<<(7-bit)); }
    }
    screenBytes[addr]=b;
  }
  for (int addr=0;addr<768;addr++) {
    int row=addr/32; int col=addr%32;
    int[] cnt=new int[16];
    for (int py=0;py<8;py++) { for (int px=0;px<8;px++) {
      color c=zxPix[row*8+py][col*8+px];
      for (int ci=0;ci<16;ci++) { if (c==ZX[ci]) { cnt[ci]++; break; } }
    } }
    int ink=0,paper=0,m1i=0,m2i=0;
    for (int ci=0;ci<16;ci++) {
      if (cnt[ci]>m1i) { m2i=m1i; paper=ink; m1i=cnt[ci]; ink=ci; }
      else if (cnt[ci]>m2i) { m2i=cnt[ci]; paper=ci; }
    }
    boolean bright=(ink>=8)||(paper>=8);
    screenBytes[6144+addr]=(byte)((bright?0x40:0)|((ink&7)<<3)|(paper&7));
  }
}

// ═══════════════════════════════════════
//  FACE DETECTION
// ═══════════════════════════════════════

void detectFace() {
  if (selfie == null) return;
  selfie.loadPixels();
  int w = selfie.width; int h = selfie.height;
  int minX=w,maxX=0,minY=h,maxY=0,skinCount=0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      color c = selfie.pixels[y*w+x];
      float r=red(c); float g=green(c); float b=blue(c);
      boolean isSkin = false;
      if (r>60&&g>40&&b>20) {
        float mx=max(r,max(g,b)); float mn=min(r,min(g,b));
        if ((mx-mn)>15&&r>g&&r>b&&abs(r-g)>15) isSkin=true;
        if (r>80&&g>60&&(r-b)>15) isSkin=true;
      }
      if (r>40&&g>30&&b>15&&r>b) { float ratio=r/(g+1); if (ratio>0.9&&ratio<1.8) isSkin=true; }
      if (isSkin) { skinCount++; if(x<minX)minX=x; if(x>maxX)maxX=x; if(y<minY)minY=y; if(y>maxY)maxY=y; }
    }
  }
  if (skinCount > 500) {
    int cx=minX+(maxX-minX)/2; int cy=minY+(maxY-minY)/3;
    faceW=(int)((maxX-minX)*0.7); faceH=(int)((maxY-minY)*0.6);
    faceX=max(0,cx-faceW/2); faceY=max(0,cy-faceH/2);
    faceW=min(faceW,w-faceX); faceH=min(faceH,h-faceY);
    faceFound=true;
  } else {
    faceX=w/4; faceY=h/6; faceW=w/2; faceH=h*2/3; faceFound=false;
  }
}

// (caricature warp removed — direct selfie processing)

// createCaricature removed — selfie used directly

// ═══════════════════════════════════════
//  SCREEN 5: LOADING
// ═══════════════════════════════════════

void drawLoading() {
  background(0);
  int s = zxAudio.seg;
  int ox = (width - SW) / 2;
  int oy = (height - SH) / 2 - 20;

  // SEG 0..3 — checklist with beep/silence choreography
  if (s <= 3) {
    drawChecklist(s, zxAudio.segElapsed(), ox, oy);
    return;
  }

  // SEG 4 — LOADING / PLEASE WAIT (long beep before the data)
  if (s == 4) {
    bText("LOADING", width / 2, oy + SH / 2 - 20, 4, CLR_YELLOW);
    int dots = (frameCount / 8) % 4;
    String d = "";
    for (int i = 0; i < dots; i++) d += " .";
    bText("PLEASE WAIT" + d, width / 2, oy + SH / 2 + 30, 2, CLR_WHITE);
    int barY = oy + SH / 2 + 70;
    for (int i = 0; i < 300; i++) {
      int ci = (i / 4 + frameCount / 2) % 7;
      fill(RAIN7[ci]); noStroke();
      rect(width / 2 - 150 + i, barY, 1, 4);
    }
    return;
  }

  // SEG 5 — pixel-by-pixel reveal driven by tape data
  if (s == 5) {
    drawReveal(ox, oy);
    if (!zxAudio.isRunning()) { appState = 6; completeStartTime = millis(); }
    return;
  }

  // SEG 6 — done
  appState = 6;
  completeStartTime = millis();
}

void drawChecklist(int s, long se, int ox, int oy) {
  // Each line: appears (sequentially, with dots = "working") during a BEEP segment,
  // then flips to OK exactly when the sound PAUSES (the following silence segment).
  String[] names = {
    "SELFIE CAPTURED", "FACE DETECTION", "BACKGROUND REMOVAL",   // appear in beep seg 0
    "STYLE PROCESSING", "ZX SPECTRUM CONVERT", "SCREEN MEMORY BUILT", // appear in beep seg 2
    "PREPARING TAPE"                                              // appears in silence seg 3
  };
  int[] appearSeg = { 0, 0, 0, 2, 2, 2, 3 };
  int[] okSeg     = { 1, 1, 1, 3, 3, 3, -1 }; // -1 = never resolves (stays "working")

  int lineH = 34;
  int startY = oy + SH / 2 - (names.length * lineH) / 2;

  for (int i = 0; i < names.length; i++) {
    int aseg = appearSeg[i];

    // Visibility — items in the same beep appear one by one across that segment
    boolean visible;
    if (s > aseg) visible = true;
    else if (s < aseg) visible = false;
    else {
      int order = 0, count = 0;
      for (int k = 0; k < names.length; k++) if (appearSeg[k] == aseg) { count++; if (k < i) order++; }
      float thresh = (count <= 1) ? 0 : (order / (float)count) * zxAudio.SEG_MS[aseg];
      visible = se >= thresh;
    }
    if (!visible) continue;

    int y = startY + i * lineH;
    boolean done = (okSeg[i] >= 0) && (s >= okSeg[i]); // OK from the start of the silence

    if (done) {
      bText(names[i], width / 2 - 60, y, 2, CLR_GREEN);
      bText("OK", width / 2 + 200, y, 2, CLR_GREEN);
    } else {
      int dots = (frameCount / 8) % 4;
      String ds = "";
      for (int d = 0; d < dots; d++) ds += ".";
      bText(names[i], width / 2 - 60, y, 2, CLR_YELLOW);
      bText(ds, width / 2 + 200, y, 2, CLR_WHITE);
    }
  }

  // Animated rainbow bar at bottom
  int barY = oy + SH + 15;
  for (int i = 0; i < SW; i++) {
    int ci = (i / 8 + frameCount / 2) % 7;
    fill(RAIN7[ci]); noStroke();
    rect(ox + i, barY, 1, 4);
  }
}

void drawReveal(int ox, int oy) {
  noStroke();
  int maxAddr = min(zxAudio.currentByte, 6144);
  for (int addr = 0; addr < maxAddr; addr++) {
    int third = (addr >> 11) & 0x03;
    int scanLine = (addr >> 8) & 0x07;
    int charRow = (addr >> 5) & 0x07;
    int colAddr = addr & 0x1F;
    int y = third * 64 + charRow * 8 + scanLine;
    int xBase = colAddr * 8;
    for (int bit = 0; bit < 8; bit++) {
      int x = xBase + bit;
      if (x < ZX_W && y < ZX_H) {
        fill(zxPix[y][x]);
        rect(ox + x * PS, oy + y * PS, PS, PS);
      }
    }
  }
  stroke(0, 40); strokeWeight(1);
  for (int sy = oy; sy < oy + SH; sy += 3) line(ox, sy, ox + SW, sy);
}

// ═══════════════════════════════════════
//  SCREEN 6: COMPLETE
// ═══════════════════════════════════════

void drawComplete() {
  background(0);
  int imgS = PS;
  int imgW = ZX_W * imgS;
  int imgH = ZX_H * imgS;
  int imgX = (width - imgW) / 2;
  int imgY = max(10, (height - imgH - 220) / 2);
  stroke(CLR_CYAN); strokeWeight(3); noFill();
  rect(imgX - 5, imgY - 5, imgW + 10, imgH + 10);
  noStroke();
  for (int y = 0; y < ZX_H; y++) {
    for (int x = 0; x < ZX_W; x++) {
      fill(zxPix[y][x]);
      rect(imgX + x * imgS, imgY + y * imgS, imgS, imgS);
    }
  }

  // Branding is already burned into the ZX image pixels

  int py = imgY + imgH + 50;
  pressPrompt("PRESS SPACE TO PRINT", width / 2, py);
  pressPrompt("PRESS ENTER TO START OVER", width / 2, py + 55);

  // 30-second inactivity auto-restart
  int remain = 30 - (millis() - completeStartTime) / 1000;
  if (remain < 0) remain = 0;
  bText("AUTO RESTART IN " + remain, width / 2, py + 95, 1, #777777);
  if (millis() - completeStartTime > 30000) resetApp();
}

// ═══════════════════════════════════════
//  SHARED UI: Circle Button with Glow
// ═══════════════════════════════════════

// Unified interactive prompt — same font/size/glow everywhere for visual identity
void pressPrompt(String txt, int cx, int cy) {
  color g = RAIN7[(frameCount / 6) % 7];
  bGlow(txt, cx, cy, 3, CLR_WHITE, g);
}

// 8-bit colored frame: rainbow checkerboard ring of blocks around a circle
void drawZXRing(int cx, int cy, int rOuter, int thickness) {
  int bs = 8; // 8-bit block size
  int rInner = rOuter - thickness;
  noStroke();
  for (int y = cy - rOuter; y < cy + rOuter; y += bs) {
    for (int x = cx - rOuter; x < cx + rOuter; x += bs) {
      float dx = x + bs / 2 - cx;
      float dy = y + bs / 2 - cy;
      float d = sqrt(dx * dx + dy * dy);
      if (d <= rOuter && d >= rInner) {
        int seg = ((int)(atan2(dy, dx) * 7 / PI) + 7) % 7;
        boolean checker = (((x / bs) + (y / bs)) % 2 == 0);
        fill(checker ? RAIN7[seg] : color(0));
        rect(x, y, bs, bs);
      }
    }
  }
}

void drawCircleBtn(int cx, int cy, int r, color colNorm, color colHov, String t1, String t2, color tCol, color gCol) {
  boolean hov = dist(mouseX, mouseY, cx, cy) < r;
  noStroke();

  // Animated glow pulse — ALWAYS the intense glow (per visual identity)
  float pulse = (sin(frameCount * 0.06) + 1.0) * 0.5; // 0..1
  float glowSize = r * 2 + 30 + pulse * 12;
  int glowAlpha = (int)(100 + pulse * 60);
  color gcol = hov ? colHov : colNorm;
  // White outer glow
  fill(255, (int)(glowAlpha * 0.3));
  ellipse(cx, cy, glowSize + 16, glowSize + 16);
  // Color glow
  fill(red(gcol), green(gcol), blue(gcol), glowAlpha);
  ellipse(cx, cy, glowSize, glowSize);

  // Main circle
  fill(hov ? colHov : colNorm);
  ellipse(cx, cy, r * 2, r * 2);

  // Text
  if (t2.length() > 0) {
    if (hov) { bGlow(t1, cx, cy - 12, 2, tCol, gCol); bGlow(t2, cx, cy + 12, 2, tCol, gCol); }
    else { bText(t1, cx, cy - 12, 2, tCol); bText(t2, cx, cy + 12, 2, tCol); }
  } else {
    if (hov) { bGlow(t1, cx, cy, 2, tCol, gCol); }
    else { bText(t1, cx, cy, 2, tCol); }
  }
}

// ═══════════════════════════════════════
//  INPUT
// ═══════════════════════════════════════

// Shared selection helpers (used by both mouse/touch and keyboard)
void chooseStyle(int mode) {
  caricMode = mode;
  appState = 4; // -> choose background
}

void startConversion() {
  // THINK phase happens here (convertAll), then SPEAK (loading) begins
  convertAll();
  zxAudio.setScreenData(screenBytes);
  zxAudio.start();
  loadingStartTime = millis();
  appState = 5;
}

void chooseBG(int bg) {
  bgChoice = constrain(bg, 0, 4);
  startConversion();
}

void mousePressed() {
  // appState 0 (welcome), 2 (camera), 6 (complete), 7 (confirm) are keyboard-only

  if (appState == 1) {
    int cR = 115; int cx = width / 2; int cy = height / 2 - 20;
    int spacing = min(330, (width - 300) / 2);
    if (dist(mouseX,mouseY,cx-spacing,cy) < cR) chooseStyle(3); // NORMAL
    if (dist(mouseX,mouseY,cx,cy) < cR)         chooseStyle(0); // B&W
    if (dist(mouseX,mouseY,cx+spacing,cy) < cR) chooseStyle(1); // 8 BIT
  }
  else if (appState == 4) {
    int bw = 180; int bh = 135; int gap = 15;
    int totalW = 5 * bw + 4 * gap;
    int startX = (width - totalW) / 2;
    int by = 160;
    for (int i = 0; i < 5; i++) {
      int bx = startX + i * (bw + gap);
      if (mouseX >= bx && mouseX <= bx + bw && mouseY >= by && mouseY <= by + bh + 40) {
        chooseBG(i);
        break;
      }
    }
  }
}

void keyPressed() {
  // WELCOME — SPACE starts camera (LISTEN)
  if (appState == 0) {
    if (key == ' ') { initCamera(); if (cam != null) cam.start(); camReady = false; appState = 2; }
  }
  // CAMERA — SPACE = 3-second timer, ESC = back to welcome
  else if (appState == 2) {
    if (key == ' ') { if (countdown < 0 && flashTimer == 0) { countdown = 3; countdownStart = millis(); } }
    else if (key == ESC) { key = 0; if (cam != null) cam.stop(); appState = 0; }
  }
  // CONFIRM — SPACE continues, ENTER retakes
  else if (appState == 7) {
    if (key == ' ') { appState = 1; }
    else if (key == ENTER || key == RETURN || key == ESC) {
      key = 0; if (cam != null) cam.start(); camReady = false; appState = 2;
    }
  }
  // CHOOSE STYLE — 1..3 select, SPACE shuffles
  else if (appState == 1) {
    if (key == '1') chooseStyle(3);       // NORMAL
    else if (key == '2') chooseStyle(0);  // B&W
    else if (key == '3') chooseStyle(1);  // 8 BIT
    else if (key == ' ') { int[] m = {3, 0, 1}; chooseStyle(m[(int)random(3)]); }
  }
  // CHOOSE BACKGROUND — 1..5 select, SPACE shuffles
  else if (appState == 4) {
    if (key >= '1' && key <= '5') chooseBG(key - '1');
    else if (key == ' ') chooseBG((int)random(5));
  }
  // COMPLETE — SPACE prints, ENTER starts over (any key resets idle timer)
  else if (appState == 6) {
    completeStartTime = millis();
    if (key == ' ') doPrint();
    else if (key == ENTER || key == RETURN) resetApp();
  }
}

// ═══════════════════════════════════════
//  ACTIONS
// ═══════════════════════════════════════

String saveImg() {
  // Print template: 15x10cm at 300dpi = 1770x1181 pixels
  // ZX is 256x192 so scale = ~7x for width, ~9x for height
  // Use uniform scale to maintain ZX pixels
  int printScale = 7;
  int outW = ZX_W * printScale;  // 1792
  int outH = ZX_H * printScale;  // 1344
  PGraphics out = createGraphics(outW, outH);
  out.beginDraw();
  out.noStroke();
  for (int y = 0; y < ZX_H; y++) {
    for (int x = 0; x < ZX_W; x++) {
      out.fill(zxPix[y][x]);
      out.rect(x * printScale, y * printScale, printScale, printScale);
    }
  }
  out.endDraw();
  String fn = "SELFTRUM_" + year() + nf(month(),2) + nf(day(),2)
    + "_" + nf(hour(),2) + nf(minute(),2) + nf(second(),2) + ".png";
  File dir = new File(sketchPath("output"));
  if (!dir.exists()) dir.mkdirs();
  String fullPath = sketchPath("output/" + fn);
  out.save(fullPath);
  return fullPath;
}

void doPrint() {
  String path=saveImg();
  if (cfgNetwork.isPrinterReady()) {
    try {
      byte[] data=java.nio.file.Files.readAllBytes(new java.io.File(path).toPath());
      boolean ok=cfgNetwork.sendToPrinter(data);
      fbMsg=ok?"PRINT SENT":"PRINT FAILED";
    } catch (Exception e) { fbMsg="PRINT ERROR"; }
  } else { fbMsg="SAVED "+path.substring(path.lastIndexOf('/')+1); }
  fbTimer=120;
}

void doEmail() {
  saveImg();
  if (cfgEmail.isReady()) { fbMsg="EMAIL: "+cfgEmail.getStatus(); }
  else { fbMsg="EDIT DATA/EMAIL_CONFIG.JSON"; }
  fbTimer=120;
}

void resetApp() {
  zxAudio.stop(); appState=0; selfie=null;
  zxImage=null;
  countdown=-1; camReady=false; cam=null;
}
