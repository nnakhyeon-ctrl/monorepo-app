enum SocialProvider { google, kakao, apple }

class SocialChallengeData {
  factory SocialChallengeData.fromJson(Map<String, dynamic> json) {
    final values = [json['challengeId'], json['state'], json['nonce']];
    if (values.any(
      (s) => s is! String || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(s),
    )) {
      throw const FormatException('social challenge');
    }
    return SocialChallengeData._(
      values[0] as String,
      values[1] as String,
      values[2] as String,
    );
  }
  SocialChallengeData._(this.id, this.state, this.nonce);
  final String id, state, nonce;
  @override
  String toString() => 'SocialChallengeData([redacted])';
}

class SocialProof {
  SocialProof(this.provider, this.idToken, {this.accessToken});
  final SocialProvider provider;
  final String idToken;
  final String? accessToken;
  Map<String, Object?> toJson() => {
    'kind': '${provider.name}-id-token',
    'idToken': idToken,
    if (accessToken != null) 'accessToken': accessToken,
  };
  @override
  String toString() => 'SocialProof([redacted])';
}

abstract interface class SocialProviderClient {
  bool configured(SocialProvider provider);
  Future<SocialProof> authorize(
    SocialProvider provider,
    SocialChallengeData challenge, {
    bool kakaoAccountOnly = false,
  });
  Future<void> clear();
}
