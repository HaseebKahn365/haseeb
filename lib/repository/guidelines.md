3. deleteWishlistItem

(Remove wishlist items — also used when a goal is completed)

FunctionDeclaration(
  'deleteWishlistItem',
  'Delete a wishlist item by its ID (also used when a goal is completed)',
  parameters: <String, Schema>{
    'id': Schema.string(description: 'ID of the wishlist item to delete'),
  },
),


DB Method:

Future<void> deleteItem(String id) async {
  await box.delete(id);
}


//removal and clearance tools

📌 Function Declaration: clearWishlist
FunctionDeclaration(
  'clearWishlist',
  'Delete all wishlist items from the database',
  parameters: <String, Schema>{},
),

📌 DB Method

Inside WishlistRepository:

Future<void> clearAll() async {
  await box.clear();
}

📌 Example Use Cases

User says:
“Wipe my wishlist.”
→ Agent calls clearWishlist.

User says:
“Remove all my goals.”
→ Agent calls clearWishlist.