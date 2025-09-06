# Implementation Strategy — Activity Training App (Core Models & Database)

## 1. Purpose & Scope

This document describes the implementation strategy for the core model classes, database layout, and related infrastructure required to realize the Activity Training application’s storyboard and agent-driven workflows. It is written for the coding agent and developers responsible for implementing models, persistence, state management, and the agent toolkit. **No code** is included — only formal design, rules, and acceptance criteria.

This strategy focuses on:

* The domain model and how to represent it in Hive.
* Riverpod-based state management architecture and synchronization rules.
* Agent toolkit surface (what functions/tools the agent should rely on).
* Widget construction rules and data contracts for widgets.
* Chat persistence, audio transcription flow, export workflow, and performance considerations.
* Testing and verification strategy to ensure model correctness.

## 2. High-level Principles and Non-functional Requirements

1. **Single Source of Truth (SSOT):** Hive must be the authoritative data store for activities and chat state. UI and agent state are views derived from Hive via Riverpod providers.
2. **Immediate Persistence:** Any modification initiated by the agent or user must be persisted to Hive in real time, with Riverpod used to keep UI in sync.
3. **Token & Data Economy:** Agent interactions that request data should fetch **only** the fields required for the task; avoid fetching entire objects blindly. Use summarization and limited fields for agent reasoning to reduce token cost.
4. **Modularity & Testability:** Separate domain logic, repository logic, provider/adapter layers, and widget construction so unit tests can target each layer.
5. **Performance & UX:** Recent chat messages and recent activities should load first; older data should load lazily as the user scrolls. Avoid blocking the UI for long operations by using asynchronous operations and optimistic updates.
6. **Generalization:** Activities are **not** workout-specific; the domain model supports any count- or duration-based tasks and planned tasks.

## 3. Domain Model (Descriptive — no code)

These are the canonical domain concepts. Each entry lists responsibilities, important fields, and invariants.

### Activity (Base)

**Purpose:** Base abstraction for anything the user wants to track. Shared fields are the basis for queries and widget construction.
**Fields:** `id` (unique identifier), `title` (short text), `timestamp` (Date/time for creation or schedule), `type` (discriminator: COUNT|DURATION|PLANNED)
**Invariants:** `id` unique; `title` non-empty; `timestamp` stored in ISO-like format with timezone.

### CountActivity (Activity subtype)

**Purpose:** Track repetition-based tasks.
**Fields:** inherits base fields; `total_count` (target integer), `done_count` (integer)
**Invariants:** 0 ≤ `done_count` ≤ `total_count` (unless explicitly allowed to exceed — see policy below). When `total_count` is unknown, it may be null but `type` remains COUNT.

### DurationActivity (Activity subtype)

**Purpose:** Track time-based tasks and contribute to the daily utilization metric.
**Fields:** inherits base fields; `total_duration` (minutes or seconds), `done_duration` (minutes or seconds)
**Invariants:** All durations stored using the same unit (minutes recommended). 0 ≤ `done_duration` ≤ `total_duration` (or `total_duration` can be null for open-ended tasks).

### PlannedActivity (Activity subtype)

**Purpose:** A scheduled/planned item that may be either count-based or duration-based. Useful for future planning and schedule display.
**Fields:** inherits base fields; `description`, `planned_type` (COUNT|DURATION), `estimated_completion_duration` (minutes) or `estimated_total_count` (if COUNT)
**Invariants:** `timestamp` may indicate scheduled date/time. Planned activities may be promoted to active CountActivity/DurationActivity when started.

### CustomList

**Purpose:** Named collections of activities produced by agent queries or user requests (e.g., "This Week", "Stretch Routine").
**Fields:** `title`, `activityIds` (ordered list of activity ids), `createdAt`.
**Invariants:** Activity ids reference existing activities; list order preserved as created by agent/user.

### ChatMessage (for agent <-> user chat state persistence)

**Purpose:** Persist chat messages and widget instances so chat can be fully restored across restarts.
**Fields:** `id`, `sender` (user|agent|system), `timestamp`, `content` (text content or null), `widgetType` (nullable), `widgetData` (structured payload for widget reconstruction), `isDeleted` (soft-delete flag)
**Invariants:** `widgetData` is the serialized minimal representation required to reconstruct the widget in UI.

### WidgetModel (conceptual)

**Purpose:** A typed contract describing how widgets are constructed given data; built by agent via tool-calls.
**Common Widget Inputs:** radial: {total, done}, activityCard: {id, title, total, done, timestamp}, markdown: {text}, exportData: {fileId, fileName, columns}
**Invariants:** Widgets persisted in chat should contain only data necessary for rendering. Widgets that reference activity ids may fetch fresh activity details when displayed (to reflect updates).

