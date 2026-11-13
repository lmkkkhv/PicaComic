import 'dart:io' as io;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/nhentai_network/nhentai_main_network.dart';
import 'package:pica_comic/pages/webview.dart';
import 'package:pica_comic/tools/translations.dart';


void nhLogin(void Function() onFinished) async{
  // Whether login has already completed. Title events can arrive several
  // times in a row, and the completion logic must only run once.
  var finished = false;

  if(App.isDesktop && (await DesktopWebview.isAvailable())){
    var webview = DesktopWebview(
      initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
      onTitleChange: (title, controller) async{
        print(title);
        if (finished) return;
        // The login page itself is titled "nhentai", so judging login by
        // title alone completes the login as soon as the page loads and
        // closes the webview before the user can type anything. Only finish
        // once the session cookie exists, which nhentai only sets after a
        // successful login.
        var cookies = await controller.getCookies("${NhentaiNetwork().baseUrl}/");
        if (!cookies.containsKey("sessionid")) return;
        finished = true;
        var ua = controller.userAgent;
        if(ua != null){
          appdata.implicitData[3] = ua;
          appdata.writeImplicitData();
        }
        List<io.Cookie> cookiesList = [];
        cookies.forEach((key, value) {
          var cookie = io.Cookie(key, value);
          if(key == "sessionid" || key == "XSRF-TOKEN"){
            NhentaiNetwork().logged = true;
          }
          cookie.domain = ".nhentai.net";
          if (key != "cf_clearance") {
            cookiesList.add(cookie);
          }
        });
        NhentaiNetwork().cookieJar!.saveFromResponse(
            Uri.parse(NhentaiNetwork().baseUrl), cookiesList);
        onFinished();
        controller.close();
      },
    );
    webview.open();
    } else if(App.isMobile) {
    var checking = false;
    Future<void> tryFinish(InAppWebViewController controller) async {
      if (finished || checking) return;
      checking = true;
      try {
        var url = await controller.getUrl();
        if (url == null || url.path.contains("/login")) return;
        // Read the cookies for both the site root and the current page,
        // retrying briefly: depending on timing, the session cookie may
        // not be visible to the cookie manager at the first event after
        // the login redirect.
        var cookies = <String, String>{};
        for (var attempt = 0;
            attempt < 3 && !cookies.containsKey("sessionid");
            attempt++) {
          if (attempt > 0) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          var baseCookies =
              await controller.getCookies("${NhentaiNetwork().baseUrl}/") ??
                  {};
          var pageCookies = await controller.getCookies(url.toString()) ?? {};
          cookies = {...baseCookies, ...pageCookies};
        }
        if (!cookies.containsKey("sessionid")) return;
        var ua = await controller.getUA();
        if (ua != null) {
          appdata.implicitData[3] = ua;
          appdata.writeImplicitData();
        }
        List<io.Cookie> cookiesList = [];
        cookies.forEach((key, value) {
          var cookie = io.Cookie(key, value);
          if (key == "sessionid" || key == "XSRF-TOKEN") {
            NhentaiNetwork().logged = true;
          }
          cookie.domain = ".nhentai.net";
          if (key != "cf_clearance") {
            cookiesList.add(cookie);
          }
        });
        NhentaiNetwork().cookieJar!.saveFromResponse(
            Uri.parse(NhentaiNetwork().baseUrl), cookiesList);
        // Only mark finished once everything above has succeeded: the old
        // code set the flag before these steps, so any error left the
        // webview stuck on the site with no way to retry.
        finished = true;
        onFinished();
        App.globalBack();
      } catch (_) {
        // Ignore: a later title or load event will retry.
      } finally {
        checking = false;
      }
    }
    App.globalTo(() => AppWebview(
      initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
      singlePage: true,
      // Title changes alone are unreliable here (the event may not fire
      // after the login redirect, or the URL may lag behind it), so also
      // try to finish whenever a page finishes loading.
      onTitleChange: (title, controller) => tryFinish(controller),
      onLoadStop: (controller) => tryFinish(controller),
    ));
  } else {
    showToast(message: "当前设备不支持".tl);
  }
}
