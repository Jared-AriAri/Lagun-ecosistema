import 'dart:io';
import 'dart:typed_data';

class SocketService {
  Socket? _socket;
  final String host = '10.0.2.2'; // IP especial para emuladores
  final int port = 7777;

  // Callback para recibir los datos procesados
  Function(int time, int articles, int activity)? onDataReceived;

  Future<void> connect() async {
    try {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      print("Conectado al Wearable");

      _socket!.listen(
        (Uint8List data) {
          if (data.length >= 4) {
            // Reconstruir los datos (siguiendo el formato de 4 bytes del Wear)
            int time = (data[0] << 8) | data[1];
            int articles = data[2];
            int activity = data[3];

            if (onDataReceived != null) {
              onDataReceived!(time, articles, activity);
            }
          }
        },
        onError: (e) => print("Error de conexión: $e"),
        onDone: () => disconnect(),
      );
    } catch (e) {
      print("No se pudo conectar: $e");
    }
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
  }
}