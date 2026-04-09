import 'package:equatable/equatable.dart';

import '../../data/models/remote_hadith.dart';

enum HadithSectionsStatus { initial, loading, loaded, error }

class HadithSectionsState extends Equatable {
  final HadithSectionsStatus status;
  final List<RemoteSection> sections;
  final String? errorMessage;

  const HadithSectionsState({
    this.status = HadithSectionsStatus.initial,
    this.sections = const [],
    this.errorMessage,
  });

  HadithSectionsState copyWith({
    HadithSectionsStatus? status,
    List<RemoteSection>? sections,
    String? errorMessage,
  }) {
    return HadithSectionsState(
      status: status ?? this.status,
      sections: sections ?? this.sections,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, sections, errorMessage];
}
