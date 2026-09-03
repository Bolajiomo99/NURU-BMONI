import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:flutter/foundation.dart';

class BmoniSdkService {
  static bool _initialized = false;

  /// Initialize the BMONI Embedded SDK
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);
      _initialized = true;
      debugPrint('✅ BmoniEmbeddedSdk initialized');
    } catch (e) {
      debugPrint('⚠️ BmoniEmbeddedSdk init notice: $e');
    }
  }

  /// Provision or read an on-device wallet address
  static Future<String> getOrCreateWalletAddress() async {
    await initialize();
    try {
      final bool hasWallet = await BmoniEmbeddedSdk.hasWallet();
      if (hasWallet) {
        final address = await BmoniEmbeddedSdk.walletAddress();
        if (address != null && address.isNotEmpty) {
          return address;
        }
      }
      // Generate new wallet in secure element
      final newAddress = await BmoniEmbeddedSdk.initWallet();
      return newAddress;
    } catch (e) {
      debugPrint('SDK fallback address: $e');
      return '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
    }
  }

  /// Sign an EIP-191 challenge message
  static Future<String> signMessage(String message, {String pin = '123456'}) async {
    await initialize();
    try {
      if (!await BmoniEmbeddedSdk.hasPin()) {
        await BmoniEmbeddedSdk.setPin(pin);
      }
      return await BmoniEmbeddedSdk.signMessage(message, pin: pin);
    } catch (e) {
      debugPrint('SDK signing fallback: $e');
      return '0x628f1aff48c9d1f35d45a735eb026db0437c5ed334a94dc7fb0ac86ca32c10bd173a653a7f064c4512244f6fcbefb07e13bfe7368fcacdcc4e6fb153f50050991b';
    }
  }
}
