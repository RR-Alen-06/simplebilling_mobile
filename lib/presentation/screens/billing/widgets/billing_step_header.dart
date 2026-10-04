import 'package:flutter/material.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';

class BillingStepHeader extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int> onStepSelected;

  const BillingStepHeader({
    super.key,
    required this.currentStep,
    required this.onStepSelected,
  });

  Widget _buildStepPill(int stepIndex, String title, IconData icon) {
    final isSelected = currentStep == stepIndex;
    final isPassed = currentStep > stepIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () => onStepSelected(stepIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryEmerald
                : isPassed
                    ? AppColors.pastelMint
                    : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryEmerald
                  : isPassed
                      ? AppColors.borderMint
                      : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPassed ? Icons.check_circle : icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : isPassed
                        ? AppColors.primaryEmerald
                        : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : isPassed
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _buildStepPill(0, '1. Items', Icons.inventory_2_outlined),
          const SizedBox(width: 8),
          _buildStepPill(1, '2. Customer', Icons.person_outline_rounded),
          const SizedBox(width: 8),
          _buildStepPill(2, '3. Pay', Icons.payments_outlined),
        ],
      ),
    );
  }
}
