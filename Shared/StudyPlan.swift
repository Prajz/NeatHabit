import Foundation

let appGroupIdentifier = "group.uk.co.praj.NeatHabit"
let progressStorageKey = "neatHabit.progress.v2"

enum StudyHabit: String, CaseIterable, Codable, Hashable, Identifiable {
    case pattern
    case problems
    case review
    case systemDesign

    var id: String { rawValue }

    static func activeCases(hasRedoDue: Bool = false) -> [StudyHabit] {
        var habits: [StudyHabit] = []

        if hasRedoDue {
            habits.append(.review)
        }

        habits.append(.systemDesign)
        return habits
    }

    var title: String {
        switch self {
        case .pattern:
            return "Pattern Study"
        case .problems:
            return "Problem Block"
        case .review:
            return "Review + Redo"
        case .systemDesign:
            return "System Design"
        }
    }

    var shortTitle: String {
        switch self {
        case .pattern:
            return "Pattern"
        case .problems:
            return "Problems"
        case .review:
            return "Review"
        case .systemDesign:
            return "Design"
        }
    }

    var subtitle: String {
        switch self {
        case .pattern:
            return "Optional template review before solving."
        case .problems:
            return "Completes automatically from the question rows."
        case .review:
            return "Only appears when redo work is due."
        case .systemDesign:
            return "Spend focused time on the daily design topic."
        }
    }

    func durationMinutes(settings: StudySettings) -> Int {
        switch self {
        case .pattern:
            return 0
        case .problems:
            return settings.problemBlockMinutes
        case .review:
            return 30
        case .systemDesign:
            return 20
        }
    }

    var systemImage: String {
        switch self {
        case .pattern:
            return "book.closed.fill"
        case .problems:
            return "keyboard.fill"
        case .review:
            return "arrow.triangle.2.circlepath"
        case .systemDesign:
            return "server.rack"
        }
    }
}

enum ProblemStatus: String, CaseIterable, Codable, Hashable, Identifiable {
    case untouched
    case green
    case yellow
    case red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .untouched:
            return "Not Started"
        case .green:
            return "Green"
        case .yellow:
            return "Yellow"
        case .red:
            return "Red"
        }
    }

    var shortTitle: String {
        switch self {
        case .untouched:
            return "Todo"
        case .green:
            return "Green"
        case .yellow:
            return "Yellow"
        case .red:
            return "Red"
        }
    }

    var description: String {
        switch self {
        case .untouched:
            return "Not attempted yet"
        case .green:
            return "Solved without help in under 35 mins"
        case .yellow:
            return "Needed hint or video but coded it yourself"
        case .red:
            return "Did not understand or copied; redo is scheduled"
        }
    }

    var next: ProblemStatus {
        switch self {
        case .untouched:
            return .green
        case .green:
            return .yellow
        case .yellow:
            return .red
        case .red:
            return .untouched
        }
    }
}

struct StudySettings: Codable, Equatable {
    var dailyMinutes: Int
    var targetFinishDate: Date
    var extraProblems: [CustomProblem]
    var reminderHour: Int
    var reminderMinute: Int
    var notificationsEnabled: Bool

    init(
        dailyMinutes: Int = 200,
        targetFinishDate: Date = Calendar.current.date(byAdding: .day, value: 29, to: Calendar.current.startOfDay(for: Date())) ?? Date(),
        extraProblems: [CustomProblem] = [],
        reminderHour: Int = 19,
        reminderMinute: Int = 0,
        notificationsEnabled: Bool = true
    ) {
        self.dailyMinutes = dailyMinutes
        self.targetFinishDate = targetFinishDate
        self.extraProblems = extraProblems
        self.reminderHour = min(max(reminderHour, 0), 23)
        self.reminderMinute = min(max(reminderMinute, 0), 59)
        self.notificationsEnabled = notificationsEnabled
    }

