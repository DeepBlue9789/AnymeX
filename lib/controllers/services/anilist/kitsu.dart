import 'dart:math' as math;
import 'dart:convert';
import 'package:anymex/utils/logger.dart';
import 'package:get/get.dart';

import 'package:anymex/database/isar_models/episode.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

class Kitsu {
  static Future<List<Episode>> fetchKitsuEpisodes(
      String id, List<Episode> episodes) async {
    final query = '''
    query {
      lookupMapping(externalId: $id, externalSite: ANILIST_ANIME) {
        __typename
        ... on Anime {
          id
          episodes(first: 2000) {
            nodes {
              number
              titles {
                canonicalLocale
              }
              description
              thumbnail {
                original {
                  url
                }
              }
            }
          }
        }
      }
    }
    ''';

    final result = await fetchFromKitsu(query);
    if (result == null) {
      Logger.i("Kitsu request returned null for animeId $id");
      return episodes;
    }
    final mapping = result['data']?['lookupMapping'];
    if (mapping == null) {
      Logger.i("Kitsu lookupMapping was null for animeId $id");
      return episodes;
    }
    final kitsuEpisodes = mapping['episodes']?['nodes'] as List?;
    if (kitsuEpisodes == null || kitsuEpisodes.isEmpty) {
      Logger.i("No Kitsu episode nodes found for animeId $id");
      return episodes;
    }
    final nodes = kitsuEpisodes.whereType<Map<String, dynamic>>().toList();
    final kitsuMap = <String, Map<String, dynamic>>{};
    for (final node in nodes) {
      final numStr = node['number']?.toString();
      if (numStr != null) kitsuMap[numStr] = node;
    }

    for (int i = 0; i < episodes.length; i++) {
      final episode = episodes[i];
      final node = kitsuMap[episode.number] ??
          nodes.firstWhereOrNull((n) {
            final nNum = n['number']?.toString();
            return nNum != null &&
                double.tryParse(nNum) != null &&
                double.tryParse(nNum) == double.tryParse(episode.number);
          }) ??
          (i < nodes.length ? nodes[i] : null);

      if (node != null) {
        final title = node['titles']?['canonicalLocale']?.toString();
        final thumb = node['thumbnail']?['original']?['url']?.toString();
        final desc = node['description']?.toString();

        if (title != null && title.isNotEmpty) {
          episode.title = title;
        }
        if (thumb != null && thumb.isNotEmpty) {
          episode.thumbnail = thumb;
        }
        if (desc != null && desc.isNotEmpty) {
          episode.desc = desc;
        }
      }
    }
    return episodes;
  }

  static Future<dynamic> fetchFromKitsu(String query) async {
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };

    try {
      final response = await post(
        Uri.parse('https://kitsu.io/api/graphql'),
        headers: headers,
        body: jsonEncode({"query": query}),
      );
      final json = await jsonDecode(response.body);
      return json;
    } catch (e) {
      debugPrint("Error fetching Kitsu data: $e");
      return null;
    }
  }
}
