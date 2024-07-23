library forceupdate;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';

import 'package:in_app_update/in_app_update.dart';
import 'package:launch_review/launch_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:store_launcher_nullsafe/store_launcher_nullsafe.dart';
import 'package:http/http.dart' as http;


class AppVersionStatus {
  bool? canUpdate;
  String? localVersion;
  String? storeVersion;
  String? appStoreUrl;
  AppVersionStatus({this.canUpdate, this.localVersion, this.storeVersion});
}

class CheckVersion {
  BuildContext context;
  String? androidId;
  String? iOSId;

  CheckVersion({this.androidId, this.iOSId, required this.context});

  Future<AppVersionStatus?> getVersionStatus({bool checkInBigger = true}) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    AppVersionStatus? versionStatus = AppVersionStatus(
      localVersion: packageInfo.version,
    );
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        final id = iOSId ?? packageInfo.packageName;
        versionStatus = await getiOSAtStoreVersion(id, versionStatus);
        if (versionStatus == null) return null;

        List<String> storeVersion = versionStatus.storeVersion?.split(".") ?? [];
        List<String> currentVersion = versionStatus.localVersion?.split(".") ?? [];
        if ((storeVersion.length) < (currentVersion.length )) {
          int missValues = (currentVersion.length) - (storeVersion.length );
          for (int i = 0; i < missValues; i++) {
            storeVersion.add(0.toString());
          }
        } else if ((storeVersion.length ) > (currentVersion.length )) {
          int missValues = (storeVersion.length ) - (currentVersion.length );
          for (int i = 0; i < missValues; i++) {
            currentVersion.add(0.toString());
          }
        }
        if((int.tryParse(storeVersion.first) ?? 0) > (int.tryParse(currentVersion.first) ?? 0)){
          versionStatus.canUpdate = true;
          return versionStatus;
        }else if(int.tryParse(storeVersion.first) == int.tryParse(currentVersion.first)){
          if((int.tryParse(storeVersion[1]) ?? 0) > (int.tryParse(currentVersion[1]) ?? 0)){
            versionStatus.canUpdate = true;
            return versionStatus;
          }else if(int.tryParse(storeVersion[1]) == int.tryParse(currentVersion[1])){
            if((int.tryParse(storeVersion[2]) ?? 0) > (int.tryParse(currentVersion[2]) ?? 0)){
              versionStatus.canUpdate = true;
              return versionStatus;
            }
          }
        }
        break;
      case TargetPlatform.android:
        final id = androidId ?? packageInfo.packageName;
        versionStatus = await getAndroidAtStoreVersion(id, versionStatus);
        break;
      default:
        debugPrint("This platform is not yet supported by this package.");
    }

    return versionStatus;
  }

  alertIfAvailable(String androidApplicationId, String iOSAppId) async {
    AppVersionStatus? versionStatus = await getVersionStatus();
    if (versionStatus?.canUpdate ?? false) {
      showUpdateDialog(androidApplicationId, iOSAppId,
          versionStatus: versionStatus!);
    }
  }

  Future<AppVersionStatus?> getiOSAtStoreVersion(
      String appId /**app id in apple store not app bundle id*/,
      AppVersionStatus versionStatus) async {
    try {
      final response =
          await http.get(Uri.parse('http://itunes.apple.com/lookup?bundleId=$appId'));
      if (response.statusCode == 200) {
        final jsonObj = jsonDecode(response.body);
        if(jsonObj != null && jsonObj['results'] != null && jsonObj['results'].length > 0){
          versionStatus.storeVersion = jsonObj['results']?.first['version'];
          versionStatus.appStoreUrl = jsonObj['results']?.first['trackViewUrl'];
          return versionStatus;
        }
      }else{
        debugPrint('The app with id: $appId is not found in app store');
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  Future<AppVersionStatus> getAndroidAtStoreVersion(
      String applicationId /**application id, generally stay in build.gradle*/,
      AppVersionStatus versionStatus) async {
    versionStatus.canUpdate = false;
    try {
      AppUpdateInfo update = await InAppUpdate.checkForUpdate();

      versionStatus.canUpdate = update.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      //debugPrint(e.toString());
    }
    return versionStatus;
  }

  showUpdateDialog(
    String androidApplicationId,
    String iOSAppId, {
    String? urlIos,
    AppVersionStatus? versionStatus,
    String message = "You can now update this app from store.",
    String titleText = 'Update Available',
    String dismissText = 'Later',
    String updateText = 'Update Now',
    VoidCallback? dismissFunc
    }) async {
    if(Platform.isAndroid){
      try {
        await InAppUpdate.performImmediateUpdate().catchError((e) {
          return AppUpdateResult.inAppUpdateFailed;
        });
      } catch (e) {
        debugPrint(e.toString());
      }
    }else{
      Text title = Text(titleText);
      final content = Text(message);
      Text dismiss = Text(dismissText);
      final dismissAction = dismissFunc != null ? dismissFunc : (){
        if (Platform.isIOS) {
          try {
            exit(0);
          } catch (e) {
            SystemNavigator.pop(); // for IOS, not true this, you can make comment this :)
          }
        } else {
          try {
            SystemNavigator.pop(); // sometimes it cant exit app
          } catch (e) {
            exit(0); // so i am giving crash to app ... sad :(
          }
        }
      };
      Text update = Text(updateText);
      final updateAction = () {
        Platform.isIOS ? StoreLauncher.openWithStore(iOSAppId).catchError((e) {
          debugPrint('---------ERROR> $e');
        }) :
        LaunchReview.launch(
          androidAppId: androidApplicationId,
          iOSAppId: iOSAppId,
        );
      };
      final platform = Theme.of(context).platform;
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return platform == TargetPlatform.iOS
              ? CupertinoAlertDialog(
            title: title,
            content: content,
            actions: <Widget>[
              CupertinoDialogAction(
                child: dismiss,
                onPressed: dismissAction,
              ),
              CupertinoDialogAction(
                child: update,
                onPressed: updateAction,
              ),
            ],
          ) : AlertDialog(
            title: title,
            content: content,
            actions: <Widget>[
              TextButton(
                child: dismiss,
                onPressed: dismissAction,
              ),
              TextButton(
                child: update,
                onPressed: updateAction,
              ),
            ],
          );
        },
      );
    }
  }
}



class OpenAppstore {
  static MethodChannel _channel = MethodChannel('flutter.moum.open_appstore');

  static Future<String> get platformVersion async {
    _channel = MethodChannel('flutter.moum.open_appstore');
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static void launch(String androidApplicationId, String iOSAppId) async {
    _channel = MethodChannel('flutter.moum.open_appstore');
    await _channel.invokeMethod('openappstore', {
      'android_id':
          androidApplicationId, // eexamplex : com.company.projectName,
      'ios_id': iOSAppId //example :id1234567890
    });
  }
}
