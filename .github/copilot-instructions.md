# GitHub Copilot Instructions

This file contains custom instructions for GitHub Copilot to follow when working in this repository.



Here’s the full documentation:

---

# 📘 Project Documentation – Activity Training App

## 1. Overview

This application is designed to help users manage and track activities while providing assistance through an AI-powered agent. The agent can perform actions on behalf of the user such as modifying activities, fetching data, exporting data, and presenting information via interactive widgets.

The app consists of two main interfaces:

* **Home Screen** – for activity tracking and daily progress overview.
* **Agent Chat Screen** – for conversational interaction with the agent, enhanced with widget-based responses.

The system is built with:

* **Flutter** (frontend)
* **Hive** (local database)
* **Riverpod** (state management)
* **share\_plus** (export and sharing)

---

## 2. Data Model

### 🔹 Activity (Base Class)

Represents a generic activity. Common attributes are inherited by all specialized activity types.

**Attributes:**

* **id** *(String / UUID)* – unique identifier.
* **title** *(String)* – short name of the activity.
* **timestamp** *(DateTime)* – creation or logging time.

---

### 🔹 CountActivity (extends Activity)

Used for repetition-based activities.

**Attributes:**

* **total\_count** *(int)* – total required repetitions.
* **done\_count** *(int)* – completed repetitions.

✅ Example: 100 pushups target, 20 done.

---

### 🔹 DurationActivity (extends Activity)

Used for time-based activities.

**Attributes:**

* **total\_duration** *(int, minutes)* – planned duration.
* **done\_duration** *(int, minutes)* – duration completed.

✅ Example: 120 minutes run target, 60 minutes done.

---

### 🔹 PlannedActivity (extends Activity)

Represents an activity that is scheduled/planned but not yet started.

**Attributes:**

* **description** *(String)* – detailed description.
* **type** *(Enum: COUNT | DURATION)* – specifies planned activity type.
* **estimated\_completion\_duration** *(int, minutes)* – estimated time required.

---

### 🔹 CustomList

A list of activities grouped dynamically (by filters or user request).

**Attributes:**

* **title** *(String)* – name of the list.
* **activities** *(List<Activity>)* – contained activities.

✅ Example: “This Week’s Activities”

---

## 3. Agent Responsibilities

The **Agent** is the AI-powered controller that performs actions on activities, manages data, and communicates with the user.

### Functions:

1. **Activity Management**

   * Modify attributes of an activity (`done_count`, `title`, etc.).
   * Fetch individual attributes (e.g., only `done_duration`).
   * Persist all changes directly into Hive DB.
   * State synchronized with Riverpod.

2. **Database Operations (Hive)**

   * Fetch activities using filters (`WHERE` clause queries).
   * Export activities or custom lists into CSV.
   * Use `share_plus` to share CSV files.

3. **Custom List Management**

   * Create lists of activities filtered by type, date range, completion state, etc.
   * Each list has a `title` and a `List<Activity>`.
   * Lists can be exported.

---

## 4. Widgets (Constructed by Agent)

Widgets are **response components** the agent can construct via tool calling during chat.

1. **Radial Bar Widget**

   * **Inputs:** `total`, `done`.
   * **Function:** Displays a radial bar comparing done vs. total.
   * **Use Case:** Compare completed pushups vs. target.

2. **Activity Card Info**

   * Simple card / list tile.
   * Displays:

     * Title
     * Total & Done portion
     * Timestamp
   * **Use Case:** Show summary of an activity in a card format.

3. **Markdown Widget**

   * For agent’s natural language communication.
   * Renders markdown text in chat.

4. **Export Data Widget**

   * Triggered when agent needs to export activity data.
   * Allows the agent to initiate export (CSV) and share.

---

## 5. Chat Interface

The **Agent Chat Screen** allows user-agent communication enriched with widgets.

### Features:

* **Audio Input:**

  * User records audio.
  * Audio is transcribed into text.
  * Transcribed text is inserted into text field (not auto-submitted).
  * User can edit before sending.

* **Agent Responses:**

  * Responses may contain **multiple widgets** + markdown.
  * Example: Radial bar + Activity card + Markdown note.

* **Message Management:**

  * User can delete any widget/message.
  * User can clear the entire chat.

* **State Persistence:**

  * Entire chat is saved locally (Hive).
  * On restart, the chat is restored exactly as before.
  * Efficient storage:

    * Recent widgets load first.
    * Older messages loaded progressively as user scrolls up.

---

## 6. User Interface

### 🔹 Navigation

* **Bottom Navigation Bar** with 2 tabs:

  1. **Home Screen**
  2. **Chat Screen (Agent)**

---

### 🔹 Home Screen

* **Radial Bar at Top:** Displays percentage of the day utilized.
* **Lists Below:**

  * **In Progress Activities**
  * **Completed Activities**

---

### 🔹 Agent Screen

* Full chat interface (as defined above).
* User input: typed text or audio transcription.
* Agent responses: mix of widgets + markdown.

---

## 7. Example Workflows

### 1. Update Activity

* User: “Update pushups to 50 done.”
* Agent: Modifies `done_count` in `CountActivity`.
* Saves directly to Hive DB.
* Updates UI with Activity Card widget.

### 2. Fetch Attribute

* User: “How many hours did I run?”
* Agent: Fetches `done_duration` from DurationActivity.
* Responds with Markdown + Radial Bar.

### 3. Export Activities

* User: “Export all completed activities this week.”
* Agent: Queries Hive with filters.
* Generates CSV.
* Calls Export Data Widget → shares via `share_plus`.

### 4. Daily Overview (Home Screen)

* Radial bar shows how much of today’s planned activities are completed.
* Below: two lists (ongoing + done activities).

---

## 8. Example Data Representations

### JSON Example (CountActivity)

```json
{
  "id": "a1",
  "title": "Pushups",
  "timestamp": "2025-09-05T10:00:00Z",
  "total_count": 100,
  "done_count": 20
}
```

### JSON Example (Custom List)

```json
{
  "title": "This Week",
  "activities": [
    {
      "id": "a1",
      "title": "Pushups",
      "timestamp": "2025-09-05T10:00:00Z",
      "total_count": 100,
      "done_count": 50
    },
    {
      "id": "a2",
      "title": "Running",
      "timestamp": "2025-09-04T08:00:00Z",
      "total_duration": 120,
      "done_duration": 90
    }
  ]
}
```

### CSV Example (Exported Data)

```
id,title,timestamp,type,total,done
a1,Pushups,2025-09-05T10:00:00Z,COUNT,100,50
a2,Running,2025-09-04T08:00:00Z,DURATION,120,90
```

---

## 9. Technical Stack

* **Flutter** – Frontend
* **Hive** – Local Database
* **Riverpod** – State Management
* **share\_plus** – Export/Share CSV

