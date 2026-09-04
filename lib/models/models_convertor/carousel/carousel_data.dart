import 'package:anymex/controllers/service_handler/service_handler.dart';
import 'package:anymex/models/Media/media.dart';

class CarouselData {
  String? id;
  String? title;
  String? poster;
  String? extraData;
  String? rating;
  String? episodes;
  String? source;
  String? args;
  ServicesType servicesType;
  bool releasing;
  NextAiringEpisode? nextAiringEpisode;

  int? anilistUserId;
  int? malUserId;
  String? author;
  String? reason;

  CarouselData({
    this.id,
    this.title,
    this.poster,
    this.extraData,
    this.rating,
    this.episodes,
    this.source,
    this.args,
    required this.servicesType,
    required this.releasing,
    this.nextAiringEpisode,
    this.anilistUserId,
    this.malUserId,
    this.author,
    this.reason,
  });
}
