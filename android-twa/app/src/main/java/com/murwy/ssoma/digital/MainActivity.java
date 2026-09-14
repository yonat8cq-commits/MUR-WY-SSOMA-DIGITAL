package com.murwy.ssoma.digital;

import android.Manifest;
import android.app.Activity;
import android.app.DownloadManager;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.provider.Settings;
import android.util.Base64;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.SslErrorHandler;
import android.webkit.URLUtil;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.net.http.SslError;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.Locale;

public final class MainActivity extends Activity {
    private static final String APP_URL =
            "https://mur-wy-ssoma-digital.roboasaltante.chatgpt.site/";
    private static final String APP_HOST =
            "mur-wy-ssoma-digital.roboasaltante.chatgpt.site";
    private static final int FILE_CHOOSER_REQUEST = 4101;
    private static final int STORAGE_PERMISSION_REQUEST = 4102;

    private WebView webView;
    private ValueCallback<Uri[]> fileChooserCallback;
    private boolean showingConnectionError;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().setStatusBarColor(Color.rgb(36, 39, 44));
        getWindow().setNavigationBarColor(Color.rgb(36, 39, 44));

        webView = new WebView(this);
        webView.setBackgroundColor(Color.rgb(244, 245, 247));
        webView.setOverScrollMode(View.OVER_SCROLL_NEVER);
        setContentView(webView);

