"""Phone number normalization for BMONI lookups."""

import phonenumbers


class InvalidPhoneNumberError(ValueError):
    """Raised when a submitted phone number cannot be parsed into E.164."""


def normalize_phone_e164(raw_number, region='NG'):
    """Parse a user-submitted phone number into E.164 format.

    Defaults to the Nigeria (NG) numbering plan for numbers with no
    country code, since BMONI's sandbox is NG-focused.
    """
    if not raw_number:
        raise InvalidPhoneNumberError('Phone number is required.')
    try:
        parsed = phonenumbers.parse(raw_number, region)
    except phonenumbers.NumberParseException as e:
        raise InvalidPhoneNumberError(f'Could not parse phone number: {e}') from e
    if not phonenumbers.is_valid_number(parsed):
        raise InvalidPhoneNumberError('That phone number is not valid.')
    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
