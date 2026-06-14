import java.io.*;
import java.net.*;

/**
 * ConfigNetwork — reads data/network_config.json
 * Handles network printer connection and proxy settings.
 *
 * Printer protocols supported:
 *   "raw"   — direct TCP/IP print (port 9100)
 *   "ipp"   — Internet Printing Protocol
 *   "local" — system default printer via Java PrintService
 *
 * To enable: edit data/network_config.json, set printer.enabled: true
 */
public class ConfigNetwork {

  // Printer
  public boolean printerEnabled = false;
  public String printerType = "network";
  public String printerName = "ZX-Printer";
  public String printerIP = "192.168.1.100";
  public int printerPort = 9100;
  public String printerProtocol = "raw";
  public String paperSize = "A4";
  public String orientation = "landscape";
  public int dpi = 300;
  public int copies = 1;
  public String colorMode = "color";
  public boolean fitToPage = true;

  // Network
  public boolean proxyEnabled = false;
  public String proxyHost = "";
  public int proxyPort = 8080;
  public int timeoutSeconds = 30;

  public ConfigNetwork(String dataPath) {
    load(dataPath + File.separator + "network_config.json");
  }

  private void load(String path) {
    try {
      File f = new File(path);
      if (!f.exists()) {
        System.out.println("[Network] No config at " + path);
        return;
      }
      String json = readFile(path);

      printerEnabled = jBool(json, "enabled", printerEnabled);
      printerType = jStr(json, "type", printerType);
      printerName = jStr(json, "name", printerName);
      printerIP = jStr(json, "ip", printerIP);
      printerPort = jInt(json, "port", printerPort);
      printerProtocol = jStr(json, "protocol", printerProtocol);
      paperSize = jStr(json, "paper_size", paperSize);
      orientation = jStr(json, "orientation", orientation);
      dpi = jInt(json, "dpi", dpi);
      copies = jInt(json, "copies", copies);
      colorMode = jStr(json, "color_mode", colorMode);
      fitToPage = jBool(json, "fit_to_page", fitToPage);

      proxyEnabled = jBool(json, "proxy_enabled", proxyEnabled);
      proxyHost = jStr(json, "proxy_host", proxyHost);
      proxyPort = jInt(json, "proxy_port", proxyPort);
      timeoutSeconds = jInt(json, "timeout_seconds", timeoutSeconds);

      System.out.println("[Network] Loaded. printer=" + printerName + " enabled=" + printerEnabled);

      if (proxyEnabled && proxyHost.length() > 0) {
        System.setProperty("http.proxyHost", proxyHost);
        System.setProperty("http.proxyPort", String.valueOf(proxyPort));
        System.setProperty("https.proxyHost", proxyHost);
        System.setProperty("https.proxyPort", String.valueOf(proxyPort));
        System.out.println("[Network] Proxy set: " + proxyHost + ":" + proxyPort);
      }
    } catch (Exception e) {
      System.out.println("[Network] Load error: " + e.getMessage());
    }
  }

  public boolean isPrinterReady() {
    return printerEnabled && printerIP.length() > 0;
  }

  public String getPrinterStatus() {
    if (!printerEnabled) return "Printer disabled. Edit data/network_config.json";
    return printerName + " @ " + printerIP + ":" + printerPort + " (" + printerProtocol + ")";
  }

  /**
   * Send raw image data to network printer via TCP.
   * For raw protocol — sends PNG bytes directly.
   */
  public boolean sendToPrinter(byte[] imageData) {
    if (!isPrinterReady()) {
      System.out.println("[Network] Printer not configured");
      return false;
    }
    if (printerProtocol.equals("local")) {
      return printLocal(imageData);
    }
    try {
      System.out.println("[Network] Connecting to " + printerIP + ":" + printerPort);
      Socket sock = new Socket();
      sock.connect(new InetSocketAddress(printerIP, printerPort), timeoutSeconds * 1000);
      OutputStream out = sock.getOutputStream();
      out.write(imageData);
      out.flush();
      out.close();
      sock.close();
      System.out.println("[Network] Print job sent: " + imageData.length + " bytes");
      return true;
    } catch (Exception e) {
      System.out.println("[Network] Print error: " + e.getMessage());
      return false;
    }
  }

  private boolean printLocal(byte[] imageData) {
    try {
      // Use Java PrintService for local/system printers
      javax.print.PrintService[] services = javax.print.PrintServiceLookup.lookupPrintServices(null, null);
      if (services.length == 0) {
        System.out.println("[Network] No local printers found");
        return false;
      }
      javax.print.PrintService printer = services[0];
      for (javax.print.PrintService s : services) {
        if (s.getName().contains(printerName)) {
          printer = s;
          break;
        }
      }
      javax.print.Doc doc = new javax.print.SimpleDoc(
        new ByteArrayInputStream(imageData),
        javax.print.DocFlavor.INPUT_STREAM.PNG,
        null
      );
      javax.print.DocPrintJob job = printer.createPrintJob();
      job.print(doc, null);
      System.out.println("[Network] Local print sent to: " + printer.getName());
      return true;
    } catch (Exception e) {
      System.out.println("[Network] Local print error: " + e.getMessage());
      return false;
    }
  }

  // ─── JSON helpers ───

  private String readFile(String p) throws Exception {
    BufferedReader br = new BufferedReader(new FileReader(p));
    StringBuilder sb = new StringBuilder();
    String line;
    while ((line = br.readLine()) != null) sb.append(line);
    br.close();
    return sb.toString();
  }

  private String jStr(String json, String key, String def) {
    int i = json.indexOf("\"" + key + "\"");
    if (i < 0) return def;
    int c = json.indexOf(":", i);
    if (c < 0) return def;
    int q1 = json.indexOf("\"", c + 1);
    if (q1 < 0) return def;
    int q2 = json.indexOf("\"", q1 + 1);
    if (q2 < 0) return def;
    return json.substring(q1 + 1, q2);
  }

  private int jInt(String json, String key, int def) {
    int i = json.indexOf("\"" + key + "\"");
    if (i < 0) return def;
    int c = json.indexOf(":", i);
    if (c < 0) return def;
    StringBuilder n = new StringBuilder();
    for (int j = c + 1; j < json.length(); j++) {
      char ch = json.charAt(j);
      if (ch >= '0' && ch <= '9') n.append(ch);
      else if (n.length() > 0) break;
    }
    return n.length() > 0 ? Integer.parseInt(n.toString()) : def;
  }

  private boolean jBool(String json, String key, boolean def) {
    int i = json.indexOf("\"" + key + "\"");
    if (i < 0) return def;
    int c = json.indexOf(":", i);
    if (c < 0) return def;
    String r = json.substring(c + 1, Math.min(c + 20, json.length())).trim();
    if (r.startsWith("true")) return true;
    if (r.startsWith("false")) return false;
    return def;
  }
}
