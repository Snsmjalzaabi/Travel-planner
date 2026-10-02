/// Local activity recommendations — no network, no API key.
///
/// Recommendations are scored against the trip's destination, travel dates
/// (season + time of day), trip vibe (family / friends / girls / boys /
/// couple / solo / business) and group size. Everything is a local curated
/// dataset, so it works offline on the Pi-hosted build.
///
/// Set [kUseLiveApi] to true later if you want to layer a real
/// places/attractions API on top; the scoring API stays the same.
library;

/// The trip vibes the app understands.
const kTripTypes = <String, String>{
  'family': 'Family',
  'friends': 'Friends',
  'girls': 'Girls trip',
  'boys': 'Boys trip',
  'couple': 'Couple',
  'solo': 'Solo',
  'business': 'Business',
};

/// Age-suitability labels. Deliberately blunt — no euphemisms.
/// 'adult' means alcohol and/or late-night clubbing: 21+ only.
const kAgeRatings = <String, String>{
  'all': 'Family friendly — all ages',
  'teen': '16+ — no alcohol',
  'adult': '21+ ONLY — alcohol / nightlife',
};

/// Short label used on reason chips.
const kAgeShort = <String, String>{
  'all': 'All ages',
  'teen': '16+',
  'adult': '21+',
};

/// One suggestible thing to do.
class ActivityIdea {
  final String title;
  final String blurb;

  /// Culture / Food / Nature / Nightlife / Shopping / Sightseeing / Relax / Sport
  final String category;

  /// morning / afternoon / evening / night / any
  final String timeOfDay;

  /// spring / summer / autumn / winter / any
  final String season;

  /// Trip vibes this suits. Empty means it suits everyone.
  final List<String> suits;

  /// Destination keywords (lowercase). Empty means it works anywhere.
  final List<String> places;

  /// Minimum group size that makes sense (e.g. group tours need 2+).
  final int minGroup;

  /// Age suitability. 'all' = any age. 'teen' = 16+, no alcohol.
  /// 'adult' = 21+ only, involves alcohol and/or late-night clubbing.
  final String ageRating;

  /// Rough cost per person in USD.
  final int costUsd;

  /// Typical length in minutes.
  final int minutes;

  const ActivityIdea({
    required this.title,
    required this.blurb,
    required this.category,
    this.timeOfDay = 'any',
    this.season = 'any',
    this.suits = const [],
    this.places = const [],
    this.minGroup = 1,
    this.ageRating = 'all',
    this.costUsd = 0,
    this.minutes = 90,
  });
}

