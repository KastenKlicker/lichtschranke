class ConnectionStatus {
  
  String message;
  ConnectionType type;
  
  ConnectionStatus(this.message, this.type);
  
  void set(String message, ConnectionType type) {
    this.message = message;
    this.type = type;
  }
  
  void setConnected(ConnectionType type) {
    this.message = "Verbunden mit Lichtschranke";
    this.type = type;
  }
  
  void setConnecting() {
    this.message = "Verbinde mit Lichtschranke...";
    this.type = ConnectionType.CONNECTING;
  }
  
  void setDisconnected() {
    this.message = "Nicht verbunden.";
    this.type = ConnectionType.DISCONNECTED;
  }
  
  bool isConnected() {
    return this.type == ConnectionType.BLUETOOTH
      || this.type == ConnectionType.SERIAL;
  }
  
  bool isConnecting() {
    return this.type == ConnectionType.CONNECTING;
  }
  
  bool isDisconnected() {
    return this.type == ConnectionType.DISCONNECTED;
  }
  
  bool isSerial() {
    return this.type == ConnectionType.SERIAL;
  }
  
  bool isBluetooth() {
    return this.type == ConnectionType.BLUETOOTH;
  }
}

enum ConnectionType {CONNECTING, DISCONNECTED, BLUETOOTH, SERIAL}