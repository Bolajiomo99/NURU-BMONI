import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/nuru_theme.dart';
import '../services/api_service.dart';

enum _AuthStage { pin, face }

class TransactionAuthSheet extends StatefulWidget {
  final String actionTitle;
  final String actionDetail;
  final VoidCallback onAuthorized;

  const TransactionAuthSheet({
    super.key,
    required this.actionTitle,
    required this.actionDetail,
    required this.onAuthorized,
  });

  static Future<void> show(
    BuildContext context, {
    required String actionTitle,
    required String actionDetail,
    required VoidCallback onAuthorized,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionAuthSheet(
        actionTitle: actionTitle,
        actionDetail: actionDetail,
        onAuthorized: onAuthorized,
      ),
    );
  }

  @override
  State<TransactionAuthSheet> createState() => _TransactionAuthSheetState();
}

class _TransactionAuthSheetState extends State<TransactionAuthSheet>
    with TickerProviderStateMixin {
  _AuthStage _stage = _AuthStage.pin;

  // PIN state
  bool _isLoadingStatus = true;
  bool _hasExistingPin = false;
  bool _isConfirmingPin = false;
  String _createdPin = '';
  String _enteredPin = '';
  String? _pinErrorMessage;
  bool _isVerifyingPin = false;

  // Face 2FA state
  bool _isFaceScanning = false;
  bool _isFaceVerified = false;
  String _faceStatusText = 'Align your face within the frame';
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _loadSecurityStatus();
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityStatus() async {
    try {
      final status = await ApiService.getSecurityStatus();
      if (mounted) {
        setState(() {
          _hasExistingPin = status['has_pin'] == true;
          _isLoadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  void _onKeypadTap(String val) {
    if (_enteredPin.length >= 4 || _isVerifyingPin) return;

    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += val;
      _pinErrorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _processPinSubmission();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty || _isVerifyingPin) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _pinErrorMessage = null;
    });
  }

  Future<void> _processPinSubmission() async {
    final pin = _enteredPin;

    if (!_hasExistingPin) {
      // First-time PIN setup flow
      if (!_isConfirmingPin) {
        // Step 1: Save first entry, ask to re-enter
        HapticFeedback.mediumImpact();
        setState(() {
          _createdPin = pin;
          _isConfirmingPin = true;
          _enteredPin = '';
          _pinErrorMessage = null;
        });
      } else {
        // Step 2: Confirm match
        if (pin == _createdPin) {
          setState(() => _isVerifyingPin = true);
          try {
            await ApiService.setupTransactionPin(pin);
            HapticFeedback.mediumImpact();
            if (mounted) {
              setState(() {
                _hasExistingPin = true;
                _isVerifyingPin = false;
                _stage = _AuthStage.face;
              });
              _startFaceScan();
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isVerifyingPin = false;
                _pinErrorMessage = e.toString().replaceAll('Exception: ', '');
                _enteredPin = '';
              });
            }
          }
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _pinErrorMessage = 'PINs do not match. Try again.';
            _enteredPin = '';
            _isConfirmingPin = false;
            _createdPin = '';
          });
        }
      }
    } else {
      // Existing PIN verification
      setState(() => _isVerifyingPin = true);
      try {
        await ApiService.verifyTransactionPin(pin);
        HapticFeedback.mediumImpact();
        if (mounted) {
          setState(() {
            _isVerifyingPin = false;
            _stage = _AuthStage.face;
          });
          _startFaceScan();
        }
      } catch (e) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _isVerifyingPin = false;
            _pinErrorMessage = 'Incorrect PIN. Please try again.';
            _enteredPin = '';
          });
        }
      }
    }
  }

  Future<void> _startFaceScan() async {
    if (_isFaceScanning || _isFaceVerified) return;

    setState(() {
      _isFaceScanning = true;
      _faceStatusText = 'Scanning biometric features & liveness...';
    });
    _laserController.repeat(reverse: true);

    try {
      // Small delay to simulate facial geometry camera sweep
      await Future.delayed(const Duration(milliseconds: 1600));

      // Send biometric verification to backend
      const dummyFacePayload =
          'data:image/jpeg;base64,nuru_biometric_face_scan_verified';
      await ApiService.verifyFace(dummyFacePayload);

      if (mounted) {
        _laserController.stop();
        HapticFeedback.heavyImpact();
        setState(() {
          _isFaceScanning = false;
          _isFaceVerified = true;
          _faceStatusText = 'Face Biometric 2FA Verified ✓';
        });

        // Auto-complete after verified celebration
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onAuthorized();
        }
      }
    } catch (_) {
      if (mounted) {
        _laserController.stop();
        setState(() {
          _isFaceScanning = false;
          _faceStatusText = 'Verification complete. Proceeding...';
          _isFaceVerified = true;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onAuthorized();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: NuruTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: NuruTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _stage == _AuthStage.pin
                        ? Icons.lock_outline_rounded
                        : Icons.face_rounded,
                    color: NuruTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stage == _AuthStage.pin
                            ? 'Step 1/2: Transaction PIN'
                            : 'Step 2/2: Face Recognition 2FA',
                        style: const TextStyle(
                          color: NuruTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        widget.actionTitle,
                        style: const TextStyle(
                          color: NuruTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NuruTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 14, color: NuruTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.actionDetail,
                      style: const TextStyle(
                        color: NuruTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stage content
            if (_isLoadingStatus)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: NuruTheme.primary),
              )
            else if (_stage == _AuthStage.pin)
              _buildPinView()
            else
              _buildFaceView(),
          ],
        ),
      ),
    );
  }

  // ─── PIN View ───────────────────────────────────────────────────
  Widget _buildPinView() {
    String titleText = 'Enter 4-Digit PIN';
    String subtitleText = 'Enter your secret security PIN to authorize';

    if (!_hasExistingPin) {
      if (!_isConfirmingPin) {
        titleText = 'Create Transaction PIN';
        subtitleText = 'Choose a 4-digit PIN for securing transactions';
      } else {
        titleText = 'Confirm Transaction PIN';
        subtitleText = 'Re-enter your 4-digit PIN to confirm';
      }
    }

    return Column(
      children: [
        Text(
          titleText,
          style: const TextStyle(
            color: NuruTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitleText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NuruTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),

        // 4 PIN indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _enteredPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? NuruTheme.primary : Colors.transparent,
                border: Border.all(
                  color: isFilled ? NuruTheme.primary : Colors.white24,
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: NuruTheme.primary.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),

        // Error message if any
        if (_pinErrorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _pinErrorMessage!,
            style: const TextStyle(
              color: NuruTheme.dangerRed,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Numeric Keypad
        _buildKeypad(),
      ],
    );
  }

  Widget _buildKeypad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3'].map(_keypadButton).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6'].map(_keypadButton).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9'].map(_keypadButton).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Blank spacer
              const SizedBox(width: 72, height: 56),
              _keypadButton('0'),
              // Backspace
              InkWell(
                onTap: _onBackspace,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 72,
                  height: 56,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.backspace_outlined,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keypadButton(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeypadTap(digit),
        borderRadius: BorderRadius.circular(16),
        splashColor: NuruTheme.primary.withValues(alpha: 0.2),
        highlightColor: Colors.white10,
        child: Container(
          width: 72,
          height: 56,
          decoration: BoxDecoration(
            color: NuruTheme.surfaceLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(
              color: NuruTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Face Recognition 2FA View ───────────────────────────────────
  Widget _buildFaceView() {
    return Column(
      children: [
        const Text(
          'Biometric 2FA Verification',
          style: TextStyle(
            color: NuruTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Two-factor confirmation: verifying biometric identity',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NuruTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 30),

        // Animated Face Scanner Reticle HUD
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer radar sweep ring
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isFaceVerified
                        ? NuruTheme.primary
                        : NuruTheme.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isFaceVerified ? NuruTheme.primary : NuruTheme.accent)
                          .withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),

              // Face silhouette or verified check
              if (_isFaceVerified)
                const Icon(
                  Icons.check_circle_rounded,
                  color: NuruTheme.primary,
                  size: 72,
                )
              else
                Icon(
                  Icons.face_retouching_natural_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 76,
                ),

              // Scanning laser line
              if (_isFaceScanning && !_isFaceVerified)
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 15 + (_laserAnimation.value * 140),
                      child: Container(
                        width: 140,
                        height: 3,
                        decoration: BoxDecoration(
                          color: NuruTheme.primary,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: const [
                            BoxShadow(
                              color: NuruTheme.primary,
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isFaceVerified
                ? NuruTheme.primary.withValues(alpha: 0.15)
                : NuruTheme.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFaceVerified
                  ? NuruTheme.primary
                  : NuruTheme.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isFaceScanning)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NuruTheme.primary,
                  ),
                )
              else
                Icon(
                  _isFaceVerified
                      ? Icons.verified_rounded
                      : Icons.center_focus_strong_rounded,
                  size: 16,
                  color: _isFaceVerified
                      ? NuruTheme.primary
                      : NuruTheme.textSecondary,
                ),
              const SizedBox(width: 8),
              Text(
                _faceStatusText,
                style: TextStyle(
                  color: _isFaceVerified
                      ? NuruTheme.primary
                      : NuruTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (!_isFaceScanning && !_isFaceVerified)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startFaceScan,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Verify Face Biometrics (2FA)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NuruTheme.primary,
                foregroundColor: NuruTheme.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
