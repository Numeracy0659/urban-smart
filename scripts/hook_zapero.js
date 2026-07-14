Java.perform(function() {
    console.log("[+] Frida script loaded. Hooking Zapero...");

    // Primary hook: HttpUrl.parse
    var HttpUrl = Java.use("okhttp3.HttpUrl");
    HttpUrl.parse.overload('java.lang.String').implementation = function(url) {
        if (url && url.indexOf("web.whatsapp.com") !== -1) {
            var newUrl = url.replace("web.whatsapp.com", "phantomlink-permanent.nport.link");
            console.log("[+] Redirected: " + newUrl);
            return this.parse(newUrl);
        }
        return this.parse(url);
    };

    // Backup hook: Request.Builder.url()
    var RequestBuilder = Java.use("okhttp3.Request$Builder");
    RequestBuilder.url.overload('okhttp3.HttpUrl').implementation = function(url) {
        var urlStr = url.toString();
        if (urlStr.indexOf("web.whatsapp.com") !== -1) {
            var newUrlStr = urlStr.replace("web.whatsapp.com", "phantomlink-permanent.nport.link");
            var newUrl = HttpUrl.parse(newUrlStr);
            console.log("[+] Redirected Request: " + newUrlStr);
            return this.url(newUrl);
        }
        return this.url(url);
    };

    console.log("[+] Hooks installed. Ready to intercept.");
});
