import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/running_shoes.dart';
import '../services/gear_tracker_service.dart';
import '../widgets/app_surface_card.dart';

class GearTrackerScreen extends StatefulWidget {
  const GearTrackerScreen({
    required this.gearTracker,
    super.key,
  });

  final GearTrackerService gearTracker;

  @override
  State<GearTrackerScreen> createState() => _GearTrackerScreenState();
}

class _GearTrackerScreenState extends State<GearTrackerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mileageController = TextEditingController(text: '0');
  bool _isSaving = false;
  String? _actionError;

  @override
  void dispose() {
    _nameController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _addShoe() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _actionError = null;
    });
    try {
      await widget.gearTracker.addShoe(
        name: _nameController.text,
        startingKilometers:
            double.parse(_mileageController.text.replaceAll(',', '.')),
      );
      _nameController.clear();
      _mileageController.text = '0';
    } on Exception {
      if (mounted) {
        setState(() => _actionError = AppStrings.of(context).gearStorageFailed);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeShoe(RunningShoes shoe) async {
    try {
      await widget.gearTracker.removeShoe(shoe.id);
    } on Exception {
      if (mounted) {
        setState(() => _actionError = AppStrings.of(context).gearStorageFailed);
      }
    }
  }

  Future<void> _selectShoe(String shoeId) async {
    try {
      await widget.gearTracker.selectShoe(shoeId);
    } on Exception {
      if (mounted) {
        setState(() => _actionError = AppStrings.of(context).gearStorageFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.gearTracker,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      strings.shoesTitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(strings.shoesIntro),
                    const SizedBox(height: 20),
                    if (!widget.gearTracker.isLoaded)
                      const Center(child: CircularProgressIndicator())
                    else if (widget.gearTracker.loadError != null)
                      Column(
                        children: [
                          _GearMessage(message: strings.shoeStorageUnavailable),
                          TextButton(
                            onPressed: widget.gearTracker.load,
                            child: Text(strings.retry),
                          ),
                        ],
                      )
                    else ...[
                      AppSurfaceCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? strings.shoeNameRequired
                                        : null,
                                decoration: InputDecoration(
                                  labelText: strings.shoeName,
                                  hintText: strings.shoeNameHint,
                                  prefixIcon:
                                      const Icon(Icons.directions_run_rounded),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _mileageController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*[.,]?\d*$'),
                                  ),
                                ],
                                validator: (value) {
                                  final mileage = double.tryParse(
                                    (value ?? '').replaceAll(',', '.'),
                                  );
                                  return mileage == null ||
                                          !mileage.isFinite ||
                                          mileage < 0
                                      ? strings.invalidMileage
                                      : null;
                                },
                                decoration: InputDecoration(
                                  labelText: strings.startingMileage,
                                  suffixText: 'km',
                                  prefixIcon: const Icon(Icons.speed_rounded),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _isSaving ? null : _addShoe,
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(strings.addShoe),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_actionError != null) ...[
                        const SizedBox(height: 12),
                        _GearMessage(message: _actionError!),
                      ],
                      const SizedBox(height: 20),
                      if (widget.gearTracker.shoes.isEmpty)
                        _GearMessage(message: strings.noShoes)
                      else
                        ...widget.gearTracker.shoes.map(
                          (shoe) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ShoeCard(
                              shoe: shoe,
                              isSelected:
                                  widget.gearTracker.selectedShoeId == shoe.id,
                              onSelect: () => _selectShoe(shoe.id),
                              onRemove: () => _removeShoe(shoe),
                            ),
                          ),
                        ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShoeCard extends StatelessWidget {
  const _ShoeCard({
    required this.shoe,
    required this.isSelected,
    required this.onSelect,
    required this.onRemove,
  });

  final RunningShoes shoe;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final needsReplacement = shoe.totalKilometers > 700;
    return AppSurfaceCard(
      color: isSelected ? colors.primaryContainer : null,
      child: Row(
        children: [
          Icon(
            Icons.directions_run_rounded,
            color: isSelected ? colors.onPrimaryContainer : colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shoe.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${strings.mileage}: '
                  '${shoe.totalKilometers.toStringAsFixed(1)} km',
                ),
                if (needsReplacement) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: Text(strings.replaceShoes),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.errorContainer,
                    labelStyle: TextStyle(color: colors.onErrorContainer),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: strings.deleteShoe,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          if (!isSelected)
            IconButton(
              tooltip: strings.selectShoes,
              onPressed: onSelect,
              icon: const Icon(Icons.radio_button_unchecked_rounded),
            )
          else
            Icon(Icons.check_circle_rounded, color: colors.primary),
        ],
      ),
    );
  }
}

class _GearMessage extends StatelessWidget {
  const _GearMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(child: Text(message));
  }
}
