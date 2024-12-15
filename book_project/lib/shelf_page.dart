import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';  

class ShelfPage extends StatefulWidget {
  @override
  _ShelfPageState createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

   Future<List<Map<String, dynamic>>> _fetchBooks() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shelf')
        .get();

     return snapshot.docs.map((doc) {
      return {
        'isbn': doc['isbn'],
        'name': doc['name'],
        'author': doc['author'],
        'coverUrl': doc['coverUrl'],
      };
    }).toList();
  }
 
Future<void> _addOrUpdateCommentAndRating(
    BuildContext context, String isbn) async {
  final user = _auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("You need to be logged in to comment and rate."),
    ));
    return;
  }

   TextEditingController commentController = TextEditingController();
  double rating = 0;

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Add Comment & Rating'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: commentController,
              decoration: InputDecoration(hintText: 'Enter your comment'),
              maxLines: null,  
              keyboardType: TextInputType.multiline,  
              style: TextStyle(fontSize: 16),
              textInputAction: TextInputAction.newline,  
            ),
            SizedBox(height: 10),
        
            RatingBar.builder(
              initialRating: rating,
              minRating: 1,
              itemSize: 40,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemBuilder: (context, _) => Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (newRating) {
                rating = newRating;  
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
             
              final bookRef = FirebaseFirestore.instance
                  .collection('books')
                  .doc(isbn)
                  .collection('comments')
                  .doc(user.uid);  

              await bookRef.set({
                'comment': commentController.text,
                'rating': rating,
                'timestamp': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));  

              Navigator.pop(context);
            },
            child: Text('Submit'),
          ),
        ],
      );
    },
  );
}


   Future<void> _deleteBook(String isbn) async {
    final user = _auth.currentUser;
    if (user != null) {
      final userBooksCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shelf');

      final querySnapshot = await userBooksCollection
          .where('isbn', isEqualTo: isbn)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      print('Book removed from shelf');
    } else {
      print('No user logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Shelf'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(

        future: _fetchBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No books in your shelf.'));
          }

          final books = snapshot.data!;

          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];

              return ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                leading: book['coverUrl'] != null && book['coverUrl'] != ''
                    ? Image.network(
                        book['coverUrl'],
                        width: 50,
                        height: 75,
                        fit: BoxFit.cover,
                      )
                    : Container(width: 50, height: 75, color: Colors.grey),
                title: Text(book['name'] ?? 'No title'),
                subtitle: Text('Author: ${book['author']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.comment),
                      onPressed: () => _addOrUpdateCommentAndRating(
                          context, book['isbn']),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () async {
                         bool? confirmDelete = await showDialog<bool>( 
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete Book'),
                            content: Text('Are you sure you want to delete this book?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        );

                         if (confirmDelete == true) {
                          await _deleteBook(book['isbn']);
                          setState(() {});  
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Book deleted from your shelf."),
                          ));
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
