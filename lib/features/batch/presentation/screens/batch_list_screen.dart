import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/batch_provider.dart';
import 'batch_form_screen.dart';
import 'batch_detail_screen.dart';
import '../../../../core/widgets/app_drawer.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  static const Color primaryNavy = Color(0xFF191A4E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Batches', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BatchFormScreen()),
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: primaryNavy, size: 20),
                ),
              ),
            ),
          )
        ],
      ),
      body: Consumer<BatchProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }

          if (provider.batches.isEmpty) {
            return const EmptyStateWidget(
              message: 'No batches found. Tap + to create one.',
              icon: Icons.class_outlined,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.batches.length,
            itemBuilder: (context, index) {
              final batch = provider.batches[index];
              return Opacity(
                opacity: batch.isActive ? 1.0 : 0.6,
                child: AppCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BatchDetailScreen(batch: batch),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: batch.isActive ? AppTheme.accentColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                        foregroundColor: batch.isActive ? AppTheme.accentColor : Colors.grey,
                        child: const Icon(Icons.class_),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    batch.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (!batch.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('Inactive', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${batch.studentCount} Student${batch.studentCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (batch.scheduleDays != null && batch.timeSlot != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${batch.scheduleDays} | ${batch.timeSlot}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (batch.description != null && batch.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                batch.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
