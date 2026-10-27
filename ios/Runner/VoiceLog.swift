import AppIntents
import Flutter
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Runway through Siri (and Shortcuts, Spotlight, the Action button):
/// "Log lunch in Runway", "How much can I spend today in Runway?".
///
/// Nothing here opens the app. A logged expense waits in a small inbox; the
/// Dart side (lib/app/voice_inbox.dart) takes it whenever Runway opens or
/// comes back, and files it like a Quick Add. To answer questions, the app
/// leaves a copy of its numbers here ([Budget]) after every change, and
/// anything still in the inbox is taken off them.
enum VoiceLog {
  private static let inboxKey = "runway.voiceInbox"
  private static let budgetKey = "runway.budget"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "runway/voice", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "take":
        result(take())
      case "share":
        if let json = call.arguments as? String {
          UserDefaults.standard.set(json, forKey: budgetKey)
        } else {
          UserDefaults.standard.removeObject(forKey: budgetKey)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Everything waiting, oldest first; the inbox is empty afterwards.
  /// Always on the main thread, so a Siri log can't slip in between.
  static func take() -> [[String: Any]] {
    let defaults = UserDefaults.standard
    let waiting = defaults.array(forKey: inboxKey) as? [[String: Any]] ?? []
    defaults.removeObject(forKey: inboxKey)
    return waiting
  }

  /// [what] is what it was ("Chipotle", or everything said without Apple
  /// Intelligence); the Dart side cleans it into a note. [category] is a
  /// Dart ExpenseCategory name and [custom] one of the person's own
  /// category names, when known.
  @MainActor
  static func add(amount: Double, what: String, category: String?, custom: String?) {
    let defaults = UserDefaults.standard
    var waiting = defaults.array(forKey: inboxKey) as? [[String: Any]] ?? []
    var entry: [String: Any] = [
      "amount": amount,
      "what": what,
      "at": Date().timeIntervalSince1970 * 1000,
    ]
    if let category { entry["category"] = category }
    if let custom { entry["custom"] = custom }
    waiting.append(entry)
    defaults.set(waiting, forKey: inboxKey)
  }

  /// Logged through Siri but not in the app yet: (which day, how much).
  @MainActor
  static var pending: [(day: String, amount: Double)] {
    let waiting = UserDefaults.standard.array(forKey: inboxKey) as? [[String: Any]] ?? []
    return waiting.compactMap { entry in
      guard let amount = entry["amount"] as? Double, let at = entry["at"] as? Double
      else { return nil }
      return (Budget.key(Date(timeIntervalSince1970: at / 1000)), amount)
    }
  }

  /// The app's latest numbers, or nil if it hasn't left any yet.
  static var savedBudget: Budget? {
    guard let json = UserDefaults.standard.string(forKey: budgetKey),
          let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(Budget.self, from: data)
  }

  /// The first amount in "8 bucks on coffee" or "$23.40 Uber", if it was
  /// said in digits (Siri writes most amounts that way).
  static func amount(in said: String) -> Double? {
    let pattern = #"\$?\s?(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(
            in: said, range: NSRange(said.startIndex..., in: said)),
          let whole = Range(match.range(at: 1), in: said)
    else { return nil }
    var text = said[whole].replacingOccurrences(of: ",", with: "")
    if let cents = Range(match.range(at: 2), in: said) {
      text += "." + said[cents]
    }
    guard let value = Double(text), value > 0, value < 100_000 else { return nil }
    return value
  }

  /// Whether an amount was said at all, in digits or words. Apple
  /// Intelligence's amount is only trusted when one was, so "log lunch"
  /// can't come back with a made-up price.
  static func mentionsAmount(_ said: String) -> Bool {
    if said.rangeOfCharacter(from: .decimalDigits) != nil { return true }
    let words = Set(said.lowercased().split { !$0.isLetter }.map(String.init))
    let numbers: Set<String> = [
      "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
      "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
      "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty", "sixty",
      "seventy", "eighty", "ninety", "hundred", "thousand", "half", "dollar",
      "dollars", "bucks", "buck",
    ]
    return !words.isDisjoint(with: numbers)
  }
}