    enum CodingKeys: String, CodingKey {
        case dailyMinutes
        case targetFinishDate
        case extraProblems
        case reminderHour
        case reminderMinute
        case notificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyMinutes) ?? 200
        targetFinishDate = try container.decodeIfPresent(Date.self, forKey: .targetFinishDate) ?? Calendar.current.date(
            byAdding: .day,
            value: 29,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
        extraProblems = try container.decodeIfPresent([CustomProblem].self, forKey: .extraProblems) ?? []
        reminderHour = min(max(try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 19, 0), 23)
        reminderMinute = min(max(try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0, 0), 59)
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dailyMinutes, forKey: .dailyMinutes)
        try container.encode(targetFinishDate, forKey: .targetFinishDate)
        try container.encode(extraProblems, forKey: .extraProblems)
        try container.encode(reminderHour, forKey: .reminderHour)
        try container.encode(reminderMinute, forKey: .reminderMinute)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
    }

    var fixedMinutes: Int {
        20
    }

    var problemBlockMinutes: Int {
        max(30, dailyMinutes - fixedMinutes)
    }

    var estimatedProblemCapacity: Int {
        max(1, problemBlockMinutes / 25)
    }

    var reminderDate: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = reminderHour
        components.minute = reminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }
}

struct CustomProblem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var sectionTitle: String

    init(id: UUID = UUID(), title: String, sectionTitle: String = "Extra Practice") {
        self.id = id
        self.title = title
        self.sectionTitle = sectionTitle
    }
}

struct ProblemSection: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let template: String
    let problems: [String]
}

struct StudyDay: Identifiable, Codable, Equatable {
    let day: Int
    let topic: String
    let problems: [String]
    let systemDesignFocus: String
    let date: Date?
    let sections: [String]

    var id: Int { day }
}

struct StudySchedule: Equatable {
    let days: [StudyDay]
    let settings: StudySettings
    let startDate: Date
    let requiredProblemCount: Int

    var totalDays: Int { days.count }
    var totalProblems: Int { days.reduce(0) { $0 + $1.problems.count } }
    var extraProblemCount: Int { max(0, totalProblems - requiredProblemCount) }

    var averageProblemsPerDay: Double {
        guard totalDays > 0 else { return 0 }
        return Double(totalProblems) / Double(totalDays)
    }

    var dailyLoadIsOverCapacity: Bool {
        averageProblemsPerDay > Double(settings.estimatedProblemCapacity)
    }

    func clampedDay(_ day: Int) -> Int {
        min(max(day, 1), max(totalDays, 1))
    }

    func day(_ day: Int) -> StudyDay {
        days[clampedDay(day) - 1]
    }
}

enum StudyPlanner {
    static var requiredProblemCount: Int {
        sections.reduce(0) { $0 + $1.problems.count }
    }

    static var requiredProblemTitles: [String] {
        sections.flatMap(\.problems)
    }

    static func plan(for progress: StoredProgress) -> StudySchedule {
        let baseSchedule = plan(startDate: progress.startDate, settings: progress.settings)
        let currentDay = progress.currentDayNumber(in: baseSchedule)
        let completedProblemTitles = progress.touchedProblemTitles
        var lockedProblemTitles = Set<String>()
        var adaptedDays: [StudyDay] = []

        for day in baseSchedule.days where day.day <= currentDay {
            let recordedProblems = progress.dailyProgress(for: day.day).problemStatuses.compactMap { problem, status in
                status == .untouched ? nil : problem
            }
            let problems = orderedUnique(day.problems + recordedProblems)
            lockedProblemTitles.formUnion(problems)
            adaptedDays.append(
                StudyDay(
                    day: day.day,
                    topic: day.topic,
                    problems: problems,
                    systemDesignFocus: day.systemDesignFocus,
                    date: day.date,
                    sections: day.sections
                )
            )
        }

        let remainingProblems = (requiredProblems + progress.settings.extraProblems.map { ProblemRef(title: $0.title, sectionTitle: $0.sectionTitle) }).filter { problem in
            !completedProblemTitles.contains(problem.title) && !lockedProblemTitles.contains(problem.title)
        }
        let futureDays = baseSchedule.days.filter { $0.day > currentDay }
        let counts = balancedCounts(total: remainingProblems.count, buckets: futureDays.count)
        var problemIndex = 0

        for (index, day) in futureDays.enumerated() {
            let count = counts[index]
            let slice = Array(remainingProblems[problemIndex..<problemIndex + count])
            problemIndex += count

            adaptedDays.append(
                StudyDay(
                    day: day.day,
                    topic: topic(for: slice),
                    problems: slice.map(\.title),
                    systemDesignFocus: day.systemDesignFocus,
                    date: day.date,
                    sections: orderedUnique(slice.map(\.sectionTitle))
                )
            )
        }

        return StudySchedule(
            days: adaptedDays,
            settings: progress.settings,
            startDate: baseSchedule.startDate,
            requiredProblemCount: requiredProblemCount
        )
    }

