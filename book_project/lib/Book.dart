class Book {
  final String title;
  final String author;
  final String coverUrl;
  final String genre;
  final String publisher;
  final String description;
  final String isbn;
  final List<String> authors;
  final String generatedDescription;

  Book({
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.genre,
    required this.publisher,
    required this.description,
    required this.isbn,
    required this.authors,
    required this.generatedDescription,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      title: json['title'] ?? 'Unknown Title',
      author: (json['authors'] as List?)?.join(', ') ?? 'Unknown Author',
      coverUrl: json['imageLinks']?['thumbnail'] ?? '',
      genre: (json['categories'] != null && json['categories'].isNotEmpty)
          ? json['categories'][0]
          : 'Unknown',
      publisher: json['publisher'] ?? 'N/A',
      description: json['description'] ?? 'No Description Available',
      isbn: json['industryIdentifiers']?[0]['identifier'] ?? 'N/A',
      authors: List<String>.from(json['authors'] ?? []),
      generatedDescription: json['description'] ?? 'No generated description available.',
    );
  }
}
