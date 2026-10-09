import 'dart:typed_data';

import 'package:cyber_vault/core/crypto/crypto_service.dart';
import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/features/documents/domain/document_entry.dart';
import 'package:cyber_vault/features/documents/presentation/document_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart'
    show PdfViewer, PdfViewerParams, PdfTextSelectionParams;

/// Shows a document without ever writing decrypted data to disk:
///  * the encrypted blob is decrypted into RAM,
///  * PDFs are rendered by PDFium straight from memory,
///  * images are decoded with Image.memory.
/// The page closes itself the moment the app goes to the background, and wipes
/// the decrypted bytes when it is disposed.
class DocumentViewerPage extends ConsumerStatefulWidget {
  const DocumentViewerPage({super.key, required this.entry});

  final DocumentEntry entry;

  @override
  ConsumerState<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends ConsumerState<DocumentViewerPage> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    backgroundSignal.addListener(_onBackground);
    _load();
  }

  @override
  void dispose() {
    backgroundSignal.removeListener(_onBackground);
    CryptoService.wipe(_bytes);
    _bytes = null;
    final ImageCache cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    super.dispose();
  }

  void _onBackground() {
    if (!mounted) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _load() async {
    try {
      final Uint8List data =
          await ref.read(documentRepositoryProvider).readBytes(widget.entry);
      if (!mounted) {
        CryptoService.wipe(data);
        return;
      }
      setState(() => _bytes = data);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not decrypt this file. It may be damaged.';
      });
    }
  }

  Widget _buildBody() {
    final String? error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      );
    }

    final Uint8List? bytes = _bytes;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.entry.kind == DocumentKind.pdf) {
      return PdfViewer.data(
        bytes,
        sourceName: widget.entry.id,
        params: PdfViewerParams(
          // No text selection: it would allow copying content to the clipboard.
          textSelectionParams: PdfTextSelectionParams(enabled: false),
        ),
      );
    }

    return InteractiveViewer(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
      ),
      body: _buildBody(),
    );
  }
}
