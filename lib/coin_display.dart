import 'package:flutter/material.dart';
import 'coin_service.dart';

class CoinDisplay extends StatefulWidget {
  const CoinDisplay({super.key});

  @override
  State<CoinDisplay> createState() => CoinDisplayState();
}

class CoinDisplayState extends State<CoinDisplay> {
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final coins = await CoinService.getCoins();
    setState(() {
      _coins = coins;
    });
  }

  // 提供一個方法讓外部調用來刷新金幣顯示
  Future<void> refreshCoins() async {
    await _loadCoins();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on,
            color: Colors.amber.shade700,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            '$_coins',
            style: TextStyle(
              color: Colors.amber.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
} 