## 4. Hive Storage Strategy & Schema Design (Guidelines)

These are recommendations to store data efficiently and allow easy retrieval and queries. The design balances simplicity, query performance, and storage efficiency.

### Boxes

* **activities** — main box to store all Activity records (single box, use `type` discriminator). Rationale: a single box simplifies queries that cross types (e.g., "activities in last week").
* **custom\_lists** — store CustomList objects (title + ordered activityIds).
* **chat\_messages** — store chat history including widget payloads.
* **exports** (optional) — metadata for generated CSV exports (filename, path, timestamp).

### Record Format

* Use a record object per Activity with a `type` string (COUNT, DURATION, PLANNED). Store numeric fields (durations, counts) as native integers. Include `updatedAt` for concurrency or audit.
* For `timestamp`, always store an ISO8601 string or epoch millis, consistently across records.

### Indexes & Query Hints

* While Hive doesn’t support indexes natively, store derived query fields for faster filter-based lookup when needed (for example, `dateBucket` for day/week/month) or maintain secondary boxes/mappings: e.g., `activities_by_dateBucket` map from dateBucket to list of IDs. Use this only if necessary for performance.

### Inheritance & Type Handling

* Use a discriminator field `type` in the activity record and store all fields in the same object. Fields that don’t apply for a `type` may be null. This reduces the need for multiple boxes and simplifies cross-type queries.

### Transactions & Atomicity

* Group multi-field updates (e.g., incrementing `done_count` and setting `updatedAt`) in a single write operation to Hive to avoid transient inconsistent state.

## 5. Repository & Provider Layer (Behavioral Contract)

Define a repository layer that encapsulates Hive reads/writes. The agent should use repository APIs rather than interacting with Hive directly.

### Repository Responsibilities

* CRUD operations for activities.
* Query functions with well-defined arguments: `byType(type, limit, offset)`, `byDateRange(start, end, limit, offset)`, `byCompletion(isDone, limit, offset)`, `byId(id)`, and `customQuery(filters...)`.
* Export function: `generateCsv(listOfActivityIds, columns, filename)` which returns an export metadata handle.
* Chat persistence helpers: append message, fetch messages (paged), mark deleted.

### Provider (Riverpod) Patterns

* **activityRepositoryProvider**: exposes repository instance.
* **activityListProvider**: parameterized (family) provider returning paginated activities for given filters. Use `AutoDispose` with caching rules.
* **activityDetailProvider(id)**: provider that returns live updates for a single activity (listen to Hive box changes or repository stream).
* **chatProvider**: provider that manages chat message pagination, append/delete, and persistence.
* **widgetFactoryProvider**: creates widget payloads from activities or raw inputs.
* **exportProvider**: manages export creation state and share flow.

**Behavior Rules:**

* Providers must reflect Hive updates: when repository writes to Hive, related providers should refresh automatically.
* Support optimistic updates: provider updates UI first, repository write proceeds; on write failure, provider rollbacks and surfaces error.

## 6. Agent Tool-kit (Surface the agent should use)

The following functions/tools are what the agent is permitted and expected to use. Represent them abstractly as capabilities; each maps to repository or provider functions.

### Core Tools

1. **fetchActivity(id, fields=\[])** — fetch specific fields for token efficiency. If `fields` omitted, fetch summary fields.
2. **queryActivities(filters, limit, offset, fields=\[])** — return ordered list of activity IDs and minimal fields.
3. **updateActivity(id, updates)** — apply and persist updates atomically; returns updated activity summary.
4. **createActivity(activityData)** — create and persist new activity (Count, Duration, or Planned). Returns id.
5. **deleteActivity(id)** — soft or hard delete as per app policy.
6. **createCustomList(title, activityIds)** — persist named list.
7. **exportActivitiesToCsv(activityIds, columns)** — generate CSV and return export metadata (path, fileName).
8. **appendChatMessage(messagePayload)** — persist chat message with minimal widget payload.
9. **fetchChatMessages(pageToken)** — paginated chat fetch.
10. **transcribeAudio(audioBlob)** — returns transcribed text (agent must place it in the input field, not auto-submit). This tool integrates with the transcriber service.

### Helper Tools

* **computeDailyUtilization(date)** — returns total duration done today and total planned; used to render the home radial.
* **suggestActivities(availableTimeMinutes, userContext)** — returns ordered candidate activities (IDs + score) considering user interests, mood, and activity suitability.
* **summarizeActivitiesForAgent(activityIds, tokenLimit)** — returns concise summaries to keep token usage low.

## 7. Widget Construction Rules & Contracts

Widgets are UI primitives the agent constructs by calling the widget factory via tool calls. Each widget must carry only the minimal data required to render.

