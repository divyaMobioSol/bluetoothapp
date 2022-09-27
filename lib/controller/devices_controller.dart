import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ble_messenger/controller/dates_controller.dart';
import 'package:flutter_ble_messenger/controller/login_controller.dart';
import 'package:flutter_ble_messenger/controller/messages_controller.dart';
import 'package:flutter_ble_messenger/model/device.dart';
import 'package:flutter_ble_messenger/view/widgets/common/loading_overlay.dart';
import 'package:flutter_ble_messenger/view/widgets/common/show_bottom_modal.dart';
import 'package:get/get.dart';
import 'package:nearby_connections/nearby_connections.dart';

class DevicesController extends GetxController {
  final BuildContext context;
  DevicesController(this.context);

  
  Strategy strategy = Strategy.P2P_CLUSTER;

  Nearby nearby = Get.put(Nearby());
  LoginController loginController = Get.put(LoginController());
  MessagesController messagesController = Get.put(MessagesController());
  DatesController datesController = Get.put(DatesController());

  /// Nickname of the logged in user
  var username = ''.obs;

  /// List of devices detected
  var devices = <Device>[].obs;

  /// The one who is requesting the info of a device
  var requestorId = '0'.obs;
  ConnectionInfo requestorDeviceInfo;

  /// The one who is being requested with an info
  var requesteeId = '0'.obs;
  ConnectionInfo requesteeDeviceInfo;

  @override
  void onInit() {
    datesController.onInit();
    username = RxString(loginController.username.value);
    advertiseDevice();
    searchNearbyDevices();
    super.onInit();
  }

  @override
  void onClose() {
    datesController.onClose();
    messagesController.connectedIdList.clear();
    nearby.stopAllEndpoints();
    nearby.stopDiscovery();
    nearby.stopAdvertising();
    super.onClose();
  }


  void searchNearbyDevices() async {
    try {
      await nearby.startDiscovery(
        username.value,
        strategy,
        onEndpointFound: (id, name, serviceId) {
        
          devices.removeWhere((device) => device.id == id);

       
          devices.add(Device(
              id: id, name: name, serviceId: serviceId, isConnected: false));
        },
        onEndpointLost: (id) {
          messagesController.onDisconnect(id);
          devices.removeWhere((device) => device.id == id);
          nearby.disconnectFromEndpoint(id);
        },
      );
    } catch (e) {
      print('there is an error searching for nearby devices:: $e');
    }
  }


  void advertiseDevice() async {
    try {
      await nearby.startAdvertising(
        username.value,
        strategy,
        onConnectionInitiated: (id, info) {

          devices.removeWhere((device) => device.id == id);
              requestorDeviceInfo = info;

    
          showBottomModal(context, requestorId.value.toString(), id, info);
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            messagesController.onConnect(id);

           
            devices.add(Device(
                id: id,
                name: requestorDeviceInfo.endpointName,
                serviceId: requestorDeviceInfo.endpointName,
                isConnected: true));
          } else if (status == Status.REJECTED) {
            devices.add(Device(
                id: id,
                name: requestorDeviceInfo.endpointName,
                serviceId: requestorDeviceInfo.endpointName,
                isConnected: false));
          }
        },
        onDisconnected: (endpointId) {
          messagesController.onDisconnect(endpointId);

         
          devices.removeWhere((device) => device.id == endpointId);
        },
      );
    } catch (e) {
      print('there is an error advertising the device:: $e');
    }
  }


  void requestDevice({
    BuildContext requestContext,
    String nickname,
    String deviceId,
    void onConnectionResult(String endpointId, Status status),
    void onDisconnected(String endpointId),
  }) async {
    final overlay = LoadingOverlay.of(requestContext);

    overlay.show();
    try {
      await nearby.requestConnection(
        nickname,
        deviceId,
        onConnectionInitiated: (id, info) {
          overlay.hide();

      
          requesteeDeviceInfo = info;

         
          showBottomModal(requestContext, deviceId, id, info);
        },
        onConnectionResult: onConnectionResult,
        onDisconnected: (value) {
          messagesController.onDisconnect(deviceId);
          onDisconnected(value);
        },
      );
    } catch (e) {
      print('there is an error requesting to connect to a device:: $e');
    }
  }


  void disconnectDevice({String id, void updateStateFunction()}) {
    try {
      messagesController.onDisconnect(id);
      nearby.disconnectFromEndpoint(id);
      updateStateFunction();
    } catch (e) {
      print('there is an error disconnecting the device:: $e');
    }
  }


  void rejectConnection({String id}) async {
    try {
      messagesController.onDisconnect(id);
      await nearby.rejectConnection(id);
    } catch (e) {
      print('there is an error in rejection:: $e');
    }
  }


  void acceptConnection({String id, ConnectionInfo info}) async {
    try {
      messagesController.onConnect(id);
      nearby.acceptConnection(
        id,
        onPayLoadRecieved: (endId, payload) {
          messagesController.onReceiveMessage(
            fromId: endId,
            fromInfo: info,
            payload: payload,
          );
        },
      );
    } catch (e) {
      print('there is an error accepting connection from another device:: $e');
    }
  }

  Future<bool> sendMessage(
      {String toId,
      String toUsername,
      String fromId,
      String fromUsername,
      String message}) async {
    try {
      if (messagesController.isDeviceConnected(toId)) {
        nearby.sendBytesPayload(toId, Uint8List.fromList(message.codeUnits));
        messagesController.onSendMessage(
            toId: toId ?? '',
            toUsername: toUsername ?? '',
            fromId: fromId ?? '',
            fromUsername: fromUsername ?? '',
            message: message);
        return true;
      }
      return false;
    } catch (e) {
      print('there is an error sending message to another device:: $e');
      return false;
    }
  }
}