/// All curated ideas. Kept deliberately generic-but-useful so any
/// destination produces results; place-specific entries score higher when
/// the destination keyword matches.
const List<ActivityIdea> kActivityIdeas = [
  // ---------- Food ----------
  ActivityIdea(
    title: 'Breakfast at a local café',
    blurb: 'Start slow with shakshuka or baladi fuul — cheap, filling, and the fastest way to read a new city.',
    category: 'Food',
    timeOfDay: 'morning',
    minGroup: 1,
    costUsd: 8,
    minutes: 60,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Street food crawl',
    blurb: 'Three to four small stops instead of one big meal. Cheaper, faster, and more memorable.',
    category: 'Food',
    timeOfDay: 'evening',
    minGroup: 1,
    costUsd: 12,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Local cooking class',
    blurb: 'Market trip plus a hands-on class. Works well for families and friend groups.',
    category: 'Food',
    minGroup: 2,
    costUsd: 45,
    minutes: 180,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Night market',
    blurb: 'Best value evening out. Go hungry, go with cash, go together.',
    category: 'Food',
    timeOfDay: 'night',
    minGroup: 2,
    costUsd: 20,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Rooftop dinner with a view',
    blurb: 'Book ahead for sunset. Cocktails and wine with the meal — this is an adults-only evening.',
    category: 'Food',
    timeOfDay: 'evening',
    suits: ['couple', 'friends', 'girls'],
    minGroup: 2,
    costUsd: 55,
    minutes: 120,
    ageRating: 'adult',
  ),

  // ---------- Culture ----------
  ActivityIdea(
    title: 'National / city museum',
    blurb: 'The reliable rainy-day and jet-lag option. Start with the ground floor and work up.',
    category: 'Culture',
    minGroup: 1,
    costUsd: 10,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Old town walking tour',
    blurb: 'Meet at the main square, walk outward. Free tours usually run morning and late afternoon.',
    category: 'Culture',
    timeOfDay: 'morning',
    minGroup: 1,
    costUsd: 5,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Local mosque / temple visit',
    blurb: 'Dress modestly, shoes off, quiet inside. Often free and the most memorable stop of the day.',
    category: 'Culture',
    timeOfDay: 'morning',
    minGroup: 1,
    costUsd: 0,
    minutes: 60,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Live music or traditional show',
    blurb: 'Check what is on at the theatre or a folklore venue for the night you land.',
    category: 'Culture',
    timeOfDay: 'night',
    minGroup: 2,
    costUsd: 25,
    minutes: 120,
    ageRating: 'all',
  ),

  // ---------- Nature ----------
  ActivityIdea(
    title: 'Sunrise viewpoint',
    blurb: 'Early start, low cost, and you get the city to yourself before the crowds.',
    category: 'Nature',
    timeOfDay: 'morning',
    minGroup: 1,
    costUsd: 3,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'City park or botanical garden',
    blurb: 'Cheap, shaded, and easy for kids. Good mid-trip recovery day.',
    category: 'Nature',
    suits: ['family', 'solo', 'couple'],
    minGroup: 1,
    costUsd: 4,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Day trip out of town',
    blurb: 'One good excursion beats three museum hours. Book transport the night before.',
    category: 'Nature',
    timeOfDay: 'morning',
    minGroup: 2,
    costUsd: 40,
    minutes: 420,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Desert / dune outing',
    blurb: 'Sunset drives, camps or camel rides. Carry water and go with a local operator.',
    category: 'Nature',
    timeOfDay: 'evening',
    season: 'winter',
    suits: ['friends', 'boys'],
    minGroup: 2,
    costUsd: 60,
    minutes: 300,
    ageRating: 'all',
  ),

  // ---------- Relax ----------
  ActivityIdea(
    title: 'Hammam / spa afternoon',
    blurb: 'Half a day resets everyone. Especially worth it after a travel day.',
    category: 'Relax',
    timeOfDay: 'afternoon',
    minGroup: 1,
    costUsd: 35,
    minutes: 150,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Café hopping and people-watching',
    blurb: 'Two or three cafés, no agenda. The cheapest good plan for a short trip.',
    category: 'Relax',
    timeOfDay: 'afternoon',
    suits: ['friends', 'girls', 'couple', 'solo'],
    minGroup: 1,
    costUsd: 10,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Swim break',
    blurb: 'Hotel pool or a day pass. Keeps a family group happy on a hot day.',
    category: 'Relax',
    timeOfDay: 'afternoon',
    season: 'summer',
    suits: ['family', 'friends'],
    minGroup: 1,
    costUsd: 15,
    minutes: 120,
    ageRating: 'all',
  ),

  // ---------- Shopping ----------
  ActivityIdea(
    title: 'Souk / local market',
    blurb: 'Go mid-morning, bargain politely, and agree a price before you commit.',
    category: 'Shopping',
    timeOfDay: 'morning',
    minGroup: 1,
    costUsd: 0,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Mall / department store afternoon',
    blurb: 'Air-conditioned, restrooms, and everyone finds something. Good group fallback.',
    category: 'Shopping',
    timeOfDay: 'afternoon',
    suits: ['family', 'girls', 'boys'],
    minGroup: 1,
    costUsd: 0,
    minutes: 120,
    ageRating: 'all',
  ),

  // ---------- Sightseeing ----------
  ActivityIdea(
    title: 'Iconic landmark early',
    blurb: 'Beat the queues by going at opening. It is usually worth the early alarm.',
    category: 'Sightseeing',
    timeOfDay: 'morning',
    minGroup: 1,
    costUsd: 15,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Architecture / photo walk',
    blurb: 'Mosques, domes, metro stations. Bring a wide lens and no timetable.',
    category: 'Sightseeing',
    timeOfDay: 'afternoon',
    suits: ['friends', 'girls', 'solo'],
    minGroup: 1,
    costUsd: 0,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Skyline / observation deck',
    blurb: 'Good first-day orientation and a cheap way to get your bearings.',
    category: 'Sightseeing',
    timeOfDay: 'evening',
    minGroup: 1,
    costUsd: 18,
    minutes: 90,
    ageRating: 'all',
  ),

  // ---------- Nightlife ----------
  ActivityIdea(
    title: 'Rooftop bar night',
    blurb: 'Cocktails and loud music. Adults only, and expect to queue on a weekend.',
    category: 'Nightlife',
    timeOfDay: 'night',
    suits: ['friends', 'girls', 'boys'],
    minGroup: 2,
    costUsd: 30,
    minutes: 150,
    ageRating: 'adult',
  ),
  ActivityIdea(
    title: 'Dance or music club',
    blurb: 'Late-night clubbing with alcohol service. Adults only, and do not drive home.',
    category: 'Nightlife',
    timeOfDay: 'night',
    suits: ['friends', 'boys', 'girls'],
    minGroup: 3,
    costUsd: 35,
    minutes: 180,
    ageRating: 'adult',
  ),
  ActivityIdea(
    title: 'Shisha café or tea house',
    blurb: 'Shisha pipes and strong coffee. Adults only even though the tea is child-friendly.',
    category: 'Nightlife',
    timeOfDay: 'night',
    suits: ['friends', 'family'],
    minGroup: 2,
    costUsd: 12,
    minutes: 120,
    ageRating: 'adult',
  ),

  // ---------- Sport ----------
  ActivityIdea(
    title: 'Football match',
    blurb: 'Cheaper and louder than any tour. Family friendly at most league grounds, though some concourses serve alcohol.',
    category: 'Sport',
    timeOfDay: 'evening',
    suits: ['boys', 'friends'],
    minGroup: 2,
    costUsd: 15,
    minutes: 150,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Beach or water sports',
    blurb: 'Jet ski, banana boat, or just a shaded spot. Family favourite.',
    category: 'Sport',
    timeOfDay: 'afternoon',
    season: 'summer',
    suits: ['family', 'friends', 'boys'],
    minGroup: 2,
    costUsd: 25,
    minutes: 180,
    ageRating: 'all',
  ),

  // ---------- Business ----------
  ActivityIdea(
    title: 'Business lounge or coworking',
    blurb: 'Fast wifi and a quiet desk between meetings. Adults only due to the bar and phone calls.',
    category: 'Business',
    timeOfDay: 'morning',
    suits: ['business'],
    minGroup: 1,
    costUsd: 20,
    minutes: 180,
    ageRating: 'adult',
  ),
  ActivityIdea(
    title: 'Client dinner',
    blurb: 'Pick somewhere central and book early. Alcohol usually flows — cover it in the expense report.',
    category: 'Business',
    timeOfDay: 'evening',
    suits: ['business'],
    minGroup: 2,
    costUsd: 70,
    minutes: 120,
    ageRating: 'adult',
  ),

  // ---------- Place-specific ----------
  ActivityIdea(
    title: 'Registan and the Samarkand bazaar',
    blurb: 'Tilework in the morning light, then trade under the awnings. Pair with the Gur-e Amir complex.',
    category: 'Culture',
    timeOfDay: 'morning',
    season: 'spring',
    places: ['samarkand', 'uzbekistan', 'tashkent', 'uz'],
    minGroup: 1,
    costUsd: 10,
    minutes: 240,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Chimgan and the Fergana Valley',
    blurb: 'Swiss-looking lakes and cheap homestays an hour from Tashkent. Best as a two-day trip.',
    category: 'Nature',
    timeOfDay: 'morning',
    season: 'summer',
    places: ['tashkent', 'uzbekistan', 'uz'],
    minGroup: 2,
    costUsd: 35,
    minutes: 480,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Khiva walled city',
    blurb: 'Fewer tourists than Samarkand and almost intact. Stay the night if you can.',
    category: 'Culture',
    places: ['khiva', 'uzbekistan', 'uz'],
    minGroup: 1,
    costUsd: 15,
    minutes: 300,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Tashkent metro art',
    blurb: 'Every station is decorated differently and it costs a few cents to ride. Underrated.',
    category: 'Sightseeing',
    timeOfDay: 'morning',
    places: ['tashkent', 'uzbekistan', 'uz'],
    minGroup: 1,
    costUsd: 1,
    minutes: 60,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Dubai Marina and JBR walk',
    blurb: 'Flat, shaded, and open late. Easy first evening with a group of any size.',
    category: 'Sightseeing',
    timeOfDay: 'evening',
    places: ['dubai', 'uae', 'abu dhabi'],
    minGroup: 1,
    costUsd: 0,
    minutes: 120,
    ageRating: 'all',
  ),
  ActivityIdea(
    title: 'Desert safari and dune camp',
    blurb: 'Four-wheel drive into the red dunes, dinner under the stars, back late.',
    category: 'Nature',
    timeOfDay: 'evening',
    places: ['dubai', 'uae', 'abu dhabi'],
    suits: ['family', 'friends', 'boys'],
    minGroup: 2,
    costUsd: 95,
    minutes: 420,
    ageRating: 'all',
  ),
];