### General Rules

* Widgets persisted in chat should reference activity `id` whenever possible instead of embedding entire activity data (this keeps the widget small and allows live refresh). However, to guarantee consistent rendering after activity deletion or changes, include a small `fallbackSnapshot` object with the essential displayed values.
* Widgets must specify a stable `widgetType` and a small `widgetData` map.
* When a widget displays data derived from activities (e.g., radial bar), the rendering logic may optionally re-query the latest activity values at render time.

### Widget Contracts

1. **Radial Bar Widget**

   * Inputs: `total`, `done`, `label` (optional), `id` (optional activity id), `fallbackSnapshot`.
   * Expected behavior: show percent = done/total; if `total` is zero or null, show indeterminate state.

2. **Activity Card Info**

   * Inputs: `activityId`, `title`, `total`, `done`, `timestamp`, `status` (in-progress|done|planned), `fallbackSnapshot`.
   * Expected behavior: summary card with quick actions (edit, open details).

3. **Markdown Widget**

   * Inputs: `text` (markdown string).
   * Expected behavior: render rich text; can contain short data tables.

4. **Export Data Widget**

   * Inputs: `exportId`, `fileName`, `filePath`, `summary`.
   * Expected behavior: allow user to tap and share; show progress while generating.

## 8. Chat & Audio Flow (UX + Persistence)

### Audio Recording & Transcription

* User taps record -> audio recorded locally (temporary blob).
* Transcription service called via `transcribeAudio` tool.
* Transcribed text returned and placed in the **input text field** for user review (do not auto-send). User edits and sends.
* When user sends, call `appendChatMessage` and pass any associated widget requests.

### Chat Message Lifecycle

* **Create**: on send, message persisted in `chat_messages` box with `widgetData` (if any) and timestamp.
* **Render**: chat UI renders message; for widget messages, use widget factory to reconstruct widget.
* **Delete**: user can delete message/widget; implement soft-delete (`isDeleted`) with option to permanently purge periodically.
* **Clear Chat**: allow user to clear chat (wipe or archive), with confirmation.

### Pagination & Lazy Loading

* `fetchChatMessages` must support limit + cursor (or page token). Load most recent N messages on open and fetch older messages when the user scrolls up.
* Keep an in-memory cache of recently used page tokens to avoid re-fetching the same pages.

### Persistence Efficiency

* Chat message objects should be compact: store only identifiers and minimal payloads for widgets and optionally a small fallback snapshot.

## 9. Data Retrieval, Query Patterns & NL Mapping

Describe typical natural language requests and exact repository queries the agent should produce (conceptually). These translate into calls to `queryActivities`.

### Examples

1. **"Show me activities done in the last week"**

   * Query: `byDateRange(start = now - 7 days, end = now, isDone = true, fields = [id,title,timestamp,type,total,done])`
2. **"Export all duration activities between June 1 and June 7"**

   * Query: `byType(DURATION) & byDateRange(June 1, June 7)` -> `exportActivitiesToCsv(ids, columns=[id,title,timestamp,type,total,done])`
3. **"How much of my day is utilized?"**

   * Call: `computeDailyUtilization(today)` -> returns `doneMinutes` & `plannedMinutes` -> radial percent = done/planned (cap at 100%).

**NL to filter mapping rules:**

* Time expressions must be normalized to precise start/end timestamps before querying.
* Ambiguous phrases ("last week") must be interpreted using a defined convention (e.g., last 7 days or the last calendar week). If ambiguous, agent should ask a clarifying question.

## 10. Modification Rules & Concurrency

* All updates must be performed through `updateActivity(id, updates)`.
* Use atomic writes to avoid partial state. If the platform supports Hive batch write, use it for multi-field updates.
* For concurrent modifications (e.g., user manually edits while agent writes), adopt **last-writer-wins** guided by `updatedAt` timestamp; surface a conflict notification if needed.
* Keep `updatedAt` field on each activity to assist with reconciliation and sync.

## 11. CSV Export Specification

**Column Set (recommended):** `id, title, type, timestamp, total_value, done_value, extra_description`

* For `total_value` and `done_value`, map `count` to integer or `duration` to minutes. Include units in metadata.
* **Filename convention:** `activities_export_{filter}_{YYYYMMDD_HHMMSS}.csv`
* **Timezone:** Always persist timestamp in UTC or include timezone info. When exporting, offer timezone normalized strings.
* Export generation steps: gather IDs -> fetch minimal fields -> stream CSV rows -> write to temp storage -> create export metadata -> optionally call `share_plus`.

## 12. Analytics, Efficiency & Token Management

