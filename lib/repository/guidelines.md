FunctionDeclaration(
  'listWishlistItems',
  'Retrieve all wishlist items with their IDs and details for quick lookup',
  parameters: <String, Schema>{
    'includeCompleted': Schema.boolean(
      description: 'Whether to include completed/finished wishlist items (default: true)',
      nullable: true,
    ),
    'type': Schema.string(
      description: 'Optional filter: "count" or "duration"',
      nullable: true,
    ),
    'dueBeforeStr': Schema.string(
      description: 'Optional filter: only items due before this date (format: yyyy-MM-dd)',
      nullable: true,
    ),
  },
),
📌 DB Method
Extend WishlistRepository:

dart
Copy code
List<WishlistItem> listItems({
  bool includeCompleted = true,
  String? type,
  DateTime? dueBefore,
}) {
  return box.values.where((item) {
    bool matches = true;

    if (type != null && item.type != type) {
      matches = false;
    }

    if (dueBefore != null && item.dueDate.isAfter(dueBefore)) {
      matches = false;
    }

    if (!includeCompleted) {
      if (item.type == 'count' && (item.count ?? 0) <= 0) {
        matches = false;
      }
      if (item.type == 'duration' && (item.duration ?? 0) <= 0) {
        matches = false;
      }
    }

    return matches;
  }).toList();
}
📌 Example Use Cases
User says:
“Update last wishlist due date to 20 Sep.”
→ LLM first calls listWishlistItems to fetch items and IDs:

json
Copy code
{
  "includeCompleted": false
}
→ Gets list including "Fast API Course Completion" with ID 12345.
→ Then calls updateWishlistItem with:

json
Copy code
{
  "id": "12345",
  "updates": { "dueDateStr": "2025-09-20" }
}
User says:
“What are all my current goals?”
→ LLM calls listWishlistItems:

json
Copy code
{}
→ Returns full list with IDs, titles, and remaining progress.

User says:
“Show me only duration-based goals due before October.”
→ LLM calls:

json
Copy code
{
  "type": "duration",
  "dueBeforeStr": "2025-10-01"
}