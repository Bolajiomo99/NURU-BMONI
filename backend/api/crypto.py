"""
Field-level encryption for secrets stored at rest (Mono access tokens).

IMPORTANT: this module must never import from api.models. Migration 0004
serializes the field as `api.crypto.EncryptedTextField`, so Django imports this
module while loading migrations — a circular import would break `migrate`.
"""

import base64
import hashlib
import logging

from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings
from django.db import models

logger = logging.getLogger(__name__)

_fernet = None


def _derive_key_from_secret():
    """Derive a stable Fernet key from SECRET_KEY.

    Lets local dev and the test suite run without provisioning a separate
    secret. Production sets FIELD_ENCRYPTION_KEY explicitly — rotating
    SECRET_KEY would otherwise make every stored token undecryptable.
    """
    digest = hashlib.sha256(settings.SECRET_KEY.encode('utf-8')).digest()
    return base64.urlsafe_b64encode(digest)


def get_fernet():
    """Return the process-wide Fernet instance, building it on first use."""
    global _fernet
    if _fernet is None:
        key = getattr(settings, 'FIELD_ENCRYPTION_KEY', '') or ''
        _fernet = Fernet(key.encode('utf-8') if key else _derive_key_from_secret())
    return _fernet


def reset_fernet_cache():
    """Drop the cached instance. Used by tests that override the key."""
    global _fernet
    _fernet = None


def encrypt(value):
    """Encrypt a string. Empty values pass through as ''."""
    if value is None or value == '':
        return ''
    return get_fernet().encrypt(str(value).encode('utf-8')).decode('utf-8')


def decrypt(token):
    """Decrypt a string, returning '' if it is not valid ciphertext.

    Never raises: a corrupt or key-rotated row must degrade to "no token"
    rather than 500 every request that touches the record.
    """
    if not token:
        return ''
    try:
        return get_fernet().decrypt(str(token).encode('utf-8')).decode('utf-8')
    except (InvalidToken, ValueError, TypeError) as e:
        logger.error(f"Failed to decrypt stored value: {type(e).__name__}")
        return ''


class EncryptedTextField(models.TextField):
    """TextField that transparently encrypts on write and decrypts on read.

    The database column holds Fernet ciphertext. Because Fernet embeds a random
    IV, the same plaintext encrypts differently each time, so this field cannot
    be filtered or indexed on — look rows up by a separate plaintext column.
    """

    def get_prep_value(self, value):
        return encrypt(super().get_prep_value(value))

    def from_db_value(self, value, expression, connection):
        return decrypt(value)
