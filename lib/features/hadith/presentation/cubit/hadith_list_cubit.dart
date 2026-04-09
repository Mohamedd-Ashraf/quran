import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/hadith_local_datasource.dart';
import '../../data/models/remote_hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import 'hadith_list_state.dart';

/// Manages hadith list for a single category (offline) or CDN section (online).
class HadithListCubit extends Cubit<HadithListState> {
  final HadithRepository _repository;
  final String categoryId;
  final int _pageSize;

  /// When non-null, serves ALL hadiths from the CDN for this section.
  final RemoteSection? remoteSection;

  bool get _isOnline => remoteSection != null;

  HadithListCubit({
    required HadithRepository repository,
    required this.categoryId,
    int pageSize = HadithLocalDataSource.defaultPageSize,
    this.remoteSection,
  }) : _repository = repository,
       _pageSize = pageSize,
       super(const HadithListState());

  /// Loads the first (and only) page.
  Future<void> loadInitial() async {
    if (state.status == HadithListStatus.loading) return;
    emit(state.copyWith(status: HadithListStatus.loading));

    try {
      if (_isOnline) {
        // CDN returns all hadiths for a section at once
        final items = await _repository.getSectionHadiths(
          sectionNumber: remoteSection!.sectionNumber,
          sectionNameAr: remoteSection!.nameAr,
        );
        emit(state.copyWith(
          status: HadithListStatus.loaded,
          items: items,
          hasReachedEnd: true,
          lastSortOrder: items.isNotEmpty ? items.last.sortOrder : null,
        ));
      } else {
        final items = await _repository.getHadithsPaginated(
          categoryId: categoryId,
          limit: _pageSize,
        );
        emit(state.copyWith(
          status: HadithListStatus.loaded,
          items: items,
          hasReachedEnd: items.length < _pageSize,
          lastSortOrder: items.isNotEmpty ? items.last.sortOrder : null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: HadithListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Loads the next page (offline only — CDN loads everything at once).
  Future<void> loadMore() async {
    if (_isOnline) return; // CDN sections are fully loaded in one call
    if (state.status == HadithListStatus.loading || state.hasReachedEnd) return;
    emit(state.copyWith(status: HadithListStatus.loading));

    try {
      final items = await _repository.getHadithsPaginated(
        categoryId: categoryId,
        limit: _pageSize,
        afterSortOrder: state.lastSortOrder,
      );
      final allItems = [...state.items, ...items];
      emit(state.copyWith(
        status: HadithListStatus.loaded,
        items: allItems,
        hasReachedEnd: items.length < _pageSize,
        lastSortOrder: items.isNotEmpty
            ? items.last.sortOrder
            : state.lastSortOrder,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HadithListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Retry after an error.
  Future<void> retry() async {
    if (state.items.isEmpty) {
      await loadInitial();
    } else {
      await loadMore();
    }
  }
}
