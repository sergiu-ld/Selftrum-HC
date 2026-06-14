import java.io.*;
import java.util.*;

/**
 * ConfigEmail — reads data/email_config.json
 * Handles sending caricature images via SMTP.
 *
 * To enable: edit data/email_config.json, set "enabled": true
 * For Gmail: use an App Password (not your regular password)
 */
public class ConfigEmail {

  public String smtpHost = "smtp.gmail.com";
  public int smtpPort = 587;
  public String smtpUser = "";
  public String smtpPassword = "";
  public String fromName = "Selftrum HC";
  public String fromEmail = "";
  public String subject = "Your Selftrum HC Caricature!";
  public String body = "Here is your retro 8-bit caricature.";
  public boolean useTLS = true;
  public boolean enabled = false;

  public ConfigEmail(String dataPath) {
    load(dataPath + File.separator + "email_config.json");
  }

  private void load(String path) {
    try {
      File f = new File(path);
      if (!f.exists()) {
        System.out.println("[Email] No config at " + path);
        return;
      }
      String json = readFile(path);
      smtpHost = jStr(json, "smtp_host", smtpHost);
      smtpPort = jInt(json, "smtp_port", smtpPort);
      smtpUser = jStr(json, "smtp_user", smtpUser);
      smtpPassword = jStr(json, "smtp_password", smtpPassword);
      fromName = jStr(json, "from_name", fromName);
      fromEmail = jStr(json, "from_email", fromEmail);
      subject = jStr(json, "subject", subject);
      body = jStr(json, "body", body);
      useTLS = jBool(json, "use_tls", useTLS);
      enabled = jBool(json, "enabled", enabled);
      System.out.println("[Email] Loaded. host=" + smtpHost + " enabled=" + enabled);
    } catch (Exception e) {
      System.out.println("[Email] Load error: " + e.getMessage());
    }
  }

  public boolean isReady() {
    return enabled && smtpUser.length() > 3 && smtpPassword.length() > 0;
  }

  public String getStatus() {
    if (!enabled) return "E-mail disabled. Edit data/email_config.json";
    if (smtpUser.length() < 3) return "SMTP user not set";
    if (smtpPassword.length() == 0) return "SMTP password not set";
    return "Ready: " + smtpHost + ":" + smtpPort;
  }

  // ─── Simple JSON helpers ───

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