// MARK: - The budget, as the app last saw it

/// Mirrors AppState.siriSummary in lib/app/app_state.dart.
struct Budget: Decodable {
  let day: String
  let period: String
  let termEnd: String
  let available: Double
  let spentToday: Double
  let daysLeft: Int
  let allowance: Double
  let safeToday: Double
  let savingsGoal: Double
  let onTrack: Bool?
  let runsOut: String?
  let days: [String: Double]
  let weekTop: [Top]
  let categories: [String]

  struct Top: Decodable {
    let label: String
    let emoji: String
    let amount: Double
  }

  static func key(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }

  static func date(_ key: String) -> Date? {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return Calendar.current.date(
      from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }

  /// Today's numbers, with Siri logs the app hasn't taken yet taken off.
  /// If the app was last open on an earlier day, today's allowance is
  /// worked out the way the app does it. Nil once the term has ended.
  @MainActor
  func now() -> Today? {
    let today = Calendar.current.startOfDay(for: Date())
    let todayKey = Budget.key(today)
    guard let saved = Budget.date(day), let end = Budget.date(termEnd), today <= end
    else { return nil }
    let gap = Calendar.current.dateComponents([.day], from: saved, to: today).day ?? 0
    let pending = VoiceLog.pending
    let pendingToday = pending.filter { $0.day == todayKey }.reduce(0) { $0 + $1.amount }
    let pendingBefore = pending.filter { $0.day != todayKey }.reduce(0) { $0 + $1.amount }

    let weekKeys = Set((0..<7).compactMap {
      Calendar.current.date(byAdding: .day, value: -$0, to: today).map(Budget.key)
    })
    let week = days.filter { weekKeys.contains($0.key) }.values.reduce(0, +)
      + pending.filter { weekKeys.contains($0.day) }.reduce(0) { $0 + $1.amount }

    if gap <= 0 {
      return Today(
        safe: safeToday - pendingToday,
        allowance: allowance,
        spent: spentToday + pendingToday,
        left: available - pendingToday - pendingBefore,
        daysLeft: daysLeft,
        week: week)
    }
    let daysLeftNow = max(1, daysLeft - gap)
    let left = available - pendingBefore
    let newAllowance = left / Double(daysLeftNow)
    return Today(
      safe: newAllowance - pendingToday,
      allowance: newAllowance,
      spent: pendingToday,
      left: left - pendingToday,
      daysLeft: daysLeftNow,
      week: week)
  }

  struct Today {
    /// Still OK to spend today; negative when over.
    let safe: Double
    let allowance: Double
    let spent: Double
    /// Left for the rest of the term, after big costs and savings.
    let left: Double
    let daysLeft: Int
    /// Spent over the last 7 days, today included.
    let week: Double
  }
}

extension Double {
  /// "$12" or "$4.50".
  var dollars: String {
    let cents = (self * 100).rounded() / 100
    return cents.formatted(
      .currency(code: "USD").precision(.fractionLength(cents == cents.rounded() ? 0 : 2)))
  }
}

/// "$23 left for today." or "That's $8 over today's budget."
private func todayLine(_ today: Budget.Today) -> String {
  if today.left <= 0 {
    return "There's nothing left to spend this period."
  }
  if today.safe >= 0.005 {
    return "\(today.safe.dollars) left for today."
  }
  return "That's \((-today.safe).dollars) over today's budget."
}

// MARK: - Understanding what was said (Apple Intelligence)

/// What a sentence like "split a pizza with Sam, my half was 9" means.
struct Understood: Sendable {
  var amount: Double?
  var item: String?
  /// A Dart ExpenseCategory name.
  var category: String?
  /// One of the person's own categories.
  var custom: String?
}

enum Understanding {
  /// Apple's on-device model reads the sentence, when it's there (iOS 26,
  /// Apple Intelligence on). Nothing leaves the phone. Nil otherwise, or if
  /// it's slow or fails; the app's own rules then work it out.
  static func read(_ said: String, ownCategories: [String]) async -> Understood? {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      guard case .available = SystemLanguageModel.default.availability else { return nil }
      return await withTaskGroup(of: Understood?.self) { group in
        group.addTask { await ask(said, ownCategories: ownCategories) }
        group.addTask {
          try? await Task.sleep(for: .seconds(6))
          return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
      }
    }
    #endif
    return nil
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, *)
  private static func ask(_ said: String, ownCategories: [String]) async -> Understood? {
    let own = ownCategories.isEmpty
      ? "They have no categories of their own."
      : "Their own categories are: \(ownCategories.joined(separator: ", "))."
    let session = LanguageModelSession(instructions: """
      You read one sentence a college student said to log money they spent, \
      and pull out the details. The amount is only what they paid themselves: \
      for a shared or split bill, just their share. Never guess an amount \
      that wasn't said. \(own) Pick one of their own categories only if it \
      clearly fits.
      """)
    do {
      let reply = try await session.respond(
        to: said,
        generating: SpokenSpend.self,
        options: GenerationOptions(temperature: 0)
      ).content
      let item = reply.item.trimmingCharacters(in: .whitespacesAndNewlines)
      let custom = reply.ownCategory.flatMap { name in
        ownCategories.first { $0.caseInsensitiveCompare(name) == .orderedSame }
      }
      return Understood(
        amount: reply.amount.flatMap { $0 > 0 && $0 < 100_000 ? $0 : nil },
        item: item.isEmpty ? nil : item,
        category: reply.category == .other ? nil : reply.category.rawValue,
        custom: custom)
    } catch {
      return nil
    }
  }
  #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct SpokenSpend {
  @Guide(description: "Dollars the speaker paid themselves. For a split or shared bill, only their share. Null if no amount was said.")
  var amount: Double?

