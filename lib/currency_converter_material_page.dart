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
    extends State<CurrencyConverterMaterialPage>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  String fromCurrency = "USD";
  String toCurrency = "INR";
  double result = 0.0;
  double liveRate = 0.0;
  bool isLoading = false;
  bool isConverting = false;
  String? errorMessage;
  bool hasConverted = false;

  Map<String, Map<String, String>> currencies = {};
  List<String> sortedCodes = [];

  late AnimationController _resultController;
  late AnimationController _cardController;

  @override
  void initState() {
    super.initState();

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _loadCurrenciesFromJson().then((_) {
      fetchCurrencies().then((_) {
        fetchRate();
        _cardController.forward();
      });
    });
  }

  Future<void> _loadCurrenciesFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/currencies.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      setState(() {
        currencies = jsonData.map(
          (key, value) => MapEntry(key, Map<String, String>.from(value as Map)),
        );
        sortedCodes = currencies.keys.toList()..sort();
      });
    } catch (e) {
      // Fallback to empty map if JSON loading fails
      setState(() {
        currencies = {};
        sortedCodes = [];
      });
    }
  }

  @override
  void dispose() {
    _resultController.dispose();
    _cardController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchCurrencies() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = "https://open.er-api.com/v6/latest/USD";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data["rates"] as Map<String, dynamic>;

        final sorted = rates.keys.toList()..sort();

        setState(() {
          // Merge API rates with loaded currencies
          currencies = {
            for (var code in sorted)
              code:
                  currencies[code] ??
                  {'country': code, 'name': code, 'flag': '🌍'},
          };
          sortedCodes = sorted;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to load currencies";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Network error";
        isLoading = false;
      });
    }
  }

  Future<void> fetchRate() async {
    if (fromCurrency.isEmpty || toCurrency.isEmpty) return;

    if (fromCurrency == toCurrency) {
      setState(() {
        liveRate = 1.0;
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = "https://open.er-api.com/v6/latest/$fromCurrency";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data["rates"] as Map<String, dynamic>?;

        if (rates != null && rates.containsKey(toCurrency)) {
          setState(() {
            liveRate = (rates[toCurrency] as num).toDouble();
            isLoading = false;
          });
        } else {
          setState(() {
            liveRate = 0.0;
            errorMessage = "Rate not available";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          liveRate = 0.0;
          errorMessage = "Failed to fetch rate";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        liveRate = 0.0;
        errorMessage = "Network error";
        isLoading = false;
      });
    }
  }

  void _convert() async {
    if (_controller.text.isEmpty) {
      _showSnackBar(
        "Please enter an amount",
        Icons.warning_amber_rounded,
        Colors.orange,
      );
      return;
    }

    double value = double.tryParse(_controller.text) ?? 0;
    if (value <= 0) {
      _showSnackBar(
        "Please enter a valid amount",
        Icons.error_outline,
        Colors.red,
      );
      return;
    }

    if (liveRate == 0.0) {
      _showSnackBar(
        "Exchange rate not available",
        Icons.sync_problem,
        Colors.red,
      );
      return;
    }

    setState(() {
      isConverting = true;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    setState(() {
      result = value * liveRate;
      isConverting = false;
      hasConverted = true;
    });

    _resultController.forward(from: 0.0);
    HapticFeedback.mediumImpact();
  }

  void _reset() {
    setState(() {
      result = 0.0;
      hasConverted = false;
      errorMessage = null;
      _controller.clear();
    });
    fetchRate();
    HapticFeedback.lightImpact();
  }

  void _swapCurrencies() {
    setState(() {
      String temp = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = temp;
    });

    fetchRate().then((_) {
      if (_controller.text.isNotEmpty && liveRate > 0) {
        double value = double.tryParse(_controller.text) ?? 0;
        if (value > 0) {
          setState(() {
            result = value * liveRate;
            hasConverted = true;
          });
          _resultController.forward(from: 0.0);
        }
      } else {
        setState(() {
          result = 0.0;
          hasConverted = false;
        });
      }
    });

    HapticFeedback.selectionClick();
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
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
    double containerWidth = screenWidth < 600 ? screenWidth * 0.92 : 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.currency_exchange_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'CurroX',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _cardController,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: Container(
                        width: containerWidth,
                        margin: const EdgeInsets.only(top: 0),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                              spreadRadius: -5,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 35,
                              offset: const Offset(0, 18),
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1E293B),
                                    Color(0xFF334155),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  if (!hasConverted)
                                    Column(
                                      children: [
                                        const Icon(
                                          Icons.currency_exchange_rounded,
                                          size: 60,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Ready to Convert",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    ScaleTransition(
                                      scale: Tween<double>(begin: 0.5, end: 1.0)
                                          .animate(
                                            CurvedAnimation(
                                              parent: _resultController,
                                              curve: Curves.elasticOut,
                                            ),
                                          ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                currencies[toCurrency]?['flag'] ??
                                                    '🌍',
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFF10B981),
                                                          Color(0xFF059669),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF10B981,
                                                      ).withOpacity(0.4),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  toCurrency,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          TweenAnimationBuilder<double>(
                                            tween: Tween<double>(
                                              begin: 0,
                                              end: result,
                                            ),
                                            duration: const Duration(
                                              milliseconds: 800,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, value, child) {
                                              return AutoSizeText(
                                                value.toStringAsFixed(2),
                                                style: const TextStyle(
                                                  fontSize: 56,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  letterSpacing: -2,
                                                  shadows: [
                                                    Shadow(
                                                      color: Color(0xFF10B981),
                                                      blurRadius: 15,
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                minFontSize: 24,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildPremiumCurrencyDropdown(
                                    label: "From",
                                    value: fromCurrency,
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() {
                                        fromCurrency = val;
                                        hasConverted = false;
                                      });
                                      fetchRate();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  margin: const EdgeInsets.only(top: 28),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF059669),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(50),
                                      onTap: isLoading ? null : _swapCurrencies,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        child: const Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildPremiumCurrencyDropdown(
                                    label: "To",
                                    value: toCurrency,
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() {
                                        toCurrency = val;
                                        hasConverted = false;
                                      });
                                      fetchRate();
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 25),

                            // PREMIUM ENHANCED AMOUNT INPUT BOX
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF10B981).withOpacity(0.08),
                                    const Color(0xFF059669).withOpacity(0.12),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.25),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                    spreadRadius: 0,
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.6),
                                    blurRadius: 15,
                                    offset: const Offset(-5, -5),
                                  ),
                                ],
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  decoration: InputDecoration(
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF10B981,
                                            ).withOpacity(0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.payments_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    suffixIcon: _controller.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                              color: Color(0xFF64748B),
                                            ),
                                            onPressed: () {
                                              _controller.clear();
                                              setState(() {
                                                hasConverted = false;
                                              });
                                            },
                                          )
                                        : null,
                                    hintText: "Enter amount in $fromCurrency",
                                    hintStyle: TextStyle(
                                      color: const Color(
                                        0xFF64748B,
                                      ).withOpacity(0.5),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: BorderSide(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF10B981),
                                        width: 3,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 22,
                                      horizontal: 8,
                                    ),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: 0.5,
                                  ),
                                  onChanged: (_) {
                                    if (hasConverted) {
                                      setState(() => hasConverted = false);
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isLoading
                                    ? Colors.blue[50]
                                    : errorMessage != null
                                    ? Colors.red[50]
                                    : Colors.green[50],
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isLoading
                                      ? Colors.blue.withOpacity(0.3)
                                      : errorMessage != null
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.green.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isLoading
                                                ? Colors.blue
                                                : errorMessage != null
                                                ? Colors.red
                                                : Colors.green)
                                            .withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isLoading)
                                    Container(
                                      width: 18,
                                      height: 18,
                                      margin: const EdgeInsets.only(right: 10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue[600]!,
                                            ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      errorMessage != null
                                          ? Icons.error_outline
                                          : Icons.check_circle_rounded,
                                      color: errorMessage != null
                                          ? Colors.red[600]
                                          : Colors.green[600],
                                      size: 20,
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      errorMessage ??
                                          (isLoading
                                              ? "Fetching live rate..."
                                              : "1 $fromCurrency = ${liveRate.toStringAsFixed(4)} $toCurrency"),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: errorMessage != null
                                            ? Colors.red[600]
                                            : (isLoading
                                                  ? Colors.blue[600]
                                                  : Colors.green[600]),
                                        letterSpacing: 0.3,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildPremiumButton(
                                    label: isConverting
                                        ? "Converting..."
                                        : "Convert",
                                    icon: isConverting
                                        ? Icons.hourglass_empty_rounded
                                        : Icons.currency_exchange_rounded,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF059669),
                                      ],
                                    ),
                                    shadowColor: const Color(0xFF10B981),
                                    onTap: (isLoading || isConverting)
                                        ? null
                                        : _convert,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildPremiumButton(
                                    label: "Reset",
                                    icon: Icons.refresh_rounded,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF64748B),
                                        Color(0xFF475569),
                                      ],
                                    ),
                                    shadowColor: const Color(0xFF64748B),
                                    onTap: isLoading ? null : _reset,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  "© 💚 Sandip.4083",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCurrencyDropdown({
    required String label,
    required String value,
    required Function(String?) onChanged,
  }) {
    final currencyInfo =
        currencies[value] ?? {'country': value, 'name': value, 'flag': '🌍'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: value,
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Text(
                  currencyInfo['flag'] ?? '🌍',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: const Color(0xFF1E293B).withOpacity(0.12),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF10B981),
                  width: 2.5,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.only(
                left: 4,
                right: 12,
                top: 14,
                bottom: 14,
              ),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
            dropdownColor: Colors.white,
            menuMaxHeight: 500,
            itemHeight: 65,
            selectedItemBuilder: (BuildContext context) {
              return sortedCodes.map<Widget>((String code) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                );
              }).toList();
            },
            items: sortedCodes.map((code) {
              final info =
                  currencies[code] ??
                  {'country': code, 'name': code, 'flag': '🌍'};
              final countryName = info['country'] ?? code;
              final flag = info['flag'] ?? '🌍';

              return DropdownMenuItem(
                value: code,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              countryName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: isLoading ? null : onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumButton({
    required String label,
    required IconData icon,
    required Gradient gradient,
    required Color shadowColor,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: onTap == null
                ? LinearGradient(colors: [Colors.grey[300]!, Colors.grey[400]!])
                : gradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                      color: shadowColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
