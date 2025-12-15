import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../constants.dart';
import '../services/branch_state.dart';

Future<void> showBranchPickerSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _BranchPickerSheet(),
  );
}

class _BranchPickerSheet extends StatelessWidget {
  const _BranchPickerSheet();

  @override
  Widget build(BuildContext context) {
    final branchState = BranchState.instance;
    final branches = branchState.branches;
    final activeBranch = branchState.activeBranch;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (sheetContext, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.changeBranch,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.changeBranchSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                  ),
                ),
                const SizedBox(height: 18),
                for (final branch in branches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      tileColor: branch.id == activeBranch.id
                          ? primaryColor.withValues(alpha: 0.08)
                          : const Color(0xFFF6F8FC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Icon(
                        Icons.storefront_outlined,
                        color: branch.id == activeBranch.id
                            ? primaryColor
                            : titleColor,
                      ),
                      title: Text(
                        branch.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      subtitle: branch.address.isNotEmpty
                          ? Text(
                              branch.address,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: bodyTextColor,
                                fontSize: 10.0,
                              ),
                            )
                          : null,
                      trailing: branch.id == activeBranch.id
                          ? const Icon(Icons.check_circle, color: primaryColor)
                          : const Icon(
                              Icons.chevron_right_rounded,
                              color: bodyTextColor,
                            ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        branchState.selectBranch(branch);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