  @Guide(description: "What it was or where, in 1 to 4 words, like \"Chipotle\" or \"Uber to the airport\". No amount, no words like 'spent' or 'paid'.")
  var item: String

  @Guide(description: "The best fitting category.")
  var category: SpokenCategory

  @Guide(description: "One of the person's own category names, only if it clearly fits. Null otherwise.")
  var ownCategory: String?
}

/// Raw values are the Dart ExpenseCategory names.
@available(iOS 26.0, *)
@Generable
enum SpokenCategory: String {
  case coffee, groceries, eatingOut, lateNight, delivery, rideshare, transit
  case supplies, travel, shopping, fun, bills, other
}
#endif

// MARK: - Logging

/// Categories you can say in the first sentence: "Log coffee in Runway".
/// Raw values are the Dart ExpenseCategory names.
@available(iOS 17.0, *)
enum SpendingKind: String, AppEnum {
  case coffee, groceries, eatingOut, lateNight, delivery, rideshare, transit
  case supplies, travel, shopping, fun, bills

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
  static var caseDisplayRepresentations: [SpendingKind: DisplayRepresentation] = [
    .coffee: DisplayRepresentation(
      title: "coffee", synonyms: ["a coffee", "a latte", "Starbucks", "boba", "tea"]),
    .groceries: DisplayRepresentation(
      title: "groceries", synonyms: ["food shopping", "Trader Joe's", "Costco"]),
    .eatingOut: DisplayRepresentation(
      title: "eating out",
      synonyms: ["lunch", "dinner", "breakfast", "brunch", "food", "a meal", "Chipotle"]),
    .lateNight: DisplayRepresentation(
      title: "late-night food", synonyms: ["pizza", "a late night snack"]),
    .delivery: DisplayRepresentation(
      title: "delivery", synonyms: ["DoorDash", "Uber Eats", "takeout", "Amazon"]),
    .rideshare: DisplayRepresentation(
      title: "an Uber", synonyms: ["Uber", "a Lyft", "Lyft", "a ride", "a taxi", "a cab"]),
    .transit: DisplayRepresentation(
      title: "transit", synonyms: ["the subway", "the bus", "a train", "gas", "parking"]),
    .supplies: DisplayRepresentation(
      title: "school supplies", synonyms: ["supplies", "a textbook", "books", "printing"]),
    .travel: DisplayRepresentation(
      title: "travel", synonyms: ["a flight", "a hotel", "a trip"]),
    .shopping: DisplayRepresentation(
      title: "shopping", synonyms: ["clothes", "shoes", "Target"]),
    .fun: DisplayRepresentation(
      title: "fun", synonyms: ["a movie", "a concert", "tickets", "drinks", "going out"]),
    .bills: DisplayRepresentation(
      title: "a bill", synonyms: ["bills", "rent", "a subscription", "my phone bill"]),
  ]
}

/// ExpenseCategory's emoji and label (lib/app/models.dart), by name.
let categoryShown: [String: (emoji: String, label: String)] = [
  "coffee": ("☕", "Coffee"), "groceries": ("🛒", "Groceries"),
  "transit": ("🚇", "Transit"), "lateNight": ("🍕", "Late-night food"),
  "delivery": ("📦", "Delivery"), "supplies": ("📚", "Supplies"),
  "rideshare": ("🚕", "Uber / ride"), "travel": ("✈️", "Travel"),
  "eatingOut": ("🍔", "Eating out"), "shopping": ("🛍️", "Shopping"),
  "fun": ("🎉", "Fun"), "bills": ("🧾", "Bills"),
]

@available(iOS 17.0, *)
struct LogExpenseIntent: AppIntent {
  static var title: LocalizedStringResource = "Log an expense"
  static var description = IntentDescription(
    "Adds money you spent to your Runway budget, like a Quick Add. Say it any way you like: \"8 bucks on coffee\"."
  )
  // Only from an unlocked phone, so nobody can add to your budget (or hear
  // it) from the lock screen. It never opens the app.
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  static var openAppWhenRun = false

