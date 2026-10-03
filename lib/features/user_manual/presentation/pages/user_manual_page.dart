import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../domain/manual_content.dart';

class UserManualPage extends StatefulWidget {
  const UserManualPage({super.key, this.initialSectionId});

  /// Opens the manual scrolled/selected to this section, e.g. from a
  /// "Learn more" link elsewhere in the app. Falls back to the first
  /// section when null or not found.
  final String? initialSectionId;

  @override
  State<UserManualPage> createState() => _UserManualPageState();
}

class _UserManualPageState extends State<UserManualPage> {
  final _searchController = TextEditingController();
  String _query = '';
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = manualSections.any((s) => s.id == widget.initialSectionId)
        ? widget.initialSectionId!
        : manualSections.first.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Sections filtered to only entries matching [_query] (case-insensitive,
  /// over section title, entry heading and body); sections with no
  /// matching entries are dropped. Returns everything unfiltered when the
  /// query is empty.
  List<ManualSection> get _filteredSections {
    if (_query.trim().isEmpty) return manualSections;
    final q = _query.trim().toLowerCase();

    final result = <ManualSection>[];
    for (final section in manualSections) {
      final sectionMatches = section.title.toLowerCase().contains(q);
      final matchingEntries = section.entries
          .where((e) =>
              sectionMatches ||
              e.heading.toLowerCase().contains(q) ||
              e.body.toLowerCase().contains(q))
          .toList();
      if (matchingEntries.isNotEmpty) {
        result.add(
          ManualSection(
            id: section.id,
            title: section.title,
            icon: section.icon,
            entries: matchingEntries,
          ),
        );
      }
    }
    return result;
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: 'Search User Manual',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _searchController.clear();
                  _query = '';
                }),
              ),
        isDense: true,
        border:
            const OutlineInputBorder(borderRadius: AppSpacing.borderRadiusMD),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _filteredSections;

    return Scaffold(
      appBar: AppBar(title: const Text('User Manual')),
      body: context.isMobile
          ? _MobileManual(
              sections: sections,
              searchField: _searchField(),
              query: _query,
            )
          : _DesktopManual(
              sections: sections,
              allSections: manualSections,
              selectedId: sections.any((s) => s.id == _selectedId)
                  ? _selectedId
                  : (sections.isEmpty ? _selectedId : sections.first.id),
              onSelect: (id) => setState(() => _selectedId = id),
              searchField: _searchField(),
              isSearching: _query.trim().isNotEmpty,
            ),
    );
  }
}

class _MobileManual extends StatelessWidget {
  const _MobileManual({
    required this.sections,
    required this.searchField,
    required this.query,
  });

  final List<ManualSection> sections;
  final Widget searchField;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(padding: AppSpacing.paddingMD, child: searchField),
        if (sections.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No results for "$query"',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: AppSpacing.horizontalMD,
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                return ExpansionTile(
                  initiallyExpanded: query.trim().isNotEmpty,
                  leading: Icon(section.icon),
                  title: Text(section.title),
                  children: [
                    for (final entry in section.entries)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.heading,
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            AppSpacing.gapXS,
                            Text(entry.body),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DesktopManual extends StatelessWidget {
  const _DesktopManual({
    required this.sections,
    required this.allSections,
    required this.selectedId,
    required this.onSelect,
    required this.searchField,
    required this.isSearching,
  });

  final List<ManualSection> sections;
  final List<ManualSection> allSections;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final Widget searchField;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: Column(
            children: [
              Padding(padding: AppSpacing.paddingMD, child: searchField),
              Expanded(
                child: ListView.builder(
                  itemCount: allSections.length,
                  itemBuilder: (context, index) {
                    final section = allSections[index];
                    final included = sections.any((s) => s.id == section.id);
                    return ListTile(
                      leading: Icon(section.icon),
                      title: Text(section.title),
                      selected: !isSearching && section.id == selectedId,
                      enabled: !isSearching || included,
                      onTap: () => onSelect(section.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: isSearching
              ? _SearchResults(sections: sections)
              : _SectionContent(
                  section: sections.firstWhere(
                    (s) => s.id == selectedId,
                    orElse: () => allSections.first,
                  ),
                ),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.sections});

  final List<ManualSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }
    return ListView(
      padding: AppSpacing.paddingLG,
      children: [
        for (final section in sections) ...[
          Text(
            section.title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.primary,
            ),
          ),
          AppSpacing.gapSM,
          for (final entry in section.entries) ...[
            Text(
              entry.heading,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.gapXS,
            Text(entry.body),
            AppSpacing.gapMD,
          ],
          AppSpacing.gapMD,
        ],
      ],
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({required this.section});

  final ManualSection section;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.paddingLG,
      children: [
        Row(
          children: [
            Icon(section.icon, color: context.colorScheme.primary),
            AppSpacing.gapSM,
            Text(
              section.title,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        AppSpacing.gapLG,
        for (final entry in section.entries) ...[
          Text(
            entry.heading,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapSM,
          Text(entry.body, style: context.textTheme.bodyMedium),
          AppSpacing.gapLG,
        ],
      ],
    );
  }
}
