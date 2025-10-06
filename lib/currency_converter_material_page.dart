import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class CurrencyConverterMaterialPage extends StatefulWidget {
  const CurrencyConverterMaterialPage({super.key});

  @override
  State<CurrencyConverterMaterialPage> createState() =>
      _CurrencyConverterMaterialPageState();
}

class _CurrencyConverterMaterialPageState
    extends State<CurrencyConverterMaterialPage> {
  final TextEditingController _controller = TextEditingController();

  String fromCurrency = "USD";
  String toCurrency = "INR";
  double result = 0.0;
  double liveRate = 0.0;

  Map<String, String> currencies = {}; // code -> name
  List<MapEntry<String, String>> sortedList = [];

  /// 🔹 Reusable black border style
  final OutlineInputBorder blackBorder = OutlineInputBorder(
    borderSide: const BorderSide(color: Colors.black, width: 1.5),
    borderRadius: BorderRadius.circular(12),
  );

  /// Fetch all supported currencies (from open.er-api.com)
  Future<void> fetchCurrencies() async {
    final url = "https://open.er-api.com/v6/latest/USD"; // base USD
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final rates = data["rates"] as Map<String, dynamic>;

        final unsorted = rates.keys.map((code) => MapEntry(code, code));

        final sorted = unsorted.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        setState(() {
          currencies = {for (var e in sorted) e.key: e.value};
          sortedList = sorted;
        });
      } else {
        print("Failed to load currencies, status ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching currencies: $e");
    }
  }

  /// Fetch live exchange rate
  Future<void> fetchRate() async {
    if (fromCurrency.isEmpty || toCurrency.isEmpty) return;

    if (fromCurrency == toCurrency) {
      setState(() {
        liveRate = 1.0;
      });
      return;
    }

    final url = "https://open.er-api.com/v6/latest/$fromCurrency";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data["rates"] as Map<String, dynamic>?;

        if (rates != null && rates.containsKey(toCurrency)) {
          setState(() {
            liveRate = (rates[toCurrency] as num).toDouble();
          });
        } else {
          setState(() => liveRate = 0.0);
        }
      } else {
        setState(() => liveRate = 0.0);
      }
    } catch (e) {
      print("Fetch rate error: $e");
      setState(() => liveRate = 0.0);
    }
  }

  void _convert() {
    if (_controller.text.isEmpty || liveRate == 0.0) return;
    double value = double.tryParse(_controller.text) ?? 0;
    setState(() {
      result = value * liveRate;
    });
  }

  void _reset() {
    setState(() {
      fromCurrency = "USD";
      toCurrency = "INR";
      result = 0.0;
      liveRate = 0.0;
      _controller.clear();
    });
    fetchRate();
  }

  void _swapCurrencies() {
    setState(() {
      String temp = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = temp;
      result = 0.0;
    });
    fetchRate();
  }

  @override
  void initState() {
    super.initState();
    fetchCurrencies().then((_) {
      fetchRate();
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    double screenWidth = MediaQuery.of(context).size.width;
    double containerWidth = screenWidth < 600 ? screenWidth * 0.9 : 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CurroX',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2575FC),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: containerWidth,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.currency_exchange, color: Color(0xFF2575FC)),
                        SizedBox(width: 8),
                        Text(
                          "Global Currency Converter",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Result Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F0FB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            toCurrency,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2575FC),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: result),
                              duration: const Duration(milliseconds: 700),
                              builder: (context, value, child) {
                                return AutoSizeText(
                                  value.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  minFontSize: 16,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.start,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Row: From Dropdown + Swap Button + To Dropdown
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("From"),
                              ),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: fromCurrency,
                                decoration: InputDecoration(
                                  border: blackBorder,
                                  enabledBorder: blackBorder,
                                  focusedBorder: blackBorder,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                items: sortedList
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(
                                          e.key,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() {
                                    fromCurrency = val.toUpperCase();
                                  });
                                  fetchRate();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: IconButton(
                            onPressed: _swapCurrencies,
                            icon: const Icon(
                              Icons.swap_horiz,
                              size: 28,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("To"),
                              ),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: toCurrency,
                                decoration: InputDecoration(
                                  border: blackBorder,
                                  enabledBorder: blackBorder,
                                  focusedBorder: blackBorder,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                items: sortedList
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(
                                          e.key,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() {
                                    toCurrency = val.toUpperCase();
                                  });
                                  fetchRate();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Amount Input
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.attach_money_rounded,
                          color: Color(0xFF2575FC),
                        ),
                        hintText: "Enter amount in $fromCurrency",
                        border: blackBorder,
                        enabledBorder: blackBorder,
                        focusedBorder: blackBorder,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Live Rate Display
                    Text(
                      liveRate == 0
                          ? "Fetching live rate..."
                          : "1 $fromCurrency = ${liveRate.toStringAsFixed(4)} $toCurrency",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Convert Button
                    InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: _convert,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Convert",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Reset Button
                    InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: _reset,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Reset",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
