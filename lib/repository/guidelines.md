1. Define WishlistItem Model
import 'package:hive/hive.dart';

part 'wishlist_item.g.dart';

@HiveType(typeId: 5) // pick next unused typeId in your app
class WishlistItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4)
  String type; // "duration" or "count"

  @HiveField(5)
  int? count; // for count-based goals

  @HiveField(6)
  int? duration; // in minutes, for duration-based goals

  WishlistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.type,
    this.count,
    this.duration,
  });
}


Then generate the Hive adapter:

flutter packages pub run build_runner build

2. Create Hive Box

Open the box somewhere in your app bootstrap (e.g., main.dart):

await Hive.openBox<WishlistItem>('wishlistBox');

3. CRUD Methods

Repository-style service to keep logic clean:

class WishlistRepository {
  final Box<WishlistItem> box = Hive.box<WishlistItem>('wishlistBox');

  List<WishlistItem> getAllItems() {
    return box.values.toList();
  }

  WishlistItem? getItem(String id) {
    return box.values.firstWhere((item) => item.id == id, orElse: () => null);
  }

  Future<void> addItem(WishlistItem item) async {
    await box.put(item.id, item);
  }

  Future<void> updateItem(String id, WishlistItem updated) async {
    await box.put(id, updated);
  }

  Future<void> deleteItem(String id) async {
    await box.delete(id);
  }
}

4. Function Declarations for Gemini

Following the same style as your updateLatestRecord, here are tools for CRUD operations:

FunctionDeclaration(
  'createWishlistItem',
  'Create a new wishlist item (goal) for the user.',
  parameters: <String, Schema>{
    'title': Schema.string(description: 'Title of the wishlist item (goal)'),
    'description': Schema.string(description: 'Description of the goal'),
    'dueDateStr': Schema.string(
      description: 'Due date in format: yyyy-MM-dd',
    ),
    'type': Schema.string(
      description: 'Type of goal: "count" or "duration"',
    ),
    'count': Schema.number(
      description: 'Target count value for count-based goals',
      nullable: true,
    ),
    'duration': Schema.number(
      description: 'Target duration in minutes for duration-based goals',
      nullable: true,
    ),
  },
),

FunctionDeclaration(
  'updateWishlistItem',
  'Update fields of an existing wishlist item',
  parameters: <String, Schema>{
    'id': Schema.string(description: 'ID of the wishlist item to update'),
    'updates': Schema.object(
      description: 'Fields to update',
      properties: {
        'title': Schema.string(description: 'New title', nullable: true),
        'description': Schema.string(description: 'New description', nullable: true),
        'dueDateStr': Schema.string(
          description: 'New due date in format: yyyy-MM-dd',
          nullable: true,
        ),
        'count': Schema.number(description: 'New count value', nullable: true),
        'duration': Schema.number(description: 'New duration in minutes', nullable: true),
      },
    ),
  },
),

FunctionDeclaration(
  'deleteWishlistItem',
  'Delete a wishlist item by its ID',
  parameters: <String, Schema>{
    'id': Schema.string(description: 'ID of the wishlist item to delete'),
  },
),

FunctionDeclaration(
  'getWishlistItems',
  'Retrieve all wishlist items or filter by type/due date',
  parameters: <String, Schema>{
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

5. Example Use Cases

User says:
“I need to complete a 9 hour course on FastAPI this week.”
→ LLM calls createWishlistItem with:

{
  "title": "Complete FastAPI Course",
  "description": "9 hour FastAPI course",
  "dueDateStr": "2025-09-21",
  "type": "duration",
  "duration": 540
}


User says:
“I need to complete 1000 pushups in 2 days.”
→ LLM calls createWishlistItem with:

{
  "title": "1000 Pushups",
  "description": "Do 1000 pushups",
  "dueDateStr": "2025-09-17",
  "type": "count",
  "count": 1000
}


User later says:
“I did 300 pushups today.”
→ LLM calls updateWishlistItem with:

{
  "id": "<pushups-item-id>",
  "updates": { "count": 700 }
}