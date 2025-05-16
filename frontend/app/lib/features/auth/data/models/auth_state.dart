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

class Register {
  final bool success;
  final String? message;
  final String? error;

  Register({
    required this.success,
    this.message,
    this.error,
  });

  factory Register.success(String message) {
    return Register(success: true, message: message);
  }

  factory Register.failure(String error) {
    return Register(success: false, error: error);
  }
}

class RegisterRequest {
  final String email;
  final String password;
  final String name;
  final String gender;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
    required this.gender,
  });

  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "password": password,
      "name": name,
      "gender": gender,
    };
  }
}

