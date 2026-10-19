import 'dart:typed_data';

import 'package:cyber_vault/core/crypto/crypto_service.dart';
import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/documents/domain/document_entry.dart';
import 'package:cyber_vault/features/documents/presentation/document_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart'
    show PdfViewer, PdfViewerParams, PdfTextSelectionParams;

/// Shows the files of a document one at a time (previous / next buttons)
/// without ever writing decrypted data to disk:
///  * the encrypted blob is decrypted into RAM,
///  * PDFs are rendered by PDFium straight from memory,
///  * images are decoded with Image.memory.
/// The page closes itself the moment the app goes to the background, and wipes
/// the decrypted bytes when it is disposed or another file is shown.
class DocumentViewerPage extends ConsumerStatefulWidget {
  const DocumentViewerPage({
    super.key,
    required this.entry,
    this.initialIndex = 0,
  });

  final DocumentEntry entry;
  final int initialIndex;

  @override
  ConsumerState<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends ConsumerState<DocumentViewerPage> {
  late int _index;
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;
  int _loadToken = 0;

  List<DocumentFile> get _files => widget.entry.files;
  DocumentFile get _file => _files[_index];

  @override
  void initState() {
    super.initState();
    final int last = _files.isEmpty ? 0 : _files.length - 1;
    final int wanted = widget.initialIndex;
    _index = wanted < 0 ? 0 : (wanted > last ? last : wanted);
    backgroundSignal.addListener(_onBackground);
    if (_files.isEmpty) {
      _loading = false;
      _error = 'This document has no files.';
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    backgroundSignal.removeListener(_onBackground);
    _loadToken++;
    CryptoService.wipe(_bytes);
    _bytes = null;
    _dropImageCache();
    super.dispose();
  }

  void _dropImageCache() {
    final ImageCache cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }

  void _onBackground() {
    if (!mounted) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _load() async {
    final int token = ++_loadToken;
    try {
      final Uint8List data = await ref.read(documentRepositoryProvider).readFileBytes(_file);
      if (!mounted || token != _loadToken) {
        CryptoService.wipe(data);
        return;
      }
      setState(() {
        _bytes = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = 'Could not decrypt this file. It may be damaged.';
        _loading = false;
      });
    }
  }

  void _go(int index) {
    if (index < 0 || index >= _files.length || index == _index) return;
    reportUserActivity();
    CryptoService.wipe(_bytes);
    _dropImageCache();
    setState(() {
      _index = index;
      _bytes = null;
      _error = null;
      _loading = true;
    });
    _load();
  }

  Widget _buildBody() {
    final String? error = _error;
    if (error != null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: ErrorBox(error)),
      );
    }

    final Uint8List? bytes = _bytes;
    if (_loading || bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final DocumentFile file = _file;
    if (file.kind == DocumentKind.pdf) {
      return KeyedSubtree(
        key: ValueKey<String>(file.id),
        child: PdfViewer.data(
          bytes,
          sourceName: file.id,
          params: PdfViewerParams(
            // No text selection: it would allow copying content to the clipboard.
            textSelectionParams: PdfTextSelectionParams(enabled: false),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: ValueKey<String>(file.id),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 6,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                const Text('This image cannot be displayed.'),
          ),
        ),
      ),
    );
  }

  Widget? _buildNavigationBar() {
    if (_files.length < 2) return null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(top: BorderSide(color: AppColors.ink, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.chevron_left, size: 34),
                onPressed: _index > 0 ? () => _go(_index - 1) : null,
              ),
              Text(
                '${_index + 1} / ${_files.length}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.chevron_right, size: 34),
                onPressed: _index < _files.length - 1 ? () => _go(_index + 1) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = _files.isEmpty ? widget.entry.name : _file.name;
    return Scaffold(
      appBar: BrutalAppBar(title: title),
      body: _buildBody(),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }
}
