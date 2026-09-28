import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_version_text.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends GetView<SettingsController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = controller.items(context);
    return AppScaffold(
      title: 'Settings',
      padding: EdgeInsets.zero,
      body: Obx(
        () => Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final color = item.isDestructive ? Theme.of(context).colorScheme.error : null;
                      return ListTile(
                        leading: Icon(item.icon, color: color),
                        title: Text(item.label, style: TextStyle(color: color)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: item.onTap,
                      );
                    },
                  ),
                ),
                const AppVersionText(),
              ],
            ),
            if (controller.isDeletingAccount.value)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(child: AppLoadingWidget(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}
