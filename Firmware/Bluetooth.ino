#include <ArduinoBLE.h>

#define SLIDING_WIN 20

// Bluetooth® Low Energy Signal Service
BLEService signalService("19B10000-E8F2-537E-4F6C-D104768A1214");

// Bluetooth® Low Energy Signal Level Characteristic
BLEUnsignedCharCharacteristic signalLevelChar("19B10001-E8F2-537E-4F6C-D104768A1214",  // standard 16-bit characteristic UUID
    BLERead | BLENotify); // remote clients will be able to get notifications if this characteristic changes


int ref = 5;
float voltage = 0;

float signalLevel = 0.0;
long previousMillis = 0;  // last time the signal level was checked, in ms

void setup() {
  Serial.println("hi");
  Serial.begin(9600);    // initialize serial communication
  while (!Serial);

  pinMode(LED_BUILTIN, OUTPUT); // initialize the built-in LED pin to indicate when a central is connected

  // begin initialization
  if (!BLE.begin()) {
    Serial.println("starting BLE failed!");
    while (1);
  }

  BLE.setLocalName("SignalMonitor");
  BLE.setAdvertisedService(signalService); // add the service UUID
  signalService.addCharacteristic(signalLevelChar); // add the signal level characteristic
  BLE.addService(signalService); // Add the signal service
  signalLevelChar.writeValue(0); // set initial value for this characteristic

  // start advertising
  BLE.advertise();

  Serial.println("Bluetooth® device active, waiting for connections...");
}

void loop() {
  
  // wait for a Bluetooth® Low Energy central
  BLEDevice central = BLE.central();

  // if a central is connected to the peripheral:
  if (central) {
    Serial.print("Connected to central: ");
    // print the central's BT address:
    Serial.println(central.address());
    // turn on the LED to indicate the connection:
    digitalWrite(LED_BUILTIN, HIGH);

    // check the signal level every 200ms
    // while the central is connected:
    while (central.connected()) {
      updateSignalLevel();
    }
    // when the central disconnects, turn off the LED:
    digitalWrite(LED_BUILTIN, LOW);
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
  
  
}

void updateSignalLevel() {

  int voltage_sum = 0;

  for(int i = 0; i < SLIDING_WIN; i++) {
    voltage_sum += analogRead(A1);
    delay(5);
  }

  voltage = voltage_sum * (5.0 / 1023.0) / SLIDING_WIN;

  signalLevel = min(max(0, voltage - 1.75), 3);

  signalLevelChar.writeValue(int(signalLevel*100));  // and update the signal level characteristic

  Serial.print("volatge:"); Serial.print(voltage); Serial.print(", ");
  Serial.print("ref:"); Serial.print(ref); Serial.print(", ");
  Serial.print("signalLevel:"); Serial.print(signalLevel); Serial.print(", ");
  Serial.println();

}
