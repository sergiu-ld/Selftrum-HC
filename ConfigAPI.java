import java.io.*;
import java.net.*;

/**
 * ConfigAPI — Google AI Studio (Gemini) integration.
 * Reads data/api_config.json
 *
 * Uses Gemini generateContent endpoint with inline image + text prompt.
 * Each on-screen style (NORMAL, BLACK & WHITE, 8 BIT) has its own prompt.
 * Returns transformed image or null (fallback to local).
 *
 * API: https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
 * Auth: x-goog-api-key header
 *
 * Get key from: https://aistudio.google.com/apikey
 */
public class ConfigAPI {

  public boolean enabled = true;
  public boolean fallbackToLocal = true;
  public String apiKey = "AIzaSyAFR-DA8AoiA5nwFFzQzQEm_4MD1B52eF4";
  public String model = "gemini-2.5-flash";
  public int timeout = 45;

  // One prompt per on-screen style (NORMAL / BLACK & WHITE / 8 BIT)
  public String normalPrompt = "Keep this photo natural and realistic with only light enhancement";
  public String bwPrompt = "Convert this photo into high contrast black and white";
  public String eightbitPrompt = "Transform this photo into vibrant retro 8-bit pixel art";

  public ConfigAPI(String dataPath) {
    load(dataPath + File.separator + "api_config.json");
  }

  private void load(String path) {
    try {
      File f = new File(path);
      if (!f.exists()) {
        System.out.println("[API] No config at " + path);
        return;
      }
      String json = readFile(path);
      enabled = jBool(json, "enabled", enabled);
      fallbackToLocal = jBool(json, "fallback_to_local", fallbackToLocal);
      apiKey = jStr(json, "api_key", apiKey);
      model = jStr(json, "model", model);
      timeout = jInt(json, "timeout_seconds", timeout);
      normalPrompt = jStr(json, "normal_prompt", normalPrompt);
      bwPrompt = jStr(json, "bw_prompt", bwPrompt);
      eightbitPrompt = jStr(json, "eightbit_prompt", eightbitPrompt);
      System.out.println("[API] Loaded. model=" + model + " enabled=" + enabled
        + " key=" + (apiKey.length() > 10 ? "set" : "missing"));
    } catch (Exception e) {
      System.out.println("[API] Load error: " + e.getMessage());
    }
  }

  public boolean isReady() {
    return enabled && apiKey.length() > 10 && !apiKey.startsWith("your-");
  }

  public String getStatus() {
    if (!enabled) return "API disabled";
    if (!isReady()) return "Gemini key not set";
    return "Gemini " + model + " ready";
  }

  /**
   * Process image for a specific style mode via Gemini.
   * @param imageBytes PNG image bytes
   * @param mode 0=B&W, 1=8 BIT, 3=NORMAL
   * @return processed image bytes (PNG), or null on failure
   */
  public byte[] processForMode(byte[] imageBytes, int mode) {
    if (!isReady()) {
      System.out.println("[API] Not configured, fallback to local");
      return null;
    }

    String prompt;
    if (mode == 0) prompt = bwPrompt;            // BLACK & WHITE
    else if (mode == 1) prompt = eightbitPrompt; // 8 BIT
    else prompt = normalPrompt;                  // NORMAL (mode 3)

    System.out.println("[API] Calling Gemini " + model + " mode=" + mode);
    return callGemini(imageBytes, prompt);
  }

  private byte[] callGemini(byte[] imageBytes, String prompt) {
    try {
      String b64 = java.util.Base64.getEncoder().encodeToString(imageBytes);

      String endpoint = "https://generativelanguage.googleapis.com/v1beta/models/"
        + model + ":generateContent";

      URL url = new URL(endpoint);
      HttpURLConnection conn = (HttpURLConnection) url.openConnection();
      conn.setRequestMethod("POST");
      conn.setRequestProperty("x-goog-api-key", apiKey);
      conn.setRequestProperty("Content-Type", "application/json");
      conn.setConnectTimeout(timeout * 1000);
      conn.setReadTimeout(timeout * 1000);
      conn.setDoOutput(true);

      // Build JSON payload with image + text prompt
      // Request image output via responseModalities
      StringBuilder payload = new StringBuilder();
      payload.append("{");
      payload.append("\"contents\":[{\"parts\":[");
      payload.append("{\"text\":\"").append(escapeJson(prompt)).append("\"},");
      payload.append("{\"inline_data\":{");
      payload.append("\"mime_type\":\"image/png\",");
      payload.append("\"data\":\"").append(b64).append("\"");
      payload.append("}}");
      payload.append("]}],");
      payload.append("\"generationConfig\":{");
      payload.append("\"responseModalities\":[\"IMAGE\",\"TEXT\"],");
      payload.append("\"imageConfig\":{\"aspectRatio\":\"4:3\"}");
      payload.append("}");
      payload.append("}");

      OutputStream os = conn.getOutputStream();
      os.write(payload.toString().getBytes("UTF-8"));
      os.flush();
      os.close();

      int code = conn.getResponseCode();
      System.out.println("[API] Response code: " + code);

      if (code == 200) {
        String response = readStream(conn.getInputStream());

        // Parse response — look for inline_data with base64 image
        // Response format: candidates[0].content.parts[].inline_data.data
        String imageData = extractImageData(response);
        if (imageData != null && imageData.length() > 100) {
          System.out.println("[API] Got image data: " + imageData.length() + " chars");
          return java.util.Base64.getDecoder().decode(imageData);
        }

        // If no image in response, log what we got
        System.out.println("[API] No image in response. First 300 chars: "
          + response.substring(0, Math.min(300, response.length())));
      } else {
        String err = "";
        try { err = readStream(conn.getErrorStream()); } catch (Exception ex) {}
        System.out.println("[API] Error " + code + ": " + err.substring(0, Math.min(500, err.length())));
      }
    } catch (Exception e) {
      System.out.println("[API] Call failed: " + e.getMessage());
      e.printStackTrace();
    }
    return null;
  }

  /**
   * Extract base64 image data from Gemini response JSON.
   * Looks for "inline_data" -> "data" field.
   */
  private String extractImageData(String json) {
    // Find inline_data block
    int inlineIdx = json.indexOf("\"inline_data\"");
    if (inlineIdx < 0) {
      // Try alternate format
      inlineIdx = json.indexOf("\"inlineData\"");
    }
    if (inlineIdx < 0) return null;

    // Find "data" field after inline_data
    int dataIdx = json.indexOf("\"data\"", inlineIdx);
    if (dataIdx < 0) return null;

    int colon = json.indexOf(":", dataIdx);
    if (colon < 0) return null;

    int q1 = json.indexOf("\"", colon + 1);
    if (q1 < 0) return null;

    // Find closing quote — base64 data can be very long
    int q2 = json.indexOf("\"", q1 + 1);
    if (q2 < 0) return null;

    return json.substring(q1 + 1, q2);
  }

  private String escapeJson(String s) {
    return s.replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t");
  }

  private String readStream(InputStream is) throws Exception {
    if (is == null) return "";
    BufferedReader br = new BufferedReader(new InputStreamReader(is));
    StringBuilder sb = new StringBuilder();
    String line;
    while ((line = br.readLine()) != null) sb.append(line);
    br.close();
    return sb.toString();
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