        configureWebView();
        if (savedInstanceState == null) {
            webView.loadUrl(APP_URL);
        } else {
            webView.restoreState(savedInstanceState);
        }
    }

    private void configureWebView() {
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowContentAccess(true);
        settings.setAllowFileAccess(false);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        settings.setMediaPlaybackRequiresUserGesture(true);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setSupportZoom(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setUserAgentString(settings.getUserAgentString() + " MURWYSSOMA/2.0.1");

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            settings.setSafeBrowsingEnabled(true);
        }

        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptCookie(true);
        cookieManager.setAcceptThirdPartyCookies(webView, false);

        webView.addJavascriptInterface(new AndroidDownloads(), "AndroidDownloads");
        webView.setWebViewClient(new CentralWebViewClient());
        webView.setWebChromeClient(new CentralWebChromeClient());
        webView.setDownloadListener((url, userAgent, contentDisposition, mimeType, contentLength) -> {
            String filename = safeFilename(URLUtil.guessFileName(url, contentDisposition, mimeType));
            if (url != null && url.startsWith("blob:")) {
                downloadBlob(url, mimeType, filename);
            } else {
                downloadHttp(url, userAgent, contentDisposition, mimeType);
            }
        });
    }

    private final class CentralWebViewClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            return openExternalIfNeeded(request.getUrl());
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            return openExternalIfNeeded(Uri.parse(url));
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            showingConnectionError = false;
            super.onPageFinished(view, url);
        }

        @Override
        public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
            handler.cancel();
            showConnectionError("No se pudo validar la conexión segura.");
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && request.isForMainFrame()) {
                showConnectionError("No hay conexión con el sistema central.");
            }
        }

        @Override
        public void onReceivedHttpError(WebView view, WebResourceRequest request, WebResourceResponse response) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                    && request.isForMainFrame()
                    && response.getStatusCode() >= 500) {
                showConnectionError("El servidor central no respondió correctamente.");
            }
        }
    }

    private final class CentralWebChromeClient extends WebChromeClient {
        @Override
        public boolean onShowFileChooser(
                WebView view,
                ValueCallback<Uri[]> callback,
                FileChooserParams params
        ) {
            if (fileChooserCallback != null) {
                fileChooserCallback.onReceiveValue(null);
            }
            fileChooserCallback = callback;
            try {
                Intent intent = params.createIntent();
                intent.setAction(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                startActivityForResult(intent, FILE_CHOOSER_REQUEST);
                return true;
            } catch (Exception error) {
                fileChooserCallback = null;
                Toast.makeText(MainActivity.this, "No se pudo abrir el selector de archivos.", Toast.LENGTH_LONG).show();
                return false;
            }
        }
    }

    private boolean openExternalIfNeeded(Uri uri) {
        String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
        String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
        if (("https".equals(scheme) || "http".equals(scheme)) && APP_HOST.equals(host)) {
            return false;
        }
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
        } catch (Exception error) {
            Toast.makeText(this, "No existe una aplicación para abrir este enlace.", Toast.LENGTH_LONG).show();
        }
        return true;
    }

    private void showConnectionError(String message) {
        if (showingConnectionError || isFinishing()) return;
        showingConnectionError = true;
        String html = "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
                + "<style>body{margin:0;background:#f4f5f7;color:#24272c;font-family:sans-serif;display:grid;"
                + "place-items:center;min-height:100vh}.card{width:min(86%,420px);background:white;border-radius:22px;"
                + "padding:30px;box-shadow:0 18px 45px #0002;text-align:center}h1{font-size:24px}p{line-height:1.5}"
                + "button{border:0;border-radius:14px;background:#f2b91f;color:#24272c;padding:14px 24px;"
                + "font-size:17px;font-weight:700}</style></head><body><div class='card'><h1>MUR WY SSOMA DIGITAL</h1>"
                + "<p>" + message + "</p><button onclick=\"location.href='" + APP_URL + "'\">REINTENTAR</button>"
                + "</div></body></html>";
        webView.loadDataWithBaseURL(APP_URL, html, "text/html", "UTF-8", null);
    }

    private void downloadBlob(String url, String mimeType, String filename) {
        String script = "(async()=>{try{const r=await fetch(" + JSONObject.quote(url)
                + ");const b=await r.blob();const fr=new FileReader();fr.onloadend=()=>AndroidDownloads.save("
                + "fr.result," + JSONObject.quote(mimeType == null ? "application/pdf" : mimeType) + ","
                + JSONObject.quote(filename) + ");fr.readAsDataURL(b)}catch(e){AndroidDownloads.failed()}})();";
        webView.evaluateJavascript(script, null);
    }

    private void downloadHttp(String url, String userAgent, String contentDisposition, String mimeType) {
        if (url == null || url.isEmpty()) return;
        if (!canWriteLegacyDownloads()) return;
        try {
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
            request.setMimeType(mimeType);
            request.addRequestHeader("User-Agent", userAgent);
            String cookies = CookieManager.getInstance().getCookie(url);
            if (cookies != null) request.addRequestHeader("Cookie", cookies);
            String filename = safeFilename(URLUtil.guessFileName(url, contentDisposition, mimeType));
            request.setTitle(filename);
            request.setDescription("Registro SSOMA");
            request.setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename);
            DownloadManager manager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
            manager.enqueue(request);
            Toast.makeText(this, "Descarga iniciada.", Toast.LENGTH_SHORT).show();
        } catch (Exception error) {
            Toast.makeText(this, "No se pudo descargar el archivo.", Toast.LENGTH_LONG).show();
        }
    }

    private boolean canWriteLegacyDownloads() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) return true;
        if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED) return true;
        requestPermissions(
                new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
                STORAGE_PERMISSION_REQUEST);
        Toast.makeText(this, "Autoriza el almacenamiento y vuelve a descargar.", Toast.LENGTH_LONG).show();
        return false;
    }

    private String safeFilename(String name) {
        String cleaned = name == null ? "" : name.replaceAll("[\\\\/:*?\"<>|]", "_").trim();
        if (cleaned.isEmpty() || "downloadfile".equalsIgnoreCase(cleaned)) {
            return "Registro-SSOMA.pdf";
        }
        return cleaned.length() > 120 ? cleaned.substring(0, 120) : cleaned;
    }

    private final class AndroidDownloads {
        @JavascriptInterface
        public void save(String dataUrl, String mimeType, String filename) {
            new Thread(() -> {
                try {
                    int comma = dataUrl.indexOf(',');
                    if (comma < 0) throw new IllegalArgumentException("Formato no válido");
                    byte[] bytes = Base64.decode(dataUrl.substring(comma + 1), Base64.DEFAULT);
                    saveBytes(bytes, mimeType, safeFilename(filename));
                    runOnUiThread(() -> Toast.makeText(
                            MainActivity.this,
                            "Archivo guardado en Descargas.",
                            Toast.LENGTH_LONG).show());
                } catch (Exception error) {
                    failed();
                }
            }).start();
        }

        @JavascriptInterface
        public void failed() {
            runOnUiThread(() -> Toast.makeText(
                    MainActivity.this,
                    "No se pudo guardar el archivo.",
                    Toast.LENGTH_LONG).show());
        }
    }

    private void saveBytes(byte[] bytes, String mimeType, String filename) throws Exception {
        OutputStream output;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Downloads.DISPLAY_NAME, filename);
            values.put(MediaStore.Downloads.MIME_TYPE,
                    mimeType == null || mimeType.isEmpty() ? "application/octet-stream" : mimeType);
            values.put(MediaStore.Downloads.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/MUR WY SSOMA");
            values.put(MediaStore.Downloads.IS_PENDING, 1);
            Uri uri = getContentResolver().insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            if (uri == null) throw new IllegalStateException("No se creó el archivo");
            output = getContentResolver().openOutputStream(uri);
            if (output == null) throw new IllegalStateException("No se abrió el archivo");
            try (OutputStream stream = output) {
                stream.write(bytes);
            }
            values.clear();
            values.put(MediaStore.Downloads.IS_PENDING, 0);
            getContentResolver().update(uri, values, null, null);
        } else {
            if (!canWriteLegacyDownloads()) throw new SecurityException("Permiso pendiente");
            File directory = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS);
            if (!directory.exists() && !directory.mkdirs()) {
                throw new IllegalStateException("No se creó Descargas");
            }
            try (OutputStream stream = new FileOutputStream(new File(directory, filename))) {
                stream.write(bytes);
            }
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == FILE_CHOOSER_REQUEST && fileChooserCallback != null) {
            Uri[] result = WebChromeClient.FileChooserParams.parseResult(resultCode, data);
            fileChooserCallback.onReceiveValue(result);
            fileChooserCallback = null;
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        webView.saveState(outState);
        super.onSaveInstanceState(outState);
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.removeJavascriptInterface("AndroidDownloads");
            webView.stopLoading();
            webView.destroy();
        }
        super.onDestroy();
    }
}
