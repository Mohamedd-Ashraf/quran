import 'package:equatable/equatable.dart';

import '../../data/datasources/hadith_firestore_datasource.dart';

enum HadithSectionsStatus { initial, loading, loaded, error }

class HadithSectionsState extends Equatable {
  final HadithSectionsStatus status;
  final List<BukhariBook> books;
  final String? errorMessage;

  const HadithSectionsState({
    this.status = HadithSectionsStatus.initial,
    this.books = const [],
    this.errorMessage,
  });

  HadithSectionsState copyWith({
    HadithSectionsStatus? status,
    List<BukhariBook>? books,
    String? errorMessage,
  }) {
    return HadithSectionsState(
      status: status ?? this.status,
      books: books ?? this.books,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, books, errorMessage];
}
