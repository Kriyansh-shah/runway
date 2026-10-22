import Flutter
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model for the coach (iOS 26, Apple Intelligence).
/// Everything runs on the phone; nothing is sent anywhere. The Dart side
/// (lib/app/on_device_coach.dart) falls back to the rule-based coach when
/// this says it's unavailable or a reply fails.
enum CoachModel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "runway/coach", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "status":
        result(status())
      case "respond":
        guard let args = call.arguments as? [String: Any],
              let instructions = args["instructions"] as? String,
              let prompt = args["prompt"] as? String
        else {
          result(FlutterError(code: "bad_arguments", message: nil, details: nil))
          return
        }
        respond(instructions: instructions, prompt: prompt, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// "available", or why not: "notEligible" (older iPhone),
  /// "notEnabled" (Apple Intelligence off), "notReady" (still downloading),
  /// "unsupported" (before iOS 26).
  private static func status() -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available:
        return "available"
      case .unavailable(.deviceNotEligible):
        return "notEligible"
      case .unavailable(.appleIntelligenceNotEnabled):
        return "notEnabled"
      case .unavailable(.modelNotReady):
        return "notReady"
      case .unavailable:
        return "unsupported"
      }
    }
    #endif
    return "unsupported"
  }

  private static func respond(
    instructions: String,
    prompt: String,
    result: @escaping FlutterResult
  ) {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      Task {
        do {
          // A fresh session each time: every question carries its own facts.
          let session = LanguageModelSession(instructions: instructions)
          let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(temperature: 0.4)
          )
          await MainActor.run { result(response.content) }
        } catch {
          await MainActor.run {
            result(FlutterError(
              code: "generation_failed",
              message: String(describing: error),
              details: nil
            ))
          }
        }
      }
      return
    }
    #endif
    result(nil)
  }
}
