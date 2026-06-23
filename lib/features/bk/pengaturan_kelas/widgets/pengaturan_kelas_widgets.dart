part of '../screens/pengaturan_kelas_screen.dart';

class _AssignSheetResult {
  final String kelasId;
  final String kelasNama;
  final List<String> siswaIds;

  const _AssignSheetResult({
    required this.kelasId,
    required this.kelasNama,
    required this.siswaIds,
  });
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(36)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  const _ClassChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text('$label $count'),
        avatar: selected
            ? const Icon(Icons.check_rounded, size: 16)
            : const Icon(Icons.class_outlined, size: 16),
        selectedColor: AppColors.primary.withAlpha(34),
        backgroundColor: const Color(0xFFF8FAFC),
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryDark : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.primary.withAlpha(110)
              : Colors.grey.shade300,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _AssignedStudentCard extends StatelessWidget {
  final BkKelasSiswaItem item;
  final VoidCallback onMove;
  final VoidCallback onDeactivate;
  final VoidCallback onDelete;

  const _AssignedStudentCard({
    required this.item,
    required this.onMove,
    required this.onDeactivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentAvatar(color: AppColors.primary, active: item.aktif),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.siswaNama,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.siswaNis?.trim().isNotEmpty == true
                          ? 'NIS: ${item.siswaNis}'
                          : 'NIS belum tersedia',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kelas: ${item.kelasNama} - Tahun Ajaran: ${item.tahunAjaranNama}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opsi lainnya',
                onSelected: (value) {
                  if (value == 'deactivate') {
                    onDeactivate();
                    return;
                  }
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Text('Nonaktifkan'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus Assignment'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusPill(active: item.aktif),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onMove,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Ubah Kelas'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnassignedStudentCard extends StatelessWidget {
  final BkSiswaBelumKelasItem item;
  final VoidCallback onAssign;

  const _UnassignedStudentCard({required this.item, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const _StudentAvatar(color: AppColors.warning, active: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.siswaNama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.siswaNis?.trim().isNotEmpty == true
                      ? 'NIS: ${item.siswaNis}'
                      : 'NIS belum tersedia',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tahun Ajaran: ${item.tahunAjaranNama}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Tambah ke kelas',
            onPressed: onAssign,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  final Color color;
  final bool active;

  const _StudentAvatar({required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withAlpha(26),
      child: Icon(
        active ? Icons.person_rounded : Icons.person_outline_rounded,
        color: color,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;

  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _StudentIdentityHeader extends StatelessWidget {
  final String name;
  final String? nis;
  final Color color;

  const _StudentIdentityHeader({
    required this.name,
    required this.nis,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StudentAvatar(color: color, active: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                nis?.trim().isNotEmpty == true
                    ? 'NIS: $nis'
                    : 'NIS belum tersedia',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PageEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: _InlineEmptyState(icon: icon, title: title, subtitle: subtitle),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 58, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
