import 'package:flutter/material.dart';

class AppLoadingWidget extends StatelessWidget {
  const AppLoadingWidget({super.key, this.size = 32, this.color});

  const AppLoadingWidget.small({super.key, this.color}) : size = 18;

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: size < 24 ? 2 : 3,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
