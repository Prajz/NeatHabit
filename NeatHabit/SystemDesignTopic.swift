import SwiftUI

struct SystemDesignTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let category: String
    let overview: String
    let concepts: [DesignConcept]
    let diagramNodes: [DiagramNode]
    let diagramStyle: DiagramStyle
    let talkingPoints: [String]
    let tradeoffs: [String]

    enum DiagramStyle: String, Codable, Hashable {
        case flow
        case architecture
        case comparison
        case cycle
    }
}

struct DesignConcept: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let detail: String
}

struct DiagramNode: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let subtitle: String
    let icon: String
    let role: NodeRole

    enum NodeRole: String, Codable, Hashable {
        case client
        case edge
        case service
        case cache
        case storage
        case queue
        case external
        case monitor
    }
}

enum SystemDesignTopics {
    static func topic(for focus: String) -> SystemDesignTopic? {
        all.first { $0.id == focus || focus.hasPrefix($0.title) }
    }

    static let all: [SystemDesignTopic] = [
        SystemDesignTopic(
            id: "client-server-basics",
            title: "Client-server basics",
            icon: "network",
            category: "Fundamentals",
            overview: "Every distributed system starts with a client sending a request and a server returning a response. Understanding latency, throughput, and the difference between connection-oriented and connectionless protocols is the foundation for every design decision that follows.",
            concepts: [
                DesignConcept(title: "Request-response lifecycle", detail: "DNS lookup, TCP handshake, TLS negotiation, request transmission, server processing, response delivery. Each phase adds latency you can optimize."),
                DesignConcept(title: "Latency vs throughput", detail: "Latency is time per request (ms). Throughput is requests per second. Optimizing one often hurts the other. CDN reduces latency; batching increases throughput."),
                DesignConcept(title: "Connection models", detail: "HTTP/1.1 keep-alive reuses connections. HTTP/2 multiplexes streams. HTTP/3 uses QUIC over UDP. WebSockets provide persistent bidirectional channels."),
                DesignConcept(title: "Stateless vs stateful", detail: "Stateless servers scale horizontally because any server can handle any request. Stateful servers need session affinity or external session storage."),
                DesignConcept(title: "Backpressure", detail: "When the server cannot keep up, it must signal the client to slow down. Mechanisms include HTTP 429, TCP flow control, and queue-based buffering.")
            ],
            diagramNodes: [
                DiagramNode(title: "Client", subtitle: "Browser / Mobile", icon: "iphone", role: .client),
                DiagramNode(title: "DNS + CDN", subtitle: "Edge resolution", icon: "globe", role: .edge),
                DiagramNode(title: "Load Balancer", subtitle: "L4 / L7 routing", icon: "arrow.triangle.branch", role: .edge),
                DiagramNode(title: "API Server", subtitle: "Stateless workers", icon: "server.rack", role: .service),
                DiagramNode(title: "Database", subtitle: "Primary + replicas", icon: "cylinder.fill", role: .storage)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Measure P50, P95, and P99 latency before optimizing. P99 reveals tail latency caused by garbage collection, cold starts, or network jitter.",
                "Use connection pooling on the server side and keep-alive on the client side to avoid paying the TCP+TLS handshake cost on every request.",
                "Design APIs to be idempotent from day one. Retries are inevitable in distributed systems, and non-idempotent endpoints cause duplicate side effects.",
                "Choose between synchronous (REST, gRPC) and asynchronous (message queues, WebSockets) based on whether the client needs an immediate answer."
            ],
            tradeoffs: [
                "Stateless scales easily but requires external session/cache storage, adding a network hop per request.",
                "HTTP/2 multiplexing reduces head-of-line blocking at the HTTP level but TCP head-of-line blocking remains. HTTP/3 solves this with QUIC but has less CDN support.",
                "Long-lived connections (WebSockets) give low latency but consume server resources per connection and complicate load balancing."
            ]
        ),
        SystemDesignTopic(
            id: "api-modeling",
            title: "API modeling",
            icon: "arrow.left.arrow.right.circle.fill",
            category: "Fundamentals",
            overview: "APIs define the contract between services and clients. Good API modeling makes systems easier to reason about, version, and scale. The choice between REST, GraphQL, and gRPC shapes caching strategy, payload size, and developer experience.",
            concepts: [
                DesignConcept(title: "Resource-oriented design", detail: "Model APIs around nouns (resources) not verbs. GET /users/123 not GET /getUser?id=123. This maps naturally to HTTP caching and CDN behavior."),
                DesignConcept(title: "Idempotency keys", detail: "Clients send a unique key with mutating requests. The server stores the key and returns the cached response on retry. Critical for payment and order APIs."),
                DesignConcept(title: "Pagination strategies", detail: "Offset-based (LIMIT/OFFSET) is simple but slow on large tables. Cursor-based (WHERE id > last_seen) is efficient but cannot jump to arbitrary pages."),
                DesignConcept(title: "Versioning", detail: "URL versioning (/v2/users) is explicit and CDN-friendly. Header versioning is cleaner but harder to test. Breaking changes require a migration plan, not just a version bump."),
                DesignConcept(title: "gRPC vs REST", detail: "gRPC uses protobuf for compact binary payloads and code generation. Ideal for service-to-service. REST with JSON is better for public APIs and browser clients.")
            ],
            diagramNodes: [
                DiagramNode(title: "Client", subtitle: "Sends request", icon: "iphone", role: .client),
                DiagramNode(title: "API Gateway", subtitle: "Auth, rate limit, route", icon: "shield.lefthalf.filled", role: .edge),
                DiagramNode(title: "Service A", subtitle: "Users resource", icon: "person.2.fill", role: .service),
                DiagramNode(title: "Service B", subtitle: "Orders resource", icon: "cart.fill", role: .service),
                DiagramNode(title: "Idempotency Store", subtitle: "Redis / DynamoDB", icon: "key.fill", role: .cache)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Design the API contract first, then implement. Use OpenAPI specs or protobuf definitions as the source of truth before writing any server code.",
                "Cursor pagination scales to billions of rows. Offset pagination degrades to O(n) because the database must scan and discard rows.",
                "Rate limiting should be per-endpoint, not just global. A read-heavy endpoint and a write-heavy endpoint have very different capacity limits.",
                "Version from day one. Even if you only have v1, the version prefix gives you room to evolve without breaking existing clients."
            ],
            tradeoffs: [
                "REST is cacheable and simple but causes over-fetching. GraphQL solves over-fetching but defeats HTTP caching and complicates server implementation.",
                "gRPC is fast and type-safe but requires code generation and is not browser-friendly without gRPC-Web proxy.",
                "Cursor pagination is fast but does not support 'jump to page 47'. Choose based on whether your UI needs random access or infinite scroll."
            ]
        ),
        SystemDesignTopic(
            id: "storage-choice",
            title: "Storage choice",
            icon: "cylinder.split.1x2.fill",
            category: "Data & Storage",
            overview: "Choosing between SQL and NoSQL is not about which is better but which access patterns your workload demands. The wrong choice shows up as slow joins, expensive scans, or operational complexity you did not budget for.",
            concepts: [
                DesignConcept(title: "SQL strengths", detail: "ACID transactions, complex joins, referential integrity, mature tooling. Best when data has relationships and consistency matters (payments, orders, user accounts)."),
                DesignConcept(title: "NoSQL document stores", detail: "MongoDB, DynamoDB store self-contained documents. Best when entities are read as a whole unit and joins are rare. Schema flexibility speeds up iteration."),
                DesignConcept(title: "Wide-column stores", detail: "Cassandra, ScyllaDB optimize for write throughput and time-series data. Data is partitioned by key and sorted by clustering columns. No ad-hoc joins."),
                DesignConcept(title: "When to denormalize", detail: "If you always read user + orders together, store them together. Denormalization trades write complexity (update in multiple places) for read speed (one query)."),
                DesignConcept(title: "Polyglot persistence", detail: "Use different stores for different access patterns. PostgreSQL for transactions, Elasticsearch for search, Redis for sessions. Adds operational cost but each store excels at its job.")
            ],
            diagramNodes: [
                DiagramNode(title: "SQL (PostgreSQL)", subtitle: "ACID, joins, relations", icon: "tablecells.fill", role: .storage),
                DiagramNode(title: "Document (MongoDB)", subtitle: "Flexible schema, embedded reads", icon: "doc.fill", role: .storage),
                DiagramNode(title: "Wide-column (Cassandra)", subtitle: "Write-heavy, time-series", icon: "rectangle.split.3x1.fill", role: .storage),
                DiagramNode(title: "Key-value (Redis)", subtitle: "Sub-ms reads, sessions", icon: "memorychip.fill", role: .cache),
                DiagramNode(title: "Search (Elasticsearch)", subtitle: "Full-text, faceted search", icon: "magnifyingglass", role: .external)
            ],
            diagramStyle: .comparison,
            talkingPoints: [
                "Start with PostgreSQL unless you have a specific reason not to. It handles JSON columns, full-text search, and geospatial queries well enough for most startups.",
                "The question is not SQL vs NoSQL but 'what are my read and write access patterns?' Write-heavy workloads with simple reads favor wide-column. Read-heavy with joins favor SQL.",
                "Migration between storage engines is the most expensive infrastructure change you will make. Invest time in choosing correctly upfront.",
                "Consider the operational burden. Managed services (RDS, DynamoDB) reduce ops work but limit tuning. Self-hosted gives control but requires DBA expertise."
            ],
            tradeoffs: [
                "SQL gives you transactions and joins but vertical scaling hits a ceiling. NoSQL scales horizontally but you lose cross-partition transactions.",
                "Document stores allow schema evolution without migrations but make it easy to store inconsistent data that breaks downstream consumers.",
                "Polyglot persistence gives each workload the ideal store but introduces data synchronization problems and increases the blast radius of outages."
            ]
        ),
        SystemDesignTopic(
            id: "indexes-access-patterns",
            title: "Indexes and access patterns",
            icon: "list.bullet.indent",
            category: "Data & Storage",
            overview: "Indexes are the single most impactful tool for read performance, but every index slows down writes. Understanding which queries to index, how composite indexes work, and when to use covering indexes separates adequate designs from great ones.",
            concepts: [
                DesignConcept(title: "B-tree indexes", detail: "Default in most databases. O(log n) lookups. Supports equality and range queries. Leaf nodes can store the full row (clustered) or a pointer (secondary)."),
                DesignConcept(title: "Composite indexes", detail: "Multi-column indexes follow leftmost-prefix rule. Index on (a, b, c) supports queries on (a), (a, b), and (a, b, c) but not (b) or (c) alone."),
                DesignConcept(title: "Covering indexes", detail: "If the index contains all columns the query needs, the database never touches the table. This is an index-only scan and is dramatically faster."),
                DesignConcept(title: "Write cost", detail: "Every INSERT, UPDATE, DELETE must update every index on that table. More than 5-6 indexes on a high-write table is usually a sign of over-indexing."),
                DesignConcept(title: "Index maintenance", detail: "Indexes fragment over time. REINDEX or VACUUM reclaims space. Monitor index usage with pg_stat_user_indexes and drop unused indexes.")
            ],
            diagramNodes: [
                DiagramNode(title: "Query", subtitle: "WHERE user_id = ? AND created_at > ?", icon: "magnifyingglass", role: .client),
                DiagramNode(title: "Composite Index", subtitle: "(user_id, created_at)", icon: "list.bullet.indent", role: .cache),
                DiagramNode(title: "Index Scan", subtitle: "O(log n) lookup", icon: "arrow.down.right.and.arrow.up.left", role: .service),
                DiagramNode(title: "Table Heap", subtitle: "Fetch full row if needed", icon: "cylinder.fill", role: .storage)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Profile your actual queries before adding indexes. Use EXPLAIN ANALYZE to see if the query planner uses the index or does a sequential scan.",
                "The leftmost-prefix rule means column order in a composite index matters. Put the most selective (highest cardinality) column first for equality lookups.",
                "Covering indexes eliminate table lookups entirely. If your query only needs indexed columns, the answer comes straight from the index B-tree.",
                "Partial indexes (WHERE status = 'active') index only a subset of rows. Dramatically smaller and faster when most queries filter on the same condition."
            ],
            tradeoffs: [
                "More indexes speed up reads but slow down writes. A table with 10 indexes can be 3-5x slower on INSERT than one with 2 indexes.",
                "Covering indexes are fast but duplicate data. If you add a column to the SELECT, you must rebuild the index to include it.",
                "Composite indexes are powerful but rigid. An index on (a, b, c) does not help queries that filter only on b or c."
            ]
        ),
        SystemDesignTopic(
            id: "caching-basics",
            title: "Caching basics",
            icon: "bolt.circle.fill",
            category: "Performance",
            overview: "Caching trades consistency for speed. The hard part is not adding a cache but deciding what to cache, when to invalidate, and how to handle cache misses under load. Every senior engineer should be able to explain cache stampede and how to prevent it.",
            concepts: [
                DesignConcept(title: "Cache-aside pattern", detail: "Application checks cache first. On miss, reads from database, writes to cache, returns result. Simple but the application owns invalidation logic."),
                DesignConcept(title: "Write-through cache", detail: "Every write goes to both cache and database atomically. Reads are always fast. Higher write latency but data is always consistent between cache and DB."),
                DesignConcept(title: "TTL and eviction", detail: "Time-to-live ensures stale data eventually expires. LRU eviction removes least-recently-used keys when memory is full. Choose TTL based on how stale you can tolerate."),
                DesignConcept(title: "Cache stampede", detail: "When a popular key expires, hundreds of requests hit the database simultaneously. Prevent with mutex locks, probabilistic early expiration, or background refresh."),
                DesignConcept(title: "Hot keys", detail: "A small number of keys receive disproportionate traffic. Solutions: local in-process caching, read replicas of the cache, or key sharding with replicas.")
            ],
            diagramNodes: [
                DiagramNode(title: "Client Request", subtitle: "GET /users/123", icon: "iphone", role: .client),
                DiagramNode(title: "Cache (Redis)", subtitle: "Hit? Return immediately", icon: "bolt.circle.fill", role: .cache),
                DiagramNode(title: "Database", subtitle: "Miss? Query here", icon: "cylinder.fill", role: .storage),
                DiagramNode(title: "Write-back", subtitle: "Populate cache", icon: "arrow.uturn.backward", role: .service)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Cache at the layer closest to the consumer. Browser cache for static assets, CDN for API responses, Redis for database queries, local cache for computed values.",
                "Always have a cache invalidation strategy before you add the cache. 'It expires in 5 minutes' is not a strategy if stale data causes incorrect behavior.",
                "Cache stampede is the most common cache failure in production. Use a mutex (SETNX in Redis) so only one request repopulates while others wait or get stale data.",
                "Monitor cache hit rate. Below 80% means your cache keys or TTLs are wrong. Above 95% means you might be over-provisioning cache capacity."
            ],
            tradeoffs: [
                "Cache-aside is simple but risks stale reads between invalidation and repopulation. Write-through is consistent but doubles write latency.",
                "Longer TTLs reduce database load but increase the window of stale data. The right TTL depends on how much staleness the business can tolerate.",
                "Local in-process caches (Caffeine, NSCache) are the fastest option but create consistency problems across multiple server instances."
            ]
        ),
        SystemDesignTopic(
            id: "cdns-static-delivery",
            title: "CDNs and static delivery",
            icon: "globe.americas.fill",
            category: "Performance",
            overview: "A CDN moves content closer to users, reducing latency from hundreds of milliseconds to single digits. Beyond static assets, modern CDNs handle dynamic content, edge computing, and DDoS protection. Understanding cache-control headers is essential for any web-facing system.",
            concepts: [
                DesignConcept(title: "Edge caching", detail: "CDN nodes (PoPs) around the world cache content. First request goes to origin (cache miss), subsequent requests served from edge. Reduces origin load by 90%+."),
                DesignConcept(title: "Cache-control headers", detail: "max-age sets TTL. s-maxage is CDN-specific. no-cache means revalidate every time. immutable means never revalidate. Getting these wrong causes stale content or unnecessary origin hits."),
                DesignConcept(title: "Cache invalidation", detail: "Purge specific URLs instantly. Purge by tag for bulk invalidation. Version filenames (app.v2.js) avoid invalidation entirely. Choose based on how dynamic the content is."),
                DesignConcept(title: "Origin shield", detail: "A single caching layer between edge nodes and origin. Prevents multiple edge nodes from fetching the same uncached content simultaneously from origin."),
                DesignConcept(title: "Edge computing", detail: "Run lightweight logic at the edge: A/B testing, geolocation routing, image resizing. Cloudflare Workers, Lambda@Edge. Reduces latency by avoiding the round trip to origin.")
            ],
            diagramNodes: [
                DiagramNode(title: "User (Tokyo)", subtitle: "Requests asset", icon: "person.fill", role: .client),
                DiagramNode(title: "Edge PoP (Tokyo)", subtitle: "Cache hit? Serve here", icon: "globe.asia.australia.fill", role: .edge),
                DiagramNode(title: "Origin Shield", subtitle: "Single fetch layer", icon: "shield.fill", role: .edge),
                DiagramNode(title: "Origin Server", subtitle: "Source of truth", icon: "server.rack", role: .service)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Set cache-control headers correctly before adding a CDN. The CDN respects these headers. Wrong headers mean the CDN caches things it should not or does not cache things it should.",
                "Use content-hash filenames for static assets (app.abc123.js). This allows infinite cache TTL because the filename changes when the content changes.",
                "CDN purge is not instant globally. It takes seconds to propagate. If you need instant updates, use versioned URLs instead of purge.",
                "For dynamic APIs, use short TTLs (1-5 seconds) with stale-while-revalidate. This absorbs traffic spikes while keeping data reasonably fresh."
            ],
            tradeoffs: [
                "CDNs dramatically reduce latency but add a propagation delay for updates. Purge operations take seconds to reach all edge nodes globally.",
                "Edge computing reduces origin load but limits what you can do (no database access, limited CPU time, cold starts at the edge).",
                "Origin shield reduces origin load but adds a single point of failure and an extra network hop for cache misses."
            ]
        ),
        SystemDesignTopic(
            id: "load-balancing",
            title: "Load balancing",
            icon: "arrow.triangle.branch",
            category: "Scale",
            overview: "Load balancers distribute traffic across servers to prevent any single server from becoming a bottleneck. The choice between L4 and L7, the selection algorithm, and health check strategy determine whether your system handles traffic spikes gracefully or collapses under them.",
            concepts: [
                DesignConcept(title: "L4 vs L7", detail: "L4 (TCP/UDP) routes based on IP and port. Fast, low overhead. L7 (HTTP) inspects headers, paths, cookies. Enables smart routing but adds latency."),
                DesignConcept(title: "Selection algorithms", detail: "Round-robin is simple but ignores server load. Least-connections routes to the server with fewest active requests. Consistent hashing routes the same key to the same server."),
                DesignConcept(title: "Health checks", detail: "Active health checks ping /health every N seconds. Passive health checks detect failures from real traffic. Remove unhealthy servers from rotation and re-add when recovered."),
                DesignConcept(title: "Sticky sessions", detail: "Route the same user to the same server. Needed when server holds local state. Reduces load balancing effectiveness and complicates failover."),
                DesignConcept(title: "Multi-layer LB", detail: "DNS round-robin to multiple L4 load balancers, each routing to L7 load balancers, each routing to application servers. Each layer handles a different failure mode.")
            ],
            diagramNodes: [
                DiagramNode(title: "DNS", subtitle: "Round-robin to LBs", icon: "globe", role: .edge),
                DiagramNode(title: "L4 LB", subtitle: "TCP-level routing", icon: "arrow.triangle.branch", role: .edge),
                DiagramNode(title: "L7 LB", subtitle: "Path/header routing", icon: "arrow.triangle.3.branch", role: .edge),
                DiagramNode(title: "Server Pool", subtitle: "N stateless instances", icon: "server.rack", role: .service),
                DiagramNode(title: "Health Check", subtitle: "Active + passive", icon: "heart.fill", role: .monitor)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Start with L7 load balancing unless you are routing non-HTTP traffic. L7 gives you path-based routing, header inspection, and SSL termination at the LB.",
                "Health checks should test real dependencies, not just 'is the process running'. A server that returns 200 but cannot reach the database is not healthy.",
                "Avoid sticky sessions when possible. If you need them, use a cookie-based approach with a fallback to consistent hashing when the cookie is missing.",
                "Use graceful draining when removing servers. Stop sending new requests, wait for in-flight requests to complete, then shut down. Prevents dropped requests during deploys."
            ],
            tradeoffs: [
                "L4 is faster and simpler but cannot route based on URL path or headers. L7 is smarter but adds 1-5ms of latency per request.",
                "Sticky sessions simplify stateful services but create hot spots when some users generate more traffic than others.",
                "Active health checks detect problems quickly but add load. Passive checks are free but take longer to detect a failing server."
            ]
        ),
        SystemDesignTopic(
            id: "stateless-services",
            title: "Stateless services",
            icon: "square.stack.3d.up.fill",
            category: "Scale",
            overview: "Stateless services can be scaled horizontally by simply adding more instances. Any request can be handled by any server. The tradeoff is that session state, file uploads, and in-process caches must be moved to external stores, adding network hops and operational complexity.",
            concepts: [
                DesignConcept(title: "Horizontal scaling", detail: "Add more servers behind a load balancer. No session affinity needed. Each server is identical and replaceable. This is the simplest scaling strategy."),
                DesignConcept(title: "Session externalization", detail: "Move sessions from in-memory to Redis or a database. Every request reads session from the external store. Adds latency but enables any server to handle any request."),
                DesignConcept(title: "JWT as session", detail: "Store session data in a signed token on the client. Server is truly stateless. Tradeoff: cannot revoke tokens without a blocklist, and tokens grow with session data."),
                DesignConcept(title: "Shared nothing", detail: "No local files, no local caches that differ between instances. All state lives in external stores. Deployments become trivial: replace old instances with new ones."),
                DesignConcept(title: "Idempotent operations", detail: "When any server can retry a request, operations must be idempotent. Use idempotency keys for writes and read-your-writes consistency for user-facing reads.")
            ],
            diagramNodes: [
                DiagramNode(title: "Load Balancer", subtitle: "Any server can handle request", icon: "arrow.triangle.branch", role: .edge),
                DiagramNode(title: "Server 1", subtitle: "Stateless instance", icon: "server.rack", role: .service),
                DiagramNode(title: "Server 2", subtitle: "Stateless instance", icon: "server.rack", role: .service),
                DiagramNode(title: "Session Store", subtitle: "Redis / DB", icon: "key.fill", role: .cache),
                DiagramNode(title: "Object Storage", subtitle: "S3 / GCS", icon: "externaldrive.fill", role: .storage)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Stateless is the default goal. Only accept stateful components when you have a concrete reason (low-latency local cache, GPU affinity, WebSocket connection persistence).",
                "Session externalization adds a network hop per request. Mitigate with local LRU caches for hot sessions, but accept that cache misses will hit the external store.",
                "JWTs eliminate the session store but make revocation hard. Use short-lived access tokens (15 min) with refresh tokens stored server-side for revocation.",
                "Test statelessness by killing a random server instance. If users notice anything beyond a single failed request that succeeds on retry, you have hidden state."
            ],
            tradeoffs: [
                "External session stores add latency (1-5ms per request) and a new failure mode. If Redis goes down, all sessions are lost.",
                "JWTs are truly stateless but token size grows with claims, and you cannot invalidate a compromised token without maintaining a server-side blocklist.",
                "Local in-process caches break statelessness but are 10x faster than remote caches. Use them sparingly and accept eventual consistency."
            ]
        ),
        SystemDesignTopic(
            id: "rate-limiting",
            title: "Rate limiting",
            icon: "speedometer",
            category: "Reliability",
            overview: "Rate limiting protects your system from abuse, noisy neighbors, and cascading failures. The algorithm you choose (token bucket, sliding window, leaky bucket) determines whether legitimate burst traffic gets blocked or whether your protection is too lenient to matter.",
            concepts: [
                DesignConcept(title: "Token bucket", detail: "Bucket fills at a fixed rate. Each request consumes a token. Allows bursts up to bucket capacity. Most flexible algorithm. Used by AWS API Gateway."),
                DesignConcept(title: "Sliding window log", detail: "Log each request timestamp. Count requests in the last N seconds. Precise but memory-intensive for high-traffic endpoints."),
                DesignConcept(title: "Sliding window counter", detail: "Approximate sliding window using weighted counters from current and previous fixed windows. Low memory, good accuracy. Best balance of precision and cost."),
                DesignConcept(title: "Leaky bucket", detail: "Requests enter a queue. Bucket drains at a fixed rate. Smooths out bursts completely. Used when downstream cannot handle any burst (payment processors)."),
                DesignConcept(title: "Distributed rate limiting", detail: "Use Redis with Lua scripts for atomic check-and-increment. Race conditions between check and set cause over-admission. Atomic operations are essential.")
            ],
            diagramNodes: [
                DiagramNode(title: "Incoming Request", subtitle: "Check rate limit", icon: "arrow.down.circle.fill", role: .client),
                DiagramNode(title: "Rate Limiter", subtitle: "Token bucket / sliding window", icon: "speedometer", role: .service),
                DiagramNode(title: "Redis", subtitle: "Atomic counter store", icon: "memorychip.fill", role: .cache),
                DiagramNode(title: "Allowed", subtitle: "Forward to service", icon: "checkmark.circle.fill", role: .service),
                DiagramNode(title: "Rejected", subtitle: "HTTP 429 + Retry-After", icon: "xmark.circle.fill", role: .external)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Rate limit at multiple layers: per-user, per-IP, per-endpoint, and global. A single global limit protects the system but does not prevent one user from consuming all capacity.",
                "Always return Retry-After header with 429 responses. Well-behaved clients will back off. Without it, clients retry immediately and make the overload worse.",
                "Use atomic operations in Redis (Lua scripts or INCR with EXPIRE). Non-atomic check-then-set allows race conditions that over-admit requests under concurrent load.",
                "Rate limiting is not just for abuse prevention. Use it to enforce fair usage in multi-tenant systems so one customer cannot starve others of resources."
            ],
            tradeoffs: [
                "Token bucket allows bursts but can overwhelm downstream if the burst is large. Leaky bucket smooths everything but adds latency to every request.",
                "Distributed rate limiting with Redis adds a network hop per request. Local rate limiting is faster but inconsistent across instances.",
                "Strict rate limits protect the system but frustrate legitimate users during traffic spikes. Adaptive rate limiting that adjusts based on system load is more complex but more fair."
            ]
        ),
        SystemDesignTopic(
            id: "queues-async-jobs",
            title: "Queues and async jobs",
            icon: "tray.full.fill",
            category: "Reliability",
            overview: "Message queues decouple producers from consumers, absorb traffic spikes, and enable retry logic for flaky operations. The hard parts are ensuring exactly-once processing, handling poison messages, and designing dead-letter flows that do not lose data silently.",
            concepts: [
                DesignConcept(title: "Producer-consumer decoupling", detail: "Producers enqueue work without knowing who processes it. Consumers process at their own pace. The queue absorbs spikes and buffers during consumer slowdowns."),
                DesignConcept(title: "At-least-once delivery", detail: "Most queues guarantee at-least-once delivery. Consumers must be idempotent because messages can be delivered more than once, especially after consumer crashes."),
                DesignConcept(title: "Dead-letter queues", detail: "Messages that fail after N retries go to a DLQ. DLQs must be monitored and have a replay mechanism. Silent DLQ accumulation means you are losing data."),
                DesignConcept(title: "Visibility timeout", detail: "After a consumer picks up a message, it becomes invisible for a timeout period. If the consumer crashes, the message reappears. Set timeout longer than max processing time."),
                DesignConcept(title: "Ordering guarantees", detail: "FIFO queues guarantee order within a partition/group. Standard queues do not. Ordering reduces throughput because only one consumer per partition can process in order.")
            ],
            diagramNodes: [
                DiagramNode(title: "Producer", subtitle: "Enqueues work", icon: "arrow.up.circle.fill", role: .service),
                DiagramNode(title: "Message Queue", subtitle: "SQS / Kafka / RabbitMQ", icon: "tray.full.fill", role: .queue),
                DiagramNode(title: "Consumer Pool", subtitle: "Processes messages", icon: "gearshape.2.fill", role: .service),
                DiagramNode(title: "Dead Letter Queue", subtitle: "Failed after N retries", icon: "exclamationmark.triangle.fill", role: .queue),
                DiagramNode(title: "DLQ Monitor", subtitle: "Alert + replay", icon: "bell.fill", role: .monitor)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Design consumers to be idempotent from day one. Use deduplication IDs or database constraints to ensure processing the same message twice has no side effect.",
                "Set visibility timeout to at least 2x the expected processing time. If processing takes 30 seconds, set visibility to 60 seconds to avoid double processing.",
                "Monitor DLQ depth as a first-class metric. A growing DLQ means something is broken. Set up alerts and a regular review process for DLQ messages.",
                "Choose your queue technology based on throughput needs. SQS for simple work queues. Kafka for event streaming with replay. RabbitMQ for complex routing."
            ],
            tradeoffs: [
                "At-least-once delivery is simpler and more reliable than exactly-once but requires idempotent consumers. Exactly-once (Kafka transactions) adds complexity and reduces throughput.",
                "FIFO queues guarantee order but limit throughput to one consumer per message group. Standard queues are faster but can deliver messages out of order.",
                "Long visibility timeouts prevent double processing but delay retry when a consumer genuinely crashes. Short timeouts retry faster but risk duplicate work."
            ]
        ),
        SystemDesignTopic(
            id: "sharding-consistent-hashing",
            title: "Sharding and consistent hashing",
            icon: "square.grid.3x3.fill",
            category: "Scale",
            overview: "When a single database server cannot handle your workload, you split data across multiple servers (shards). The challenge is choosing a partition key that distributes data evenly, handling hotspots, and rebalancing when you add or remove shards.",
            concepts: [
                DesignConcept(title: "Partition strategies", detail: "Range-based partitions split by key range (A-M, N-Z). Hash-based partitions use hash(key) % N. Range is good for scans, hash is good for even distribution."),
                DesignConcept(title: "Consistent hashing", detail: "Map keys and servers onto a hash ring. Each server owns keys clockwise from its position. Adding/removing a server only moves 1/N of keys, not all keys."),
                DesignConcept(title: "Virtual nodes", detail: "Each physical server gets multiple positions on the ring (virtual nodes). This distributes load more evenly and handles heterogeneous server capacity."),
                DesignConcept(title: "Hotspots", detail: "Some keys receive disproportionate traffic (celebrity accounts, popular products). Solutions: split hot keys across shards, cache aggressively, or use a separate hot-key tier."),
                DesignConcept(title: "Rebalancing", detail: "When adding a shard, move only the data that belongs to the new shard. Use online migration: serve reads from old location during move, switch writes last.")
            ],
            diagramNodes: [
                DiagramNode(title: "Request", subtitle: "hash(key) → ring position", icon: "number.circle.fill", role: .client),
                DiagramNode(title: "Hash Ring", subtitle: "Consistent hash ring", icon: "circle.dotted.circle", role: .service),
                DiagramNode(title: "Shard A", subtitle: "Virtual nodes 1, 5, 9", icon: "cylinder.fill", role: .storage),
                DiagramNode(title: "Shard B", subtitle: "Virtual nodes 2, 6, 10", icon: "cylinder.fill", role: .storage),
                DiagramNode(title: "Shard C", subtitle: "Virtual nodes 3, 7, 11", icon: "cylinder.fill", role: .storage)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Choose your partition key carefully. It determines your access pattern forever. user_id works for user-centric apps. tenant_id works for multi-tenant SaaS.",
                "Consistent hashing with virtual nodes is the standard approach. Without virtual nodes, one server can accidentally own 60% of the ring.",
                "Cross-shard queries are expensive and should be rare. If you frequently need data from multiple shards, your partition key is wrong.",
                "Plan for rebalancing before you need it. Online migration (dual-write, backfill, cutover) is complex but avoids downtime."
            ],
            tradeoffs: [
                "Hash-based sharding distributes evenly but makes range queries impossible. Range-based sharding supports range queries but creates hotspots as data grows.",
                "Consistent hashing minimizes data movement on rebalance but does not guarantee perfectly even distribution. Virtual nodes help but add routing complexity.",
                "More shards increase write throughput but make cross-shard transactions, joins, and aggregations much more expensive."
            ]
        ),
        SystemDesignTopic(
            id: "replication-failover",
            title: "Replication and failover",
            icon: "externaldrive.connected.to.line.below",
            category: "Scale",
            overview: "Replication copies data across multiple servers for read scaling and fault tolerance. The fundamental tension is between consistency (all replicas agree) and availability (system works when a replica is down). Understanding quorum-based reads and writes lets you tune this tradeoff explicitly.",
            concepts: [
                DesignConcept(title: "Leader-follower", detail: "One leader accepts writes and replicates to followers. Followers serve reads. Simple but the leader is a single write bottleneck and single point of failure."),
                DesignConcept(title: "Multi-leader", detail: "Multiple leaders accept writes and replicate to each other. Higher write throughput but requires conflict resolution (last-write-wins, CRDTs, or application-level merge)."),
                DesignConcept(title: "Quorum reads/writes", detail: "Write to W of N replicas, read from R of N replicas. If W + R > N, at least one replica in the read set has the latest write. Dynamo-style consistency."),
                DesignConcept(title: "Replication lag", detail: "Followers are eventually consistent. Reads from followers may return stale data. Read-your-writes consistency requires reading from the leader for a short window after writing."),
                DesignConcept(title: "Failover", detail: "When the leader fails, promote a follower. Automatic failover risks split-brain (two leaders). Use consensus (Raft/Paxos) or a fencing token to prevent it.")
            ],
            diagramNodes: [
                DiagramNode(title: "Writer", subtitle: "Sends to leader", icon: "pencil.circle.fill", role: .client),
                DiagramNode(title: "Leader", subtitle: "Accepts writes", icon: "star.fill", role: .storage),
                DiagramNode(title: "Follower 1", subtitle: "Read replica", icon: "cylinder.fill", role: .storage),
                DiagramNode(title: "Follower 2", subtitle: "Read replica", icon: "cylinder.fill", role: .storage),
                DiagramNode(title: "Failover Monitor", subtitle: "Detects leader failure", icon: "eye.fill", role: .monitor)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Leader-follower is the right default. It is simple, well-understood, and supported by every major database. Only move to multi-leader when write throughput demands it.",
                "Set W + R > N for strong consistency. W=2, R=2, N=3 means every read overlaps with at least one replica that received the latest write.",
                "Replication lag is not a bug, it is a feature of asynchronous replication. Design your application to tolerate it: read from leader after writes, from followers otherwise.",
                "Automatic failover without consensus causes split-brain. Use a consensus protocol (Raft in etcd/Consul) or a fencing token to ensure only one leader is active."
            ],
            tradeoffs: [
                "Synchronous replication (wait for all followers) gives strong consistency but increases write latency and reduces availability when a follower is slow.",
                "Multi-leader increases write throughput but introduces conflict resolution complexity. Last-write-wins loses data. CRDTs preserve data but are hard to model.",
                "Automatic failover reduces downtime but risks split-brain. Manual failover is safer but means minutes of downtime while an operator intervenes."
            ]
        ),
        SystemDesignTopic(
            id: "object-storage",
            title: "Object storage",
            icon: "externaldrive.fill",
            category: "Data & Storage",
            overview: "Object storage (S3, GCS) is the standard for storing user uploads, backups, logs, and large binary files. It is infinitely scalable and cheap but has high latency for small reads and no in-place updates. Understanding signed URLs and lifecycle rules is essential for secure, cost-effective storage.",
            concepts: [
                DesignConcept(title: "Object vs block storage", detail: "Object storage stores immutable blobs with metadata. Block storage (EBS) provides a disk-like interface. Use object storage for uploads, backups, and static assets. Use block storage for databases."),
                DesignConcept(title: "Signed URLs", detail: "Generate a time-limited URL that grants access to a private object. The client uploads/downloads directly from the storage service without proxying through your server."),
                DesignConcept(title: "Multipart uploads", detail: "Files larger than 5GB must use multipart upload. Split into parts, upload in parallel, then combine. Supports resume on failure and parallel throughput."),
                DesignConcept(title: "Lifecycle rules", detail: "Automatically transition objects to cheaper storage tiers (S3 Glacier) after N days. Delete objects after M days. Reduces storage costs by 80%+ for old data."),
                DesignConcept(title: "Metadata tables", detail: "Store object metadata (size, type, owner, tags) in a database, not in the object itself. This enables querying, searching, and access control without reading the object.")
            ],
            diagramNodes: [
                DiagramNode(title: "Client", subtitle: "Requests upload URL", icon: "iphone", role: .client),
                DiagramNode(title: "API Server", subtitle: "Generates signed URL", icon: "server.rack", role: .service),
                DiagramNode(title: "Object Store", subtitle: "S3 / GCS / R2", icon: "externaldrive.fill", role: .storage),
                DiagramNode(title: "Metadata DB", subtitle: "File records + ACLs", icon: "cylinder.fill", role: .storage),
                DiagramNode(title: "CDN", subtitle: "Cache public objects", icon: "globe", role: .edge)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Never proxy uploads through your application server. Use signed URLs to let clients upload directly to S3. This eliminates your server as a bottleneck for large files.",
                "Store file metadata in a relational database alongside the object reference. This lets you query by owner, type, or date without listing the entire bucket.",
                "Set lifecycle rules from day one. Moving objects to Glacier after 90 days and deleting after 365 days can reduce storage costs from thousands to tens of dollars per month.",
                "Use content-addressable storage (hash as filename) for deduplication. If two users upload the same file, you only store it once."
            ],
            tradeoffs: [
                "Signed URLs offload transfer to the storage provider but expose the storage URL to the client. Use short expiration and restrict to specific operations.",
                "Object storage is cheap and durable but has 10-50ms latency per request. For latency-sensitive workloads, cache frequently accessed objects in Redis or on local disk.",
                "Multipart uploads enable large files but add complexity. Partial uploads must be cleaned up (lifecycle rules for incomplete multipart uploads) or they accumulate storage costs silently."
            ]
        ),
        SystemDesignTopic(
            id: "search-systems",
            title: "Search systems",
            icon: "magnifyingglass.circle.fill",
            category: "Data & Storage",
            overview: "Full-text search requires an inverted index that maps terms to documents. Beyond basic search, production systems need ranking, autocomplete, faceted filtering, and near-real-time indexing. Elasticsearch and similar systems are powerful but operationally complex.",
            concepts: [
                DesignConcept(title: "Inverted index", detail: "Maps each term to a list of documents containing that term. Like the index at the back of a book. Enables O(1) lookup by term instead of scanning every document."),
                DesignConcept(title: "Ranking and relevance", detail: "BM25 scores documents by term frequency, inverse document frequency, and field length. Machine learning rankers (Learning to Rank) improve on BM25 using click-through data."),
                DesignConcept(title: "Autocomplete", detail: "Prefix queries on a completion suggester (FST-based). Edge n-grams index prefixes as separate terms. Both trade index size for sub-millisecond suggestions."),
                DesignConcept(title: "Near-real-time indexing", detail: "Elasticsearch refreshes segments every 1 second by default. Newly indexed documents are not searchable until refresh. Reduce refresh interval for faster indexing at the cost of more segments."),
                DesignConcept(title: "Faceted search", detail: "Aggregations compute counts for categories, price ranges, etc. Run aggregations alongside the search query. Pre-compute popular facets for faster responses.")
            ],
            diagramNodes: [
                DiagramNode(title: "Search Query", subtitle: "\"best running shoes\"", icon: "magnifyingglass", role: .client),
                DiagramNode(title: "Search Engine", subtitle: "Elasticsearch / Meilisearch", icon: "text.magnifyingglass", role: .service),
                DiagramNode(title: "Inverted Index", subtitle: "term → doc IDs", icon: "list.bullet.indent", role: .storage),
                DiagramNode(title: "Ranker", subtitle: "BM25 / ML scoring", icon: "chart.bar.fill", role: .service),
                DiagramNode(title: "Source DB", subtitle: "Sync via CDC / dual-write", icon: "cylinder.fill", role: .storage)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Use Elasticsearch or Meilisearch rather than building your own search engine. The inverted index, ranking, and tokenization are solved problems.",
                "Keep search index in sync with your primary database using CDC (Change Data Capture) or dual-write. CDC with Debezium is more reliable than application-level dual-write.",
                "Autocomplete needs sub-50ms responses. Use a dedicated completion suggester (FST-based) rather than prefix queries on the main index.",
                "Monitor index size and segment count. Too many small segments degrade search performance. Run force-merge during low-traffic periods."
            ],
            tradeoffs: [
                "Dual-write (write to DB and search index in the same request) is simple but risks inconsistency if one write fails. CDC is more reliable but adds infrastructure.",
                "Lower refresh intervals make indexing faster but create more segments, which slows search. Default 1-second refresh is a good balance for most use cases.",
                "ML rankers improve relevance significantly but require training data (click-through logs) and add latency to search queries."
            ]
        ),
        SystemDesignTopic(
            id: "notifications",
            title: "Notifications",
            icon: "bell.badge.fill",
            category: "Application Design",
            overview: "Notification systems must handle fanout (one event triggers thousands of notifications), respect user preferences, batch delivery to avoid overwhelming downstream services, and track delivery receipts. The design scales from a simple push notification service to a multi-channel engagement platform.",
            concepts: [
                DesignConcept(title: "Fanout", detail: "One event (new post) creates notifications for thousands of followers. Fanout-on-write creates all notifications immediately. Fanout-on-read generates them when the user checks."),
                DesignConcept(title: "User preferences", detail: "Per-channel opt-in (email, push, SMS). Per-type preferences (mentions yes, likes no). Quiet hours. Preferences must be checked before every send."),
                DesignConcept(title: "Batching and debouncing", detail: "Group multiple notifications into a digest. Debounce rapid-fire events (5 likes in 10 seconds become '5 people liked your post'). Reduces notification fatigue."),
                DesignConcept(title: "Delivery receipts", detail: "Track sent, delivered, read, and failed states. Retry failed deliveries with exponential backoff. Mark permanently failed after N retries."),
                DesignConcept(title: "Multi-channel routing", detail: "Route each notification to the best channel based on urgency, user preference, and cost. Push for urgent, email for digest, in-app for low priority.")
            ],
            diagramNodes: [
                DiagramNode(title: "Event Source", subtitle: "Post created, comment added", icon: "sparkles", role: .service),
                DiagramNode(title: "Fanout Service", subtitle: "Expand to recipients", icon: "person.3.fill", role: .service),
                DiagramNode(title: "Preference Store", subtitle: "Per-user, per-channel", icon: "slider.horizontal.3", role: .cache),
                DiagramNode(title: "Delivery Queue", subtitle: "Batch + debounce", icon: "tray.full.fill", role: .queue),
                DiagramNode(title: "Channels", subtitle: "Push / Email / SMS / In-app", icon: "bell.badge.fill", role: .external)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Fanout-on-write is simpler but creates millions of rows for popular users. Fanout-on-read scales better for celebrity users but adds latency when reading the feed.",
                "Always check preferences before sending. Sending a notification a user opted out of is worse than not sending one. Store preferences as a fast lookup (Redis hash or database index).",
                "Batch notifications into digests for high-volume events. '10 people liked your photo' is better than 10 separate push notifications.",
                "Track delivery metrics (sent, delivered, opened, failed) as first-class metrics. High failure rates indicate a problem with the downstream channel provider."
            ],
            tradeoffs: [
                "Fanout-on-write gives instant notification delivery but creates O(followers) writes per event. For users with millions of followers, this is prohibitively expensive.",
                "Batching reduces notification fatigue but delays delivery. A 5-minute batch window means notifications arrive up to 5 minutes late.",
                "Multi-channel increases engagement but adds complexity. Each channel has different APIs, rate limits, and failure modes."
            ]
        ),
        SystemDesignTopic(
            id: "realtime-systems",
            title: "Realtime systems",
            icon: "dot.radiowaves.left.and.right",
            category: "Application Design",
            overview: "Realtime systems maintain persistent connections to push updates to clients instantly. WebSockets, Server-Sent Events, and long polling each have different tradeoffs. The hard parts are connection management at scale, message ordering, and handling reconnections gracefully.",
            concepts: [
                DesignConcept(title: "WebSocket", detail: "Full-duplex persistent connection over HTTP upgrade. Both client and server can send at any time. Best for chat, gaming, and collaborative editing."),
                DesignConcept(title: "Server-Sent Events", detail: "Server-to-client only over HTTP. Simpler than WebSocket, auto-reconnects, works with HTTP/2 multiplexing. Best for live feeds, notifications, and dashboards."),
                DesignConcept(title: "Connection management", detail: "Each WebSocket consumes a file descriptor and memory. At 100K connections, you need multiple servers. Use a pub/sub layer (Redis, NATS) to route messages to the right server."),
                DesignConcept(title: "Message ordering", detail: "Clients may receive messages out of order due to network conditions. Include sequence numbers. Clients buffer and reorder. Server tracks last-seen sequence per client."),
                DesignConcept(title: "Reconnection", detail: "Clients must reconnect with exponential backoff and jitter. Server must handle reconnection gracefully: resume from last-seen sequence, not replay everything.")
            ],
            diagramNodes: [
                DiagramNode(title: "Client A", subtitle: "WebSocket connection", icon: "iphone", role: .client),
                DiagramNode(title: "WS Server 1", subtitle: "Holds connections", icon: "server.rack", role: .service),
                DiagramNode(title: "Pub/Sub", subtitle: "Redis / NATS / Kafka", icon: "dot.radiowaves.left.and.right", role: .queue),
                DiagramNode(title: "WS Server 2", subtitle: "Holds connections", icon: "server.rack", role: .service),
                DiagramNode(title: "Client B", subtitle: "WebSocket connection", icon: "laptopcomputer", role: .client)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Use SSE for server-to-client only (feeds, notifications). Use WebSocket when the client also sends frequently (chat, collaborative editing). SSE is simpler and works with existing HTTP infrastructure.",
                "At scale, WebSocket servers are connection holders, not application servers. They subscribe to a pub/sub system and forward messages to their connected clients.",
                "Include sequence numbers in every message. Clients use them to detect gaps and request missing messages on reconnection. Without sequence numbers, clients silently miss updates.",
                "Plan for connection storms. When a server restarts, all clients reconnect simultaneously. Use exponential backoff with jitter to spread the reconnection load."
            ],
            tradeoffs: [
                "WebSockets give full duplex but defeat HTTP caching and complicate load balancing (sticky sessions or pub/sub routing needed).",
                "SSE is simpler and auto-reconnects but is server-to-client only. If the client needs to send data, it must open a separate HTTP request.",
                "Holding 100K+ WebSocket connections per server is possible but requires tuning OS file descriptors, TCP buffers, and memory allocation."
            ]
        ),
        SystemDesignTopic(
            id: "feed-design",
            title: "Feed design",
            icon: "list.bullet.rectangle.fill",
            category: "Application Design",
            overview: "News feeds and activity streams are one of the most common system design interview questions. The core challenge is fanout: when a user posts, how do you efficiently populate the feeds of all their followers? The answer depends on the follower graph shape.",
            concepts: [
                DesignConcept(title: "Fanout-on-write", detail: "When a user posts, write a copy to every follower's feed. Reads are fast (one query per user). Writes are expensive for popular users (O(followers) writes)."),
                DesignConcept(title: "Fanout-on-read", detail: "When a user opens their feed, query all followees' posts and merge. Writes are cheap (one write per post). Reads are expensive for users who follow many people."),
                DesignConcept(title: "Hybrid approach", detail: "Fanout-on-write for normal users (< 1000 followers). Fanout-on-read for celebrities (> 1000 followers). This handles the bimodal follower distribution of real social graphs."),
                DesignConcept(title: "Ranking", detail: "Chronological is simplest. Engagement-based ranking (likes, comments, time spent) increases engagement. ML rankers use hundreds of features but add latency."),
                DesignConcept(title: "Pagination", detail: "Cursor-based pagination (WHERE created_at < last_seen) is efficient. Offset pagination degrades on large feeds. Use feed IDs as cursors for consistent results.")
            ],
            diagramNodes: [
                DiagramNode(title: "User Posts", subtitle: "New content created", icon: "pencil.circle.fill", role: .client),
                DiagramNode(title: "Fanout Service", subtitle: "Write to follower feeds", icon: "person.3.fill", role: .service),
                DiagramNode(title: "Feed Cache", subtitle: "Redis sorted sets per user", icon: "memorychip.fill", role: .cache),
                DiagramNode(title: "Post Store", subtitle: "Source of truth", icon: "cylinder.fill", role: .storage),
                DiagramNode(title: "Feed Reader", subtitle: "Merge + rank + paginate", icon: "list.bullet.rectangle.fill", role: .service)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "The hybrid approach is the standard answer in interviews. Real social graphs have a power-law distribution: most users have few followers, a few users have millions.",
                "Use Redis sorted sets for feed caches. Score = timestamp for chronological, score = ranking score for ranked feeds. ZRANGEBYSCORE gives you paginated results.",
                "Pre-compute feeds for active users. If a user has not logged in for 30 days, do not populate their feed. Compute it on-demand when they return.",
                "Ranking adds latency. Pre-compute ranked feeds periodically (every 5 minutes) and serve from cache. Real-time ranking on every read is too slow for large feeds."
            ],
            tradeoffs: [
                "Fanout-on-write gives instant feed reads but creates millions of writes for celebrity posts. Fanout-on-read avoids this but makes feed reads slow for users following many celebrities.",
                "Ranked feeds increase engagement but reduce recency. Users may miss recent posts from close friends because older viral posts rank higher.",
                "Pre-computed feeds are fast but stale. Real-time feeds are fresh but slow. Most production systems pre-compute and inject real-time updates on top."
            ]
        ),
        SystemDesignTopic(
            id: "url-shortener",
            title: "Design a URL shortener",
            icon: "link.circle.fill",
            category: "Classic Problems",
            overview: "The URL shortener is the canonical system design interview question. It seems simple but reveals depth when you explore ID generation at scale, redirect strategies, analytics, and expiration. A strong answer covers the read path, write path, and operational concerns.",
            concepts: [
                DesignConcept(title: "ID generation", detail: "Base62 encode a counter (auto-increment) for short, unique IDs. Or use a snowflake-like generator for distributed ID generation without a central counter."),
                DesignConcept(title: "Hash collision approach", detail: "Hash the long URL and take the first 7 characters. Collisions require retry with a salt. Simpler than counters but needs collision handling."),
                DesignConcept(title: "Redirect types", detail: "301 (permanent) is cached by browsers, reducing server load but preventing analytics on repeat visits. 302 (temporary) hits the server every time, enabling full analytics."),
                DesignConcept(title: "Analytics", detail: "Track clicks, referrers, geolocation, device type. Write to a queue for async processing. Aggregate into dashboards. This is often more valuable than the shortening itself."),
                DesignConcept(title: "Expiration and cleanup", detail: "Store TTL with each link. Background job deletes expired links. Or use lazy expiration: check TTL on read and delete if expired. Lazy is simpler but leaves garbage.")
            ],
            diagramNodes: [
                DiagramNode(title: "User", subtitle: "Clicks short URL", icon: "person.fill", role: .client),
                DiagramNode(title: "Load Balancer", subtitle: "Routes to read service", icon: "arrow.triangle.branch", role: .edge),
                DiagramNode(title: "Read Service", subtitle: "Lookup short → long URL", icon: "server.rack", role: .service),
                DiagramNode(title: "Cache (Redis)", subtitle: "Hot URL mappings", icon: "bolt.circle.fill", role: .cache),
                DiagramNode(title: "Database", subtitle: "All URL mappings", icon: "cylinder.fill", role: .storage)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Use Base62 encoding of an auto-increment ID for the simplest unique short code. For distributed systems, use a pre-allocated ID range per server (Zookeeper range assignment).",
                "Use 302 redirects for analytics. 301 redirects are cached by browsers and subsequent clicks never reach your server, making click counts inaccurate.",
                "Cache the top 1% of URLs in Redis. URL access follows a power law: a small number of URLs receive the vast majority of clicks.",
                "The write path (creating a short URL) is much less frequent than the read path (redirecting). Optimize the read path aggressively."
            ],
            tradeoffs: [
                "Auto-increment IDs are predictable (someone can enumerate all URLs). Random IDs are not enumerable but require collision checking or larger ID spaces.",
                "301 redirects reduce server load by 90% for popular URLs but make analytics impossible for repeat visitors. 302 gives full analytics but higher server load.",
                "Lazy expiration is simple but accumulates dead rows. Background cleanup is more complex but keeps the database clean."
            ]
        ),
        SystemDesignTopic(
            id: "pastebin",
            title: "Design Pastebin",
            icon: "doc.text.fill",
            category: "Classic Problems",
            overview: "Pastebin is a text storage system where users paste content and share via a unique URL. The design challenges are read-heavy traffic (popular pastes get millions of views), expiration, privacy controls, and preventing abuse (spam, illegal content).",
            concepts: [
                DesignConcept(title: "Storage model", detail: "Store paste content as a blob (S3 or database TEXT column). Metadata (title, author, expiration, visibility) in a relational database. Content-addressable storage for deduplication."),
                DesignConcept(title: "ID generation", detail: "Same as URL shortener: Base62 counter or UUID. Short IDs are user-friendly for sharing. UUIDs are collision-free but longer."),
                DesignConcept(title: "Read-heavy optimization", detail: "Popular pastes are read thousands of times per second. Cache in Redis with the paste ID as key. CDN for public pastes. Rate limit reads per IP to prevent scraping."),
                DesignConcept(title: "Expiration", detail: "Store expiration timestamp with each paste. Background job deletes expired pastes. Or use TTL in Redis for cached copies and lazy deletion in the database."),
                DesignConcept(title: "Abuse prevention", detail: "Rate limit paste creation per user/IP. Content scanning for spam/malware. Size limits per paste. CAPTCHA for anonymous users.")
            ],
            diagramNodes: [
                DiagramNode(title: "User", subtitle: "Creates or reads paste", icon: "person.fill", role: .client),
                DiagramNode(title: "API Server", subtitle: "CRUD operations", icon: "server.rack", role: .service),
                DiagramNode(title: "Cache (Redis)", subtitle: "Hot pastes", icon: "bolt.circle.fill", role: .cache),
                DiagramNode(title: "Object Store", subtitle: "Paste content (S3)", icon: "externaldrive.fill", role: .storage),
                DiagramNode(title: "Metadata DB", subtitle: "Paste records + ACLs", icon: "cylinder.fill", role: .storage)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Separate content storage from metadata. Content goes to object storage (cheap, unlimited). Metadata goes to a relational database (queryable, indexed).",
                "Cache aggressively. The top 0.1% of pastes receive the majority of reads. A Redis cache with LRU eviction handles this naturally.",
                "Use content-addressable storage (SHA-256 of content as key) for deduplication. If two users paste the same text, store it once.",
                "Rate limit paste creation more aggressively than reads. Creating pastes is the expensive operation (storage, abuse scanning). Reading cached pastes is nearly free."
            ],
            tradeoffs: [
                "Storing content in the database (TEXT column) simplifies the design but makes the database large and slow to back up. Object storage is cheaper but adds a network hop.",
                "Public pastes can be cached at the CDN level. Private pastes require authentication on every read, preventing CDN caching.",
                "Content deduplication saves storage but creates a reference-counting problem. When the last reference is deleted, the content must be garbage collected."
            ]
        ),
        SystemDesignTopic(
            id: "ride-matching",
            title: "Ride matching basics",
            icon: "car.fill",
            category: "Classic Problems",
            overview: "Ride matching connects riders with nearby drivers in real-time. The core challenges are geospatial indexing (finding nearby drivers efficiently), dispatch logic (which driver gets the request), ETA calculation, and managing state transitions through the ride lifecycle.",
            concepts: [
                DesignConcept(title: "Geospatial indexing", detail: "Use geohash or S2 cells to divide the map into grid cells. Index drivers by their current cell. Nearby search checks the rider's cell and adjacent cells."),
                DesignConcept(title: "Driver location updates", detail: "Drivers send GPS updates every 3-5 seconds. Store latest position in Redis (hash map: driver_id → lat/lng). Do not write every update to the database."),
                DesignConcept(title: "Dispatch algorithm", detail: "Find nearby drivers, filter by availability, rank by ETA + driver rating + acceptance rate. Offer to the best driver. If declined or timeout, offer to the next."),
                DesignConcept(title: "ETA calculation", detail: "Use a routing engine (OSRM, Google Maps API) to compute actual driving time, not straight-line distance. Cache common routes. Update ETA during the ride."),
                DesignConcept(title: "State machine", detail: "Ride states: requested → matched → driver_en_route → pickup → in_progress → completed. Each transition triggers notifications, pricing updates, and analytics events.")
            ],
            diagramNodes: [
                DiagramNode(title: "Rider App", subtitle: "Requests ride", icon: "person.fill", role: .client),
                DiagramNode(title: "Matching Service", subtitle: "Geospatial search + dispatch", icon: "location.magnifyingglass", role: .service),
                DiagramNode(title: "Driver Location", subtitle: "Redis geospatial index", icon: "location.fill", role: .cache),
                DiagramNode(title: "Driver App", subtitle: "Accepts/declines offer", icon: "car.fill", role: .client),
                DiagramNode(title: "Ride State", subtitle: "State machine + events", icon: "arrow.triangle.2.circlepath", role: .service)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Use geohash or S2 cells for geospatial indexing. A geohash of length 6 covers about 1.2km x 0.6km, which is a good granularity for urban ride matching.",
                "Driver location updates are high-volume (every driver every 3 seconds). Write to Redis, not the database. Only persist location history to the database for completed rides.",
                "Dispatch is not just 'nearest driver'. Factor in driver acceptance rate (skip drivers who always decline), current direction, and fairness (rotate opportunities among drivers).",
                "Use a state machine for the ride lifecycle. Every transition is an event that triggers notifications, pricing, and analytics. Missing a transition causes billing errors."
            ],
            tradeoffs: [
                "Geohash is simple but has edge cases: two drivers 10 meters apart can be in different geohashes. S2 cells handle boundaries better but are more complex to implement.",
                "Offering to one driver at a time (sequential dispatch) is fair but slow. Broadcasting to multiple drivers simultaneously is fast but can result in multiple acceptances.",
                "Real-time ETA updates during the ride require continuous routing computation. Pre-compute common routes and interpolate for efficiency."
            ]
        ),
        SystemDesignTopic(
            id: "payment-ledger",
            title: "Payment ledger basics",
            icon: "dollarsign.circle.fill",
            category: "Classic Problems",
            overview: "Payment systems must never lose money or double-charge. The design centers on an immutable event log (ledger), idempotent operations, double-entry bookkeeping, and reconciliation processes that catch discrepancies before they become financial losses.",
            concepts: [
                DesignConcept(title: "Immutable ledger", detail: "Every transaction is an append-only event. Never update or delete. The current balance is derived by summing all events. This provides a complete audit trail."),
                DesignConcept(title: "Double-entry bookkeeping", detail: "Every transaction has a debit and a credit that must balance. Transfer $10 from A to B: debit A $10, credit B $10. If they do not balance, the transaction is rejected."),
                DesignConcept(title: "Idempotency", detail: "Every payment request carries a unique idempotency key. The server checks if this key was already processed before executing. Prevents double-charging on retries."),
                DesignConcept(title: "Reconciliation", detail: "Compare your ledger against the payment processor's records (Stripe, bank). Run daily. Flag discrepancies for manual review. This catches bugs that silently lose or duplicate money."),
                DesignConcept(title: "Saga pattern", detail: "Multi-step payment flows (reserve → charge → confirm) use sagas instead of distributed transactions. Each step has a compensating action (release → refund → cancel) for rollback.")
            ],
            diagramNodes: [
                DiagramNode(title: "Payment Request", subtitle: "Idempotency key + amount", icon: "creditcard.fill", role: .client),
                DiagramNode(title: "Payment Service", subtitle: "Validate + deduplicate", icon: "server.rack", role: .service),
                DiagramNode(title: "Ledger", subtitle: "Append-only event log", icon: "book.fill", role: .storage),
                DiagramNode(title: "Payment Processor", subtitle: "Stripe / bank gateway", icon: "building.columns.fill", role: .external),
                DiagramNode(title: "Reconciliation", subtitle: "Daily comparison job", icon: "checkmark.seal.fill", role: .monitor)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "The ledger is append-only. Never UPDATE or DELETE a transaction. If a payment was wrong, add a reversal entry. This preserves the audit trail and makes debugging possible.",
                "Idempotency keys are non-negotiable for payment systems. Network retries are inevitable, and without idempotency, a retry creates a duplicate charge.",
                "Reconciliation is not optional. It is the safety net that catches bugs in your payment logic. Run it daily and treat discrepancies as P0 incidents.",
                "Use the saga pattern for multi-step flows. Distributed transactions (2PC) are too slow and create availability problems. Sagas with compensating actions are more practical."
            ],
            tradeoffs: [
                "Append-only ledgers grow forever. Archive old entries to cold storage periodically but keep recent entries queryable for customer support and debugging.",
                "Double-entry bookkeeping prevents accounting errors but makes the schema more complex. Every transaction requires at least two ledger entries.",
                "Sagas are eventually consistent. Between step 1 and step N, the system is in an intermediate state. Design the UI and error handling to account for this."
            ]
        ),
        SystemDesignTopic(
            id: "observability",
            title: "Observability",
            icon: "eye.fill",
            category: "Operations",
            overview: "Observability is the ability to understand a system's internal state from its external outputs. The three pillars are logs (what happened), metrics (how it is performing), and traces (where the time went). Without observability, you are guessing when things break.",
            concepts: [
                DesignConcept(title: "Structured logging", detail: "Log in JSON with consistent fields (timestamp, level, service, trace_id, message). Unstructured logs are impossible to search at scale. Use correlation IDs to trace requests across services."),
                DesignConcept(title: "Metrics and SLOs", detail: "Track RED metrics: Rate (requests/sec), Errors (error rate), Duration (latency percentiles). Define SLOs (99.9% of requests < 200ms) and alert on error budget burn."),
                DesignConcept(title: "Distributed tracing", detail: "Assign a trace ID to each request. Each service adds spans (timed operations) to the trace. Visualize the full request path to find bottlenecks. OpenTelemetry is the standard."),
                DesignConcept(title: "Alerting strategy", detail: "Alert on symptoms (error rate, latency), not causes (CPU, memory). Symptom-based alerts are actionable. Cause-based alerts generate noise and alert fatigue."),
                DesignConcept(title: "Error budgets", detail: "SLO of 99.9% means 43 minutes of downtime budget per month. Track error budget consumption. When the budget is exhausted, freeze feature releases and focus on reliability.")
            ],
            diagramNodes: [
                DiagramNode(title: "Service", subtitle: "Emits logs, metrics, traces", icon: "server.rack", role: .service),
                DiagramNode(title: "Log Aggregator", subtitle: "ELK / Loki", icon: "doc.text.magnifyingglass", role: .storage),
                DiagramNode(title: "Metrics Store", subtitle: "Prometheus / Datadog", icon: "chart.xyaxis.line", role: .storage),
                DiagramNode(title: "Trace Store", subtitle: "Jaeger / Tempo", icon: "point.3.connected.trianglepath.dotted", role: .storage),
                DiagramNode(title: "Alerting", subtitle: "PagerDuty / OpsGenie", icon: "bell.badge.fill", role: .monitor)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Instrument the three pillars from day one. Adding observability retroactively is 10x harder than building it in from the start.",
                "Use correlation IDs (trace IDs) that propagate through every service in a request path. Without them, debugging a request that touches 5 services is nearly impossible.",
                "Define SLOs before you need them. 'The system should be fast' is not an SLO. 'P99 latency < 200ms for 99.9% of requests' is an SLO that drives engineering decisions.",
                "Alert on symptoms, not causes. 'Error rate > 1%' is actionable. 'CPU > 80%' might be fine if the system is handling the load. Symptom alerts reduce noise."
            ],
            tradeoffs: [
                "High-cardinality metrics (per-user, per-request) are powerful for debugging but explode storage costs. Sample or aggregate high-cardinality data.",
                "Distributed tracing adds overhead (5-10% latency). Sample traces (1% of requests) to reduce overhead while maintaining visibility.",
                "Too many alerts cause alert fatigue. Too few alerts mean you discover outages from customers. Start with symptom-based alerts on SLOs and refine from there."
            ]
        ),
        SystemDesignTopic(
            id: "feature-flags",
            title: "Feature flags and config",
            icon: "flag.fill",
            category: "Operations",
            overview: "Feature flags decouple deployment from release. You can deploy code to production without exposing it to users. This enables gradual rollouts, A/B testing, instant kill switches, and per-user targeting. The challenge is managing flag lifecycle and preventing flag debt.",
            concepts: [
                DesignConcept(title: "Gradual rollout", detail: "Enable a feature for 1% of users, then 10%, then 100%. Monitor error rates and latency at each stage. Roll back instantly if metrics degrade."),
                DesignConcept(title: "Targeting rules", detail: "Enable features for specific users, teams, regions, or device types. Useful for beta programs, internal testing, and region-specific compliance."),
                DesignConcept(title: "Kill switches", detail: "Instantly disable a feature without deploying new code. Critical for production incidents. Kill switches should be accessible to on-call engineers, not just product managers."),
                DesignConcept(title: "Configuration management", detail: "Store flag values in a fast, consistent store (Redis, database with caching). Clients poll or subscribe for updates. Changes should propagate within seconds."),
                DesignConcept(title: "Flag lifecycle", detail: "Create → test → roll out → clean up. Flags that are never cleaned up become technical debt. Schedule regular flag cleanup sprints. Delete flags that are permanently on or off.")
            ],
            diagramNodes: [
                DiagramNode(title: "Admin Console", subtitle: "Toggle flags, set rules", icon: "slider.horizontal.3", role: .client),
                DiagramNode(title: "Flag Store", subtitle: "Redis / database", icon: "flag.fill", role: .cache),
                DiagramNode(title: "Config Service", subtitle: "Evaluate rules per user", icon: "server.rack", role: .service),
                DiagramNode(title: "Application", subtitle: "Check flag at runtime", icon: "app.fill", role: .service),
                DiagramNode(title: "Analytics", subtitle: "Measure flag impact", icon: "chart.bar.fill", role: .monitor)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Feature flags are not just for on/off. Use them for gradual rollouts, A/B tests, and user segmentation. The same infrastructure supports all three use cases.",
                "Kill switches should be the fastest path in your system. When a feature is causing a P0 incident, the kill switch must propagate in under 5 seconds.",
                "Flag debt is real. Teams with hundreds of active flags lose track of which flags are still needed. Schedule quarterly cleanup and delete flags that are permanently enabled.",
                "Use a managed service (LaunchDarkly, Unleash) or build a simple one in-house. The core evaluation logic is straightforward: check flag value, apply targeting rules, return boolean."
            ],
            tradeoffs: [
                "Feature flags add branching complexity to code. Every flag is an if/else that must be tested in both states. Too many flags make the codebase hard to reason about.",
                "Client-side flag evaluation is fast but exposes flag logic to the client. Server-side evaluation is secure but adds latency to every request.",
                "Real-time flag propagation (WebSocket push) is instant but complex. Polling every 30 seconds is simpler but means a 30-second delay for kill switches."
            ]
        ),
        SystemDesignTopic(
            id: "auth-sessions",
            title: "Auth sessions",
            icon: "lock.shield.fill",
            category: "Operations",
            overview: "Authentication proves who a user is. Authorization determines what they can do. The session layer maintains this identity across multiple requests. Choosing between cookies, JWTs, and OAuth depends on your architecture, security requirements, and whether you need server-side revocation.",
            concepts: [
                DesignConcept(title: "Session cookies", detail: "Server creates a session, stores it in a database, and sends a session ID as a cookie. Every request looks up the session. Server-side revocation is trivial. Scales with session store."),
                DesignConcept(title: "JWT access tokens", detail: "Self-contained token signed by the server. Contains user ID and claims. Server validates the signature without a database lookup. Cannot be revoked without a blocklist."),
                DesignConcept(title: "Refresh tokens", detail: "Long-lived token stored server-side. Used to obtain new short-lived access tokens. Revoking the refresh token effectively revokes all future access. Standard OAuth2 pattern."),
                DesignConcept(title: "OAuth 2.0 flows", detail: "Authorization Code flow for server-side apps. PKCE for mobile/SPA. Client Credentials for service-to-service. Each flow has different security properties."),
                DesignConcept(title: "Token storage", detail: "Access tokens in memory (not localStorage). Refresh tokens in secure, httpOnly, sameSite cookies. Never store tokens in URLs or logs.")
            ],
            diagramNodes: [
                DiagramNode(title: "Client", subtitle: "Login with credentials", icon: "person.fill", role: .client),
                DiagramNode(title: "Auth Server", subtitle: "Validate + issue tokens", icon: "lock.shield.fill", role: .service),
                DiagramNode(title: "Access Token", subtitle: "Short-lived JWT (15 min)", icon: "key.fill", role: .cache),
                DiagramNode(title: "Refresh Token", subtitle: "Long-lived, server-side", icon: "arrow.triangle.2.circlepath", role: .storage),
                DiagramNode(title: "Resource Server", subtitle: "Validates JWT signature", icon: "server.rack", role: .service)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Use short-lived access tokens (15 minutes) with refresh tokens. This limits the damage of a stolen access token while maintaining a good user experience via silent refresh.",
                "JWTs are not sessions. They cannot be revoked individually without a server-side blocklist. If you need instant revocation (admin disabling a user), use server-side sessions or refresh token rotation.",
                "Store refresh tokens in httpOnly, secure, sameSite cookies. Never in localStorage (XSS-vulnerable) or URLs (logged in browser history and server logs).",
                "Implement token rotation: every time a refresh token is used, issue a new refresh token and invalidate the old one. This limits the window of a stolen refresh token."
            ],
            tradeoffs: [
                "Server-side sessions enable instant revocation but require a session store (Redis/database) and add a lookup per request. JWTs are stateless but cannot be revoked without additional infrastructure.",
                "OAuth adds complexity (authorization server, token exchange, scopes) but enables third-party integrations and SSO. Only use OAuth when you need delegated authorization.",
                "Short-lived access tokens are more secure but require refresh logic on the client. If the refresh fails, the user is logged out unexpectedly."
            ]
        ),
        SystemDesignTopic(
            id: "analytics-modeling",
            title: "Analytics data modeling",
            icon: "chart.bar.xaxis",
            category: "Operations",
            overview: "Analytics systems collect events (user actions), store them efficiently, and enable fast aggregation for dashboards and reports. The design must handle massive write volume, support both batch and real-time processing, and manage data retention without losing historical trends.",
            concepts: [
                DesignConcept(title: "Event schema", detail: "Every event has: timestamp, event_type, user_id, session_id, properties (key-value). Use a schema registry (Protobuf, Avro) to evolve schemas without breaking consumers."),
                DesignConcept(title: "Dimensions and metrics", detail: "Dimensions are things you group by (country, device, page). Metrics are things you measure (count, sum, average). Design the schema so common dimensions are first-class columns."),
                DesignConcept(title: "Batch vs stream", detail: "Batch processing (Spark, BigQuery) handles historical analysis and complex joins. Stream processing (Kafka Streams, Flink) handles real-time dashboards and alerts. Most systems need both."),
                DesignConcept(title: "Columnar storage", detail: "Store analytics data in columnar format (Parquet, ClickHouse). Columnar storage compresses well and reads only the columns needed for a query, not entire rows."),
                DesignConcept(title: "Retention policy", detail: "Keep raw events for 30-90 days. Pre-aggregate older data into daily/weekly/monthly summaries. Delete raw data after aggregation to control storage costs.")
            ],
            diagramNodes: [
                DiagramNode(title: "SDK / App", subtitle: "Emits events", icon: "iphone", role: .client),
                DiagramNode(title: "Ingestion", subtitle: "Kafka / Kinesis", icon: "tray.full.fill", role: .queue),
                DiagramNode(title: "Stream Processor", subtitle: "Real-time aggregation", icon: "bolt.horizontal.fill", role: .service),
                DiagramNode(title: "Data Lake", subtitle: "S3 + Parquet", icon: "externaldrive.fill", role: .storage),
                DiagramNode(title: "Query Engine", subtitle: "ClickHouse / BigQuery", icon: "chart.bar.xaxis", role: .service)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Use a schema registry from day one. Analytics schemas evolve constantly (new events, new properties). Without a registry, schema changes break downstream consumers silently.",
                "Separate the ingestion path from the query path. Ingestion writes to Kafka. Stream processing writes to a real-time store. Batch processing writes to a data lake. Queries read from both.",
                "Columnar storage (Parquet, ClickHouse) is 10-100x faster than row-based storage for analytics queries. Analytics queries read a few columns from millions of rows.",
                "Pre-aggregate data for dashboards. Computing 'daily active users' from raw events every time the dashboard loads is too slow. Pre-compute and store the result."
            ],
            tradeoffs: [
                "Stream processing gives real-time dashboards but adds complexity (exactly-once semantics, late-arriving events, watermarks). Batch processing is simpler but has hours of delay.",
                "Keeping raw events enables ad-hoc analysis but is expensive at scale. Pre-aggregation saves storage but loses the ability to answer questions you did not anticipate.",
                "Columnar storage is fast for analytics but slow for point lookups. Use a separate store (PostgreSQL) for user-facing queries that need individual records."
            ]
        ),
        SystemDesignTopic(
            id: "cap-consistency",
            title: "CAP and consistency",
            icon: "triangle.fill",
            category: "Reliability",
            overview: "The CAP theorem states that a distributed system can provide at most two of three guarantees: Consistency, Availability, and Partition tolerance. Since network partitions are inevitable, the real choice is between consistency and availability during a partition. Understanding this tradeoff shapes every design decision.",
            concepts: [
                DesignConcept(title: "Strong consistency", detail: "After a write completes, all reads return the latest value. Requires coordination (consensus, locks). Higher latency, lower availability during partitions. Used for financial data."),
                DesignConcept(title: "Eventual consistency", detail: "Reads may return stale data temporarily. All replicas eventually converge. Lower latency, higher availability. Acceptable for social feeds, product catalogs, and most user-facing reads."),
                DesignConcept(title: "Read-your-writes", detail: "A user always sees their own writes, even if other users see stale data. Achieved by routing reads to the leader for a short window after the user's last write."),
                DesignConcept(title: "Conflict resolution", detail: "When two writes happen concurrently on different replicas, conflicts must be resolved. Strategies: last-write-wins (simple, loses data), CRDTs (merge automatically), manual resolution."),
                DesignConcept(title: "PACELC extension", detail: "If Partition: choose A or C. Else (normal operation): choose Latency or Consistency. Most systems trade consistency for latency even without partitions.")
            ],
            diagramNodes: [
                DiagramNode(title: "Consistency", subtitle: "All nodes see same data", icon: "checkmark.seal.fill", role: .storage),
                DiagramNode(title: "Availability", subtitle: "Every request gets response", icon: "clock.fill", role: .service),
                DiagramNode(title: "Partition Tolerance", subtitle: "System works despite network splits", icon: "network.slash", role: .edge)
            ],
            diagramStyle: .comparison,
            talkingPoints: [
                "In practice, you are choosing between consistency and latency, not consistency and availability. Most systems do not experience partitions often, but every system experiences latency.",
                "Use strong consistency for financial operations, inventory counts, and authentication. Use eventual consistency for feeds, recommendations, and analytics.",
                "Read-your-writes is the pragmatic middle ground. Users expect to see their own changes immediately but tolerate a few seconds of staleness for other users' changes.",
                "CRDTs (Conflict-free Replicated Data Types) automatically merge concurrent writes without conflicts. Use them for collaborative editing, counters, and sets."
            ],
            tradeoffs: [
                "Strong consistency requires consensus (Raft/Paxos) which adds latency (multiple round trips) and reduces availability (system blocks when a quorum is unreachable).",
                "Eventual consistency is fast and available but requires the application to handle stale reads. Users may see outdated data and must be designed for it.",
                "Last-write-wins conflict resolution is simple but silently drops data. CRDTs preserve all data but are limited to specific data types (counters, sets, registers)."
            ]
        ),
        SystemDesignTopic(
            id: "backpressure-retries",
            title: "Backpressure and retries",
            icon: "arrow.clockwise.circle.fill",
            category: "Reliability",
            overview: "When a system is overloaded, it must either slow down incoming requests (backpressure) or shed load. When a request fails, the client must retry intelligently. Naive retries without backpressure create a retry storm that makes the overload worse and can take down the entire system.",
            concepts: [
                DesignConcept(title: "Timeouts", detail: "Every network call must have a timeout. No timeout means a hung connection holds resources indefinitely. Set timeouts based on P99 latency + buffer, not on optimistic averages."),
                DesignConcept(title: "Exponential backoff + jitter", detail: "Retry after 1s, then 2s, then 4s, with random jitter. Jitter prevents synchronized retries from multiple clients hitting the server at the same instant."),
                DesignConcept(title: "Circuit breaker", detail: "After N consecutive failures, stop calling the downstream service for a cooldown period. Returns a fallback response immediately. Prevents cascading failures."),
                DesignConcept(title: "Load shedding", detail: "When overloaded, reject low-priority requests to protect high-priority ones. Return 503 with Retry-After. Better to serve 80% of traffic well than 100% poorly."),
                DesignConcept(title: "Bulkhead pattern", detail: "Isolate resources per caller or per endpoint. If one endpoint is slow, it consumes only its allocated thread pool, not the entire server's capacity.")
            ],
            diagramNodes: [
                DiagramNode(title: "Client", subtitle: "Sends request with timeout", icon: "iphone", role: .client),
                DiagramNode(title: "Circuit Breaker", subtitle: "Open after N failures", icon: "bolt.trianglebadge.exclamationmark.fill", role: .service),
                DiagramNode(title: "Downstream", subtitle: "May be slow or failing", icon: "server.rack", role: .external),
                DiagramNode(title: "Backoff Timer", subtitle: "Exponential + jitter", icon: "timer", role: .service),
                DiagramNode(title: "Fallback", subtitle: "Cached / default response", icon: "arrow.uturn.backward.circle.fill", role: .cache)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Every external call must have a timeout. The most common cause of cascading failures is a slow downstream service causing upstream connections to pile up.",
                "Retries without jitter create thundering herd problems. If 1000 clients all retry after exactly 1 second, the server receives 1000 simultaneous requests.",
                "Circuit breakers prevent cascading failures. When a downstream service is failing, the circuit breaker fails fast instead of waiting for timeouts, freeing resources for healthy requests.",
                "Load shedding is better than crashing. Returning 503 for low-priority requests preserves capacity for high-priority ones. Design priority levels before you need them."
            ],
            tradeoffs: [
                "Aggressive timeouts detect failures quickly but may kill slow-but-valid requests. Generous timeouts tolerate slow requests but hold resources longer during failures.",
                "Circuit breakers prevent cascading failures but return errors during the open state even if the downstream has recovered. Half-open state tests recovery but adds complexity.",
                "Load shedding preserves system health but rejects valid requests. The rejected requests must be retried by the client, adding latency for those users."
            ]
        ),
        SystemDesignTopic(
            id: "multi-region",
            title: "Multi-region basics",
            icon: "globe.europe.africa.fill",
            category: "Scale",
            overview: "Multi-region deployment places infrastructure in multiple geographic regions for low latency, disaster recovery, and data residency compliance. The fundamental challenge is data synchronization across regions with high latency (50-200ms) and the possibility of region-level failures.",
            concepts: [
                DesignConcept(title: "Active-active", detail: "Both regions serve read and write traffic. Requires multi-leader replication or a globally distributed database (CockroachDB, Spanner). Highest availability but most complex."),
                DesignConcept(title: "Active-passive", detail: "Primary region serves all traffic. Secondary region is on standby with replicated data. Failover promotes the secondary. Simpler but secondary is cold and failover takes minutes."),
                DesignConcept(title: "Data residency", detail: "Some regulations (GDPR, data localization laws) require data to stay within a geographic boundary. Route users to the region that holds their data. Cross-region replication may be prohibited."),
                DesignConcept(title: "Global load balancing", detail: "DNS-based routing (GeoDNS) sends users to the nearest region. Anycast routing advertises the same IP from all regions. Health checks remove unhealthy regions from DNS."),
                DesignConcept(title: "Cross-region latency", detail: "Inter-region communication adds 50-200ms per round trip. Minimize cross-region calls. Replicate reference data locally. Use async replication for non-critical data.")
            ],
            diagramNodes: [
                DiagramNode(title: "Global DNS", subtitle: "GeoDNS / Anycast", icon: "globe", role: .edge),
                DiagramNode(title: "Region A (US)", subtitle: "Active: reads + writes", icon: "flag.fill", role: .service),
                DiagramNode(title: "Region B (EU)", subtitle: "Active: reads + writes", icon: "flag.fill", role: .service),
                DiagramNode(title: "Replication", subtitle: "Async cross-region sync", icon: "arrow.left.arrow.right", role: .queue),
                DiagramNode(title: "Region C (APAC)", subtitle: "Passive: standby", icon: "flag.slash.fill", role: .external)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Start with active-passive unless you have a concrete latency or compliance requirement for active-active. Active-passive is simpler and sufficient for most disaster recovery needs.",
                "Cross-region replication lag is 1-10 seconds. Design the application to tolerate this lag. Read-your-writes consistency requires routing the user to the region they wrote to.",
                "Test failover regularly. A failover that has never been tested is a failover that will not work. Run failover drills quarterly and measure recovery time.",
                "Data residency is a legal requirement, not a technical preference. Map which data must stay in which region before designing the replication topology."
            ],
            tradeoffs: [
                "Active-active gives the best latency and availability but requires conflict resolution for concurrent writes in different regions. Multi-leader replication adds significant complexity.",
                "Active-passive is simpler but the passive region is idle capacity. Failover takes minutes during which the system is unavailable.",
                "GeoDNS routing is simple but DNS caching means failover can take 5-30 minutes (TTL). Anycast is faster but requires network-level infrastructure."
            ]
        ),
        SystemDesignTopic(
            id: "design-review-checklist",
            title: "Design review checklist",
            icon: "checklist",
            category: "Interview Prep",
            overview: "A structured checklist ensures you cover all dimensions of a system design in 45 minutes. The best candidates move through requirements, API design, data modeling, high-level architecture, deep dives, and scaling in a predictable rhythm that demonstrates senior-level thinking.",
            concepts: [
                DesignConcept(title: "Requirements (5 min)", detail: "Clarify functional requirements (what it does), non-functional requirements (scale, latency, availability), and constraints (budget, team size, existing infrastructure)."),
                DesignConcept(title: "API design (5 min)", detail: "Define the core API endpoints with request/response shapes. This forces you to think about the data model before drawing boxes."),
                DesignConcept(title: "Data model (5 min)", detail: "Define tables/collections with primary keys, indexes, and relationships. Choose SQL vs NoSQL based on access patterns identified in the API design."),
                DesignConcept(title: "High-level architecture (10 min)", detail: "Draw the major components: client, load balancer, services, databases, caches, queues. Explain the read and write paths through the system."),
                DesignConcept(title: "Deep dive + scaling (20 min)", detail: "Pick 2-3 components to explore in depth. Discuss bottlenecks, failure modes, and how each component scales. This is where senior candidates differentiate themselves.")
            ],
            diagramNodes: [
                DiagramNode(title: "1. Requirements", subtitle: "Functional + non-functional", icon: "1.circle.fill", role: .client),
                DiagramNode(title: "2. API Design", subtitle: "Endpoints + payloads", icon: "2.circle.fill", role: .service),
                DiagramNode(title: "3. Data Model", subtitle: "Tables + indexes", icon: "3.circle.fill", role: .storage),
                DiagramNode(title: "4. Architecture", subtitle: "Components + data flow", icon: "4.circle.fill", role: .edge),
                DiagramNode(title: "5. Deep Dive", subtitle: "Bottlenecks + scaling", icon: "5.circle.fill", role: .monitor)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Spend the first 5 minutes asking questions. Candidates who jump straight to drawing boxes miss requirements that change the entire design.",
                "Write down the API before drawing the architecture. The API defines the contract. The architecture implements it. Reversing this order leads to awkward designs.",
                "Name the bottlenecks explicitly. 'The database will be the bottleneck at 10K writes/sec' shows you think about scale quantitatively, not just qualitatively.",
                "End with what you would build first vs later. A phased approach (MVP → scale → optimize) shows engineering maturity and practical experience."
            ],
            tradeoffs: [
                "Spending too long on requirements leaves no time for deep dives. Spending too little leads to designing the wrong system. Aim for 5 minutes of requirements, no more.",
                "Drawing a perfect architecture diagram wastes time. A rough sketch with clear labels and data flow arrows is more valuable than a beautiful diagram.",
                "Covering every component superficially is worse than covering 2-3 components in depth. Interviewers evaluate depth of thinking, not breadth of coverage."
            ]
        ),
        SystemDesignTopic(
            id: "mock-interview",
            title: "Mock interview practice",
            icon: "person.2.wave.chevron.fill",
            category: "Interview Prep",
            overview: "The mock interview is where everything comes together. Practice explaining a complete system design from requirements to scaling plan in 45 minutes. Focus on communication clarity, quantitative reasoning, and demonstrating that you have built real systems before.",
            concepts: [
                DesignConcept(title: "Communication structure", detail: "State what you are doing before you do it. 'First, I will define the API. Then I will model the data. Then I will draw the architecture.' This keeps the interviewer oriented."),
                DesignConcept(title: "Quantitative reasoning", detail: "Estimate numbers: DAU, requests/sec, data size, storage needs. '100M DAU, 10 requests each = 1B requests/day = 12K QPS average, 36K QPS peak.' This drives architecture decisions."),
                DesignConcept(title: "Tradeoff narration", detail: "For every decision, state the alternative and why you chose this one. 'I chose Redis over Memcached because I need persistence for session data.' This shows depth."),
                DesignConcept(title: "Handling ambiguity", detail: "When the interviewer is vague, make reasonable assumptions and state them. 'I will assume 10M monthly active users. If that is wrong, I will adjust.' Do not wait for perfect information."),
                DesignConcept(title: "Self-correction", detail: "If you realize a design flaw, acknowledge it and fix it. 'Actually, this creates a single point of failure. Let me add a replica.' Self-correction shows senior-level judgment.")
            ],
            diagramNodes: [
                DiagramNode(title: "Clarify", subtitle: "Ask questions, state assumptions", icon: "questionmark.circle.fill", role: .client),
                DiagramNode(title: "Design", subtitle: "API, data, architecture", icon: "pencil.and.ruler.fill", role: .service),
                DiagramNode(title: "Deep Dive", subtitle: "Bottlenecks, failure modes", icon: "magnifyingglass.circle.fill", role: .storage),
                DiagramNode(title: "Scale", subtitle: "How each component grows", icon: "arrow.up.right.circle.fill", role: .edge),
                DiagramNode(title: "Summarize", subtitle: "Recap decisions + tradeoffs", icon: "checkmark.circle.fill", role: .monitor)
            ],
            diagramStyle: .flow,
            talkingPoints: [
                "Practice with a timer. 45 minutes feels long until you are in the interview. Most candidates run out of time because they spend too long on the high-level design.",
                "Record yourself explaining a design. Listen back for filler words, unclear explanations, and places where you assumed knowledge the interviewer would not have.",
                "Prepare 3-5 systems you know deeply (a web app, a data pipeline, a real-time system, a mobile backend). Most interview questions map to one of these archetypes.",
                "Ask the interviewer for feedback mid-interview. 'Does this direction make sense, or would you like me to explore a different approach?' This shows collaboration and saves time."
            ],
            tradeoffs: [
                "Practicing alone builds technical depth but does not improve communication. Practice with a partner to get feedback on clarity and pacing.",
                "Memorizing designs for specific questions (design Twitter, design Uber) is fragile. Interviewers modify questions. Understanding patterns (fanout, geospatial, real-time) is transferable.",
                "Over-preparing can make you rigid. If the interviewer wants to explore a specific component, follow their lead. The interview is a conversation, not a presentation."
            ]
        )
    ]
}
