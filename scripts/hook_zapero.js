Java.perform(function() {
    console.log("[+] Frida loaded. Hooking Zapero...");

    // Hook java.net.URL constructor (most reliable)
    var URL = Java.use("java.net.URL");
    URL.$init.overload('java.lang.String').implementation = function(url) {
        if (url && url.indexOf("web.whatsapp.com") !== -1) {
            var newUrl = url.replace("web.whatsapp.com", "your-server.nport.link");
            console.log("[+] Redirected URL: " + newUrl);
            return this.$init(newUrl);
        }
        return this.$init(url);
    };

    // Hook OkHttp (Baileys uses this)
    var HttpUrl = Java.use("okhttp3.HttpUrl");
    HttpUrl.parse.overload('java.lang.String').implementation = function(url) {
        if (url && url.indexOf("web.whatsapp.com") !== -1) {
            var newUrl = url.replace("web.whatsapp.com", "your-server.nport.link");
            console.log("[+] Redirected OkHttp: " + newUrl);
            return this.parse(newUrl);
        }
        return this.parse(url);
    };

    // Hook WebSocket connections
    var WebSocket = Java.use("okhttp3.WebSocket");
    WebSocket.send.overload('java.lang.String').implementation = function(message) {
        console.log("[+] WebSocket message: " + message);
        return this.send(message);
    };

    console.log("[+] Hooks installed. Ready to intercept.");
});
