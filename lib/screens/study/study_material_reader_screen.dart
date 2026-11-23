import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../models/study_material_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/gemini_service.dart';
import '../../services/study_library_service.dart';
import '../../widgets/responsive_layout.dart';

class StudyMaterialReaderScreen extends ConsumerStatefulWidget {
  final StudyMaterial material;
  const StudyMaterialReaderScreen({super.key, required this.material});
  @override
  ConsumerState<StudyMaterialReaderScreen> createState() =>
      _StudyMaterialReaderScreenState();
}

class _StudyMaterialReaderScreenState
    extends ConsumerState<StudyMaterialReaderScreen> {
  final _service = StudyLibraryService();
  List<StudyHighlight> _highlights = [];
  bool _loading = true;
  String? _selectedQuote;
  String get _readableText =>
      GeminiService.cleanExtractedDocumentText(widget.material.extractedText);
  String get _userId => ref.read(currentUserProvider).valueOrNull!.id;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.loadHighlights(_userId, widget.material.id);
      if (mounted)
        setState(() {
          _highlights = data;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _highlight() async {
    final selection = _selectedQuote?.trim() ?? '';
    final copied =
        selection.isNotEmpty
            ? selection
            : (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ??
                '';
    if (copied.isEmpty || !_readableText.contains(copied)) {
      _snack('Select a passage in the text, then click Highlight.');
      return;
    }
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Save highlight'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“$copied”',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Add a note (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    ctrl.dispose();
    if (!mounted || note == null) return;
    try {
      await _service.saveHighlight(_userId, widget.material.id, copied, note);
      await _load();
      if (mounted) {
        setState(() => _selectedQuote = null);
        _snack('Highlight saved.');
      }
    } catch (error) {
      if (mounted) _snack('Could not save highlight: $error');
    }
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(s), behavior: SnackBarBehavior.floating),
  );
  @override
  Widget build(BuildContext context) {
    final desktop = ResponsiveBreakpoints.isDesktop(context),
        dark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = dark ? Colors.white : const Color(0xff0f172a),
        bodyColor = dark ? const Color(0xffd6dfed) : const Color(0xff334155);
    final parts = _readableText.split(RegExp(r'(?=Slide \d+:)'));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.name, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: _highlight,
              icon: const Icon(Icons.highlight_alt_outlined),
              label: const Text('Highlight'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(desktop ? 34 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.material.extension.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xff32bd88),
                          letterSpacing: 1.4,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.material.name,
                        style: TextStyle(
                          fontSize: 27,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select a passage, then click Highlight to save it.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      for (final part in parts.where(
                        (p) => p.trim().isNotEmpty,
                      ))
                        _section(context, part, bodyColor),
                    ],
                  ),
                ),
              ),
              if (desktop)
                Container(
                  width: 330,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color:
                            dark
                                ? const Color(0xff334155)
                                : const Color(0xffe2e8f0),
                      ),
                    ),
                  ),
                  child: _panel(context, headingColor, bodyColor),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          !desktop
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: _highlight,
                    icon: const Icon(Icons.highlight_alt_outlined),
                    label: const Text('Highlight selection'),
                  ),
                ),
              )
              : null,
    );
  }

  Widget _section(BuildContext context, String raw, Color bodyColor) {
    final lines = raw.split('\n').where((s) => s.trim().isNotEmpty).toList(),
        heading = lines.firstOrNull ?? '',
        body = lines.skip(1).join('\n');
    final isSlide = heading.startsWith('Slide ');
    final displayedText = isSlide ? body : raw.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSlide)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Text(
                heading.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xff32bd88),
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          SelectableText.rich(
            TextSpan(
              children: _highlightSpans(displayedText, bodyColor),
              style: TextStyle(fontSize: 16, height: 1.8, color: bodyColor),
            ),
            onSelectionChanged: (selection, _) {
              if (selection.isValid && !selection.isCollapsed) {
                final selected = displayedText.substring(
                  selection.start,
                  selection.end,
                );
                if (selected != _selectedQuote) {
                  setState(() => _selectedQuote = selected);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _highlightSpans(String text, Color bodyColor) {
    final ranges = <({int start, int end})>[];
    for (final highlight in _highlights) {
      var from = 0;
      while (highlight.quote.isNotEmpty) {
        final index = text.indexOf(highlight.quote, from);
        if (index < 0) break;
        ranges.add((start: index, end: index + highlight.quote.length));
        from = index + highlight.quote.length;
      }
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start < cursor) continue;
      if (range.start > cursor)
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: const TextStyle(
            backgroundColor: Color(0xffffe58f),
            color: Color(0xff302900),
          ),
        ),
      );
      cursor = range.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }

  Widget _panel(BuildContext context, Color heading, Color body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'My highlights',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: heading,
                ),
              ),
            ),
            Text(
              '${_highlights.length}',
              style: const TextStyle(
                color: Color(0xff32bd88),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Select text, then click Highlight to save the passage.',
          style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _highlights.isEmpty
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text(
                      'Your saved key ideas will show here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children:
                      _highlights
                          .map(
                            (h) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xfffff4c2).withValues(
                                  alpha:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? .12
                                          : .65,
                                ),
                                border: Border.all(
                                  color: const Color(
                                    0xffd8bd5d,
                                  ).withValues(alpha: .4),
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '“${h.quote}”',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      color: body,
                                    ),
                                  ),
                                  if (h.note.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        h.note,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
      ),
    ],
  );
}
