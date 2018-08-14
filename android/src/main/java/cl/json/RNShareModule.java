package cl.json;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.URL;
import java.net.URLConnection;
import java.io.InputStream;
import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.util.List;
import java.lang.Exception;
import java.util.UUID;

import android.util.Log;
import android.net.Uri;
import android.webkit.MimeTypeMap;
import android.content.Intent;
import android.content.ActivityNotFoundException;
import android.webkit.URLUtil;
import android.app.Activity;
import android.os.Environment;
import android.os.StrictMode;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.Callback;

public class RNShareModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;

  public RNShareModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
  }

  @Override
  public String getName() {
    return "RNShare";
  }

  @ReactMethod
  public void open(ReadableMap options, Callback callback) {

    try {
      StrictMode.VmPolicy.Builder builder = new StrictMode.VmPolicy.Builder();
      StrictMode.setVmPolicy(builder.build());

      Intent shareIntent = createShareIntent(options);
      Intent intentChooser = createIntentChooser(options, shareIntent);
      this.reactContext.startActivity(intentChooser);

      // Create dummy result object to keep consistence with IOS
      // Unfortunately ANDROID doesn't not provide intent result
      WritableMap result = Arguments.createMap();
      result.putNull("activityType");
      result.putNull("completed");

      callback.invoke(null, result);
    } catch (Exception ex) {
      callback.invoke(ex.getMessage());
    }
  }

  /**
   * Creates an {@link Intent} to be shared from a set of {@link ReadableMap} options
   * @param {@link ReadableMap} options
   * @return {@link Intent} intent
   */
  private Intent createShareIntent(ReadableMap options) {
    Activity currentActivity = getCurrentActivity();
    Intent intent = new Intent(android.content.Intent.ACTION_SEND);

    if (hasValidKey("share_text", options)) {
      intent.setType("text/plain");
      intent.putExtra(Intent.EXTRA_SUBJECT, options.getString("share_text"));
    }

    if (hasValidKey("share_URL", options)) {
      intent.setType("text/plain");
      intent.putExtra(Intent.EXTRA_TEXT, options.getString("share_URL"));
    }

    if (hasValidKey("share_file", options)) {
      String fileUrl = options.getString("share_file");
      boolean isLocal = URLUtil.isFileUrl(fileUrl);
      File file;
      if (isLocal) {
        file = new File(fileUrl);
      } else {
        // Download and save file
        String tempFileUrl = downloadFromUrl(fileUrl);
        file = new File(tempFileUrl != null ? tempFileUrl : fileUrl);
        // Clean up file
        try {
          file.deleteOnExit();
        } catch(Exception ex) {
          // Do nothing
        }
      }

      // Add the Uri to the Intent.
      Uri uri = Uri.fromFile(file);
      String extension = MimeTypeMap.getFileExtensionFromUrl(file.getName());
      String type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
      intent.setType(type);
      intent.putExtra(Intent.EXTRA_STREAM, uri);
    }

    return intent;
  }

  /**
   * Creates an {@link Intent} representing an intent chooser
   * @param {@link ReadableMap} options
   * @param {@link Intent} intent to share
   * @return {@link Intent} intent
   */
  private Intent createIntentChooser(ReadableMap options, Intent intent) {
    String title = "Share";
    if (hasValidKey("title", options)) {
      title = options.getString("title");
    }

    Intent chooser = Intent.createChooser(intent, title);
    chooser.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

    return chooser;
  }

  /**
   * Checks if a given key is valid
   * @param @{link String} key
   * @param @{link ReadableMap} options
   * @return boolean representing whether the key exists and has a value
   */
  private boolean hasValidKey(String key, ReadableMap options) {
    return options.hasKey(key) && !options.isNull(key);
  }

  /**
   * Download a file
   */
   public String downloadFromUrl(String imageURL) {
       try {
          // Create file
          String fileName = imageURL.substring(imageURL.lastIndexOf("/"));
          String extension = MimeTypeMap.getFileExtensionFromUrl(fileName);
          String name = UUID.randomUUID().toString();
          File file = new File(this.getReactApplicationContext().getExternalFilesDir(null), name + "." + extension);

          // Download and write to file
          URL url = new URL(imageURL);
          // Open a connection to that URL.
          URLConnection ucon = url.openConnection();
          // Define InputStreams to read from the URLConnection.
          InputStream is = ucon.getInputStream();
          BufferedInputStream bis = new BufferedInputStream(is);
          // Read bytes to the Buffer until there is nothing more to read(-1).
          ByteArrayOutputStream buffer = new ByteArrayOutputStream();
          //Create an array of bytes
          byte[] data = new byte[50];
          int current = 0;
          while((current = bis.read(data,0,data.length)) != -1){
                buffer.write(data,0,current);
          }
          FileOutputStream fos = new FileOutputStream(file);
          fos.write(buffer.toByteArray());
          fos.flush();
          fos.close();

          return file.getAbsolutePath();
       } catch (IOException e) {
           Log.d("ImageDownload", "Error: " + e);
           return null;
       }
    }
}
