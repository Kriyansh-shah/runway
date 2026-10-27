import Flutter
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model for the coach (iOS 26, Apple Intelligence).
/// Everything runs on the phone; nothing is sent anywhere. The Dart side
/// (lib/app/on_device_coach.dart) falls back to the rule-based coach when
/// this says it's unavailable or a reply fails.
enum CoachModel {
  /// Also used the other way: the model's lookups ask Dart for numbers.
  private static var channel: FlutterMethodChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "runway/coach", binaryMessenger: messenger)
    Self.channel = channel
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
        respond(
          instructions: instructions,
          prompt: prompt,
          tools: args["tools"] as? Bool ?? false,
          result: result
        )
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
    tools: Bool,
    result: @escaping FlutterResult
  ) {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      Task {
        do {
          // A fresh session each time: every question carries its own facts.
          let session = if tools, let channel {
            LanguageModelSession(
              tools: [SpendingLookupTool(channel: channel)],
              instructions: instructions
            )
          } else {
            LanguageModelSession(instructions: instructions)
          }
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

#if canImport(FoundationModels)
/// Lets the model look up past spending while it answers ("How much did I
/// spend on coffee last week?"). Dart works out the numbers
/// (lib/app/spending_lookup.dart) and returns them as JSON.
@available(iOS 26.0, *)
struct SpendingLookupTool: Tool, @unchecked Sendable {
  let name = "lookUpSpending"
  let description =
    "Looks up what the student spent in a period: the total, each category, "
    + "the biggest expenses and how many days went over budget."

  @Generable
  struct Arguments {
    @Guide(
      description: "Which days to look at",
      .anyOf([
        "today", "yesterday", "thisWeek", "lastWeek", "thisMonth", "lastMonth",
        "wholeTerm", "oneDay",
      ])
    )
    var period: String

    @Guide(description: "Only for oneDay: the date as YYYY-MM-DD")
    var day: String?

    @Guide(description: "A category to narrow to, like coffee or eating out. Leave out for everything.")
    var category: String?
  }

  let channel: FlutterMethodChannel

  func call(arguments: Arguments) async throws -> String {
    var args: [String: Any] = ["period": arguments.period]
    if let day = arguments.day { args["day"] = day }
    if let category = arguments.category { args["category"] = category }
    let sendable = args as NSDictionary
    return await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        channel.invokeMethod("lookUp", arguments: sendable) { reply in
          continuation.resume(returning: reply as? String ?? #"{"error":"Lookup failed."}"#)
        }
      }
    }
  }
}
#endif
