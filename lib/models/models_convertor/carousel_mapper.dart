import 'package:anymex/controllers/service_handler/service_handler.dart';
import 'package:anymex/controllers/services/community_service.dart';
import 'package:anymex/database/isar_models/offline_media.dart';
import 'package:anymex/models/Anilist/anilist_media_user.dart';
import 'package:anymex/models/Media/media.dart';
import 'package:anymex/models/Media/relation.dart';
import 'package:anymex/models/models_convertor/carousel/carousel_data.dart';
import 'package:anymex/utils/function.dart';
import 'package:anymex_extension_runtime_bridge/anymex_extension_runtime_bridge.dart';

extension DMediaMapper on DMedia {
  CarouselData toCarouselData({
    DataVariant variant = DataVariant.extension,
    bool isManga = false,
  }) {
    return CarouselData(
        id: url,
        title: title,
        poster: cover,
        extraData: '??',
        rating: '??',
        episodes: '??',
        releasing: false,
        servicesType: ServicesType.extensions);
  }
}

extension OfflineMediaMapper on OfflineMedia {
  CarouselData toCarouselData({
    DataVariant variant = DataVariant.offline,
    bool isManga = false,
  }) {
    return CarouselData(
        id: mediaId,
        title: name,
        poster: poster,
        source: currentChapter?.sourceName ?? currentEpisode?.source,
        servicesType: ServicesType.values[serviceIndex ?? 0],
        extraData:
            (currentChapter?.number ?? currentEpisode?.number ?? 0).toString(),
        rating: rating,
        episodes: isManga
            ? "${currentChapter?.number ?? 0} | ${totalChapters ?? '??'}"
            : "${currentEpisode?.number ?? 0} | ${totalEpisodes ?? '??'}",
        releasing: status == "RELEASING");
  }
}

extension RelationMapper on Relation {
  CarouselData toCarouselData(
      {DataVariant variant = DataVariant.relation, bool isManga = false}) {
    return CarouselData(
      id: id.toString(),
      title: title,
      poster: poster,
      source: type,
      servicesType: ServicesType.anilist,
      args: type,
      extraData: relationType,
      rating: averageScore,
      episodes: "??",
      releasing: status == "RELEASING",
    );
  }
}

extension TrackedMediaMapper on TrackedMedia {
  CarouselData toCarouselData(
      {DataVariant variant = DataVariant.anilist, bool isManga = false}) {
    return CarouselData(
        id: id.toString(),
        title: title,
        poster: poster,
        servicesType: servicesType,
        extraData: switch (type) {
          "ANIME" =>
            "${episodeCount ?? "??"} | ${releasedEpisodes != null ? releasedEpisodes ?? "??" : totalEpisodes ?? "??"}",
          "MANGA" => "${episodeCount ?? "??"} | ${chapterCount ?? "??"}",
          _ => episodeCount ?? "??"
        },
        rating: rating ?? score,
        episodes: switch (type) {
          "ANIME" =>
            "${episodeCount ?? "??"} | ${releasedEpisodes != null ? releasedEpisodes ?? "??" : totalEpisodes ?? "??"}",
          "MANGA" => "${episodeCount ?? "??"} | ${chapterCount ?? "??"}",
          _ => episodeCount ?? "??"
        },
        releasing: mediaStatus == "RELEASING",
        nextAiringEpisode: nextAiringEpisode);
  }
}

extension MediaMapper on Media {
  CarouselData toCarouselData(
      {DataVariant variant = DataVariant.regular, bool isManga = false}) {
    return CarouselData(
        id: id.toString(),
        title: title,
        servicesType: serviceType,
        poster: poster,
        extraData: rating.toString(),
        rating: rating.toString(),
        episodes: isManga ? totalChapters : totalEpisodes,
        releasing: status == "RELEASING",
        nextAiringEpisode: nextAiringEpisode);
  }
}

extension CommunityMediaMapper on CommunityMedia {
  CarouselData toCarouselData({bool isManga = false}) {
    return CarouselData(
        id: media.id.toString(),
        title: displayTitle,
        servicesType: ServicesType.anilist,
        poster: media.poster,
        extraData: media.rating.toString(),
        rating: media.rating.toString(),
        episodes: isManga ? media.totalChapters : media.totalEpisodes,
        releasing: media.status == "RELEASING",
        anilistUserId: anilistUserId,
        malUserId: malUserId,
        author: author,
        reason: reason);
  }
}
