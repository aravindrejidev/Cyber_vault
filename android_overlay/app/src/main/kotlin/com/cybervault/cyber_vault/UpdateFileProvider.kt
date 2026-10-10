package com.cybervault.cyber_vault

import androidx.core.content.FileProvider

// Own subclass so this provider can never clash with a FileProvider entry
// declared by another library.
class UpdateFileProvider : FileProvider()
