import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Book.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class BookDetailPage extends StatefulWidget {
  final Book book;

  BookDetailPage({required this.book});

  @override
  _BookDetailPageState createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String bookDescription = 'Loading description...';
  bool isBookInShelf = false;
  double averageRating = 0.0;
  List<String> comments = [];

   Future<void> _fetchsummries() async {
  if (comments.isEmpty) {
    setState(() {
      bookDescription = 'There are no comments yet';
    });
    return; 
  }

  final apiKey = '';  //I can't push open ai api to github

  final url = Uri.parse('https://api.openai.com/v1/chat/completions');
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  final data = {
    'model': 'gpt-4',
    'messages': [
      {
        'role': 'user',
        'content': 'Summarize the following comments: ${comments.join("\n")}',
      }
    ],
    'max_tokens': 150,
    'temperature': 0.7,
  };

  final response = await http.post(
    url,
    headers: headers,
    body: json.encode(data),
  );

  if (response.statusCode == 200) {
    final responseBody = json.decode(response.body);
    setState(() {
      bookDescription = responseBody['choices'][0]['message']['content'];
    });
  } else {
    setState(() {
      bookDescription = 'Failed to fetch summaries.';
    });
  }
}

 
  Future<void> _fetchAverageRating() async {
    final bookRef = FirebaseFirestore.instance.collection('books').doc(widget.book.isbn);
    final ratingsSnapshot = await bookRef.collection('comments').get();

    if (ratingsSnapshot.docs.isNotEmpty) {
      double totalRating = 0;
      int ratingCount = 0;

      ratingsSnapshot.docs.forEach((doc) {
        totalRating += doc['rating'];
        ratingCount++;
      });

      setState(() {
        averageRating = totalRating / ratingCount;
      });
    } else {
      setState(() {
        averageRating = 0.0;  
      });
    }
  }

   Future<void> _fetchComments() async {
    final bookRef = FirebaseFirestore.instance.collection('books').doc(widget.book.isbn);
    final commentsSnapshot = await bookRef.collection('comments').get();

    List<String> loadedComments = [];
    commentsSnapshot.docs.forEach((doc) {
      loadedComments.add(doc['comment']);
    });

    setState(() {
      comments = loadedComments;
    }); 
     _fetchsummries();
  }

   Future<void> _checkIfBookInShelf() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userBooksCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shelf');

      final querySnapshot = await userBooksCollection
          .where('isbn', isEqualTo: widget.book.isbn)
          .get();

      setState(() {
        isBookInShelf = querySnapshot.docs.isNotEmpty;
      });
    }
  }

   Future<void> _addToShelf() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userBooksCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shelf');

      await userBooksCollection.add({
        'isbn': widget.book.isbn,
        'name': widget.book.title,
        'author': widget.book.authors.join(", "),
        'coverUrl': widget.book.coverUrl,
        'genre': widget.book.genre,  
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        isBookInShelf = true;
      });

      print('Book added to shelf');
    } else {
      print('No user logged in');
    }
  }

   Future<void> _removeFromShelf() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userBooksCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shelf');

      final querySnapshot = await userBooksCollection
          .where('isbn', isEqualTo: widget.book.isbn)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        isBookInShelf = false;
      });

      print('Book removed from shelf');
    } else {
      print('No user logged in');
    }
  }

  @override
  void initState() {
    super.initState();

    _checkIfBookInShelf();  
    _fetchAverageRating();  
    _fetchComments(); 
  
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  if (widget.book.coverUrl.isNotEmpty)
                    Image.network(
                      widget.book.coverUrl,
                      width: 150,
                      height: 225,
                      fit: BoxFit.cover,
                    ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.title,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text('Author(s): ${widget.book.authors.join(", ")}'),
                        Text('Genres: ${widget.book.genre}'),
                        Text('Average Rating: ${averageRating.toStringAsFixed(1)} ★'),
                        
                        RatingBar.builder(
                        initialRating: averageRating,
                        minRating: 1,
                        itemSize: 30,
                        allowHalfRating: true,
                        ignoreGestures: true, 
                        itemBuilder: (context, _) => Icon(
                        Icons.star,
                        color: Colors.amber,
                        ),
                        onRatingUpdate: (rating) {
                         print(rating);
                        },
                        )

                      ],
                    ),
                  ),
                ],
              ),
              Text('Description: ${widget.book.description}'),
              SizedBox(height: 20),
            
              Text(
                
                'Summries of user comments: \n$bookDescription',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.justify,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isBookInShelf ? _removeFromShelf : _addToShelf,
                child: Text(isBookInShelf ? 'Remove from Shelf' : 'Add to Shelf'),
              ),
              SizedBox(height: 20),
               if (comments.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comments:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    ...comments.map((comment) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Container(
                            padding: EdgeInsets.all(5.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(comment),
                          ),
                        )),
                  ],
                ),
              if (comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text('No comments available.'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
