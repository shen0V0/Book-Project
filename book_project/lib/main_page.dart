import 'dart:convert';
import 'package:book_project/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'Book.dart';
import 'shelf_page.dart';
import 'book_detail_page.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final String _googleBooksApiUrl = 'https://www.googleapis.com/books/v1/volumes';
  final _auth = FirebaseAuth.instance;
  List<Book> _books = [];
  List<Book> _userShelf = [];  
  String _searchQuery = ''; 

  final List<String> _defaultGenres = [
    'Fantasy', 'Science Fiction', 'Mystery', 'Romance', 'Non-fiction', 'Thriller', 'Biography'
  ];

  List<String> allGenres = [];

  @override
  void initState() {
    super.initState();
    _fetchBooks();   
    _fetchUserShelf();  
  }

   Future<void> _fetchBooks() async {
    final url = '$_googleBooksApiUrl?q=$_searchQuery&maxResults=40&key=AIzaSyD3xSlDx17GCsUiyRzF_mgy2kTGs6v8eCo';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _books = (data['items'] as List)
            .map((item) => Book.fromJson(item['volumeInfo']))
            .toList();
      });
    } else {
      print('Failed to load books');
     }
  }

   Future<void> _fetchUserShelf() async {
    final user = _auth.currentUser;

    if (user != null) {
      final userBooksCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shelf');
      
       final querySnapshot = await userBooksCollection.get();
      
       allGenres.clear();

      setState(() {
        _userShelf = querySnapshot.docs.map((doc) {
           final String genre = doc['genre'] ?? 'Unknown';  
          allGenres.add(genre);   

          return Book.fromJson(doc.data());
        }).toList();
      });

       _setSearchQueryBasedOnShelf();  
    }
  }

   void _setSearchQueryBasedOnShelf() {
    if (allGenres.isEmpty) {
       _searchQuery = _defaultGenres[(DateTime.now().millisecondsSinceEpoch % _defaultGenres.length)];
    } else {
       _searchQuery = allGenres[(DateTime.now().millisecondsSinceEpoch % allGenres.length)];
    }

    print("Search query set to: $_searchQuery");

    _fetchBooks();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchQuery = _defaultGenres[(DateTime.now().millisecondsSinceEpoch % _defaultGenres.length)];
         _fetchUserShelf();
      } else {
        _searchQuery = query;
      }
    });
    _fetchBooks();  
  }

   Future<void> _logout() async {
    await _auth.signOut();
     Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );  
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Main Page'),
        leading: IconButton(
          icon: Icon(Icons.book),
          onPressed: () {
           
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ShelfPage()),
            );
          },
        ),
        actions: [
          if (user != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(
                width: 200,
                child: TextField(
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search books...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(user?.displayName ?? 'Guest'),
                  IconButton(
                    icon: Icon(Icons.account_box),
                    onPressed: () {
                     },
                  ),
                  IconButton(
                    icon: Icon(Icons.exit_to_app),  
                    onPressed: _logout,  
                  ),
                ],
              ),
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];

          return Card(
            margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookDetailPage(book: book),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: Row(
                  children: [
                     if (book.coverUrl.isNotEmpty)
                      Image.network(
                        book.coverUrl,
                        width: 100,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    SizedBox(width: 10),  

                     Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                            book.title,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text('Author(s): ${book.authors.join(", ")}'),
                          Text('Publisher: ${book.publisher}'),
                          Text('Genres: ${book.genre}'),
                          Text('ISBN: ${book.isbn}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
