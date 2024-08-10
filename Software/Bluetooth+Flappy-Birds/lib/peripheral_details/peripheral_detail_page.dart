// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:async';
// import 'dart:nativewrappers/_internal/vm/lib/core_patch.dart';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:universal_ble/universal_ble.dart';
import '/data/capabilities.dart';
import '/peripheral_details/widgets/result_widget.dart';
import '/peripheral_details/widgets/services_list_widget.dart';
import '/widgets/platform_button.dart';
import '/widgets/responsive_buttons_grid.dart';
import '/widgets/responsive_view.dart';

import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import '/game/flappy_bird_game.dart';
import '/screens/main_menu_screen.dart';
import '/screens/game_over_screen.dart';

class PeripheralDetailPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const PeripheralDetailPage(this.deviceId, this.deviceName, {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PeripheralDetailPageState();
  }
}

class _PeripheralDetailPageState extends State<PeripheralDetailPage>{
  final game = FlappyBirdGame();

  bool isConnected = false;
  GlobalKey<FormState> valueFormKey = GlobalKey<FormState>();
  List<BleService> discoveredServices = [];
  String _log = '';
  final binaryCode = TextEditingController();

  double position_y = 0.0;

  ({
    BleService service,
    BleCharacteristic characteristic
  })? selectedCharacteristic;

  @override
  void initState() {
    super.initState();
    UniversalBle.onConnectionChange = _handleConnectionChange;
    UniversalBle.onValueChange = _handleValueChange;
    UniversalBle.onPairingStateChange = _handlePairingStateChange;
  }

  @override
  void dispose() {
    super.dispose();
    UniversalBle.onConnectionChange = null;
    UniversalBle.onValueChange = null;
    // Disconnect when leaving the page
    if (isConnected) UniversalBle.disconnect(widget.deviceId);
  }

  void _addLog(String type, dynamic data) {
    setState(() {
      _log = '$type: ${data.toString()}';
    });
  }

  void _handleConnectionChange(String deviceId, bool isConnected) {
    print('_handleConnectionChange $deviceId, $isConnected');
    setState(() {
      if (deviceId == widget.deviceId) {
        this.isConnected = isConnected;
      }
    });
    _addLog('Connection', isConnected ? "Connected" : "Disconnected");
    // Auto Discover Services
    if (this.isConnected) {
      _discoverServices();
    }
  }

  bool isNumeric(String? s) {
    if (s == null) {
      return false;
    }
    return int.tryParse(s) != null;
  }


  void _handleValueChange(
      String deviceId, String characteristicId, Uint8List value) {
    String s = String.fromCharCodes(value);
    String data = '$s\nraw :  ${value.toString()}';
    // print('_handleValueChange $deviceId, $characteristicId, $s');
    // _addLog("Value", data);
    String str_value = value.toString();
    print(str_value);

    int? signal = int.tryParse(str_value.substring(1, str_value.length - 1));
    if(signal != null) {
      print("$signal is number");
      game.bird.fly(signal / 2);
    } else {
      print("cannot convert");
    }

  }

  void _handlePairingStateChange(
      String deviceId, bool isPaired, String? error) {
    print('OnPairStateChange $deviceId, $isPaired');
    if (error != null && error.isNotEmpty) {
      _addLog("PairStateChangeError", "(Paired: $isPaired): $error ");
    } else {
      _addLog("PairStateChange", isPaired);
    }
  }

  Future<void> _discoverServices() async {
    try {
      var services = await UniversalBle.discoverServices(widget.deviceId);
      print('${services.length} services discovered');
      discoveredServices.clear();
      setState(() {
        discoveredServices = services;
      });

      if (kIsWeb) {
        _addLog(
          "DiscoverServices",
          '${services.length} services discovered,\nNote: Only services added in ScanFilter or WebConfig will be discovered',
        );
      }
      selectedCharacteristic = (
        service: discoveredServices.first, 
        characteristic: discoveredServices.first.characteristics.first,
      ) as ({BleCharacteristic characteristic, BleService service})?;

    } catch (e) {
      _addLog(
        "DiscoverServicesError",
        '$e\nNote: Only services added in ScanFilter or WebConfig will be discovered',
      );
    }
  }

  Future<void> _readValue() async {
    if (selectedCharacteristic == null) return;
    try {
      Uint8List value = await UniversalBle.readValue(
        widget.deviceId,
        selectedCharacteristic!.service.uuid,
        selectedCharacteristic!.characteristic.uuid,
      );
      String s = String.fromCharCodes(value);
      String data = '$s\nraw :  ${value.toString()}';
      _addLog('Read', data);
    } catch (e) {
      _addLog('ReadError', e);
    }
  }

  Future<void> _writeValue() async {
    if (selectedCharacteristic == null ||
        !valueFormKey.currentState!.validate() ||
        binaryCode.text.isEmpty) {
      return;
    }

    Uint8List value;
    try {
      value = Uint8List.fromList(hex.decode(binaryCode.text));
    } catch (e) {
      _addLog('WriteError', "Error parsing hex $e");
      return;
    }

    try {
      await UniversalBle.writeValue(
        widget.deviceId,
        selectedCharacteristic!.service.uuid,
        selectedCharacteristic!.characteristic.uuid,
        value,
        _hasSelectedCharacteristicProperty(
                [CharacteristicProperty.writeWithoutResponse])
            ? BleOutputProperty.withoutResponse
            : BleOutputProperty.withResponse,
      );
      _addLog('Write', value);
    } catch (e) {
      print(e);
      _addLog('WriteError', e);
    }
  }