/// A recommendation with the score breakdown, so the UI can explain itself.
class RankedIdea {
  final ActivityIdea idea;
  final int score;
  final List<String> reasons;

  const RankedIdea(this.idea, this.score, this.reasons);
}

/// Recommendation settings the user controls.
class RecommendationQuery {
  final String destination;
  final DateTime when;
  final String timeOfDay;
  final String tripType;
  final int travellers;

  /// 'any' or one of morning / afternoon / evening / night.
  final String season;
  final int maxCostUsd;

  /// 'any' = show everything, 'family' = only all-ages ideas,
  /// 'adult' = allow 21+ (alcohol/nightlife) ideas through.
  final String ageFilter;

  const RecommendationQuery({
    required this.destination,
    required this.when,
    required this.timeOfDay,
    required this.tripType,
    required this.travellers,
    this.season = 'any',
    this.maxCostUsd = 0,
    this.ageFilter = 'any',
  });
}

/// The recommendation engine. Pure functions, no I/O.
class RecommendationService {
  const RecommendationService();

  /// Returns ideas ranked for [q], highest first.
  List<RankedIdea> recommend(RecommendationQuery q, {int limit = 20}) {
    final destTokens = _tokens(q.destination);
    final season = q.season == 'any' ? seasonOf(q.when) : q.season;

    final ranked = <RankedIdea>[];
    for (final idea in kActivityIdeas) {
      final score = _score(idea, q, destTokens, season);
      if (score > 0) ranked.add(RankedIdea(idea, score, _reasons(idea, q, destTokens, season)));
    }

    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.idea.title.compareTo(b.idea.title);
    });
    return ranked.take(limit).toList();
  }

  int _score(ActivityIdea idea, RecommendationQuery q, Set<String> destTokens, String season) {
    // Hard filter on age suitability before any scoring.
    if (q.ageFilter == 'family' && idea.ageRating != 'all') return 0;
    if (q.ageFilter == 'adult' && idea.ageRating == 'teen') return 0;

    var score = 10;

    if (q.ageFilter == 'family' && idea.ageRating == 'all') score += 15;
    if (idea.ageRating == 'adult' && q.tripType != 'family') score += 4;

    // Place match is the strongest signal.
    if (idea.places.isNotEmpty) {
      final hit = idea.places.any(destTokens.contains);
      if (!hit) return 0; // place-specific ideas must actually match
      score += 40;
    }

    if (idea.timeOfDay == q.timeOfDay) {
      score += 25;
    } else if (idea.timeOfDay == 'any') {
      score += 10;
    } else {
      score -= 12;
    }

    if (idea.season == season) {
      score += 15;
    } else if (idea.season != 'any') {
      score -= 10;
    }

    if (idea.suits.isNotEmpty && idea.suits.contains(q.tripType)) {
      score += 30;
    } else if (idea.suits.isNotEmpty) {
      score -= 8;
    }

    if (q.travellers >= idea.minGroup) {
      if (q.travellers >= 6 && idea.minGroup >= 3) score += 6; // big groups like group formats
    } else {
      score -= 15;
    }

    if (q.maxCostUsd > 0) {
      if (idea.costUsd == 0) {
        score += 8;
      } else if (idea.costUsd <= q.maxCostUsd) {
        score += 5;
      } else {
        score -= 20;
      }
    }

    return score > 0 ? score : 0;
  }

  List<String> _reasons(ActivityIdea idea, RecommendationQuery q, Set<String> destTokens, String season) {
    final reasons = <String>[];
    if (idea.places.isNotEmpty && idea.places.any(destTokens.contains)) {
      reasons.add('Popular in ${q.destination}');
    }
    if (idea.suits.contains(q.tripType)) {
      final label = kTripTypes[q.tripType] ?? q.tripType;
      reasons.add('Good for a $label');
    }
    if (idea.timeOfDay == q.timeOfDay) {
      reasons.add('Best in the ${q.timeOfDay}');
    }
    if (idea.season == season) reasons.add('Right for ${_seasonLabel(season)}');
    if (q.travellers >= 6) reasons.add('Works for a group of ${q.travellers}');
    if (idea.ageRating == 'adult') reasons.add('21+ · alcohol');
    if (idea.costUsd == 0) reasons.add('Free');
    return reasons;
  }

  Set<String> _tokens(String destination) {
    return destination
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  static String _seasonLabel(String s) => switch (s) {
        'spring' => 'spring',
        'summer' => 'summer',
        'autumn' => 'autumn',
        _ => 'winter',
      };
}

/// Northern-hemisphere season for a date.
String seasonOf(DateTime date) {
  final m = date.month;
  if (m >= 3 && m <= 5) return 'spring';
  if (m >= 6 && m <= 8) return 'summer';
  if (m >= 9 && m <= 11) return 'autumn';
  return 'winter';
}

/// Maps a clock hour to the activity buckets used by the engine.
String timeOfDayFor(int hour) {
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  if (hour < 21) return 'evening';
  return 'night';
}