  @Parameter(
    title: "What you spent",
    description: "Anything like \"12 dollars at Chipotle\" or \"Uber to the airport\"."
  )
  var spent: String?

  @Parameter(title: "Category")
  var category: SpendingKind?

  @Parameter(
    title: "Amount",
    description: "How much you spent, in dollars.",
    inclusiveRange: (0.01, 99_999)
  )
  var amount: Double?

  static var parameterSummary: some ParameterSummary {
    Summary("Log \(\.$spent)") {
      \.$category
      \.$amount
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    // "Log coffee in Runway" already says what it was; otherwise one open
    // question takes anything: "8 bucks on coffee", "$23 Uber".
    var said = spent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if said.isEmpty, category == nil {
      said = try await $spent.requestValue(IntentDialog("What did you spend?"))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let budget = VoiceLog.savedBudget
    let understood = said.isEmpty
      ? nil
      : await Understanding.read(said, ownCategories: budget?.categories ?? [])
    let heardAmount = VoiceLog.mentionsAmount(said)
      ? (understood?.amount ?? VoiceLog.amount(in: said))
      : nil
    var value = amount ?? heardAmount
    if value == nil {
      value = try await $amount.requestValue(IntentDialog("How much was it?"))
    }
    let cents = ((value ?? 0) * 100).rounded() / 100
    guard cents > 0, cents < 100_000 else {
      throw $amount.needsValueError(IntentDialog("How much was it, in dollars?"))
    }

    let kind = category?.rawValue ?? understood?.category
    let label = category.map {
      String(localized: SpendingKind.caseDisplayRepresentations[$0]!.title)
    }
    // A clean name to say back: Apple Intelligence's, or the category's.
    let item = understood?.item ?? (said.isEmpty ? label : nil)
    VoiceLog.add(
      amount: cents,
      what: understood?.item ?? (said.isEmpty ? label ?? "" : said),
      category: kind,
      custom: understood?.custom)

    let today = budget?.now()
    var dialog = item.map { "Logged \(cents.dollars) for \($0)." } ?? "Logged \(cents.dollars)."
    if let today { dialog += " " + todayLine(today) }
    let shown = understood?.custom.map { (emoji: "🏷️", label: $0) }
      ?? kind.flatMap { categoryShown[$0] }
    return .result(
      dialog: IntentDialog(stringLiteral: dialog),
      view: LoggedCard(
        amount: cents,
        item: item ?? said,
        emoji: shown?.emoji ?? "💸",
        category: shown?.label,
        today: today))
  }
}

/// The card under Siri's reply: what was logged, and what's left today.
struct LoggedCard: View {
  let amount: Double
  let item: String
  let emoji: String
  let category: String?
  let today: Budget.Today?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Text(emoji).font(.system(size: 30))
        VStack(alignment: .leading, spacing: 2) {
          Text(item.isEmpty ? "Expense" : item).font(.headline).lineLimit(1)
          if let category {
            Text(category).font(.subheadline).foregroundStyle(.secondary)
          }
        }
        Spacer()
        Text(amount.dollars).font(.title2.weight(.bold)).monospacedDigit()
      }
      if let today {
        Divider()
        HStack {
          Text(today.safe >= 0.005 ? "Left for today" : "Over today's budget")
            .font(.subheadline).foregroundStyle(.secondary)
          Spacer()
          Text(abs(today.safe).dollars)
            .font(.subheadline.weight(.semibold)).monospacedDigit()
            .foregroundStyle(today.safe >= 0.005 ? .green : .red)
        }
      }
    }
    .padding()
  }
}

