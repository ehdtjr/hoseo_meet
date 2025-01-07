class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? errorMessage;
  final String? accessToken;
  final String? refreshToken;

  AuthState({
    required this.isLoading,
    required this.isLoggedIn,
    this.errorMessage,
    this.accessToken,
    this.refreshToken,
  });

  factory AuthState.initial() => AuthState(
    isLoading: false,
    isLoggedIn: false,
    errorMessage: null,
    accessToken: null,
    refreshToken: null,
  );

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? errorMessage,
    String? accessToken,
    String? refreshToken,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      errorMessage: errorMessage,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}