import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const UltraDerivApp());
}

class UltraDerivApp extends StatelessWidget {
  const UltraDerivApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ultra Deriv AI',
      theme: ThemeData.dark(),
      home: const MainDashboard(),
    );
  }
}

const markets = [
  "R_25",
  "R_50",
  "R_75",
  "R_100",
  "R_25_1S",
  "R_50_1S",
  "R_75_1S",
  "R_100_1S"
];

class ApiService {
  final String symbol;
  WebSocketChannel? _channel;

  final StreamController<int> _stream =
      StreamController<int>.broadcast();

  ApiService(this.symbol);

  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://ws.derivws.com/websockets/v3'),
    );

    _channel!.sink.add(jsonEncode({
      "ticks": symbol,
      "subscribe": 1
    }));

    _channel!.stream.listen((event) {
      final data = jsonDecode(event);

      if (data['tick'] != null) {
        String q = data['tick']['quote'].toString();
        int digit =
            int.parse(q.substring(q.length - 1));

        _stream.add(digit);
      }
    });
  }

  Stream<int> get stream => _stream.stream;
}

class AIEngine {
  Map<int, double> weight = {};

  void init() {
    for (int i = 0; i < 10; i++) {
      weight[i] = 1;
    }
  }

  void learn(List<int> ticks) {
    for (var t in ticks) {
      weight[t] = (weight[t] ?? 1) + 0.02;
    }
  }

  int bestMatch() {
    return weight.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  int bestDiffer() {
    return weight.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  double confidence(int d) {
    double total =
        weight.values.fold(0, (a, b) => a + b);

    return ((weight[d] ?? 1) / total) * 100;
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() =>
      _MainDashboardState();
}

class _MainDashboardState
    extends State<MainDashboard> {
  late ApiService api;

  AIEngine ai = AIEngine();

  List<int> ticks = [];

  String market = markets.first;

  int match = -1;
  int differ = -1;
  double conf = 0;

  @override
  void initState() {
    super.initState();

    ai.init();

    connect();
  }

  void connect() {
    api = ApiService(market);

    api.connect();

    api.stream.listen((d) {
      setState(() {
        ticks.add(d);

        if (ticks.length > 100) {
          ticks.removeAt(0);
        }
      });
    });
  }

  void analyze() {
    ai.learn(ticks);

    match = ai.bestMatch();

    differ = ai.bestDiffer();

    conf = ai.confidence(match);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            "ULTRA DERIV AI SYSTEM"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            DropdownButton<String>(
              value: market,
              onChanged: (v) {
                setState(() {
                  market = v!;
                  ticks.clear();
                });

                connect();
              },
              items: markets
                  .map((m) =>
                      DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection:
                    Axis.horizontal,
                itemCount: ticks.length,
                itemBuilder: (_, i) =>
                    Container(
                  margin:
                      const EdgeInsets.all(4),
                  padding:
                      const EdgeInsets.all(10),
                  color: Colors.white10,
                  child: Text(
                      ticks[i].toString()),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.all(
                            14),
                    color:
                        Colors.blueGrey,
                    child: Column(
                      children: [
                        const Text("MATCH"),
                        Text(
                          "$match",
                          style:
                              const TextStyle(
                            fontSize: 24,
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.all(
                            14),
                    color:
                        Colors.black54,
                    child: Column(
                      children: [
                        const Text("DIFFER"),
                        Text(
                          "$differ",
                          style:
                              const TextStyle(
                            fontSize: 24,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Text(
              "CONFIDENCE: ${conf.toStringAsFixed(1)}%",
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: analyze,
              child:
                  const Text("ANALYZE"),
            ),
          ],
        ),
      ),
    );
  }
}