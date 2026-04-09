import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/hadith_repository.dart';
import 'hadith_sections_state.dart';

/// Loads the Bukhari section list from the CDN API (cache-first).
class HadithSectionsCubit extends Cubit<HadithSectionsState> {
  final HadithRepository _repository;

  HadithSectionsCubit({
    required HadithRepository repository,
  })  : _repository = repository,
        super(const HadithSectionsState());

  Future<void> load({bool forceRefresh = false}) async {
    if (state.status == HadithSectionsStatus.loading) return;
    emit(state.copyWith(status: HadithSectionsStatus.loading));

    try {
      final sections = await _repository.getBukhariSections(
        forceRefresh: forceRefresh,
      );
      emit(state.copyWith(
        status: HadithSectionsStatus.loaded,
        sections: sections,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HadithSectionsStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> retry() => load();
  Future<void> refresh() => load(forceRefresh: true);
}
