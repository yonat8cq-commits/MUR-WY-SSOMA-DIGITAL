package com.murwy.ssoma.digital;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.DownloadManager;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
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
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

public final class MainActivity extends Activity {
    private static final String APP_URL =
            "https://mur-wy-ssoma-digital.roboasaltante.chatgpt.site/";
    private static final String APP_HOST =
            "mur-wy-ssoma-digital.roboasaltante.chatgpt.site";
    private static final int FILE_CHOOSER_REQUEST = 4107;
    private static final int STORAGE_PERMISSION_REQUEST = 4108;
    private static final String PAGE_FIX_SCRIPT =
            "(function(){"
                    + "var rows=document.querySelectorAll('.login-view .check-row');"
                    + "rows.forEach(function(row){row.style.display='none';});"
                    + "var form=document.querySelector('.login-view form');"
                    + "if(form){form.style.touchAction='manipulation';}"
                    + "})();";

    private WebView webView;
    private ProgressBar progressBar;
    private LinearLayout errorView;
    private TextView errorMessage;
    private ValueCallback<Uri[]> fileChooserCallback;
    private PendingDownload pendingDownload;
    private boolean mainFrameFailed;

    @Override
    @SuppressLint("SetJavaScriptEnabled")
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().setStatusBarColor(Color.parseColor("#24272C"));
        getWindow().setNavigationBarColor(Color.parseColor("#24272C"));

        FrameLayout root = new FrameLayout(this);
        root.setFitsSystemWindows(true);
        root.setBackgroundColor(Color.WHITE);

        webView = new WebView(this);
        webView.setBackgroundColor(Color.WHITE);
        root.addView(webView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        progressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setMax(100);
        FrameLayout.LayoutParams progressParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(4));
        progressParams.gravity = Gravity.TOP;
        root.addView(progressBar, progressParams);

        errorView = buildErrorView();
        root.addView(errorView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        setContentView(root);
        configureWebView();

        if (savedInstanceState == null) {
            webView.loadUrl(APP_URL);
        } else {
            webView.restoreState(savedInstanceState);
        }
    }

