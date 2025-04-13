import 'package:intl/intl.dart';

class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String content;
  final String url;
  final String? imageUrl;
  final DateTime publishDate;
  final String sourceId;
  final String sourceName;
  bool isFavorite;
  bool isRead;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.url,
    this.imageUrl,
    required this.publishDate,
    required this.sourceId,
    required this.sourceName,
    this.isFavorite = false,
    this.isRead = false,
  });

  factory NewsArticle.fromMap(Map<String, dynamic> map) {
    return NewsArticle(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      content: map['content'] ?? '',
      url: map['url'] ?? '',
      imageUrl: map['imageUrl'],
      publishDate: DateTime.parse(map['publishDate']),
      sourceId: map['sourceId'] ?? '',
      sourceName: map['sourceName'] ?? '',
      isFavorite: map['isFavorite'] == 1,
      isRead: map['isRead'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'url': url,
      'imageUrl': imageUrl,
      'publishDate': publishDate.toIso8601String(),
      'sourceId': sourceId,
      'sourceName': sourceName,
      'isFavorite': isFavorite ? 1 : 0,
      'isRead': isRead ? 1 : 0,
    };
  }

  String get formattedPublishDate {
    final now = DateTime.now();
    final difference = now.difference(publishDate);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      } else {
        return '${difference.inHours} hr ago';
      }
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final formatter = DateFormat('MMM d, yyyy');
      return formatter.format(publishDate);
    }
  }

  NewsArticle copyWith({
    String? id,
    String? title,
    String? description,
    String? content,
    String? url,
    String? imageUrl,
    DateTime? publishDate,
    String? sourceId,
    String? sourceName,
    bool? isFavorite,
    bool? isRead,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      url: url ?? this.url,
      imageUrl: imageUrl ?? this.imageUrl,
      publishDate: publishDate ?? this.publishDate,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      isFavorite: isFavorite ?? this.isFavorite,
      isRead: isRead ?? this.isRead,
    );
  }
}
