# 🧠💀 Brainrot Bitcoin Wallet

A chaotic meme-themed Bitcoin & Lightning wallet that absolutely melts your brain. Experience crypto with maximum chaos energy! 🚀🌙

![Version](https://img.shields.io/badge/version-1.0.0-purple)
![Flutter](https://img.shields.io/badge/Flutter-3.8.1-blue)
![Bitcoin](https://img.shields.io/badge/Bitcoin-BDK-orange)
![Lightning](https://img.shields.io/badge/Lightning-LDK-yellow)

> **Warning**: This wallet contains extreme levels of meme energy. Use with caution. May cause uncontrollable urges to HODL.

<div align="center">
  <img src="https://github.com/user-attachments/assets/2e051377-4849-4d7a-95f7-3e2c4ad5e0bd" alt="Screenshot_20250616_224433" width="500"/>
</div>


## ✨ Features

### 🪙 Bitcoin Operations
- **Full Bitcoin Wallet**: Send, receive, and manage Bitcoin with BDK integration
- **Multi-Address Support**: Taproot, Native SegWit, Nested SegWit, and Legacy addresses
- **Dynamic Fee Estimation**: Smart fee calculations with confirmation time estimates
- **UTXO Management**: Complete coin control and transaction building
- **Mnemonic Backup**: Secure BIP39 seed phrase generation and recovery
- **Transaction History**: Complete transaction tracking with meme-themed labels

### ⚡ Lightning Network
- **Lightning Development Kit**: Full LDK node implementation
- **Instant Payments**: Near-zero fee Lightning transactions
- **Channel Management**: Open, close, and manage Lightning channels
- **Invoice System**: Create and pay Lightning invoices with expiry timers
- **Real-time Updates**: Live channel and payment status tracking

### 🔒 Security & Privacy
- **Biometric Authentication**: Fingerprint and face unlock
- **End-to-End Encryption**: All wallet data encrypted at rest
- **Secure Storage**: Flutter Secure Storage for sensitive data
- **Password Protection**: Wallet-level password encryption
- **Address Privacy**: Automatic address rotation to prevent reuse

### 🎮 Chaos Level System™
The unique **Chaos Level** (0-10) controls how brainrot your wallet becomes:

- **Level 0**: Professional, boring wallet (like a normie)
- **Level 5**: Moderate meme energy with sound effects
- **Level 10**: MAXIMUM CHAOS - glitch effects, particle explosions, pure brainrot

### 🎨 Meme-Themed UI/UX
- **Custom Fonts**: Comic Sans for maximum meme energy
- **Particle Systems**: Money emojis, Bitcoin symbols, and rocket ships
- **Glitch Effects**: Digital distortion at high chaos levels
- **Sound Effects**: Custom meme sounds for actions (moon, rekt, to the moon!)
- **Confetti Celebrations**: Particle explosions for successful transactions
- **Haptic Feedback**: Chaos-responsive vibration patterns

### 🎯 Core Functionality
- **QR Code Scanner**: Scan Bitcoin addresses and Lightning invoices
- **Price Ticker**: Real-time Bitcoin price with meme reactions
- **Network Support**: Testnet and Mainnet compatibility
- **Multi-Platform**: Android, iOS, Web, macOS, Linux, Windows
- **Offline Mode**: Local wallet operations without internet

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ^3.8.1
- Android Studio / Xcode for mobile development
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/DonGuillotine/brainrot_bitcoin_wallet_v1.git
   cd brainrot_bitcoin_wallet_v1
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code (Hive adapters)**
   ```bash
   flutter packages pub run build_runner build
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Development Commands

```bash
# Install dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Generate code (Hive type adapters)
flutter build runner build

# Run static analysis
flutter analyze

# Run tests
flutter test

# Build APK
flutter build apk

# Build iOS
flutter build ios
```

## 🏗 Architecture

### Service Architecture
- **Service Locator Pattern**: Centralized dependency injection
- **Provider State Management**: Reactive state updates
- **BDK Integration**: Bitcoin Development Kit for on-chain operations
- **LDK Integration**: Lightning Development Kit for Lightning Network

### Key Services
```
├── Bitcoin Services
│   ├── BdkService - On-chain Bitcoin operations
│   └── LdkService - Lightning Network operations
├── Security Services
│   ├── BiometricService - Fingerprint/face authentication
│   ├── EncryptionService - Data encryption
│   └── SecureStorageService - Encrypted storage
├── Network Services
│   ├── NetworkService - HTTP requests
│   └── PriceService - Real-time price data
└── UX Services
    ├── HapticService - Vibration feedback
    ├── SoundService - Meme sound effects
    └── LoggerService - Comprehensive logging
```

### Data Layer
- **Secure Storage**: Encrypted sensitive data (mnemonics, keys)
- **Hive Database**: Structured local data persistence
- **Shared Preferences**: Simple key-value storage

## 🎨 Theming System

The wallet features a unique **Chaos Theme** that responds to user-selected chaos levels:

```dart
// Chaos Level 0: Professional
colors: standard blues and grays
animations: minimal
sounds: disabled

// Chaos Level 10: MAXIMUM BRAINROT
colors: hot pink, cyan, purple gradients
animations: glitch effects, particle explosions
sounds: constant meme audio
effects: screen shake, confetti, chaos
```

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/specific_test.dart

# Run with coverage
flutter test --coverage
```

Tests include:
- Unit tests for services
- Widget tests for UI components
- Integration tests for wallet operations
- Mock implementations for external services

## 📱 Platform Support

| Platform | Status | Notes |
|----------|---------|-------|
| Android | ✅ Primary | Full feature support |
| iOS | ✅ Primary | Full feature support |
| Web | ⚠️ Limited | No biometrics, limited crypto |
| macOS | ⚠️ Limited | Desktop-optimized UI needed |
| Linux | ⚠️ Limited | Community support |
| Windows | ⚠️ Limited | Community support |

## 🔧 Configuration

### Network Configuration
- Default: **Testnet** (safe for development)
- Production: Switch to **Mainnet** in settings
- Lightning: Automatic network matching

### Chaos Configuration
Adjust your chaos level in Settings:
- **Chaos Level 0-2**: Professional mode
- **Chaos Level 3-6**: Moderate meme energy
- **Chaos Level 7-10**: FULL BRAINROT MODE

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-meme`)
3. Commit your changes (`git commit -m 'Add some amazing meme'`)
4. Push to the branch (`git push origin feature/amazing-meme`)
5. Open a Pull Request

### Development Guidelines
- Follow Flutter best practices
- Maintain the meme theme consistency
- Add tests for new features
- Update documentation
- Keep chaos levels functional

## 📊 Dependencies

### Core Dependencies
- **Bitcoin**: `bdk_flutter` - Bitcoin Development Kit
- **Lightning**: `ldk_node` - Lightning Development Kit
- **State Management**: `provider` - App state management
- **Navigation**: `go_router` - Declarative routing
- **Security**: `flutter_secure_storage`, `cryptography_plus`

### UI/UX Dependencies
- **Animations**: `flutter_animate`, `lottie`
- **Effects**: `confetti`, `shimmer`
- **QR Codes**: `qr_flutter`, `mobile_scanner`
- **Audio**: `audioplayers`
- **Fonts**: `google_fonts`

## 🐛 Known Issues

- Web platform has limited cryptographic capabilities
- Some animations may be performance-intensive on older devices
- Maximum chaos level may cause sensory overload

## 📄 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT) - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This is experimental software. Use at your own risk. Not financial advice. DYOR. 

**To the moon! 🚀🌙**

---

*Built with maximum meme energy by anons, for anons. HODL strong! 💎🙌*
