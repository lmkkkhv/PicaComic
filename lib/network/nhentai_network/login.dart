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
    App.globalTo(() => AppWebview(
      initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
      singlePage: true,
      onTitleChange: (title, controller) async{
        if (finished) return;
        // The login page is titled "nhentai", so a title-only check fires
        // as soon as it loads and pops the webview. Wait until the webview
        // has left the login page (nhentai redirects to `next` after a
        // successful login) and the session cookie is present.
        var url = await controller.getUrl();
        if (url == null || url.path.contains("/login")) return;
        var cookies = await controller.getCookies("${NhentaiNetwork().baseUrl}/") ?? {};
        if (!cookies.containsKey("sessionid")) return;
        finished = true;
        var ua = await controller.getUA();
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
        App.globalBack();
      },
    ));
  } else {
    showToast(message: "当前设备不支持".tl);
  }
}
