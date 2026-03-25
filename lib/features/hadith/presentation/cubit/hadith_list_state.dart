import 'package:equatable/equatable.dart';

import '../../data/models/hadith_list_item.dart';

enum HadithListStatus { initial, loading, loaded, error }

class HadithListState extends Equatable {
  final HadithListStatus status;
  final List<HadithListItem> items;
  final bool hasReachedEnd;
  final String? errorMessage;

  /// Cursor for the next page (hadith number or sort_order of the last loaded item).
  final int? lastSortOrder;

  const HadithListState({
    this.status = HadithListStatus.initial,
    this.items = const [],
    this.hasReachedEnd = false,
    this.errorMessage,
    this.lastSortOrder,
  });

  HadithListState copyWith({
    HadithListStatus? status,
    List<HadithListItem>? items,
    bool? hasReachedEnd,
    String? errorMessage,
    int? lastSortOrder,
  }) {
    return HadithListState(
      status: status ?? this.status,
      items: items ?? this.items,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      errorMessage: errorMessage,
      lastSortOrder: lastSortOrder ?? this.lastSortOrder,
    );
  }

  bool get isLoadingMore =>
      status == HadithListStatus.loading && items.isNotEmpty;

  @override
  List<Object?> get props => [
    status,
    items,
    hasReachedEnd,
    errorMessage,
    lastSortOrder,
  ];
}