// MARK: - Questions

/// Said when the app hasn't left its numbers yet (or the term is over).
private let openRunwayFirst =
  "Open Runway once so I can see your budget, then ask me again."

@available(iOS 17.0, *)
struct SpendTodayIntent: AppIntent {
  static var title: LocalizedStringResource = "How much can I spend today?"
  static var description = IntentDescription("What's still OK to spend today in Runway.")
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  static var openAppWhenRun = false

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let today = VoiceLog.savedBudget?.now() else {
      return .result(dialog: IntentDialog(stringLiteral: openRunwayFirst))
    }
    var line: String
    if today.left <= 0 {
      line = "There's nothing left to spend this period."
    } else if today.safe >= 0.005 {
      line = "You can spend \(today.safe.dollars) more today."
      if today.spent >= 0.005 { line += " You've spent \(today.spent.dollars) so far." }
    } else {
      line = "You're \((-today.safe).dollars) over today's budget, so tomorrow's will be a little smaller."
    }
    return .result(dialog: IntentDialog(stringLiteral: line))
  }
}

@available(iOS 17.0, *)
struct SpentThisWeekIntent: AppIntent {
  static var title: LocalizedStringResource = "How much have I spent this week?"
  static var description = IntentDescription("Your spending over the last 7 days in Runway.")
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  static var openAppWhenRun = false

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let budget = VoiceLog.savedBudget, let today = budget.now() else {
      return .result(dialog: IntentDialog(stringLiteral: openRunwayFirst))
    }
    guard today.week >= 0.005 else {
      return .result(dialog: "Nothing in the last 7 days. Nice.")
    }
    var line = "You've spent \(today.week.dollars) in the last 7 days."
    if let top = budget.weekTop.first {
      line += " Most of it on \(top.label), \(top.amount.dollars)."
    }
    return .result(dialog: IntentDialog(stringLiteral: line))
  }
}

@available(iOS 17.0, *)
struct BudgetCheckIntent: AppIntent {
  static var title: LocalizedStringResource = "How's my budget?"
  static var description = IntentDescription(
    "What's left in Runway for the rest of the semester or month, and whether it lasts.")
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  static var openAppWhenRun = false

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let budget = VoiceLog.savedBudget, let today = budget.now() else {
      return .result(dialog: IntentDialog(stringLiteral: openRunwayFirst))
    }
    let days = today.daysLeft == 1 ? "1 day" : "\(today.daysLeft) days"
    guard today.left > 0 else {
      return .result(dialog: IntentDialog(stringLiteral:
        "You've used everything for this \(budget.period), with \(days) to go."))
    }
    var line = "You have \(today.left.dollars) left for the rest of the \(budget.period), \(days). "
      + "That's about \((today.left / Double(max(1, today.daysLeft))).dollars) a day."
    if let runsOut = budget.runsOut.flatMap(Budget.date) {
      line += " At your pace it runs out \(runsOut.formatted(.dateTime.month(.wide).day()))."
    } else if budget.savingsGoal > 0, let onTrack = budget.onTrack {
      line += onTrack
        ? " You're on track to keep your \(budget.savingsGoal.dollars) savings."
        : " At this pace you'd dip into your savings."
    }
    return .result(dialog: IntentDialog(stringLiteral: line))
  }
}