* **Summarization**: When the agent must reason about multiple activities, use `summarizeActivitiesForAgent(activityIds, tokenLimit)` to compress data.
* **Field selection**: always request explicit fields. Avoid fetching `widgetData` or full `description` unless necessary.
* **Batch queries**: prefer batched queries instead of N single fetches.

## 13. Testing Plan (Verifications for correctness)

### Unit Tests

* Model invariants (e.g., done ≤ total, durations non-negative).
* Repository CRUD operations (mock Hive or use isolated test boxes).
* Utility functions: `computeDailyUtilization`, `summarizeActivitiesForAgent`.

### Integration Tests

* Real Hive test boxes to validate persistence, pagination, and correct serialization.
* Riverpod provider tests for state refresh on writes.

### End-to-End (E2E)

* Test flows: create duration activity + related count activity, update done values, export CSV, chat-driven updates, audio transcribe -> edit -> send.

### Agent-centered Tests

* Given a natural language query, assert the repository query produced (or tool calls used) and that the resulting widget(s) match expected contracts.
* Token usage tests: verify summarization reduces payload size under token budgets.

## 14. Acceptance Criteria (What 'Done' Looks Like)

1. Home screen radial progress shows daily utilization computed from duration activities and updates in real time when durations change.
2. Home screen lists show in-progress and completed activities and update based on Hive state changes.
3. Creating a duration activity that includes a count component creates two persisted activity records (one duration, one count) when requested.
4. Agent can fetch individual activity attributes on demand and uses minimal fields.
5. Agent can perform atomic updates to activity attributes and the changes are immediately reflected in the UI.
6. Chat messages with widgets persist and fully restore after app restart; recent messages load first and older messages load as user scrolls up.
7. Audio is transcribed and inserted into the input field for user editing; transcription is not auto-sent.
8. The agent can export filtered activities to CSV and trigger share flow with `share_plus`.
9. Suggestion function returns ranked suggestions based on available time and user context.
10. All core flows covered by automated tests and pass CI.

## 15. Implementation Roadmap (Step-by-step)

**Phase 0 — Setup & Foundation**

* Define model classes and invariants (no code here — design validated via tests).
* Create repository interface and provider skeletons.

**Phase 1 — Persistence & Models**

* Implement Hive boxes and serialization rules.
* Implement repository functions for CRUD and queries.
* Add `updatedAt` auditing on activities.

**Phase 2 — Providers & Home Screen**

* Implement Riverpod providers: activityListProvider, activityDetailProvider, computeDailyUtilization.
* Implement Home UI: radial progress (reads computeDailyUtilization), lists (in-progress | done), and basic activity cards.
* Ensure updates are reflected via provider reactivity.

**Phase 3 — Chat & Widgets**

* Implement chat message model and chatProvider with pagination.
* Implement widget factory that maps `widgetData` to UI widgets.
* Implement message send flow and deletion/clear flows.

**Phase 4 — Agent Tools & Exports**

* Implement agent-facing tools for selective fetch, updates, suggestions, and CSV export.
* Implement export provider and share flow using `share_plus`.

**Phase 5 — Audio Transcription & UX polish**

* Integrate the transcription pipeline and text-in-input flow.
* Add optimistic updates, conflict handling, and validation UI.

**Phase 6 — Testing & Hardening**

* Implement tests described in Section 13.
* Run performance tests and optimize: pagination cache, derived fields, etc.

## 16. Troubleshooting & Developer Handoff Notes

* **If data appears stale in UI:** confirm providers are subscribed to Hive listeners or are invalidated after writes. Check `updatedAt` propagation.
* **If exports are incomplete:** validate `fields` passed to export pipeline. Ensure time range normalization is correct.
* **If chat widget shows wrong snapshot:** verify widget `fallbackSnapshot` creation at message time.

## 17. Appendix — Example NL → Agent Steps (Conceptual)

1. "Show me activities done last week"

   * Normalize date range → call `queryActivities(byDateRange(start, end), fields=[id,title,timestamp,type,totalValue,doneValue])` → construct a list of Activity Card Info widgets.

2. "I have 2 hours free, suggest activities"

   * Call `suggestActivities(availableTimeMinutes=120, userContext)` → returns ranked IDs → fetch minimal fields for top N → present suggestions as Activity Card widgets and a Markdown summary.

3. "Export my weekend workouts"

   * Parse weekend date range → query matching activities → call `exportActivitiesToCsv` → present Export Data widget with link to share.

## 18. Glossary

* **SSOT** — Single Source of Truth (Hive box).
* **WidgetData / fallbackSnapshot** — Minimal data needed to render a widget later without re-fetching.
* **Token Economy** — Limiting data sent to agent to reduce usage of token-limited resources.

---

If anything should be expanded into a developer checklist or a printable handoff doc, tell me and I will prepare that next.
