import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyConverterMaterialPage extends StatefulWidget {
  const CurrencyConverterMaterialPage({super.key});

  @override
  State<CurrencyConverterMaterialPage> createState() =>
      _CurrencyConverterMaterialPageState();
}

class _CurrencyConverterMaterialPageState
    extends State<CurrencyConverterMaterialPage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  double result = 0.0;
  double displayedResult = 0.0;
  bool _isUsdToInr = true;
  double rate = 83.0;

  @override
  void initState() {
    super.initState();
    _rateController.text = rate.toString();
  }

  Future<void> _saveRate(double newRate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('conversionRate', newRate);
  }

  void _resetRate() {
    setState(() {
      rate = 83.0;
      _rateController.text = rate.toString();
      _controller.clear();
      result = 0.0;
      displayedResult = 0.0;
    });
  }

  void _convert() {
    if (_controller.text.isNotEmpty) {
      double value = double.tryParse(_controller.text) ?? 0;
      double newResult = _isUsdToInr ? value * rate : value / rate;
      setState(() => result = newResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final border = OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.circular(20),
    );

    double screenWidth = MediaQuery.of(context).size.width;
    double containerWidth = screenWidth < 600 ? screenWidth * 0.9 : 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CurroX'),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.currency_exchange, color: Color(0xFF2575FC)),
                        SizedBox(width: 8),
                        Text(
                          "Currency Converter",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

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
                            _isUsdToInr ? "INR" : "USD",
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2575FC),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: displayedResult,
                                end: result,
                              ),
                              duration: const Duration(milliseconds: 700),
                              builder: (context, value, child) {
                                displayedResult = value;
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

                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.attach_money_rounded,
                          color: Color(0xFF2575FC),
                        ),
                        hintText: _isUsdToInr
                            ? "Enter amount in USD"
                            : "Enter amount in INR",
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: border,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isUsdToInr ? "USD → INR" : "INR → USD",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF444444),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.swap_horiz_rounded,
                            color: Color(0xFF2575FC),
                            size: 30,
                          ),
                          onPressed: () {
                            setState(() {
                              _isUsdToInr = !_isUsdToInr;
                              result = 0;
                              displayedResult = 0;
                              _controller.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _rateController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.settings,
                          color: Color(0xFF43A047),
                        ),
                        labelText: "Set Conversion Rate (e.g. 83.0)",
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: border,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        double? newRate = double.tryParse(value);
                        if (newRate != null && newRate > 0) {
                          setState(() => rate = newRate);
                          _saveRate(newRate);
                        }
                      },
                    ),
                    const SizedBox(height: 25),

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

                    InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: _resetRate,
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