    private LinearLayout buildErrorView() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER);
        panel.setPadding(dp(28), dp(28), dp(28), dp(28));
        panel.setBackgroundColor(Color.WHITE);
        panel.setVisibility(View.GONE);

        TextView title = new TextView(this);
        title.setText("MUR WY SSOMA DIGITAL");
        title.setTextColor(Color.parseColor("#24272C"));
        title.setTextSize(22);
        title.setGravity(Gravity.CENTER);
        title.setTypeface(title.getTypeface(), android.graphics.Typeface.BOLD);
        panel.addView(title, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        errorMessage = new TextView(this);
        errorMessage.setText("No se pudo abrir el panel central. Revisa tu conexión.");
        errorMessage.setTextColor(Color.parseColor("#5A606A"));
        errorMessage.setTextSize(16);
        errorMessage.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams messageParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
        messageParams.setMargins(0, dp(16), 0, dp(22));
        panel.addView(errorMessage, messageParams);

        Button retry = new Button(this);
        retry.setText("REINTENTAR");
        retry.setTextColor(Color.parseColor("#24272C"));
        retry.setOnClickListener(view -> {
            mainFrameFailed = false;
            errorView.setVisibility(View.GONE);
            webView.setVisibility(View.VISIBLE);
            webView.loadUrl(APP_URL);
        });
        panel.addView(retry, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        return panel;
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void configureWebView() {
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowContentAccess(true);
        settings.setAllowFileAccess(true);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setUserAgentString(settings.getUserAgentString() + " MURWYSSOMA/2.1.0");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            settings.setSafeBrowsingEnabled(true);
        }

        CookieManager cookies = CookieManager.getInstance();
        cookies.setAcceptCookie(true);
        cookies.setAcceptThirdPartyCookies(webView, true);
        WebView.setWebContentsDebuggingEnabled(false);

        webView.setWebViewClient(new SecureClient());
        webView.setWebChromeClient(new AppChromeClient());
        webView.setDownloadListener(new AppDownloadListener());
    }

    private final class SecureClient extends WebViewClient {
        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            mainFrameFailed = false;
            progressBar.setVisibility(View.VISIBLE);
            errorView.setVisibility(View.GONE);
            webView.setVisibility(View.VISIBLE);
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            progressBar.setVisibility(View.GONE);
            if (!mainFrameFailed) {
                errorView.setVisibility(View.GONE);
                webView.setVisibility(View.VISIBLE);
                view.evaluateJavascript(PAGE_FIX_SCRIPT, null);
            }
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            return openOutsideIfNeeded(request.getUrl());
        }

        @Override
        @SuppressWarnings("deprecation")
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            return openOutsideIfNeeded(Uri.parse(url));
        }

        @Override
        public void onReceivedError(
                WebView view, WebResourceRequest request, WebResourceError error) {
            if (request.isForMainFrame()) {
                showConnectionError("No se pudo abrir el panel central. Revisa internet y toca REINTENTAR.");
            }
        }

        @Override
        public void onReceivedHttpError(
                WebView view, WebResourceRequest request, WebResourceResponse errorResponse) {
            if (request.isForMainFrame() && errorResponse.getStatusCode() >= 500) {
                showConnectionError("El panel central no respondió. Espera un momento y toca REINTENTAR.");
            }
        }

        @Override
        public void onReceivedSslError(
                WebView view, SslErrorHandler handler, SslError error) {
            handler.cancel();
            showConnectionError("La conexión segura no pudo verificarse. No se cargó información.");
        }
    }

    private final class AppChromeClient extends WebChromeClient {
        @Override
        public void onProgressChanged(WebView view, int newProgress) {
            progressBar.setProgress(newProgress);
            progressBar.setVisibility(newProgress >= 100 ? View.GONE : View.VISIBLE);
        }

        @Override
        public boolean onShowFileChooser(
                WebView view,
                ValueCallback<Uri[]> callback,
                FileChooserParams fileChooserParams) {
            if (fileChooserCallback != null) {
                fileChooserCallback.onReceiveValue(null);
            }
            fileChooserCallback = callback;
            try {
                Intent chooser = fileChooserParams.createIntent();
                startActivityForResult(
                        Intent.createChooser(chooser, "Seleccionar archivo"),
                        FILE_CHOOSER_REQUEST);
                return true;
            } catch (ActivityNotFoundException exception) {
                fileChooserCallback = null;
                Toast.makeText(MainActivity.this, "No hay un selector de archivos disponible.", Toast.LENGTH_LONG).show();
                return false;
            }
        }
    }

    private final class AppDownloadListener implements DownloadListener {
        @Override
        public void onDownloadStart(
                String url,
                String userAgent,
                String contentDisposition,
                String mimeType,
                long contentLength) {
            PendingDownload download =
                    new PendingDownload(url, userAgent, contentDisposition, mimeType);
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P
                    && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    != PackageManager.PERMISSION_GRANTED) {
                pendingDownload = download;
                requestPermissions(
                        new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
                        STORAGE_PERMISSION_REQUEST);
                return;
            }
            enqueueDownload(download);
        }
    }

    private void enqueueDownload(PendingDownload download) {
        try {
            Uri uri = Uri.parse(download.url);
            String fileName = URLUtil.guessFileName(
                    download.url, download.contentDisposition, download.mimeType);
            DownloadManager.Request request = new DownloadManager.Request(uri);
            request.setTitle(fileName);
            request.setDescription("Descargando documento SSOMA");
            request.setMimeType(download.mimeType);
            request.setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setAllowedOverMetered(true);
            request.setAllowedOverRoaming(false);
            request.addRequestHeader("User-Agent", download.userAgent);
            String cookie = CookieManager.getInstance().getCookie(download.url);
            if (cookie != null && !cookie.isEmpty()) {
                request.addRequestHeader("Cookie", cookie);
            }
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);
            DownloadManager manager =
                    (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
            manager.enqueue(request);
            Toast.makeText(this, "Descarga iniciada.", Toast.LENGTH_SHORT).show();
        } catch (RuntimeException exception) {
            Toast.makeText(this, "No se pudo descargar el archivo.", Toast.LENGTH_LONG).show();
        }
    }

    private boolean openOutsideIfNeeded(Uri uri) {
        String scheme = uri.getScheme();
        String host = uri.getHost();
        if (scheme == null || "about".equalsIgnoreCase(scheme)
                || "data".equalsIgnoreCase(scheme) || "blob".equalsIgnoreCase(scheme)) {
            return false;
        }
        if (("https".equalsIgnoreCase(scheme) || "http".equalsIgnoreCase(scheme))
                && host != null && APP_HOST.equalsIgnoreCase(host)) {
            return false;
        }
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
        } catch (ActivityNotFoundException exception) {
            Toast.makeText(this, "No hay una aplicación para abrir este enlace.", Toast.LENGTH_LONG).show();
        }
        return true;
    }

    private void showConnectionError(String message) {
        mainFrameFailed = true;
        progressBar.setVisibility(View.GONE);
        webView.setVisibility(View.GONE);
        errorMessage.setText(message);
        errorView.setVisibility(View.VISIBLE);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
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
    public void onRequestPermissionsResult(
            int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == STORAGE_PERMISSION_REQUEST && pendingDownload != null) {
            PendingDownload download = pendingDownload;
            pendingDownload = null;
            if (grantResults.length > 0
                    && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                enqueueDownload(download);
            } else {
                Toast.makeText(this, "Permiso de descarga denegado.", Toast.LENGTH_LONG).show();
            }
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        webView.saveState(outState);
        super.onSaveInstanceState(outState);
    }

    @Override
    protected void onPause() {
        webView.onPause();
        CookieManager.getInstance().flush();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        webView.onResume();
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onDestroy() {
        if (fileChooserCallback != null) {
            fileChooserCallback.onReceiveValue(null);
            fileChooserCallback = null;
        }
        webView.stopLoading();
        webView.setWebChromeClient(null);
        webView.setWebViewClient(null);
        webView.destroy();
        super.onDestroy();
    }

    private static final class PendingDownload {
        final String url;
        final String userAgent;
        final String contentDisposition;
        final String mimeType;

        PendingDownload(
                String url, String userAgent, String contentDisposition, String mimeType) {
            this.url = url;
            this.userAgent = userAgent;
            this.contentDisposition = contentDisposition;
            this.mimeType = mimeType;
        }
    }
}