    static func plan(startDate: Date, settings: StudySettings) -> StudySchedule {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: settings.targetFinishDate)
        let rawDays = calendar.dateComponents([.day], from: start, to: maxDate(start, target)).day ?? 0
        let dayCount = max(1, rawDays + 1)
        let problems = requiredProblems + settings.extraProblems.map { ProblemRef(title: $0.title, sectionTitle: $0.sectionTitle) }
        let counts = balancedCounts(total: problems.count, buckets: dayCount)
        var problemIndex = 0

        let days = (1...dayCount).map { dayNumber -> StudyDay in
            let count = counts[dayNumber - 1]
            let slice = Array(problems[problemIndex..<problemIndex + count])
            problemIndex += count

            let sections = orderedUnique(slice.map(\.sectionTitle))

            return StudyDay(
                day: dayNumber,
                topic: topic(for: slice),
                problems: slice.map(\.title),
                systemDesignFocus: systemDesignTopics[(dayNumber - 1) % systemDesignTopics.count],
                date: calendar.date(byAdding: .day, value: dayNumber - 1, to: start),
                sections: sections
            )
        }

        return StudySchedule(
            days: days,
            settings: settings,
            startDate: start,
            requiredProblemCount: requiredProblemCount
        )
    }

    static let sections: [ProblemSection] = [
        ProblemSection(
            id: "arrays-hashing",
            title: "Arrays & Hashing",
            template: "Use sets, frequency maps, prefix/suffix arrays, buckets, and matrix validation.",
            problems: ["Contains Duplicate", "Valid Anagram", "Two Sum", "Group Anagrams", "Top K Frequent Elements", "Encode and Decode Strings", "Product of Array Except Self", "Valid Sudoku", "Longest Consecutive Sequence"]
        ),
        ProblemSection(
            id: "two-pointers",
            title: "Two Pointers",
            template: "Move left/right pointers based on what improves the answer; skip duplicates after sorting.",
            problems: ["Valid Palindrome", "Two Sum II Input Array Is Sorted", "3Sum", "Container With Most Water", "Trapping Rain Water"]
        ),
        ProblemSection(
            id: "sliding-window",
            title: "Sliding Window",
            template: "Expand right, shrink left while invalid, and track counts or a monotonic deque.",
            problems: ["Best Time to Buy And Sell Stock", "Longest Substring Without Repeating Characters", "Longest Repeating Character Replacement", "Permutation In String", "Minimum Window Substring", "Sliding Window Maximum"]
        ),
        ProblemSection(
            id: "stack",
            title: "Stack",
            template: "Use matching stacks, monotonic stacks, or store extra state with each push.",
            problems: ["Valid Parentheses", "Min Stack", "Evaluate Reverse Polish Notation", "Daily Temperatures", "Car Fleet", "Largest Rectangle In Histogram"]
        ),
        ProblemSection(
            id: "binary-search",
            title: "Binary Search",
            template: "Binary search indexes, rotated ranges, answer space, or timestamp lists.",
            problems: ["Binary Search", "Search a 2D Matrix", "Koko Eating Bananas", "Find Minimum In Rotated Sorted Array", "Search In Rotated Sorted Array", "Time Based Key Value Store", "Median of Two Sorted Arrays"]
        ),
        ProblemSection(
            id: "linked-list",
            title: "Linked List",
            template: "Use dummy nodes, fast/slow pointers, reverse, merge, detach, and reconnect.",
            problems: ["Reverse Linked List", "Merge Two Sorted Lists", "Linked List Cycle", "Reorder List", "Remove Nth Node From End of List", "Copy List With Random Pointer", "Add Two Numbers", "Find The Duplicate Number", "LRU Cache", "Merge K Sorted Lists", "Reverse Nodes In K Group"]
        ),
        ProblemSection(
            id: "trees",
            title: "Trees",
            template: "DFS return values, BFS levels, BST bounds, nonlocal results, and preorder serialization.",
            problems: ["Invert Binary Tree", "Maximum Depth of Binary Tree", "Diameter of Binary Tree", "Balanced Binary Tree", "Same Tree", "Subtree of Another Tree", "Lowest Common Ancestor of a Binary Search Tree", "Binary Tree Level Order Traversal", "Binary Tree Right Side View", "Count Good Nodes In Binary Tree", "Validate Binary Search Tree", "Kth Smallest Element In a Bst", "Construct Binary Tree From Preorder And Inorder Traversal", "Binary Tree Maximum Path Sum", "Serialize And Deserialize Binary Tree"]
        ),
        ProblemSection(
            id: "heap-priority-queue",
            title: "Heap / Priority Queue",
            template: "Use min-heaps, negative values for max-heaps, top-k, and two heaps for medians.",
            problems: ["Kth Largest Element In a Stream", "Last Stone Weight", "K Closest Points to Origin", "Kth Largest Element In An Array", "Task Scheduler", "Design Twitter", "Find Median From Data Stream"]
        ),
        ProblemSection(
            id: "backtracking",
            title: "Backtracking",
            template: "Choose, explore, unchoose; sort before duplicate skipping; use visited for permutations and grids.",
            problems: ["Subsets", "Combination Sum", "Combination Sum II", "Permutations", "Subsets II", "Generate Parentheses", "Word Search", "Palindrome Partitioning", "Letter Combinations of a Phone Number", "N Queens"]
        ),
        ProblemSection(
            id: "trie",
            title: "Tries",
            template: "Use nested nodes for prefix lookup, wildcard DFS, and board-search pruning.",
            problems: ["Implement Trie Prefix Tree", "Design Add And Search Words Data Structure", "Word Search II"]
        ),
        ProblemSection(
            id: "graphs",
            title: "Graphs",
            template: "Model adjacency, visited sets, grid BFS/DFS, topological sort, and union-find.",
            problems: ["Number of Islands", "Max Area of Island", "Clone Graph", "Walls And Gates", "Rotting Oranges", "Pacific Atlantic Water Flow", "Surrounded Regions", "Course Schedule", "Course Schedule II", "Graph Valid Tree", "Number of Connected Components In An Undirected Graph", "Redundant Connection", "Word Ladder"]
        ),
        ProblemSection(
            id: "advanced-graphs",
            title: "Advanced Graphs",
            template: "Use Dijkstra, minimum spanning tree, lexical DFS, and constrained shortest paths.",
            problems: ["Network Delay Time", "Reconstruct Itinerary", "Min Cost to Connect All Points", "Swim In Rising Water", "Alien Dictionary", "Cheapest Flights Within K Stops"]
        ),
        ProblemSection(
            id: "one-d-dp",
            title: "1D DP",
            template: "Start with recursion + memo, define dp[i], then compress or convert bottom-up.",
            problems: ["Climbing Stairs", "Min Cost Climbing Stairs", "House Robber", "House Robber II", "Longest Palindromic Substring", "Palindromic Substrings", "Decode Ways", "Coin Change", "Maximum Product Subarray", "Word Break", "Longest Increasing Subsequence", "Partition Equal Subset Sum"]
        ),
        ProblemSection(
            id: "two-d-dp",
            title: "2D DP",
            template: "Define dp[i][j], compare choices, and watch matrix boundaries and subsequence transitions.",
            problems: ["Unique Paths", "Longest Common Subsequence", "Best Time to Buy And Sell Stock With Cooldown", "Coin Change II", "Target Sum", "Interleaving String", "Longest Increasing Path In a Matrix", "Distinct Subsequences", "Edit Distance", "Burst Balloons", "Regular Expression Matching"]
        ),
        ProblemSection(
            id: "greedy",
            title: "Greedy",
            template: "Find the local choice that preserves future feasibility; track reach, intervals, or counts.",
            problems: ["Maximum Subarray", "Jump Game", "Jump Game II", "Gas Station", "Hand of Straights", "Merge Triplets to Form Target Triplet", "Partition Labels", "Valid Parenthesis String"]
        ),
        ProblemSection(
            id: "intervals",
            title: "Intervals",
            template: "Sort by start or end, merge overlaps, sweep with heaps, and isolate the conflict rule.",
            problems: ["Insert Interval", "Merge Intervals", "Non Overlapping Intervals", "Meeting Rooms", "Meeting Rooms II", "Minimum Interval to Include Each Query"]
        ),
        ProblemSection(
            id: "math-geometry",
            title: "Math & Geometry",
            template: "Simulate carefully, handle overflow-style logic, matrix layers, and coordinate counts.",
            problems: ["Rotate Image", "Spiral Matrix", "Set Matrix Zeroes", "Happy Number", "Plus One", "Pow(x, n)", "Multiply Strings", "Detect Squares"]
        ),
        ProblemSection(
            id: "bit-manipulation",
            title: "Bit Manipulation",
            template: "Use XOR, shifts, masks, bit counting, and carry loops without normal addition.",
            problems: ["Single Number", "Number of 1 Bits", "Counting Bits", "Reverse Bits", "Missing Number", "Sum of Two Integers", "Reverse Integer"]
        )
    ]

    private static let systemDesignTopics = [
        "Client-server basics: requests, responses, latency, throughput, availability.",
        "API modeling: resources, endpoints, status codes, idempotency, pagination.",
        "Storage choice: SQL vs NoSQL, primary keys, document stores, relational joins.",
        "Indexes and access patterns: read paths, write cost, composite indexes.",
        "Caching basics: cache-aside, TTLs, invalidation, hot keys.",
        "CDNs and static delivery: edge caching, origins, cache-control headers.",
        "Load balancing: L4 vs L7, health checks, sticky sessions, failover.",
        "Stateless services: horizontal scaling, session storage, shared state.",
        "Rate limiting: token bucket, leaky bucket, per-user and global limits.",
        "Queues and async jobs: producers, consumers, retries, dead-letter queues.",
        "Sharding and consistent hashing: partition keys, rebalancing, hotspots.",
        "Replication and failover: leader/follower, quorum, read replicas.",
        "Object storage: uploads, signed URLs, metadata tables, lifecycle rules.",
        "Search systems: inverted indexes, ranking, autocomplete, freshness.",
        "Notifications: fanout, preferences, batching, delivery receipts.",
        "Realtime systems: WebSockets, presence, ordering, reconnects.",
        "Feed design: fanout-on-write, fanout-on-read, ranking, pagination.",
        "Design a URL shortener: APIs, schema, redirects, analytics, scale.",
        "Design Pastebin: text storage, expiration, privacy, read-heavy traffic.",
        "Ride matching basics: geospatial indexing, dispatch, ETA, state transitions.",
        "Payment ledger basics: immutable events, balances, reconciliation, idempotency.",
        "Observability: logs, metrics, traces, SLOs, alerts.",
        "Feature flags and config: rollout, targeting, kill switches, audits.",
        "Auth sessions: cookies, JWTs, OAuth, refresh tokens, revocation.",
        "Analytics data modeling: events, dimensions, retention, batch vs stream.",
        "CAP and consistency: strong vs eventual, read-your-writes, conflicts.",
        "Backpressure and retries: timeouts, jitter, circuit breakers, overload.",
        "Multi-region basics: active-active, active-passive, latency, data residency.",
        "Design review checklist: requirements, APIs, schema, bottlenecks, tradeoffs.",
        "Mock interview: explain one full design from requirements to scaling plan."
    ]

    private static var requiredProblems: [ProblemRef] {
        sections.flatMap { section in
            section.problems.map { ProblemRef(title: $0, sectionTitle: section.title) }
        }
    }

    private static func balancedCounts(total: Int, buckets: Int) -> [Int] {
        guard buckets > 0 else { return [] }
        let base = total / buckets
        let remainder = total % buckets

        return (0..<buckets).map { index in
            let previousExtras = (index * remainder) / buckets
            let currentExtras = ((index + 1) * remainder) / buckets
            return base + (currentExtras > previousExtras ? 1 : 0)
        }
    }

    private static func topic(for problems: [ProblemRef]) -> String {
        let sections = orderedUnique(problems.map(\.sectionTitle))
        if sections.isEmpty {
            return "Review and catch-up"
        } else if sections.count == 1 {
            return sections[0]
        } else {
            return "\(sections[0]) + \(sections[1])"
        }
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }

    private static func maxDate(_ first: Date, _ second: Date) -> Date {
        first > second ? first : second
    }
}

private struct ProblemRef: Equatable {
    let title: String
    let sectionTitle: String
}
