import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.DataLine;
import javax.sound.sampled.SourceDataLine;

/**
 * ZXAudio — authentic ZX Spectrum tape engine, scripted into UI segments.
 *
 * Segment script (drives the loading screen choreography):
 *   seg 0 = long beep  (pilot)  -> SELFIE CAPTURED / FACE DETECTION
 *   seg 1 = silence             -> BACKGROUND REMOVAL
 *   seg 2 = long beep  (pilot)  -> STYLE / ZX CONVERT / SCREEN MEMORY BUILT
 *   seg 3 = silence             -> PREPARING TAPE (never resolves)
 *   seg 4 = long beep  (pilot)  -> LOADING / PLEASE WAIT
 *   seg 5 = data warble         -> pixel-by-pixel image reveal (drives currentByte)
 *   seg 6 = done
 */
public class ZXAudio implements Runnable {

  // ---- Public state read by the sketch ----
  public volatile int seg = 0;
  public volatile long segStart = 0;        // System.currentTimeMillis() at seg start
  public volatile int currentByte = 0;
  public volatile int totalDataBytes = 0;
  public volatile boolean borderHigh = false;
  public volatile int phase = 0;            // legacy mirror (kept harmless)

  // Durations (ms) for seg 0..4. seg 5 = data (variable), seg 6 = done.
  public int[] SEG_MS = { 2600, 1300, 3600, 1500, 2200 };

  private volatile boolean running = false;
  private volatile byte[] screenData;
  private Thread thread;

  private static final float SAMPLE_RATE = 44100f;
  private static final float CPU_FREQ = 3500000f;
  private float speedMultiplier = 1.0f;     // data plays at real 1.0x speed

  private SourceDataLine line;
  private java.util.Random rng = new java.util.Random(42);

  public ZXAudio() {
    screenData = new byte[6912];
  }

  public void setScreenData(byte[] d) {
    if (d != null) {
      screenData = d;
      totalDataBytes = d.length;
    }
  }

  public void setSpeed(float m) { speedMultiplier = m; }

  public long segElapsed() { return System.currentTimeMillis() - segStart; }

  public void start() {
    if (running) stop();
    currentByte = 0;
    seg = 0;
    phase = 0;
    segStart = System.currentTimeMillis();
    running = true;
    thread = new Thread(this);
    thread.setDaemon(true);
    thread.start();
  }

  public void stop() {
    running = false;
    if (thread != null) {
      try { thread.join(1000); } catch (InterruptedException e) {}
      thread = null;
    }
  }

  public boolean isRunning() { return running; }

  private float tstateToSamples(float t) {
    return (t / CPU_FREQ) * SAMPLE_RATE / speedMultiplier;
  }

  private void writePulse(float halfTstates) throws Exception {
    int half = Math.max(1, (int) tstateToSamples(halfTstates));
    byte[] buf = new byte[half * 2];
    byte hi = (byte) (0.75f * 127);
    byte lo = (byte) (-0.75f * 127);
    for (int i = 0; i < half; i++)      buf[i] = (byte) (hi + rng.nextInt(5) - 2);
    for (int i = half; i < half * 2; i++) buf[i] = (byte) (lo + rng.nextInt(5) - 2);
    borderHigh = !borderHigh;
    line.write(buf, 0, buf.length);
  }

  private void writeBit(boolean one) throws Exception {
    float t = one ? 1710f : 855f;
    writePulse(t);
    writePulse(t);
  }

  private void writeDataByte(byte b) throws Exception {
    for (int bit = 7; bit >= 0; bit--) {
      if (!running) return;
      writeBit(((b >> bit) & 1) == 1);
    }
  }

  // Short raspy DATA noise burst (the "brrt" you hear on a real tape)
  private void noiseBurstMs(int ms) throws Exception {
    long end = System.currentTimeMillis() + ms;
    while (System.currentTimeMillis() < end && running) {
      writeDataByte((byte) rng.nextInt(256));
    }
  }

  // Steady pilot tone for a real-time duration (the "long beep")
  private void beepMs(int ms) throws Exception {
    long end = System.currentTimeMillis() + ms;
    while (System.currentTimeMillis() < end && running) {
      writePulse(2168f);
    }
  }

  // Real silence for a duration, chunked so stop() stays responsive
  private void silenceMs(int ms) throws Exception {
    int total = (int) (SAMPLE_RATE * ms / 1000f);
    byte[] buf = new byte[Math.min(total, 4096)];
    for (int i = 0; i < buf.length; i++) buf[i] = (byte) (rng.nextInt(3) - 1);
    int written = 0;
    while (written < total && running) {
      int chunk = Math.min(buf.length, total - written);
      line.write(buf, 0, chunk);
      written += chunk;
    }
  }

  private void enter(int s) {
    seg = s;
    phase = s;
    segStart = System.currentTimeMillis();
  }

  public void run() {
    try {
      AudioFormat fmt = new AudioFormat(SAMPLE_RATE, 8, 1, true, false);
      DataLine.Info info = new DataLine.Info(SourceDataLine.class, fmt);
      line = (SourceDataLine) AudioSystem.getLine(info);
      line.open(fmt, 16384);
      line.start();

      // SEG 0 — long beep (selfie captured / face detection)
      enter(0); beepMs(SEG_MS[0]);
      if (!running) return;

      // SEG 1 — short data-noise on the OK, then a beat of quiet
      enter(1);
      int n1 = Math.min(SEG_MS[1], 300);
      noiseBurstMs(n1);
      if (running) silenceMs(SEG_MS[1] - n1);
      if (!running) return;

      // SEG 2 — long beep (style / zx convert / screen memory built)
      enter(2); beepMs(SEG_MS[2]);
      if (!running) return;

      // SEG 3 — short data-noise on the OK, then quiet (PREPARING TAPE lingers)
      enter(3);
      int n3 = Math.min(SEG_MS[3], 300);
      noiseBurstMs(n3);
      if (running) silenceMs(SEG_MS[3] - n3);
      if (!running) return;

      // SEG 4 — long beep (loading / please wait)
      enter(4); beepMs(SEG_MS[4]);
      if (!running) return;

      // SEG 5 — data warble: drives currentByte for the pixel reveal
      enter(5);
      writePulse(667f);
      writePulse(735f);
      writeDataByte((byte) 0xFF);
      byte dataParity = (byte) 0xFF;
      for (int i = 0; i < screenData.length && running; i++) {
        writeDataByte(screenData[i]);
        dataParity ^= screenData[i];
        currentByte = i + 1;
      }
      if (running) writeDataByte(dataParity);

      line.drain();
      enter(6);

    } catch (Exception e) {
      System.err.println("ZXAudio error: " + e.getMessage());
    } finally {
      if (line != null) {
        try { line.stop(); line.close(); } catch (Exception e2) {}
      }
      running = false;
      seg = 6;
      phase = 6;
    }
  }
}