// MARK: - What you can say

@available(iOS 17.0, *)
struct RunwayShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogExpenseIntent(),
      phrases: [
        "Log an expense in \(.applicationName)",
        "Log an expense on \(.applicationName)",
        "Log expense \(.applicationName)",
        "Log spending in \(.applicationName)",
        "Log a purchase in \(.applicationName)",
        "Add an expense in \(.applicationName)",
        "Add an expense to \(.applicationName)",
        "Add an expense on \(.applicationName)",
        "Add spending to \(.applicationName)",
        "Add a purchase to \(.applicationName)",
        "New expense in \(.applicationName)",
        "Record an expense in \(.applicationName)",
        "Track an expense in \(.applicationName)",
        "Track spending in \(.applicationName)",
        "Track my spending in \(.applicationName)",
        "I spent money in \(.applicationName)",
        "I spent money on \(.applicationName)",
        "I bought something in \(.applicationName)",
        "I just spent money \(.applicationName)",
        "Spent money \(.applicationName)",
        "\(.applicationName) log expense",
        "\(.applicationName) log",
        "\(.applicationName) add expense",
        "\(.applicationName) I spent money",
        "\(.applicationName) new expense",
        "\(.applicationName) spent",
        "Log \(\.$category) in \(.applicationName)",
        "Log \(\.$category) on \(.applicationName)",
        "Add \(\.$category) to \(.applicationName)",
        "Add \(\.$category) in \(.applicationName)",
        "I bought \(\.$category) in \(.applicationName)",
        "I bought \(\.$category) on \(.applicationName)",
        "I paid for \(\.$category) in \(.applicationName)",
        "I spent money on \(\.$category) in \(.applicationName)",
        "Spent money on \(\.$category) \(.applicationName)",
        "\(.applicationName) \(\.$category)",
        "\(.applicationName) log \(\.$category)",
      ],
      shortTitle: "Log an expense",
      systemImageName: "dollarsign.circle"
    )
    AppShortcut(
      intent: SpendTodayIntent(),
      phrases: [
        "How much can I spend today in \(.applicationName)",
        "How much can I spend today on \(.applicationName)",
        "How much can I spend in \(.applicationName)",
        "How much do I have left today in \(.applicationName)",
        "What's left for today in \(.applicationName)",
        "What can I spend today in \(.applicationName)",
        "Can I afford something in \(.applicationName)",
        "Check today's budget in \(.applicationName)",
        "\(.applicationName) today",
        "\(.applicationName) how much can I spend",
        "\(.applicationName) left today",
      ],
      shortTitle: "Left for today",
      systemImageName: "sun.max"
    )
    AppShortcut(
      intent: SpentThisWeekIntent(),
      phrases: [
        "How much have I spent this week in \(.applicationName)",
        "How much have I spent this week on \(.applicationName)",
        "How much did I spend this week in \(.applicationName)",
        "What did I spend this week in \(.applicationName)",
        "My spending this week in \(.applicationName)",
        "Weekly spending in \(.applicationName)",
        "\(.applicationName) this week",
        "\(.applicationName) weekly spending",
      ],
      shortTitle: "Spent this week",
      systemImageName: "calendar"
    )
    AppShortcut(
      intent: BudgetCheckIntent(),
      phrases: [
        "How's my budget in \(.applicationName)",
        "How is my budget in \(.applicationName)",
        "How's my budget on \(.applicationName)",
        "Check my budget in \(.applicationName)",
        "How much money do I have left in \(.applicationName)",
        "How much do I have left in \(.applicationName)",
        "Am I on track in \(.applicationName)",
        "Will my money last in \(.applicationName)",
        "\(.applicationName) budget",
        "\(.applicationName) how am I doing",
      ],
      shortTitle: "Budget check",
      systemImageName: "chart.line.uptrend.xyaxis"
    )
  }
}