  Future<void> _setBleInputProperty(BleInputProperty inputProperty) async {
    if (selectedCharacteristic == null) return;
    try {
      if (inputProperty != BleInputProperty.disabled) {
        List<CharacteristicProperty> properties =
            selectedCharacteristic!.characteristic.properties;
        if (properties.contains(CharacteristicProperty.notify)) {
          inputProperty = BleInputProperty.notification;
        } else if (properties.contains(CharacteristicProperty.indicate)) {
          inputProperty = BleInputProperty.indication;
        } else {
          throw 'No notify or indicate property';
        }
      }
      await UniversalBle.setNotifiable(
        widget.deviceId,
        selectedCharacteristic!.service.uuid,
        selectedCharacteristic!.characteristic.uuid,
        inputProperty,
      );
      _addLog('BleInputProperty', inputProperty);
    } catch (e) {
      _addLog('NotifyError', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.deviceName} - ${widget.deviceId}"),
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? Colors.greenAccent : Colors.red,
              size: 20,
            ),
          )
        ],
      ),
      body: ResponsiveView(builder: (_, DeviceType deviceType) {
        return Row(
          children: [
            if (deviceType == DeviceType.desktop)
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: Theme.of(context).secondaryHeaderColor,
                        child: discoveredServices.isEmpty
                            ? const Center(
                                child: Text('No Services Discovered'),
                              )
                            : ServicesListWidget(
                                discoveredServices: discoveredServices,
                                scrollable: true,
                                onTap: (BleService service,
                                    BleCharacteristic characteristic) {
                                  setState(() {
                                    selectedCharacteristic = (
                                      service: service,
                                      characteristic: characteristic
                                    );
                                  });
                                },
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(_log),
                      )
                  ],
                ),
              ),
            Expanded(
              flex: 5,
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    // Top buttons
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            PlatformButton(
                              text: 'Connect',
                              enabled: !isConnected,
                              onPressed: () async {
                                try {
                                  await UniversalBle.connect(widget.deviceId);
                                } catch (e) {
                                  _addLog('ConnectError', e);
                                }
                              },
                            ),

                            PlatformButton(
                              enabled: isConnected &&
                                  discoveredServices.isNotEmpty &&
                                  _hasSelectedCharacteristicProperty([
                                    CharacteristicProperty.notify,
                                    CharacteristicProperty.indicate
                                  ]),
                              onPressed: () => _setBleInputProperty(
                                  BleInputProperty.notification),
                              text: 'Subscribe',
                            ),
                            
                            PlatformButton(
                              text: 'Disconnect',
                              enabled: isConnected,
                              onPressed: () {
                                UniversalBle.disconnect(widget.deviceId);
                              },
                            ),

                          ],
                        ),
                      ),
                    ),
                    
                    // Expanded(
                    //   flex: 1,
                    //   child: Padding(
                    //     padding: const EdgeInsets.all(4.0),
                    //     child: ResponsiveButtonsGrid(
                    //       children: [
                    //         PlatformButton(
                    //           enabled: isConnected &&
                    //               discoveredServices.isNotEmpty &&
                    //               _hasSelectedCharacteristicProperty([
                    //                 CharacteristicProperty.notify,
                    //                 CharacteristicProperty.indicate
                    //               ]),
                    //           onPressed: () => _setBleInputProperty(
                    //               BleInputProperty.notification),
                    //           text: 'Subscribe',
                    //         ),
                    //         PlatformButton(
                    //           enabled: isConnected &&
                    //               discoveredServices.isNotEmpty &&
                    //               _hasSelectedCharacteristicProperty([
                    //                 CharacteristicProperty.notify,
                    //                 CharacteristicProperty.indicate
                    //               ]),
                    //           onPressed: () => _setBleInputProperty(
                    //               BleInputProperty.disabled),
                    //           text: 'Unsubscribe',
                    //         ),
                    //         if (Capabilities.supportsPairingApi)
                    //           PlatformButton(
                    //             onPressed: () async {
                    //               await UniversalBle.pair(widget.deviceId);
                    //             },
                    //             text: 'Pair',
                    //           ),
                    //         if (Capabilities.supportsPairingApi)
                    //           PlatformButton(
                    //             onPressed: () async {
                    //               bool? isPaired = await UniversalBle.isPaired(
                    //                   widget.deviceId);
                    //               _addLog('IsPaired', isPaired);
                    //             },
                    //             text: 'IsPaired',
                    //           ),
                    //         if (Capabilities.supportsPairingApi)
                    //           PlatformButton(
                    //             onPressed: () async {
                    //               await UniversalBle.unPair(widget.deviceId);
                    //             },
                    //             text: 'UnPair',
                    //           ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    
                    // Services
                    if (deviceType != DeviceType.desktop)
                      ServicesListWidget(
                        discoveredServices: discoveredServices,
                        onTap: (BleService service,
                            BleCharacteristic characteristic) {
                          setState(() {
                            selectedCharacteristic = (
                              service: service,
                              characteristic: characteristic
                            );
                          });
                        },
                      ),
                    const Divider(),
                                
                    //TODO: add game view
                    Expanded(
                      flex: 10,
                      child: GameWidget(
                        game: game,
                        initialActiveOverlays: const [MainMenuScreen.id],
                        overlayBuilderMap: {
                          'mainMenu': (context, _) => MainMenuScreen(game: game),
                          'gameOver': (context, _) => GameOverScreen(game: game),
                        },
                      ),
                    ),
                    // const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      ),
    );
  }

  bool _hasSelectedCharacteristicProperty(
          List<CharacteristicProperty> properties) =>
      properties.any((property) =>
          selectedCharacteristic?.characteristic.properties
              .contains(property) ??
          false);
}